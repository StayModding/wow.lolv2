import SwiftUI

@MainActor
struct TweaksView: View {
    @Environment(AppSettings.self) private var settings
    @State private var sharePayload: ExportPayload?
    @State private var expanded: TweakID?
    @State private var profileName = ""
    @State private var showProfilePrompt = false

    struct ExportPayload: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var theme: Theme { settings.theme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.sectionSpacing) {
                    header
                    profilesCard
                    ForEach(TweakGroup.allCases) { group in
                        let tweaks = TweakCatalog.tweaks(in: group)
                        if !tweaks.isEmpty {
                            groupSection(group: group, tweaks: tweaks)
                        }
                    }
                    injectionCard
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle("Tweaks")
            .navigationBarTitleDisplayMode(.large)
            .chromeBars()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        settings.resetTweaks()
                    } label: {
                        Text("Reset").font(.system(size: 13, weight: .semibold))
                    }
                }
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: [payload.url])
                    .presentationDetents([.medium, .large])
            }
            .alert("Save tweak profile", isPresented: $showProfilePrompt) {
                TextField("Profile name", text: $profileName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    settings.saveProfile(named: profileName)
                    profileName = ""
                }
            } message: {
                Text("Stores the current tweak set so you can reapply it in one tap.")
            }
        }
    }

    private var profilesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Profiles",
                          caption: "Named tweak sets · \(settings.tweakProfiles.count) saved")

            if settings.tweakProfiles.isEmpty {
                Text("No profiles yet. Dial in a look, then save it here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(settings.tweakProfiles) { profile in
                            Button {
                                settings.applyProfile(profile)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("\(profile.tweaks.count) tweaks")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(theme.surface))
                                .overlay(Capsule().strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    settings.deleteProfile(profile.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }

            Button {
                showProfilePrompt = true
            } label: {
                Label("Save current as profile", systemImage: "square.and.arrow.down.on.square")
            }
            .buttonStyle(WowButtonStyle(prominent: false))
        }
        .chromeSurface()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(settings.enabledCount) of \(TweakCatalog.all.count) applied")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.accent)
            Text("Chrome switches are live. Rows marked Injection change SpringBoard, which lives outside this app's sandbox, so wow-ios exports a profile for your dev VPN tweak loader instead of pretending it can patch the system.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .chromeSurface()
    }

    private func groupSection(group: TweakGroup, tweaks: [Tweak]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: group.rawValue)
            VStack(spacing: 0) {
                ForEach(Array(tweaks.enumerated()), id: \.element.id) { index, tweak in
                    tweakRow(tweak)
                    if index < tweaks.count - 1 {
                        Divider().overlay(theme.hairline).padding(.leading, 44)
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
                    .fill(theme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
                    .strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth)
            }
        }
    }

    private func tweakRow(_ tweak: Tweak) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: tweak.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(settings.isOn(tweak.id) ? theme.accent : Color.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(tweak.title)
                            .font(.system(size: 14, weight: .semibold))
                        if tweak.scope == .injection {
                            Pill(text: "Injection", tint: .orange, symbol: "cpu")
                        }
                        if tweak.needsRestart {
                            Pill(text: "Restart", tint: .secondary)
                        }
                    }
                    Text(tweak.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(expanded == tweak.id ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)

                Toggle("", isOn: Binding(get: { settings.isOn(tweak.id) },
                                         set: { _ in settings.toggle(tweak.id) }))
                    .labelsHidden()
                    .tint(tweak.scope == .injection ? .orange : theme.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(theme.animation) {
                    expanded = expanded == tweak.id ? nil : tweak.id
                }
            }
        }
    }

    private var injectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Injection profile",
                          caption: "For the tweaks that live in SpringBoard")
            Text("Export the JSON and point your dev VPN app at it. It carries the enabled system tweaks plus the full app profile so the loader knows what to apply.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                exportProfile()
            } label: {
                Label("Export injection profile", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(WowButtonStyle(prominent: false))
        }
        .chromeSurface()
    }

    private func exportProfile() {
        let json = settings.injectionProfile()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wowios-injection-profile.json")
        do {
            try json.write(to: url, atomically: true, encoding: .utf8)
            sharePayload = ExportPayload(url: url)
        } catch {
            // Nothing user-facing to do here; the file is recreated on every export.
        }
    }
}
