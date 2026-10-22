import Foundation

enum WallpaperKind: String, Codable, Hashable, CaseIterable {
    case live
    case video
    case photo
    case preset

    var label: String {
        switch self {
        case .live: return "Live Photo"
        case .video: return "MP4"
        case .photo: return "Photo"
        case .preset: return "Preset"
        }
    }
}

/// A pack advertised by the local dev server over the VPN port.
struct WallpaperPack: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var kind: String
    var author: String?
    var tags: [String]?
    var duration: Double?
    var hd: Bool?
    var allowDownload: Bool?
    /// Paths are relative to the dev server root, e.g. "/files/aurora/preview.jpg".
    var preview: String
    var video: String?
    var still: String?
    var trimStart: Double?
    var trimEnd: Double?

    var resolvedKind: WallpaperKind {
        WallpaperKind(rawValue: kind) ?? .video
    }
}

struct DevManifest: Codable {
    var version: Int
    var name: String?
    var packs: [WallpaperPack]
}

/// What the UI actually shows: packs, local imports and built-in presets.
struct Wallpaper: Identifiable, Hashable {
    enum Origin: Hashable {
        case preset(PresetID)
        case custom(CustomPreset)
        case remote(WallpaperPack)
        case local(URL)
    }

    var id: String
    var title: String
    var subtitle: String
    var kind: WallpaperKind
    var origin: Origin
    var declaredTrim: ClosedRange<Double>?
    var allowDownload: Bool
    var isHD: Bool

    init(id: String,
         title: String,
         subtitle: String,
         kind: WallpaperKind,
         origin: Origin,
         declaredTrim: ClosedRange<Double>? = nil,
         allowDownload: Bool = false,
         isHD: Bool = true) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.origin = origin
        self.declaredTrim = declaredTrim
        self.allowDownload = allowDownload
        self.isHD = isHD
    }

    init(pack: WallpaperPack) {
        let kind = pack.resolvedKind
        var trim: ClosedRange<Double>?
        if let start = pack.trimStart, let end = pack.trimEnd, end > start {
            trim = start...end
        }
        self.init(
            id: pack.id,
            title: pack.title,
            subtitle: pack.author ?? (pack.tags?.joined(separator: " · ") ?? "Dev server"),
            kind: kind,
            origin: .remote(pack),
            declaredTrim: trim,
            allowDownload: pack.allowDownload ?? false,
            isHD: pack.hd ?? true
        )
    }

    init(custom preset: CustomPreset) {
        self.init(id: "custom.\(preset.id.uuidString)",
                  title: preset.name,
                  subtitle: "Custom gradient",
                  kind: .preset,
                  origin: .custom(preset),
                  allowDownload: false,
                  isHD: true)
    }

    var customPreset: CustomPreset? {
        if case let .custom(preset) = origin { return preset }
        return nil
    }

    var pack: WallpaperPack? {
        if case let .remote(pack) = origin { return pack }
        return nil
    }

    var localURL: URL? {
        if case let .local(url) = origin { return url }
        return nil
    }
}
