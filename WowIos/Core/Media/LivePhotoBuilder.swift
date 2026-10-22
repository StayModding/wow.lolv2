import Foundation
import AVFoundation
import Photos
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

struct LivePhotoOptions {
    var trim: ClosedRange<Double>? = nil
    var maxDimension: CGFloat? = nil
    var jpegQuality: Double = 0.96
    var stripMetadata: Bool = false
    var includeAudio: Bool = false
}

struct LivePhotoBundle {
    let stillURL: URL
    let videoURL: URL
    let identifier: String
    let duration: Double
    let pixelSize: CGSize
}

enum MediaError: LocalizedError {
    case noVideoTrack
    case unreadable(String)
    case writeFailed(String)
    case photoDenied
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "That file has no video track."
        case .unreadable(let reason):
            return "Could not read the file: \(reason)"
        case .writeFailed(let reason):
            return "Writing the Live Photo failed: \(reason)"
        case .photoDenied:
            return "wow-ios needs add-only access to Photos to save wallpapers."
        case .cancelled:
            return "Cancelled."
        }
    }
}

/// Turns any video into a paired Live Photo (still JPEG + MOV sharing one content
/// identifier) which is what iOS actually accepts as a video wallpaper. Frames are
/// copied through a passthrough writer, so nothing is re-encoded, watermarked or
/// downscaled unless you ask for it.
enum LivePhotoBuilder {

    // MARK: Public pipeline

    static func makeLivePhoto(fromVideo source: URL, options: LivePhotoOptions) async throws -> LivePhotoBundle {
        let asset = AVURLAsset(url: source, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else { throw MediaError.noVideoTrack }

        let assetDuration = try await asset.load(.duration).seconds
        guard assetDuration.isFinite, assetDuration > 0.1 else {
            throw MediaError.unreadable("the video is too short")
        }

        let range = clamp(range: options.trim, duration: assetDuration)
        let identifier = UUID().uuidString

        let frame = try await stillImage(asset: asset, at: range.lowerBound + 0.05, maxDimension: options.maxDimension)
        let stillURL = temporaryURL(fileExtension: "jpg")
        try writeJPEG(frame, to: stillURL, quality: options.jpegQuality, identifier: identifier)

        let videoURL = temporaryURL(fileExtension: "mov")
        try await transcode(asset: asset,
                            track: videoTrack,
                            range: range,
                            to: videoURL,
                            identifier: identifier,
                            includeAudio: options.includeAudio)

        let natural = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let oriented = natural.applying(transform)
        let size = CGSize(width: abs(oriented.width), height: abs(oriented.height))

        return LivePhotoBundle(stillURL: stillURL,
                               videoURL: videoURL,
                               identifier: identifier,
                               duration: range.upperBound - range.lowerBound,
                               pixelSize: size)
    }

    /// A plain photo wallpaper: re-encoded at the requested ceiling, no overlay added.
    static func makeStill(fromImage source: URL, options: LivePhotoOptions) throws -> URL {
        guard let src = CGImageSourceCreateWithURL(source as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw MediaError.unreadable("image could not be decoded")
        }
        let scaled = resize(image, maxDimension: options.maxDimension)
        let url = temporaryURL(fileExtension: "jpg")
        try writeJPEG(scaled, to: url, quality: options.jpegQuality, identifier: nil)
        return url
    }

    /// Export for sharing/saving: copies the master file untouched (HD, no watermark).
    /// With stripMetadata on it rewrites the container so camera/GPS metadata is dropped
    /// while the encoded frames stay bit-identical.
    static func exportMaster(from source: URL, stripMetadata: Bool) async throws -> URL {
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let destination = temporaryURL(fileExtension: ext, prefix: "wowios-export")
        if !stripMetadata {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        }

        let asset = AVURLAsset(url: source)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { throw MediaError.noVideoTrack }
        let duration = try await asset.load(.duration).seconds
        let fileType: AVFileType = ext.lowercased() == "mp4" ? .mp4 : .mov
        try await transcode(asset: asset,
                            track: track,
                            range: 0...max(0.2, duration),
                            to: destination,
                            identifier: nil,
                            includeAudio: true,
                            fileType: fileType)
        return destination
    }

    // MARK: Photos

    static func saveLivePhotoToLibrary(_ bundle: LivePhotoBundle) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw MediaError.photoDenied }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let stillOptions = PHAssetResourceCreationOptions()
            stillOptions.originalFilename = "wowios-still.jpg"
            stillOptions.shouldMoveFile = true
            request.addResource(with: .photo, fileURL: bundle.stillURL, options: stillOptions)

            let videoOptions = PHAssetResourceCreationOptions()
            videoOptions.originalFilename = "wowios-video.mov"
            videoOptions.shouldMoveFile = true
            request.addResource(with: .pairedVideo, fileURL: bundle.videoURL, options: videoOptions)
        }
    }

    static func savePhotoToLibrary(_ url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw MediaError.photoDenied }
        // Copy first: the source may be a library master that must stay on disk.
        let staged = temporaryURL(fileExtension: url.pathExtension.isEmpty ? "jpg" : url.pathExtension, prefix: "wowios-save")
        try? FileManager.default.removeItem(at: staged)
        try FileManager.default.copyItem(at: url, to: staged)
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = staged.lastPathComponent
            options.shouldMoveFile = true
            request.addResource(with: .photo, fileURL: staged, options: options)
        }
    }

    // MARK: Still extraction

    static func stillImage(asset: AVAsset, at seconds: Double, maxDimension: CGFloat?) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        if let maxDimension {
            generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        }
        let result = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
        return result.image
    }

    // MARK: Writers

    static func writeJPEG(_ image: CGImage, to url: URL, quality: Double, identifier: String?) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL,
                                                              UTType.jpeg.identifier as CFString,
                                                              1,
                                                              nil) else {
            throw MediaError.writeFailed("could not open \(url.lastPathComponent)")
        }
        var properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: max(0.1, min(1.0, quality))
        ]
        // Key 17 is the Apple maker-note slot Photos uses to pair a still with its video.
        if let identifier {
            properties[kCGImagePropertyMakerAppleDictionary] = ["17": identifier]
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw MediaError.writeFailed("JPEG finalize failed")
        }
    }

    private static func transcode(asset: AVAsset,
                                  track: AVAssetTrack,
                                  range: ClosedRange<Double>,
                                  to url: URL,
                                  identifier: String?,
                                  includeAudio: Bool,
                                  fileType: AVFileType = .mov) async throws {
        try? FileManager.default.removeItem(at: url)

        let seconds = max(0.2, range.upperBound - range.lowerBound)
        let cutRange = CMTimeRange(start: CMTime(seconds: range.lowerBound, preferredTimescale: 600),
                                   duration: CMTime(seconds: seconds, preferredTimescale: 600))

        var readAsset: AVAsset = asset
        var readVideoTrack: AVAssetTrack = track
        var readAudioTrack: AVAssetTrack?
        if includeAudio {
            readAudioTrack = (try? await asset.loadTracks(withMediaType: .audio))?.first
        }

        // Cutting through a composition re-bases timing to zero. Without this a clip
        // trimmed from the middle keeps its original start timestamp and the Live
        // Photo opens on dead air before the first frame.
        if range.lowerBound > 0.05 {
            let composition = AVMutableComposition()
            if let cutVideo = composition.addMutableTrack(withMediaType: .video,
                                                          preferredTrackID: kCMPersistentTrackID_Invalid) {
                try cutVideo.insertTimeRange(cutRange, of: track, at: .zero)
                readVideoTrack = cutVideo
            }
            if let sourceAudio = readAudioTrack,
               let cutAudio = composition.addMutableTrack(withMediaType: .audio,
                                                          preferredTrackID: kCMPersistentTrackID_Invalid) {
                try? cutAudio.insertTimeRange(cutRange, of: sourceAudio, at: .zero)
                readAudioTrack = cutAudio
            }
            readAsset = composition
        }

        let reader = try AVAssetReader(asset: readAsset)
        if range.lowerBound <= 0.05 {
            reader.timeRange = CMTimeRange(start: .zero, duration: cutRange.duration)
        }

        let videoOutput = AVAssetReaderTrackOutput(track: readVideoTrack, outputSettings: nil)
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else { throw MediaError.unreadable("video output rejected") }
        reader.add(videoOutput)

        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        let videoFormat = (try? await readVideoTrack.load(.formatDescriptions))?.first
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: videoFormat)
        videoInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput) else { throw MediaError.writeFailed("video input rejected") }
        writer.add(videoInput)

        var audioOutput: AVAssetReaderTrackOutput?
        var audioInput: AVAssetWriterInput?
        if let audioTrack = readAudioTrack {
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            output.alwaysCopiesSampleData = false
            if reader.canAdd(output) {
                reader.add(output)
                audioOutput = output
                let format = (try? await audioTrack.load(.formatDescriptions))?.first
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: format)
                input.expectsMediaDataInRealTime = false
                if writer.canAdd(input) {
                    writer.add(input)
                    audioInput = input
                } else {
                    audioOutput = nil
                }
            }
        }

        // Metadata is only ever written by us, which is exactly the strip/keep behaviour.
        if let identifier {
            let item = AVMutableMetadataItem()
            item.keySpace = .quickTimeMetadata
            item.key = "com.apple.quicktime.content.identifier" as NSString
            item.value = identifier as NSString
            writer.metadata = [item]
        }

        guard writer.startWriting() else {
            throw MediaError.writeFailed(writer.error?.localizedDescription ?? "startWriting")
        }
        writer.startSession(atSourceTime: .zero)
        guard reader.startReading() else {
            throw MediaError.writeFailed(reader.error?.localizedDescription ?? "startReading")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let queue = DispatchQueue(label: "com.wowios.transcode", attributes: .concurrent)
            let group = DispatchGroup()
            let lock = NSLock()
            var failure: Error?

            func pump(_ output: AVAssetReaderTrackOutput, _ input: AVAssetWriterInput) {
                while let sample = output.copyNextSampleBuffer() {
                    while !input.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.002)
                    }
                    if !input.append(sample) {
                        lock.lock()
                        failure = writer.error ?? MediaError.writeFailed("append rejected")
                        lock.unlock()
                        return
                    }
                }
            }

            group.enter()
            queue.async {
                pump(videoOutput, videoInput)
                group.leave()
            }
            if let audioOutput, let audioInput {
                group.enter()
                queue.async {
                    pump(audioOutput, audioInput)
                    group.leave()
                }
            }

            group.notify(queue: queue) {
                videoInput.markAsFinished()
                audioInput?.markAsFinished()
                writer.finishWriting {
                    lock.lock()
                    let captured = failure
                    lock.unlock()
                    if let captured {
                        continuation.resume(throwing: captured)
                    } else if writer.status == .completed {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: MediaError.writeFailed(writer.error?.localizedDescription ?? "unknown writer state"))
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private static func clamp(range: ClosedRange<Double>?, duration: Double) -> ClosedRange<Double> {
        guard let range else { return 0...duration }
        let lower = max(0, min(range.lowerBound, duration - 0.2))
        let upper = max(lower + 0.2, min(range.upperBound, duration))
        return lower...upper
    }

    private static func resize(_ image: CGImage, maxDimension: CGFloat?) -> CGImage {
        guard let maxDimension else { return image }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let longest = max(width, height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: width * scale, height: height * scale)
        let context = CGContext(data: nil,
                               width: Int(target.width),
                               height: Int(target.height),
                               bitsPerComponent: 8,
                               bytesPerRow: 0,
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(origin: .zero, size: target))
        return context?.makeImage() ?? image
    }

    static func temporaryURL(fileExtension ext: String, prefix: String = "wowios") -> URL {
        let name = "\(prefix)-\(UUID().uuidString).\(ext)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }
}
