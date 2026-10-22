import Foundation
import Observation

/// Talks to the little wallpaper server running on your dev machine. Whatever
/// wires the VPN (tunnel address, port forward, or a localhost proxy) does not
/// matter: this client just needs to reach host:port.
@MainActor
@Observable
final class DevLink {
    enum Status: Equatable {
        case idle
        case connecting
        case connected
        case failed(String)
    }

    var status: Status = .idle
    var manifest: DevManifest?
    var lastConnectedHost: String?
    var busyPackIDs: Set<String> = []
    var message: String?
    var tunnel: [TunnelInterface] = []
    var isScanning = false
    var scanSummary: String?

    private var session: URLSession
    private var base: URL?
    private let cacheRoot: URL

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 90
        configuration.waitsForConnectivity = false
        configuration.allowsExpensiveNetworkAccess = true
        session = URLSession(configuration: configuration)

        cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WowIosRemote", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
    }

    var isConnected: Bool {
        if case .connected = status { return true }
        return false
    }

    static let candidatePorts = [8787, 8080, 8000, 3000, 5000, 9000]

    // MARK: Tunnel

    func refreshTunnel() {
        tunnel = TunnelProbe.interfaces().filter { $0.name.hasPrefix("utun") }
    }

    /// Probes every tunnel-derived host against the common dev ports in parallel and
    /// connects to the first one that answers /api/health.
    @discardableResult
    func scan(preferring host: String, port: Int) async -> Bool {
        guard !isScanning else { return false }
        isScanning = true
        defer { isScanning = false }

        refreshTunnel()
        let hosts = TunnelProbe.candidates(extra: [host])
        let ports = Array(Set([port] + Self.candidatePorts)).sorted()
        let pairs = hosts.flatMap { candidate in ports.map { (candidate, $0) } }
        let session = self.session

        var winner: (host: String, port: Int)?
        await withTaskGroup(of: (host: String, port: Int)?.self) { group in
            for pair in pairs {
                group.addTask {
                    await Self.reachable(session: session, host: pair.0, port: pair.1) ? pair : nil
                }
            }
            for await result in group {
                if let result {
                    winner = result
                    group.cancelAll()
                    break
                }
            }
        }

        guard let winner else {
            status = .failed("No dev server answered on \(hosts.count) hosts × \(ports.count) ports.")
            scanSummary = "Scanned \(hosts.joined(separator: ", ")) on ports \(ports.map(String.init).joined(separator: ", "))."
            return false
        }

        await connect(host: winner.host, port: winner.port)
        scanSummary = "Found the dev server at \(winner.host):\(winner.port)"
        return isConnected
    }

    nonisolated private static func reachable(session: URLSession, host: String, port: Int) async -> Bool {
        guard let url = URL(string: "http://\(host):\(port)/api/health") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.9
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (_, response) = try? await session.data(for: request) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: Connection

    func connect(host: String, port: Int) async {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: "http://\(trimmed):\(port)") else {
            status = .failed("That host and port do not form a URL.")
            return
        }
        status = .connecting
        message = nil
        base = url

        do {
            var request = URLRequest(url: url.appendingPathComponent("api/manifest"))
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("wowios/1.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw DevLinkError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
            }
            let decoded = try JSONDecoder().decode(DevManifest.self, from: data)
            manifest = decoded
            status = .connected
            lastConnectedHost = "\(trimmed):\(port)"
            message = "\(decoded.packs.count) packs from \(decoded.name ?? trimmed)"
        } catch {
            status = .failed(Self.describe(error))
            manifest = nil
        }
    }

    func disconnect() {
        status = .idle
        manifest = nil
        base = nil
        message = "Disconnected"
    }

    func refresh() async {
        guard let base else { return }
        do {
            let (data, _) = try await session.data(from: base.appendingPathComponent("api/manifest"))
            manifest = try JSONDecoder().decode(DevManifest.self, from: data)
            status = .connected
        } catch {
            status = .failed(Self.describe(error))
        }
    }

    func health() async -> Bool {
        guard let base else { return false }
        var request = URLRequest(url: base.appendingPathComponent("api/health"))
        request.timeoutInterval = 4
        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    // MARK: Files

    func url(for path: String) -> URL? {
        if let direct = URL(string: path), direct.scheme != nil { return direct }
        guard let base else { return nil }
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return base.appendingPathComponent(trimmed)
    }

    func cachedFile(for pack: WallpaperPack, remotePath: String) -> URL? {
        let name = URL(string: remotePath)?.lastPathComponent ?? "file"
        let url = cacheRoot.appendingPathComponent(pack.id, isDirectory: true).appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Downloads the master file for a pack and returns the local copy. The bytes
    /// are stored exactly as served, which is what keeps exports watermark-free
    /// and full quality.
    func download(_ path: String, for pack: WallpaperPack) async throws -> URL {
        let name = URL(string: path)?.lastPathComponent ?? "file"
        let folder = cacheRoot.appendingPathComponent(pack.id, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(name)

        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }
        guard let url = url(for: path) else { throw DevLinkError.badURL(path) }

        busyPackIDs.insert(pack.id)
        defer { busyPackIDs.remove(pack.id) }

        let (temp, response) = try await session.download(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw DevLinkError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temp, to: destination)
        return destination
    }

    func clearCache() {
        try? FileManager.default.removeItem(at: cacheRoot)
        try? FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
    }

    func cacheSize() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: cacheRoot,
                                                             includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }

    // MARK: Errors

    private static func describe(_ error: Error) -> String {
        if let devError = error as? DevLinkError {
            return devError.errorDescription ?? "Unknown dev link error"
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost:
                return "Could not reach the dev server. Check the port and that the VPN tunnel is up."
            case NSURLErrorTimedOut:
                return "The dev server did not answer in time."
            case NSURLErrorAppTransportSecurityRequiresSecureConnection:
                return "Blocked by App Transport Security."
            default:
                return nsError.localizedDescription
            }
        }
        return nsError.localizedDescription
    }
}

enum DevLinkError: LocalizedError {
    case badURL(String)
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badURL(let path):
            return "Bad path: \(path)"
        case .badStatus(let code):
            return "Server answered with HTTP \(code)."
        }
    }
}
