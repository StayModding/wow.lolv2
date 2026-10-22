import SwiftUI
import UIKit

struct CustomPresetView: View {
    let preset: CustomPreset
    var animated: Bool = true

    var body: some View {
        if animated {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                mesh(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            mesh(time: 0)
        }
    }

    private func mesh(time: TimeInterval) -> some View {
        let t = Float(time * max(0.05, preset.speed))
        let a: Float = 0.13
        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                SIMD2<Float>(0, 0),
                SIMD2<Float>(0.5 + a * 0.6 * sin(t * 0.9), 0),
                SIMD2<Float>(1, 0),
                SIMD2<Float>(0, 0.5 + a * 0.4 * cos(t * 0.7)),
                SIMD2<Float>(0.5 + a * 0.8 * sin(t), 0.5 + a * 0.8 * cos(t * 1.1)),
                SIMD2<Float>(1, 0.5 + a * 0.5 * sin(t * 0.8)),
                SIMD2<Float>(0, 1),
                SIMD2<Float>(0.5 + a * 0.6 * cos(t * 0.9), 1),
                SIMD2<Float>(1, 1)
            ],
            colors: preset.palette
        )
        .overlay(
            LinearGradient(colors: [.black.opacity(0.15), .clear, .black.opacity(0.28)],
                           startPoint: .top,
                           endPoint: .bottom)
        )
    }
}

@MainActor
enum StudioRenderer {
    /// Renders a static frame at iPhone-native resolution (1179x2556 by default).
    static func render(_ preset: CustomPreset,
                       width: CGFloat = 1179,
                       height: CGFloat = 2556) -> CGImage? {
        let renderer = ImageRenderer(content: CustomPresetView(preset: preset, animated: false)
            .frame(width: width, height: height))
        renderer.scale = 1
        return renderer.cgImage
    }

    static func exportJPEG(_ preset: CustomPreset, quality: Double = 0.97) throws -> URL {
        guard let image = render(preset) else {
            throw MediaError.writeFailed("the gradient could not be rendered")
        }
        let url = LivePhotoBuilder.temporaryURL(fileExtension: "jpg", prefix: "wowios-preset")
        try LivePhotoBuilder.writeJPEG(image, to: url, quality: quality, identifier: nil)
        return url
    }
}
