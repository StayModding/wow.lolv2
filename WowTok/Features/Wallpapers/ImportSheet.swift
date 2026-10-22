import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

@MainActor
struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(LocalLibrary.self) private var library

    @State private var videoItem: PhotosPickerItem?
    @State private var photoItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var photoURL: URL?
    @State private var title = "My wallpaper"
    @State private var trimLength: Double = 3
    @State private var keepInLibrary = true
    @State private var busyMessage: String?
    @State private var errorMessage: String?
    @State private var finished = false
    @State private var sourceDuration: Double = 3

    private var theme: Theme { settings.theme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.sectionSpacing) {
                    pickers
                    if videoURL != nil || photoURL != nil { previewCard }
                    if videoURL != nil { trimCard }
                    nameCard
                    actions
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.9))
                            .chromeSurface()
                    }
                    explainer
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle("New wallpaper")
            .navigationBarTitleDisplayMode(.inline)
            .chromeBars()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .overlay {
                if let busyMessage {
                    ZStack {
                        Color.black.opacity(0.6).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView().tint(.white)
                            Text(busyMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(22)
                        .background(RoundedRectangle(cornerRadius: 18).fill(theme.solidChrome))
                    }
                }
            }
            .onAppear {
                trimLength = settings.isOn(.autoTrimThreeSeconds) ? settings.trimSeconds : 4
            }
            .onChange(of: videoItem) { _, item in
                guard let item else { return }
                Task { await loadVideo(item) }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await loadPhoto(item) }
            }
        }
    }

    // MARK: Sections

    private var pickers: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $videoItem, matching: .videos, photoLibrary: .shared()) {
                HStack {
                    Image(systemName: "film.stack")
                    Text("Choose a video (MP4 / MOV)")
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .chromeSurface()
            }

            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                HStack {
                    Image(systemName: "photo")
                    Text("Choose a photo")
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .chromeSurface()
            }
        }
    }

    private var previewCard: some View {
        ZStack {
            Color.black
            if let videoURL {
                LoopVideoView(url: videoURL, looping: true, muted: true, pauseOnLowPower: false)
            } else if let photoURL {
                LocalPhotoThumbnail(url: photoURL)
            }
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
                .strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth)
        }
    }

    private var trimCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Live Photo burst",
                          caption: String(format: "%.1fs of %.1fs · lockscreen shows this window", trimLength, sourceDuration))
            Slider(value: $trimLength, in: 1...min(6, max(1.2, sourceDuration))).tint(theme.accent)
        }
        .chromeSurface()
    }

    private var nameCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Name").font(.system(size: 13, weight: .semibold))
                Spacer()
                TextField("My wallpaper", text: $title)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 13))
            }
            Divider().overlay(theme.hairline)
            Toggle(isOn: $keepInLibrary) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep a copy in my wallpapers").font(.system(size: 13, weight: .semibold))
                    Text("Stores the master file on this device for re-export")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(theme.accent)
        }
        .chromeSurface()
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if videoURL != nil {
                Button {
                    Task { await buildLivePhoto() }
                } label: {
                    Label("Create Live Photo & save", systemImage: "livephoto")
                }
                .buttonStyle(WowButtonStyle())
                .disabled(busyMessage != nil)
            }
            if photoURL != nil {
                Button {
                    Task { await saveStill() }
                } label: {
                    Label("Save photo for wallpaper", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(WowButtonStyle())
                .disabled(busyMessage != nil)
            }
            if finished {
                Text("Saved. Open Settings → Wallpaper to set it.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accentSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var explainer: some View {
        Text("Video wallpapers only work on iOS as Live Photos, so wow.tok writes a paired still + MOV with a shared content identifier. Frames are copied through a passthrough writer, never re-encoded with a watermark.")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .chromeSurface()
    }

    // MARK: Work

    private func loadVideo(_ item: PhotosPickerItem) async {
        errorMessage = nil
        do {
            guard let file = try await item.loadTransferable(type: VideoFile.self) else {
                errorMessage = "Could not read that video."
                return
            }
            videoURL = file.url
            photoURL = nil
            let asset = AVURLAsset(url: file.url)
            let loaded = (try? await asset.load(.duration)) ?? .zero
            sourceDuration = loaded.seconds.isFinite ? max(0.6, loaded.seconds) : 3
            trimLength = min(trimLength, sourceDuration)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        errorMessage = nil
        do {
            guard let file = try await item.loadTransferable(type: ImageFile.self) else {
                errorMessage = "Could not read that photo."
                return
            }
            photoURL = file.url
            videoURL = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildLivePhoto() async {
        guard let videoURL else { return }
        busyMessage = "Building Live Photo…"
        errorMessage = nil
        defer { busyMessage = nil }

        var options = settings.livePhotoOptions
        options.trim = 0...trimLength
        do {
            let bundle = try await LivePhotoBuilder.makeLivePhoto(fromVideo: videoURL, options: options)
            if keepInLibrary {
                try library.add(fileURL: videoURL, title: title, kind: .video)
            }
            try await LivePhotoBuilder.saveLivePhotoToLibrary(bundle)
            finished = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveStill() async {
        guard let photoURL else { return }
        busyMessage = "Preparing photo…"
        defer { busyMessage = nil }
        do {
            let prepared = try LivePhotoBuilder.makeStill(fromImage: photoURL, options: settings.livePhotoOptions)
            if keepInLibrary {
                try library.add(fileURL: prepared, title: title, kind: .photo)
            }
            try await LivePhotoBuilder.savePhotoToLibrary(prepared)
            finished = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Transferables

struct VideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("wowtok-import-\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return VideoFile(url: destination)
        }
    }
}

struct ImageFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .image) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "jpg" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("wowtok-photo-\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return ImageFile(url: destination)
        }
    }
}
