import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DevLink.self) private var devLink
    @Environment(LocalLibrary.self) private var library

    @State private var cacheBytes: Int64 = 0

    private var theme: Theme { settings.theme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.sectionSpacing) {
                    SettingsPipelineCard()
                    SettingsPreviewCard()
                    storageCard
                    aboutCard
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .chromeBars()
            .onAppear {
                cacheBytes = devLink.cacheSize()
            }
        }
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Storage")
            HStack {
                Text("Dev download cache").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(byteCount(cacheBytes))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("My wallpapers").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(byteCount(library.totalBytes))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Button {
                devLink.clearCache()
                cacheBytes = devLink.cacheSize()
            } label: {
                Label("Clear download cache", systemImage: "trash")
            }
            .buttonStyle(WowButtonStyle(prominent: false))
        }
        .chromeSurface()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "About")
            infoRow("App", "wow.tok 1.0")
            infoRow("Runs on", "iOS 18 and later")
            infoRow("Tweaks on", "\(settings.enabledCount) of \(TweakCatalog.all.count)")
            infoRow("Dev server", "\(settings.host):\(settings.port)")
            Divider().overlay(theme.hairline)
            Text("iOS does not let an app change the system wallpaper, so wow.tok builds and saves the finished wallpaper and then walks you through the two taps in Settings. SpringBoard-owned chrome (Dock, Control Center, system apps) is handled by the injection profile in the Tweaks tab, not by a switch that would do nothing.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                settings.resetTweaks()
            } label: {
                Label("Reset all tweaks", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(WowButtonStyle(prominent: false))
        }
        .chromeSurface()
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
    }

    private func byteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Pipeline defaults

@MainActor
private struct SettingsPipelineCard: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let theme = settings.theme

        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Wallpaper pipeline",
                          caption: "Defaults applied to every new Live Photo")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Burst length").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(String(format: "%.1fs", settings.trimSeconds))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(value: binding(\.trimSeconds), in: 1...6)
                    .tint(theme.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                label("Max still dimension",
                      "Ignored while Keep source resolution is on")
                Picker(selection: binding(\.maxDimension)) {
                    Text("1080").tag(1080)
                    Text("1440").tag(1440)
                    Text("2160").tag(2160)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
            }

            Divider().overlay(theme.hairline)

            Toggle(isOn: binding(\.includeAudio)) {
                label("Keep audio track",
                      "Wallpapers are silent; enable to keep sound when sharing")
            }
            .tint(theme.accent)

            Toggle(isOn: toggleBinding(.stripMetadata)) {
                label("Strip metadata", "Removes GPS and device tags on export")
            }
            .tint(theme.accent)
        }
        .chromeSurface()
    }

    private func binding<T>(_ path: ReferenceWritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { settings[keyPath: path] },
                set: { newValue in settings[keyPath: path] = newValue })
    }

    private func toggleBinding(_ id: TweakID) -> Binding<Bool> {
        Binding(get: { settings.isOn(id) }, set: { _ in settings.toggle(id) })
    }

    private func label(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

@MainActor
private struct SettingsPreviewCard: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let theme = settings.theme

        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Preview")
            Toggle(isOn: binding(\.loopEnabled)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Loop wallpapers").font(.system(size: 13, weight: .semibold))
                    Text("Seamless repeat in every preview")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(theme.accent)

            Toggle(isOn: binding(\.mutePreview)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mute preview").font(.system(size: 13, weight: .semibold))
                    Text("Silences source audio while browsing")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(theme.accent)
        }
        .chromeSurface()
    }

    private func binding<T>(_ path: ReferenceWritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { settings[keyPath: path] },
                set: { newValue in settings[keyPath: path] = newValue })
    }
}
