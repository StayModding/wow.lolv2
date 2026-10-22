import SwiftUI
import UIKit

@MainActor
struct DevLinkView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DevLink.self) private var devLink
    @Environment(LocalLibrary.self) private var library

    @State private var host = ""
    @State private var portText = "8787"
    @State private var busy = false
    @State private var pulling = false
    @State private var didAutoScan = false
    @State private var errorMessage: String?
    @State private var toast: String?

    private var theme: Theme { settings.theme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.sectionSpacing) {
                    tunnelCard
                    connectionCard
                    recentCard
                    packSection
                    helpCard
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(theme.bg.ignoresSafeArea())
            .navigationTitle("Dev Link")
            .navigationBarTitleDisplayMode(.large)
            .chromeBars()
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(theme.solidChrome))
                        .overlay(Capsule().strokeBorder(theme.hairline, lineWidth: 1))
                        .padding(.bottom, 22)
                }
            }
            .onAppear {
                if host.isEmpty {
                    host = settings.host
                }
                portText = String(settings.port)
                devLink.refreshTunnel()
            }
            .task { await autoScanIfNeeded() }
        }
    }

    // MARK: Tunnel

    private var tunnelCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "LocalDevVPN",
                              caption: devLink.tunnel.isEmpty
                              ? "No tunnel interface yet"
                              : "Read straight from the interface table")
                Button {
                    Task { await scan() }
                } label: {
                    if devLink.isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Scan")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }
                }
                .buttonStyle(.plain)
                .disabled(devLink.isScanning)
            }

            if devLink.tunnel.isEmpty {
                Text("Open LocalDevVPN and connect, then scan. The app reads the utun address and derives the peer (10.7.0.1 → 10.7.1.1) on its own.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(devLink.tunnel) { interface in
                    HStack(spacing: 8) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.accentSecondary)
                        Text(interface.name)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(interface.address)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                }
            }

            if let summary = devLink.scanSummary {
                Text(summary)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .chromeSurface()
    }

    private func autoScanIfNeeded() async {
        guard !didAutoScan, !devLink.isConnected else { return }
        didAutoScan = true
        devLink.refreshTunnel()
        guard !devLink.tunnel.isEmpty else { return }
        await scan()
    }

    private func scan() async {
        let port = Int(portText.trimmingCharacters(in: .whitespaces)) ?? settings.port
        let found = await devLink.scan(preferring: host, port: port)
        guard found, let connected = devLink.lastConnectedHost else { return }
        let parts = connected.split(separator: ":")
        host = parts.first.map(String.init) ?? host
        if parts.count > 1 { portText = String(parts[1]) }
        settings.host = host
        if let parsed = Int(portText) { settings.port = parsed }
        settings.rememberHost(connected)
        Haptics.success()
    }

    // MARK: Connection

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Local dev server",
                              caption: "Whatever the VPN exposes · host + port")
                StatusPill(label: statusLabel, color: statusColor)
            }

            HStack(spacing: 8) {
                field(label: "Host", text: $host, keyboard: .URL)
                field(label: "Port", text: $portText, keyboard: .numberPad, width: 90)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await connect() }
                } label: {
                    if busy {
                        ProgressView().tint(.black)
                    } else {
                        Text(devLink.isConnected ? "Reconnect" : "Connect")
                    }
                }
                .buttonStyle(WowButtonStyle())
                .disabled(busy)

                if devLink.isConnected {
                    Button {
                        devLink.disconnect()
                    } label: {
                        Text("Disconnect")
                    }
                    .buttonStyle(WowButtonStyle(prominent: false))
                    .frame(width: 130)
                }
            }

            if let message = devLink.message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if case let .failed(reason) = devLink.status {
                Text(reason)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.9))
            }
        }
        .chromeSurface()
    }

    private func field(label: String,
                       text: Binding<String>,
                       keyboard: UIKeyboardType,
                       width: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            TextField("", text: text)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                        .fill(theme.solidChrome)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                        .strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth)
                }
        }
        .frame(width: width)
    }

    private var recentCard: some View {
        Group {
            if !settings.recentHosts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Recent")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(settings.recentHosts, id: \.self) { entry in
                                Button {
                                    let parts = entry.split(separator: ":")
                                    host = parts.first.map(String.init) ?? entry
                                    if parts.count > 1 { portText = String(parts[1]) }
                                } label: {
                                    Text(entry)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(theme.surface))
                                        .overlay(Capsule().strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .chromeSurface()
            }
        }
    }

    // MARK: Packs

    private var packSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionHeader(title: "Server library",
                              caption: devLink.isConnected ? "Downloads stay in their original resolution" : "Connect to browse")
                if devLink.isConnected {
                    Button {
                        copyConnectLink()
                    } label: {
                        Image(systemName: "link")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy connect link")

                    Button {
                        Task { await pullAll() }
                    } label: {
                        if pulling {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(pulling)
                    .accessibilityLabel("Pull every pack")
                }
            }
            if let packs = devLink.manifest?.packs, !packs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(packs.enumerated()), id: \.element.id) { index, pack in
                        packRow(pack)
                        if index < packs.count - 1 {
                            Divider().overlay(theme.hairline).padding(.leading, 12)
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous).fill(theme.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
                        .strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth)
                }
            } else {
                EmptyHint(symbol: "externaldrive.connected.to.line.below",
                          title: "No packs",
                          message: "Start server/devserver.py on your machine, then connect on the port your VPN forwards.")
                    .chromeSurface()
            }
        }
    }

    private func packRow(_ pack: WallpaperPack) -> some View {
        HStack(spacing: 10) {
            AsyncThumbnail(url: devLink.url(for: pack.preview))
                .frame(width: 40, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(pack.title).font(.system(size: 13, weight: .semibold))
                HStack(spacing: 5) {
                    Pill(text: pack.resolvedKind.label, tint: theme.accent)
                    if pack.hd ?? true { Pill(text: "HD", tint: theme.accentSecondary) }
                }
            }
            Spacer()
            if devLink.busyPackIDs.contains(pack.id) {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await download(pack) }
                } label: {
                    Image(systemName: library.contains(title: pack.title) ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "How the port handshake works",
                          caption: "No cloud, no account")
            VStack(alignment: .leading, spacing: 6) {
                bullet("1", "Run the dev server on your machine: python server/devserver.py --port 8787")
                bullet("2", "Connect LocalDevVPN. The phone sits on 10.7.0.1 and the host is routed at 10.7.1.1; Scan reads the utun address and probes that peer for you.")
                bullet("3", "wow-ios calls /api/manifest and streams packs byte for byte over plain HTTP on the tunnel, then converts any MP4 into a Live Photo locally.")
            }
        }
        .chromeSurface()
    }

    private func bullet(_ index: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(index)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 16, height: 16)
                .background(Circle().fill(theme.accent.opacity(0.22)))
                .foregroundStyle(theme.accent)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Actions

    private func connect() async {
        guard !busy else { return }
        busy = true
        errorMessage = nil
        defer { busy = false }
        let port = Int(portText.trimmingCharacters(in: .whitespaces)) ?? settings.port
        await devLink.connect(host: host, port: port)
        if devLink.isConnected {
            settings.host = host.trimmingCharacters(in: .whitespaces)
            settings.port = port
            settings.rememberHost("\(settings.host):\(port)")
            Haptics.success()
        } else if !devLink.tunnel.isEmpty {
            // The typed address did not answer; let the tunnel scan find the server.
            await scan()
        }
    }

    private func download(_ pack: WallpaperPack) async {
        guard let path = pack.video ?? pack.still else { return }
        errorMessage = nil
        do {
            let file = try await devLink.download(path, for: pack)
            try library.add(fileURL: file,
                            title: pack.title,
                            kind: pack.resolvedKind == .photo ? .photo : .video,
                            allowDownload: pack.allowDownload ?? true)
            showToast("Saved \(pack.title)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Pulls every pack the server advertises into the on-device library.
    private func pullAll() async {
        guard let packs = devLink.manifest?.packs, !packs.isEmpty, !pulling else { return }
        pulling = true
        defer { pulling = false }
        var added = 0
        for pack in packs {
            guard let path = pack.video ?? pack.still else { continue }
            do {
                let file = try await devLink.download(path, for: pack)
                if !library.contains(title: pack.title) {
                    try library.add(fileURL: file,
                                    title: pack.title,
                                    kind: pack.resolvedKind == .photo ? .photo : .video,
                                    allowDownload: pack.allowDownload ?? true)
                    added += 1
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        Haptics.success()
        showToast("Pulled \(added) packs")
    }

    /// A deep link another device (or a QR code) can open to jump straight in.
    private func copyConnectLink() {
        let link = "wowios://connect?host=\(host)&port=\(portText)"
        UIPasteboard.general.string = link
        Haptics.tap()
        showToast("Connect link copied")
    }

    private func showToast(_ text: String) {
        withAnimation(theme.spring) { toast = text }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(theme.spring) { toast = nil }
        }
    }

    private var statusLabel: String {
        switch devLink.status {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .failed: return "Failed"
        case .idle: return "Idle"
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
