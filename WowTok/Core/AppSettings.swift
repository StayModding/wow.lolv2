import Foundation
import SwiftUI
import Observation

/// Single source of truth for tweaks, dev-server connection and export defaults.
@MainActor
@Observable
final class AppSettings {
    private static let storageKey = "wowtok.settings.v1"

    var enabledTweaks: Set<TweakID> {
        didSet { persist() }
    }
    var host: String {
        didSet { persist() }
    }
    var port: Int {
        didSet { persist() }
    }
    var loopEnabled: Bool {
        didSet { persist() }
    }
    var mutePreview: Bool {
        didSet { persist() }
    }
    var maxDimension: Int {
        didSet { persist() }
    }
    var jpegQuality: Double {
        didSet { persist() }
    }
    var trimSeconds: Double {
        didSet { persist() }
    }
    var includeAudio: Bool {
        didSet { persist() }
    }
    var recentHosts: [String] {
        didSet { persist() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            enabledTweaks = snapshot.enabledTweaks
            host = snapshot.host
            port = snapshot.port
            loopEnabled = snapshot.loopEnabled
            mutePreview = snapshot.mutePreview
            maxDimension = snapshot.maxDimension
            jpegQuality = snapshot.jpegQuality
            trimSeconds = snapshot.trimSeconds
            includeAudio = snapshot.includeAudio
            recentHosts = snapshot.recentHosts
        } else {
            enabledTweaks = TweakCatalog.defaults
            host = "127.0.0.1"
            port = 8787
            loopEnabled = true
            mutePreview = true
            maxDimension = 1440
            jpegQuality = 0.96
            trimSeconds = 3
            includeAudio = false
            recentHosts = []
        }
    }

    // MARK: Queries

    func isOn(_ id: TweakID) -> Bool {
        enabledTweaks.contains(id)
    }

    func toggle(_ id: TweakID) {
        if enabledTweaks.contains(id) {
            enabledTweaks.remove(id)
        } else {
            enabledTweaks.insert(id)
        }
    }

    func resetTweaks() {
        enabledTweaks = TweakCatalog.defaults
    }

    var enabledCount: Int { enabledTweaks.count }

    // MARK: Resolved look

    var theme: Theme {
        var theme = Theme()
        theme.flatChrome = isOn(.neutralizeGlass)
        theme.killBarBlur = isOn(.killBarBlur)
        theme.squareCorners = isOn(.squareCorners)
        theme.noMotion = isOn(.noMotion)
        theme.amoled = isOn(.amoledBlack)
        theme.highContrastHairlines = isOn(.highContrastHairlines)
        theme.compact = isOn(.compactDensity)
        theme.mintAccent = isOn(.mintAccent)
        return theme
    }

    // MARK: Import / export defaults

    var importTrim: ClosedRange<Double>? {
        isOn(.autoTrimThreeSeconds) ? 0...max(0.6, trimSeconds) : nil
    }

    var livePhotoOptions: LivePhotoOptions {
        LivePhotoOptions(
            trim: importTrim,
            maxDimension: isOn(.keepSourceResolution) ? nil : CGFloat(maxDimension),
            jpegQuality: jpegQuality,
            stripMetadata: isOn(.stripMetadata),
            includeAudio: includeAudio
        )
    }

    func rememberHost(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var next = recentHosts.filter { $0 != trimmed }
        next.insert(trimmed, at: 0)
        recentHosts = Array(next.prefix(6))
    }

    // MARK: Injection profile

    /// A profile your dev VPN / injection tool can consume for the tweaks that
    /// cannot be applied from inside the app sandbox (SpringBoard-owned chrome).
    func injectionProfile() -> String {
        let flags = enabledTweaks.map(\.rawValue).sorted()
        let payload: [String: Any] = [
            "app": "wow.tok",
            "profileVersion": 1,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "targets": [
                [
                    "process": "SpringBoard",
                    "tweaks": [
                        ["id": "systemGlassOff", "enabled": isOn(.systemGlassOff), "effect": "set UIChromeGlassEnabled=false"],
                        ["id": "dockGlassOff", "enabled": isOn(.dockGlassOff), "effect": "set DockBackgroundMaterial=none"]
                    ]
                ]
            ],
            "appTweaks": flags
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    // MARK: Persistence

    private struct Snapshot: Codable {
        var enabledTweaks: Set<TweakID>
        var host: String
        var port: Int
        var loopEnabled: Bool
        var mutePreview: Bool
        var maxDimension: Int
        var jpegQuality: Double
        var trimSeconds: Double
        var includeAudio: Bool
        var recentHosts: [String]
    }

    private func persist() {
        let snapshot = Snapshot(
            enabledTweaks: enabledTweaks,
            host: host,
            port: port,
            loopEnabled: loopEnabled,
            mutePreview: mutePreview,
            maxDimension: maxDimension,
            jpegQuality: jpegQuality,
            trimSeconds: trimSeconds,
            includeAudio: includeAudio,
            recentHosts: recentHosts
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
