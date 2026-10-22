import Foundation

enum TweakScope: String, Codable {
    /// Fully implemented inside wow-ios.
    case app
    /// Needs to be applied by your dev VPN / injection tool because the target
    /// UI belongs to another process. wow-ios exports a profile for it.
    case injection
}

enum TweakGroup: String, CaseIterable, Identifiable, Codable {
    case chrome = "Chrome & Liquid Glass"
    case shape = "Shape & Motion"
    case look = "Look"
    case pipeline = "Wallpaper pipeline"
    case dev = "Dev link"

    var id: String { rawValue }
}

enum TweakID: String, CaseIterable, Codable, Identifiable {
    case neutralizeGlass
    case killBarBlur
    case highContrastHairlines
    case squareCorners
    case noMotion
    case compactDensity
    case amoledBlack
    case mintAccent
    case safeAreaGuides
    case loopByDefault
    case pauseLoopOnLowPower
    case autoLivePhoto
    case autoTrimThreeSeconds
    case keepSourceResolution
    case stripMetadata
    case autoConnectDevLink
    case systemGlassOff
    case dockGlassOff

    var id: String { rawValue }
}

struct Tweak: Identifiable, Hashable {
    let id: TweakID
    let title: String
    let detail: String
    let symbol: String
    let group: TweakGroup
    let scope: TweakScope
    let defaultOn: Bool
    let needsRestart: Bool
}

enum TweakCatalog {
    static let all: [Tweak] = [
        Tweak(id: .neutralizeGlass,
              title: "Neutralize Liquid Glass",
              detail: "Paints opaque fills behind every bar and card and stops requesting system materials, so no glass shows through anywhere in wow-ios. The build also sets UIDesignRequiresCompatibility, which opts the whole app out of the Liquid Glass redesign.",
              symbol: "square.fill.on.square.fill",
              group: .chrome,
              scope: .app,
              defaultOn: true,
              needsRestart: false),
        Tweak(id: .killBarBlur,
              title: "Kill bar blur",
              detail: "Solid color under the navigation bar and tab bar instead of a blur, including scroll-edge fog.",
              symbol: "rectangle.fill",
              group: .chrome,
              scope: .app,
              defaultOn: true,
              needsRestart: false),
        Tweak(id: .highContrastHairlines,
              title: "High-contrast hairlines",
              detail: "Turns the faint dividers into crisp 1pt edges so flat chrome still reads as layered.",
              symbol: "square.dashed",
              group: .chrome,
              scope: .app,
              defaultOn: false,
              needsRestart: false),
        Tweak(id: .squareCorners,
              title: "Square corners",
              detail: "Drops every corner radius to 2pt for a hard-edged, pre-glass look.",
              symbol: "square.on.square",
              group: .shape,
              scope: .app,
              defaultOn: false,
              needsRestart: false),
        Tweak(id: .noMotion,
              title: "No motion",
              detail: "Removes transitions, spring animations and animated wallpaper presets. Live wallpaper previews still loop, but statically framed.",
              symbol: "timer",
              group: .shape,
              scope: .app,
              defaultOn: false,
              needsRestart: false),
        Tweak(id: .compactDensity,
              title: "Compact density",
              detail: "Tighter row spacing and section padding, roughly 15 percent more content per screen.",
              symbol: "rectangle.compress.vertical",
              group: .shape,
              scope: .app,
              defaultOn: false,
              needsRestart: false),
        Tweak(id: .amoledBlack,
              title: "AMOLED black",
              detail: "Pure black background for OLED panels, with the lowest-contrast support surfaces that still pass legibility.",
              symbol: "moon.stars.fill",
              group: .look,
              scope: .app,
              defaultOn: false,
              needsRestart: false),
        Tweak(id: .mintAccent,
              title: "Mint accent",
              detail: "Swaps the violet accent for mint across buttons, selection states and the waveform.",
              symbol: "paintpalette.fill",
              group: .look,
              scope: .app,
              defaultOn: false,
              needsRestart: false),
        Tweak(id: .safeAreaGuides,
              title: "Safe-area guides",
              detail: "Shows status bar and lock screen clock guides over wallpaper previews so your subject is not hidden by the clock.",
              symbol: "ruler",
              group: .look,
              scope: .app,
              defaultOn: false,
              needsRestart: false),
        Tweak(id: .loopByDefault,
              title: "Loop by default",
              detail: "Every video wallpaper loops forever with a seamless AVPlayerLooper instead of playing once.",
              symbol: "arrow.triangle.2.circlepath",
              group: .pipeline,
              scope: .app,
              defaultOn: true,
              needsRestart: false),
        Tweak(id: .pauseLoopOnLowPower,
              title: "Pause loops in Low Power Mode",
              detail: "Stops wallpaper loops when the device reports Low Power Mode, so previews never drain the battery.",
              symbol: "battery.25percent",
              group: .pipeline,
              scope: .app,
              defaultOn: true,
              needsRestart: false),
        Tweak(id: .autoLivePhoto,
              title: "Auto-convert MP4 to Live Photo",
              detail: "Importing or downloading an MP4 immediately builds a paired still + MOV Live Photo, which is the only way iOS will accept a video wallpaper.",
              symbol: "photo.on.rectangle.angled",
              group: .pipeline,
              scope: .app,
              defaultOn: true,
              needsRestart: false),
        Tweak(id: .autoTrimThreeSeconds,
              title: "Auto-trim to 3 seconds",
              detail: "Live Photo wallpapers only show a short burst. New imports are trimmed to the first 3 seconds unless you drag the trim handles.",
              symbol: "scissors",
              group: .pipeline,
              scope: .app,
              defaultOn: true,
              needsRestart: false),
        Tweak(id: .keepSourceResolution,
              title: "Keep source resolution",
              detail: "Exports copy the original encoded frames bit for bit instead of re-encoding, so a 4K source stays 4K and nothing is watermarked or downscaled.",
              symbol: "arrow.up.left.and.arrow.down.right",
              group: .pipeline,
              scope: .app,
              defaultOn: true,
              needsRestart: false),
        Tweak(id: .stripMetadata,
              title: "Strip metadata on export",
              detail: "Drops GPS, device and creation metadata from exported files while keeping the quality untouched.",
              symbol: "eraser.fill",
              group: .pipeline,
              scope: .app,
              defaultOn: false,
              needsRestart: false),
        Tweak(id: .autoConnectDevLink,
              title: "Auto-connect on launch",
              detail: "Reconnects to your last dev server port over the VPN as soon as the app opens.",
              symbol: "antenna.radiowaves.left.and.right",
              group: .dev,
              scope: .app,
              defaultOn: false,
              needsRestart: false),
        Tweak(id: .systemGlassOff,
              title: "System-wide glass off",
              detail: "Home screen, Control Center, notifications and system apps keep their Liquid Glass because those views live in another process. This row writes the preference into an injection profile your dev VPN app can apply to SpringBoard.",
              symbol: "cpu",
              group: .chrome,
              scope: .injection,
              defaultOn: false,
              needsRestart: true),
        Tweak(id: .dockGlassOff,
              title: "Dock glass off",
              detail: "Same story as system-wide glass: the Dock is SpringBoard-owned. Export the injection profile from this tab and feed it to your dev VPN tweak loader.",
              symbol: "dock.rectangle",
              group: .chrome,
              scope: .injection,
              defaultOn: false,
              needsRestart: true)
    ]

    static func tweaks(in group: TweakGroup) -> [Tweak] {
        all.filter { $0.group == group }
    }

    static func tweak(_ id: TweakID) -> Tweak {
        all.first { $0.id == id } ?? all[0]
    }

    static var defaults: Set<TweakID> {
        Set(all.filter(\.defaultOn).map(\.id))
    }
}
