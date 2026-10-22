import Foundation
import SwiftUI
import Observation

/// Single source of truth for tweaks, dev-server connection and export defaults.
@MainActor
@Observable
final class AppSettings {
    private static let storageKey = "wowios.settings.v1"

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
    var favorites: Set<String> {
        didSet { persist() }
    }
    var customPresets: [CustomPreset] {
        didSet { persist() }
    }
    var tweakProfiles: [TweakProfile] {
        didSet { persist() }
    }
    var onboardingSeen: Bool {
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
            favorites = snapshot.favorites
            customPresets = snapshot.customPresets
            tweakProfiles = snapshot.tweakProfiles
            onboardingSeen = snapshot.onboardingSeen
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
            favorites = []
            customPresets = []
            tweakProfiles = []
            onboardingSeen = false
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
            "app": "wow-ios",
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

    // MARK: Studio collections

    func isFavorite(_ id: String) -> Bool {
        favorites.contains(id)
    }

    @discardableResult
    func toggleFavorite(_ id: String) -> Bool {
        if favorites.contains(id) {
            favorites.remove(id)
        } else {
            favorites.insert(id)
        }
        Haptics.select()
        return favorites.contains(id)
    }

    func upsertCustomPreset(_ preset: CustomPreset) {
        if let index = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[index] = preset
        } else {
            customPresets.insert(preset, at: 0)
        }
    }

    func deleteCustomPreset(_ id: UUID) {
        customPresets.removeAll { $0.id == id }
    }

    func saveProfile(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = TweakProfile(name: trimmed.isEmpty ? "Profile \(tweakProfiles.count + 1)" : trimmed,
                                   tweaks: enabledTweaks.map(\.rawValue).sorted())
        tweakProfiles.append(profile)
        Haptics.success()
    }

    func applyProfile(_ profile: TweakProfile) {
        enabledTweaks = profile.enabled
        Haptics.select()
    }

    func deleteProfile(_ id: UUID) {
        tweakProfiles.removeAll { $0.id == id }
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
        var favorites: Set<String>
        var customPresets: [CustomPreset]
        var tweakProfiles: [TweakProfile]
        var onboardingSeen: Bool
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
            recentHosts: recentHosts,
            favorites: favorites,
            customPresets: customPresets,
            tweakProfiles: tweakProfiles,
            onboardingSeen: onboardingSeen
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
