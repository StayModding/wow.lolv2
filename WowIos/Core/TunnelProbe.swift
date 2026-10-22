import Foundation
import Darwin

/// One IPv4 address bound to a network interface.
struct TunnelInterface: Identifiable, Hashable {
    var id: String { "\(name)/\(address)" }
    let name: String
    let address: String
}

/// Reads the tunnel LocalDevVPN installs and works out where the dev server lives.
///
/// The VPN hands the phone a /32 on a utun interface (10.7.0.1 in the shipped app)
/// and routes the next /32 (10.7.1.1) to the machine running the server. Instead of
/// making you type that in, we read the interface table, derive the peer for every
/// address we find, and probe those candidates.
enum TunnelProbe {
    static func interfaces() -> [TunnelInterface] {
        var results: [TunnelInterface] = []
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(pointer.pointee.ifa_flags)
            guard (flags & IFF_UP) == IFF_UP, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let address = pointer.pointee.ifa_addr else { continue }
            guard address.pointee.sa_family == UInt8(AF_INET) else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let code = getnameinfo(address,
                                   socklen_t(address.pointee.sa_len),
                                   &host,
                                   socklen_t(host.count),
                                   nil,
                                   0,
                                   NI_NUMERICHOST)
            guard code == 0 else { continue }
            let name = String(cString: pointer.pointee.ifa_name)
            results.append(TunnelInterface(name: name, address: String(cString: host)))
        }
        return results
    }

    static var tunnelAddresses: [String] {
        interfaces()
            .filter { $0.name.hasPrefix("utun") }
            .map(\.address)
    }

    /// `10.7.0.1` -> `10.7.1.1`: the peer sits on the next third octet in a /32 pair.
    static func peerAddress(for address: String) -> String? {
        let parts = address.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return nil }
        let third = min(254, parts[2] + 1)
        return "\(parts[0]).\(parts[1]).\(third).\(parts[3])"
    }

    /// Ordered, de-duplicated hosts to probe: tunnel peers first, then the tunnel
    /// addresses themselves, then whatever was typed, then loopback.
    static func candidates(extra: [String] = []) -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()

        func add(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return }
            ordered.append(trimmed)
        }

        for address in tunnelAddresses {
            if let peer = peerAddress(for: address) {
                add(peer)
            }
        }
        tunnelAddresses.forEach(add)
        extra.forEach(add)
        add("127.0.0.1")
        add("localhost")
        return ordered
    }
}
