import SwiftUI
import AVFoundation
import UIKit

struct Pill: View {
    let text: String
    var tint: Color? = nil
    var symbol: String? = nil
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 9, weight: .bold))
            }
            Text(text.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill((tint ?? theme.accent).opacity(0.18)))
        .overlay(Capsule().strokeBorder((tint ?? theme.accent).opacity(0.4), lineWidth: 0.5))
        .foregroundStyle(tint ?? theme.accent)
    }
}

struct StatusPill: View {
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }
}

struct WowButtonStyle: ButtonStyle {
    var prominent: Bool = true
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background {
                RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                    .fill(prominent ? theme.accent : theme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                    .strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth)
            }
            .foregroundStyle(prominent ? Color.black.opacity(0.88) : Color.primary)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct SectionHeader: View {
    let title: String
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
            if let caption {
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Thumbnails

struct AsyncThumbnail: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                placeholder(symbol: "exclamationmark.triangle")
            case .empty:
                ZStack {
                    placeholder(symbol: nil)
                    ProgressView().tint(.white.opacity(0.7))
                }
            @unknown default:
                placeholder(symbol: nil)
            }
        }
    }

    private func placeholder(symbol: String?) -> some View {
        ZStack {
            LinearGradient(colors: [WowColor.slate, Color.black], startPoint: .top, endPoint: .bottom)
            if let symbol {
                Image(systemName: symbol).foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

struct VideoThumbnail: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [WowColor.slate, .black], startPoint: .top, endPoint: .bottom)
                ProgressView().tint(.white.opacity(0.6))
            }
        }
        .task(id: url) {
            guard image == nil else { return }
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 640)
            if let result = try? await generator.image(at: CMTime(seconds: 0.3, preferredTimescale: 600)) {
                image = UIImage(cgImage: result.image)
            }
        }
    }
}

struct LocalPhotoThumbnail: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.black
            }
        }
        .task(id: url) {
            guard image == nil else { return }
            image = UIImage(contentsOfFile: url.path)
        }
    }
}

// MARK: - Card

struct WallpaperCard: View {
    let wallpaper: Wallpaper
    let previewURL: URL?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topLeading) {
                thumbnail
                    .frame(maxWidth: .infinity)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cardRadius - 6, style: .continuous))

                HStack(spacing: 4) {
                    Pill(text: wallpaper.kind.label, symbol: icon)
                    if wallpaper.isHD {
                        Pill(text: "HD", tint: theme.accentSecondary)
                    }
                }
                .padding(7)

                if wallpaper.allowDownload {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(wallpaper.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(wallpaper.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
                .fill(theme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
                .strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth)
        }
    }

    private var icon: String {
        switch wallpaper.kind {
        case .live: return "livephoto"
        case .video: return "film"
        case .photo: return "photo"
        case .preset: return "sparkles"
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch wallpaper.origin {
        case .preset(let id):
            PresetWallpaperView(preset: id, animated: false)
        case .remote:
            AsyncThumbnail(url: previewURL)
        case .local(let url):
            if wallpaper.kind == .photo {
                LocalPhotoThumbnail(url: url)
            } else {
                VideoThumbnail(url: url)
            }
        }
    }
}

// MARK: - Guides

struct LockScreenGuides: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 10)
                    .padding(.top, max(58, geo.safeAreaInsets.top + 40))
                    .padding(.bottom, max(40, geo.safeAreaInsets.bottom + 26))

                HStack(spacing: 5) {
                    Text("9:41").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "wifi").font(.system(size: 12, weight: .semibold))
                    Image(systemName: "battery.100").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .shadow(radius: 2)
                .padding(.horizontal, 24)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 8)

                VStack(spacing: 2) {
                    Text("9:41")
                        .font(.system(size: 62, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(radius: 6)
                    Text("Monday, October 22")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .offset(y: -geo.size.height * 0.26)
            }
        }
        .allowsHitTesting(false)
    }
}

struct EmptyHint: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}
