import SwiftUI

enum PresetID: String, CaseIterable, Identifiable, Hashable {
    case aurora
    case neonTokyo
    case mintWave
    case solarFlare
    case deepSpace
    case chromeFade

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aurora: return "Aurora Drift"
        case .neonTokyo: return "Neon Tokyo"
        case .mintWave: return "Mint Wave"
        case .solarFlare: return "Solar Flare"
        case .deepSpace: return "Deep Space"
        case .chromeFade: return "Chrome Fade"
        }
    }

    var subtitle: String {
        switch self {
        case .aurora: return "Slow green-violet curtain"
        case .neonTokyo: return "Magenta rain on glass"
        case .mintWave: return "Soft mint horizon"
        case .solarFlare: return "Molten orange bloom"
        case .deepSpace: return "Indigo void with a violet core"
        case .chromeFade: return "Graphite to silver sweep"
        }
    }

    var spec: PresetSpec {
        switch self {
        case .aurora:
            return PresetSpec(colors: [WowColor.ink, Color(red: 0.10, green: 0.35, blue: 0.32), WowColor.ink,
                                       Color(red: 0.12, green: 0.55, blue: 0.45), Color(red: 0.35, green: 0.90, blue: 0.74), Color(red: 0.20, green: 0.30, blue: 0.70),
                                       WowColor.ink, Color(red: 0.30, green: 0.20, blue: 0.55), WowColor.ink],
                              amplitude: 0.16, speed: 0.35)
        case .neonTokyo:
            return PresetSpec(colors: [Color(red: 0.05, green: 0.0, blue: 0.10), Color(red: 0.55, green: 0.05, blue: 0.45), Color(red: 0.05, green: 0.02, blue: 0.12),
                                       Color(red: 0.85, green: 0.10, blue: 0.55), Color(red: 0.30, green: 0.05, blue: 0.60), Color(red: 0.10, green: 0.85, blue: 0.90),
                                       Color(red: 0.04, green: 0.0, blue: 0.08), Color(red: 0.60, green: 0.15, blue: 0.70), Color(red: 0.06, green: 0.02, blue: 0.14)],
                              amplitude: 0.10, speed: 0.55)
        case .mintWave:
            return PresetSpec(colors: [Color(red: 0.02, green: 0.12, blue: 0.12), Color(red: 0.10, green: 0.45, blue: 0.42), Color(red: 0.02, green: 0.16, blue: 0.16),
                                       Color(red: 0.18, green: 0.70, blue: 0.62), Color(red: 0.55, green: 0.98, blue: 0.85), Color(red: 0.10, green: 0.40, blue: 0.55),
                                       Color(red: 0.01, green: 0.08, blue: 0.10), Color(red: 0.22, green: 0.55, blue: 0.60), Color(red: 0.01, green: 0.10, blue: 0.12)],
                              amplitude: 0.13, speed: 0.30)
        case .solarFlare:
            return PresetSpec(colors: [Color(red: 0.20, green: 0.02, blue: 0.02), Color(red: 0.85, green: 0.28, blue: 0.05), Color(red: 0.25, green: 0.02, blue: 0.05),
                                       Color(red: 0.98, green: 0.55, blue: 0.10), Color(red: 1.0, green: 0.86, blue: 0.45), Color(red: 0.70, green: 0.15, blue: 0.20),
                                       Color(red: 0.12, green: 0.01, blue: 0.02), Color(red: 0.55, green: 0.10, blue: 0.10), Color(red: 0.18, green: 0.01, blue: 0.03)],
                              amplitude: 0.15, speed: 0.40)
        case .deepSpace:
            return PresetSpec(colors: [.black, Color(red: 0.08, green: 0.05, blue: 0.22), .black,
                                       Color(red: 0.18, green: 0.10, blue: 0.45), Color(red: 0.42, green: 0.28, blue: 0.95), Color(red: 0.10, green: 0.06, blue: 0.30),
                                       .black, Color(red: 0.12, green: 0.08, blue: 0.30), .black],
                              amplitude: 0.08, speed: 0.25)
        case .chromeFade:
            return PresetSpec(colors: [Color(white: 0.05), Color(white: 0.35), Color(white: 0.08),
                                       Color(white: 0.55), Color(white: 0.85), Color(white: 0.25),
                                       Color(white: 0.06), Color(white: 0.30), Color(white: 0.10)],
                              amplitude: 0.12, speed: 0.45)
        }
    }
}

struct PresetSpec {
    var colors: [Color]
    var amplitude: Float
    var speed: Double
}

struct PresetWallpaperView: View {
    let preset: PresetID
    var animated: Bool = true

    var body: some View {
        let spec = preset.spec
        if animated {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                mesh(spec: spec, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            mesh(spec: spec, time: 0)
        }
    }

    private func mesh(spec: PresetSpec, time: TimeInterval) -> some View {
        MeshGradient(width: 3,
                     height: 3,
                     points: points(t: Float(time * spec.speed), amplitude: spec.amplitude),
                     colors: spec.colors,
                     smoothsColors: true)
            .overlay(
                LinearGradient(colors: [.black.opacity(0.18), .clear, .black.opacity(0.30)],
                               startPoint: .top,
                               endPoint: .bottom)
            )
    }

    private func points(t: Float, amplitude: Float) -> [SIMD2<Float>] {
        let a = amplitude
        return [
            SIMD2<Float>(0, 0),
            SIMD2<Float>(0.5 + a * 0.5 * sin(t * 0.9), 0),
            SIMD2<Float>(1, 0),
            SIMD2<Float>(0, 0.5 + a * 0.4 * cos(t * 0.7)),
            SIMD2<Float>(0.5 + a * 0.7 * sin(t), 0.5 + a * 0.7 * cos(t * 1.1)),
            SIMD2<Float>(1, 0.5 + a * 0.4 * sin(t * 0.8)),
            SIMD2<Float>(0, 1),
            SIMD2<Float>(0.5 + a * 0.5 * cos(t * 0.9), 1),
            SIMD2<Float>(1, 1)
        ]
    }
}
