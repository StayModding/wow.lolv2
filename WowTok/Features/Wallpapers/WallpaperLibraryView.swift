import SwiftUI

@MainActor
struct WallpaperLibraryView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DevLink.self) private var devLink
    @Environment(LocalLibrary.self) private var library

    @State private var filter: Filter = .all
    @State private var selected: Wallpaper?
    @State private var showImport = false
    @State private var isRefreshing = false

    enum Filter: String, CaseIterable, Identifiable {
        case all, presets, server, mine
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All"
            case .presets: return "Presets"
            case .server: return "Dev server"
            case .mine: return "My wallpapers"
            }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var theme: Theme { settings.theme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.sectionSpacing) {
                    header
                    filterRow
                    if filter == .all || filter == .presets { presetsSection }
                    if filter == .all || filter == .server { serverSection }
                    if filter == .all || filter == .mine { mineSection }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
            .background(theme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .chromeBars()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("wow.tok")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImport = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .accessibilityLabel("Import a wallpaper")
                }
            }
            .sheet(isPresented: $showImport) {
                ImportSheet()
                    .environment(settings)
                    .environment(library)
                    .environment(devLink)
            }
            .navigationDestination(item: $selected) { wallpaper in
                WallpaperDetailView(wallpaper: wallpaper)
                    .environment(settings)
                    .environment(devLink)
                    .environment(library)
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [theme.accent, theme.accentSecondary],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                    Text("w")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.black.opacity(0.8))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text("wow.tok")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                    Text("Wallpapers, live photos and tweaks")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                StatusPill(label: statusLabel, color: statusColor)
                if settings.enabledCount > 0 {
                    Pill(text: "\(settings.enabledCount) tweaks", symbol: "slider.horizontal.3")
                }
            }
        }
        .padding(.top, 8)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { item in
                    Button {
                        withAnimation(theme.animation) { filter = item }
                    } label: {
                        Text(item.label)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                Capsule()
                                    .fill(filter == item ? theme.accent.opacity(0.22) : theme.surface)
                            }
                            .overlay {
                                Capsule().strokeBorder(filter == item ? theme.accent.opacity(0.55) : theme.hairline,
                                                       lineWidth: theme.hairlineWidth)
                            }
                            .foregroundStyle(filter == item ? theme.accent : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Built-in presets",
                          caption: "Generated on device, loop forever, nothing to download")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(PresetID.allCases) { preset in
                    Button {
                        selected = Wallpaper(id: "preset.\(preset.rawValue)",
                                             title: preset.title,
                                             subtitle: preset.subtitle,
                                             kind: .preset,
                                             origin: .preset(preset),
                                             allowDownload: false)
                    } label: {
                        WallpaperCard(wallpaper: Wallpaper(id: "preset.\(preset.rawValue)",
                                                           title: preset.title,
                                                           subtitle: preset.subtitle,
                                                           kind: .preset,
                                                           origin: .preset(preset)),
                                      previewURL: nil)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "From your dev server",
                              caption: devLink.isConnected
                              ? "\(devLink.manifest?.packs.count ?? 0) packs live over the VPN port"
                              : "Connect on the Dev Link tab to pull packs over the tunnel")
                Button {
                    Task {
                        isRefreshing = true
                        await devLink.refresh()
                        isRefreshing = false
                    }
                } label: {
                    if isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .disabled(!devLink.isConnected)
            }

            if let packs = devLink.manifest?.packs, !packs.isEmpty {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(packs) { pack in
                        let model = Wallpaper(pack: pack)
                        Button {
                            selected = model
                        } label: {
                            WallpaperCard(wallpaper: model, previewURL: devLink.url(for: pack.preview))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                EmptyHint(symbol: "antenna.radiowaves.left.and.right",
                          title: "No packs yet",
                          message: "Run the dev server on port 8787 and connect from the Dev Link tab.")
                    .chromeSurface()
            }
        }
    }

    private var mineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "My wallpapers",
                          caption: "Imports and downloads stored on this device")
            if library.wallpapers.isEmpty {
                EmptyHint(symbol: "photo.on.rectangle.angled",
                          title: "Nothing imported",
                          message: "Tap + to turn a video or photo from your library into a wallpaper.")
                    .chromeSurface()
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(library.wallpapers) { item in
                        Button {
                            selected = item
                        } label: {
                            WallpaperCard(wallpaper: item, previewURL: nil)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                if let entry = library.entries.first(where: { $0.id == item.id }) {
                                    library.remove(entry)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var statusLabel: String {
        switch devLink.status {
        case .connected: return devLink.lastConnectedHost ?? "Connected"
        case .connecting: return "Connecting"
        case .failed: return "Dev link offline"
        case .idle: return "Dev link idle"
        }
    }

    private var statusColor: Color {
        switch devLink.status {
        case .connected: return theme.accentSecondary
        case .connecting: return .yellow
        case .failed: return .red
        case .idle: return .secondary
        }
    }
}
