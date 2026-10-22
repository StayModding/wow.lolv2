import SwiftUI
import AVFoundation

@MainActor
struct WallpaperDetailView: View {
    let wallpaper: Wallpaper

    @Environment(AppSettings.self) private var settings
    @Environment(DevLink.self) private var devLink
    @Environment(LocalLibrary.self) private var library
    @Environment(\.theme) private var theme

    @State private var loop = true
    @State private var mute = true
    @State private var showGuides = false
    @State private var sourceURL: URL?
    @State private var sourceDuration: Double = 3
    @State private var trimStart: Double = 0
    @State private var trimLength: Double = 3
    @State private var isLoading = false
    @State private var busyMessage: String?
    @State private var errorMessage: String?
    @State private var toast: String?
    @State private var sharePayload: SharePayload?
    @State private var didLoad = false

    struct SharePayload: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.sectionSpacing) {
                hero
                titleBlock
                playbackControls
                if isVideo { trimControls }
                actionButtons
                howToSet
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .chromeSurface()
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle(wallpaper.title)
        .navigationBarTitleDisplayMode(.inline)
        .chromeBars()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let added = settings.toggleFavorite(wallpaper.id)
                    showToast(added ? "Added to favorites" : "Removed from favorites")
                } label: {
                    Image(systemName: settings.isFavorite(wallpaper.id) ? "star.fill" : "star")
                }
                .accessibilityLabel("Favorite")
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(theme.solidChrome))
                    .overlay(Capsule().strokeBorder(theme.hairline, lineWidth: 1))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: [payload.url])
                .presentationDetents([.medium, .large])
        }
        .task { await prepare() }
    }

    // MARK: Hero

    private var hero: some View {
        ZStack {
            Color.black

            if let sourceURL, isVideo {
                LoopVideoView(url: sourceURL,
                              looping: loop,
                              muted: mute,
                              pauseOnLowPower: settings.isOn(.pauseLoopOnLowPower))
                    .id(sourceURL)
            } else if case let .preset(id) = wallpaper.origin {
                PresetWallpaperView(preset: id, animated: !settings.isOn(.noMotion))
            } else if case let .custom(preset) = wallpaper.origin {
                CustomPresetView(preset: preset, animated: !settings.isOn(.noMotion))
            } else if let preview = previewURL {
                AsyncThumbnail(url: preview)
            } else if let sourceURL, wallpaper.kind == .photo {
                LocalPhotoThumbnail(url: sourceURL)
            }

            if showGuides {
                LockScreenGuides()
            }

            if isLoading || busyMessage != nil {
                ZStack {
                    Color.black.opacity(0.55)
                    VStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text(busyMessage ?? "Loading source…")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
                .strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth)
        }
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 6) {
                Pill(text: wallpaper.kind.label, symbol: "sparkles")
                if wallpaper.isHD { Pill(text: "No watermark", tint: theme.accentSecondary) }
                if isVideo { Pill(text: loop ? "Looping" : "Play once", tint: .white.opacity(0.85)) }
            }
            .padding(10)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(wallpaper.title)
                .font(.system(size: 22, weight: .bold))
            Text(wallpaper.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Controls

    private var playbackControls: some View {
        VStack(spacing: 2) {
            if isVideo {
                toggleRow(title: "Loop playback",
                          detail: "Seamless AVPlayerLooper, no gap between repeats",
                          isOn: $loop,
                          symbol: "arrow.triangle.2.circlepath")
                toggleRow(title: "Mute preview",
                          detail: "Wallpapers are silent on the lock screen anyway",
                          isOn: $mute,
                          symbol: "speaker.slash.fill")
            }
            if settings.isOn(.safeAreaGuides) || showGuides {
                toggleRow(title: "Show lock-screen guides",
                          detail: "Frames the clock and status bar over the preview",
                          isOn: $showGuides,
                          symbol: "ruler")
            }
        }
        .chromeSurface(padding: 4)
    }

    private var trimControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Trim",
                          caption: String(format: "Live Photo wallpaper burst · %.1fs of %.1fs",
                                          trimLength, sourceDuration))
            VStack(spacing: 6) {
                Slider(value: $trimStart, in: 0...max(0.5, sourceDuration - 0.6))
                    .tint(theme.accent)
                HStack {
                    Text("Start").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1fs", trimStart))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                Slider(value: $trimLength, in: 1...min(6, max(1, sourceDuration)))
                    .tint(theme.accentSecondary)
                HStack {
                    Text("Length").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1fs", trimLength))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
        }
        .chromeSurface()
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if wallpaper.kind == .preset {
                Button {
                    Task { await savePreset() }
                } label: {
                    Label("Save preset as photo · 1179×2556", systemImage: "sparkles")
                }
                .buttonStyle(WowButtonStyle())
                .disabled(busyMessage != nil)
            } else if wallpaper.kind == .photo {
                Button {
                    Task { await savePhoto() }
                } label: {
                    Label("Save photo to Photos", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(WowButtonStyle())
            } else {
                Button {
                    Task { await makeLivePhoto() }
                } label: {
                    Label("Save as Live Photo wallpaper", systemImage: "livephoto")
                }
                .buttonStyle(WowButtonStyle())
                .disabled(busyMessage != nil || isLoading)
            }

            if isVideo {
                Button {
                    Task { await exportHD() }
                } label: {
                    Label("Export HD video · no watermark", systemImage: "arrow.up.forward.square")
                }
                .buttonStyle(WowButtonStyle(prominent: false))
                .disabled(busyMessage != nil)
            }

            if wallpaper.pack != nil {
                Button {
                    Task { await addToLibrary() }
                } label: {
                    Label(library.contains(title: wallpaper.title) ? "Already in my wallpapers" : "Keep in my wallpapers",
                          systemImage: "tray.and.arrow.down.fill")
                }
                .buttonStyle(WowButtonStyle(prominent: false))
                .disabled(busyMessage != nil || isLoading)
            }
        }
    }

    private var howToSet: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Set it as your wallpaper",
                          caption: "iOS has no public API for changing the wallpaper, so the last two taps are yours")
            VStack(alignment: .leading, spacing: 6) {
                step(1, "Save the Live Photo above. It lands in Recents as a normal live photo.")
                step(2, "Open Settings → Wallpaper → Add New Wallpaper → Photos.")
                step(3, "Pick the saved item, tap the Live Photo button if it is offered, then Set as Wallpaper Pair.")
            }
        }
        .chromeSurface()
    }

    private func step(_ index: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index)")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 16, height: 16)
                .background(Circle().fill(theme.accent.opacity(0.25)))
                .foregroundStyle(theme.accent)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toggleRow(title: String, detail: String, isOn: Binding<Bool>, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(theme.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: Derived

    private var isVideo: Bool {
        wallpaper.kind == .video || wallpaper.kind == .live
    }

    private var previewURL: URL? {
        guard let pack = wallpaper.pack else { return nil }
        return devLink.url(for: pack.preview)
    }

    private var trimRange: ClosedRange<Double> {
        let start = max(0, min(trimStart, max(0, sourceDuration - 0.4)))
        let end = min(max(start + 0.4, start + trimLength), max(sourceDuration, start + 1))
        return start...end
    }

    // MARK: Loading

    private func prepare() async {
        guard !didLoad else { return }
        didLoad = true
        loop = settings.loopEnabled
        mute = settings.mutePreview
        showGuides = settings.isOn(.safeAreaGuides)
        trimLength = settings.isOn(.autoTrimThreeSeconds) ? settings.trimSeconds : 5

        if let local = wallpaper.localURL {
            sourceURL = local
            sourceDuration = await duration(of: local)
            return
        }
        guard let pack = wallpaper.pack else { return }

        isLoading = true
        defer { isLoading = false }
        do {
            if let video = pack.video {
                let file = try await devLink.download(video, for: pack)
                sourceURL = file
                sourceDuration = await duration(of: file)
            } else if let still = pack.still {
                sourceURL = try await devLink.download(still, for: pack)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func duration(of url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        let seconds = (try? await asset.load(.duration).seconds) ?? 3
        return seconds.isFinite ? max(0.5, seconds) : 3
    }

    // MARK: Actions

    private func makeLivePhoto() async {
        guard let sourceURL else {
            errorMessage = "The source file is not downloaded yet."
            return
        }
        busyMessage = "Building Live Photo…"
        errorMessage = nil
        defer { busyMessage = nil }

        var options = settings.livePhotoOptions
        options.trim = isVideo ? trimRange : nil
        do {
            let bundle = try await LivePhotoBuilder.makeLivePhoto(fromVideo: sourceURL, options: options)
            try await LivePhotoBuilder.saveLivePhotoToLibrary(bundle)
            showToast("Live Photo saved · \(Int(bundle.pixelSize.width))×\(Int(bundle.pixelSize.height))")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Presets are drawn with MeshGradient, so "exporting" means rendering a frame
    /// at the native resolution of a current iPhone and writing a clean JPEG.
    private func savePreset() async {
        busyMessage = "Rendering gradient…"
        defer { busyMessage = nil }

        let image: CGImage?
        let title = wallpaper.title
        switch wallpaper.origin {
        case .preset(let id):
            let renderer = ImageRenderer(content: PresetWallpaperView(preset: id, animated: false)
                .frame(width: 1179, height: 2556))
            renderer.scale = 1
            image = renderer.cgImage
        case .custom(let preset):
            image = StudioRenderer.render(preset)
        default:
            image = nil
        }
        guard let image else {
            errorMessage = "Could not render that gradient."
            return
        }
        do {
            let url = LivePhotoBuilder.temporaryURL(fileExtension: "jpg", prefix: "wowios-preset")
            try LivePhotoBuilder.writeJPEG(image, to: url, quality: 0.97, identifier: nil)
            try library.storeExport(title: title, kind: "Preset", fileURL: url)
            try await LivePhotoBuilder.savePhotoToLibrary(url)
            Haptics.success()
            showToast("Saved \(title) at 1179×2556")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func savePhoto() async {
        busyMessage = "Saving photo…"
        defer { busyMessage = nil }
        do {
            if let sourceURL, wallpaper.kind == .photo, wallpaper.localURL != nil {
                try await LivePhotoBuilder.savePhotoToLibrary(sourceURL)
                showToast("Photo saved to Photos")
                return
            }
            guard let pack = wallpaper.pack else { return }
            let still = pack.still ?? pack.preview
            let downloaded = try await devLink.download(still, for: pack)
            let prepared = try LivePhotoBuilder.makeStill(fromImage: downloaded, options: settings.livePhotoOptions)
            try await LivePhotoBuilder.savePhotoToLibrary(prepared)
            showToast("Photo saved to Photos")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportHD() async {
        guard let sourceURL else {
            errorMessage = "Download the source first."
            return
        }
        busyMessage = "Preparing HD export…"
        defer { busyMessage = nil }
        do {
            let file = try await LivePhotoBuilder.exportMaster(from: sourceURL,
                                                              stripMetadata: settings.isOn(.stripMetadata))
            sharePayload = SharePayload(url: file)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addToLibrary() async {
        guard let pack = wallpaper.pack, let video = pack.video else { return }
        busyMessage = "Downloading master…"
        defer { busyMessage = nil }
        do {
            let file = try await devLink.download(video, for: pack)
            try library.add(fileURL: file, title: wallpaper.title, kind: wallpaper.kind, allowDownload: true)
            showToast("Saved to my wallpapers")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func showToast(_ text: String) {
        withAnimation(theme.spring) { toast = text }
        Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            withAnimation(theme.spring) { toast = nil }
        }
    }
}
