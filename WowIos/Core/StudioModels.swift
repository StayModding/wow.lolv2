import SwiftUI

/// A gradient the user builds in the preset studio.
struct CustomPreset: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var topHex: String
    var bottomHex: String
    var accentHex: String
    var speed: Double = 0.4
    var createdAt: Date = Date()

    var top: Color { Color(hex: topHex) }
    var bottom: Color { Color(hex: bottomHex) }
    var accent: Color { Color(hex: accentHex) }

    /// Nine stops for a 3x3 MeshGradient: dark edges, accent core.
    var palette: [Color] {
        [
            top,
            Color.mix(top, accent, 0.35),
            top,
            Color.mix(top, accent, 0.65),
            accent,
            Color.mix(bottom, accent, 0.65),
            bottom,
            Color.mix(bottom, accent, 0.30),
            bottom
        ]
    }

    static func starter() -> CustomPreset {
        CustomPreset(name: "My gradient",
                     topHex: "#0B0B0F",
                     bottomHex: "#101A2A",
                     accentHex: "#6BF0C7")
    }
}

/// A named set of tweak toggles you can reapply in one tap.
struct TweakProfile: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var tweaks: [String]
    var createdAt: Date = Date()

    var enabled: Set<TweakID> {
        Set(tweaks.compactMap(TweakID.init(rawValue:)))
    }
}

/// Something the app exported, kept on disk so it can be re-shared later.
struct ExportRecord: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var kind: String
    var fileName: String
    var bytes: Int
    var date: Date
}
