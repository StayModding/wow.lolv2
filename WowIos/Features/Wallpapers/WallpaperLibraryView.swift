import SwiftUI

@MainActor
struct WallpaperLibraryView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DevLink.self) private var devLink
    @Environment(LocalLibrary.self) private var library

    @State private var filter: Filter = .all
    @State private var sort: SortOrder = .newest
    @State private var query = ""
    @State private var selected: Wallpaper?
    @State private var showImport = false
    @State private var showStudio = false
    @State private var isRefreshing = false

    enum Filter: String, CaseIterable, Identifiable {
        case all, presets, custom, server, mine, favorites
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All"
            case .presets: return "Presets"
            case .custom: return "Custom"
            case .server: return "Dev server"
            case .mine: return "Mine"
            case .favorites: return "Favorites"
            }
        }
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case newest, alphabetical, hdFirst
        var id: String { rawValue }
        var label: String {
            switch self {
            case .newest: return "Newest"
            case .alphabetical: return "A–Z"
            case .hdFirst: return "HD first"
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
                    searchField
                    filterRow
                    if showsCustom { customSection }
                    if showsPresets { presetsSection }
                    if showsServer { serverSection }
                    if showsMine { mineSection }
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
                    Text("wow-ios")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showStudio = true
                    } label: {
                        Image(systemName: "paintbrush.pointed.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .accessibilityLabel("Preset studio")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(SortOrder.allCases) { order in
                                Text(order.label).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .accessibilityLabel("Sort")
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
            .sheet(isPresented: $showStudio) {
                PresetStudioView()
                    .environment(settings)
                    .environment(library)
            }
            .navigationDestination(item: $selected) { wallpaper in
                WallpaperDetailView(wallpaper: wallpaper)
                    .environment(settings)
                    .environment(devLink)
                    .environment(library)
            }
        }
    }

    // MARK: Header

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
                    Text("wow-ios")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                    Text("Wallpapers, Live Photos and tweaks")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                StatusPill(label: statusLabel, color: statusColor)
                if !settings.favorites.isEmpty {
                    Pill(text: "\(settings.favorites.count) saved", tint: theme.accentSecondary, symbol: "star.fill")
                }
                if settings.enabledCount > 0 {
                    Pill(text: "\(settings.enabledCount) tweaks", symbol: "slider.horizontal.3")
                }
            }
        }
        .padding(.top, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Search wallpapers, tags, presets", text: $query)
                .font(.system(size: 13))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: theme.radius, style: .continuous).fill(theme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                .strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth)
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { item in
                    Button {
                        Haptics.select()
                        withAnimation(theme.animation) { filter = item }
                    } label: {
                        Text(item.label)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                Capsule().fill(filter == item ? theme.accent.opacity(0.22) : theme.surface)
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

    // MARK: Sections

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Custom gradients",
                              caption: "Built in the preset studio, rendered on device")
                Button {
                    showStudio = true
                } label: {
                    Text("Studio").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }

            if filteredCustom.isEmpty {
                EmptyHint(symbol: "paintbrush.pointed.fill",
                          title: settings.customPresets.isEmpty ? "No custom gradients yet" : "No matches",
                          message: settings.customPresets.isEmpty
                          ? "Open the studio, pick three colours, save. It shows up here and exports at native resolution."
                          : "Try a different search.")
                    .chromeSurface()
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredCustom) { preset in
                        let model = Wallpaper(custom: preset)
                        Button {
                            selected = model
                        } label: {
                            WallpaperCard(wallpaper: model, previewURL: nil)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                settings.toggleFavorite(model.id)
                            } label: {
                                Label(settings.isFavorite(model.id) ? "Unfavorite" : "Favorite", systemImage: "star")
                            }
                            Button(role: .destructive) {
                                settings.deleteCustomPreset(preset.id)
                            } label: {
                                Label("Delete gradient", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Built-in presets",
                          caption: "Generated on device, loop forever, nothing to download")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredPresets) { preset in
                    let model = Wallpaper(id: "preset.\(preset.rawValue)",
                                          title: preset.title,
                                          subtitle: preset.subtitle,
                                          kind: .preset,
                                          origin: .preset(preset))
                    Button {
                        selected = model
                    } label: {
                        WallpaperCard(wallpaper: model, previewURL: nil)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            settings.toggleFavorite(model.id)
                        } label: {
                            Label(settings.isFavorite(model.id) ? "Unfavorite" : "Favorite", systemImage: "star")
                        }
                    }
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

            if filteredPacks.isEmpty {
                EmptyHint(symbol: "antenna.radiowaves.left.and.right",
                          title: devLink.manifest == nil ? "No packs yet" : "No matches",
                          message: devLink.manifest == nil
                          ? "Run the dev server on port 8787 and connect from the Dev Link tab."
                          : "Try a different search.")
                    .chromeSurface()
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredPacks) { pack in
                        let model = Wallpaper(pack: pack)
                        Button {
                            selected = model
                        } label: {
                            WallpaperCard(wallpaper: model, previewURL: devLink.url(for: pack.preview))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                settings.toggleFavorite(model.id)
                            } label: {
                                Label(settings.isFavorite(model.id) ? "Unfavorite" : "Favorite", systemImage: "star")
                            }
                        }
                    }
                }
            }
        }
    }

    private var mineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "My wallpapers",
                          caption: "Imports and downloads stored on this device")
            if filteredMine.isEmpty {
                EmptyHint(symbol: "photo.on.rectangle.angled",
                          title: library.wallpapers.isEmpty ? "Nothing imported" : "No matches",
                          message: library.wallpapers.isEmpty
                          ? "Tap + to turn a video or photo from your library into a wallpaper."
                          : "Try a different search.")
                    .chromeSurface()
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredMine) { item in
                        Button {
                            selected = item
                        } label: {
                            WallpaperCard(wallpaper: item, previewURL: nil)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                settings.toggleFavorite(item.id)
                            } label: {
                                Label(settings.isFavorite(item.id) ? "Unfavorite" : "Favorite", systemImage: "star")
                            }
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

    // MARK: Filtering

    private var showsCustom: Bool { filter == .all || filter == .custom || filter == .favorites }
    private var showsPresets: Bool { filter == .all || filter == .presets || filter == .favorites }
    private var showsServer: Bool { filter == .all || filter == .server || filter == .favorites }
    private var showsMine: Bool { filter == .all || filter == .mine || filter == .favorites }

    private var needle: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func matches(_ text: String) -> Bool {
        needle.isEmpty || text.lowercased().contains(needle)
    }

    private var filteredCustom: [CustomPreset] {
        let items = settings.customPresets.filter { preset in
            let favoriteOK = filter != .favorites || settings.isFavorite("custom.\(preset.id.uuidString)")
            return favoriteOK && matches("\(preset.name) custom gradient \(preset.accentHex)")
        }
        return sortedByName(items, name: { $0.name })
    }

    private var filteredPresets: [PresetID] {
        let items = PresetID.allCases.filter { preset in
            let id = "preset.\(preset.rawValue)"
            let favoriteOK = filter != .favorites || settings.isFavorite(id)
            return favoriteOK && matches("\(preset.title) \(preset.subtitle) preset")
        }
        return sortedByName(items, name: { $0.title })
    }

    private var filteredPacks: [WallpaperPack] {
        let items = (devLink.manifest?.packs ?? []).filter { pack in
            let favoriteOK = filter != .favorites || settings.isFavorite(pack.id)
            let haystack = "\(pack.title) \(pack.author ?? "") \(pack.tags?.joined(separator: " ") ?? "") \(pack.kind)"
            return favoriteOK && matches(haystack)
        }
        if sort == .alphabetical {
            return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        if sort == .hdFirst {
            return items.sorted { ($0.hd ?? true) && !($1.hd ?? true) }
        }
        return items
    }

    private var filteredMine: [Wallpaper] {
        let items = library.wallpapers.filter { item in
            let favoriteOK = filter != .favorites || settings.isFavorite(item.id)
            return favoriteOK && matches("\(item.title) \(item.subtitle) \(item.kind.label)")
        }
        if sort == .alphabetical {
            return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return items
    }

    private func sortedByName<T>(_ items: [T], name: (T) -> String) -> [T] {
        guard sort == .alphabetical else { return items }
        return items.sorted { name($0).localizedCaseInsensitiveCompare(name($1)) == .orderedAscending }
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
