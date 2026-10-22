import SwiftUI

@main
@MainActor
struct WowIosApp: App {
    @State private var settings = AppSettings()
    @State private var devLink = DevLink()
    @State private var library = LocalLibrary()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(devLink)
                .environment(library)
                .environment(\.theme, settings.theme)
                .preferredColorScheme(.dark)
                .tint(settings.theme.accent)
                .onOpenURL { url in
                    handle(url)
                }
        }
    }

    /// wowios://connect?host=192.168.1.20&port=8787 opens the app already pointed
    /// at a dev server, so a QR code is enough to set a phone up.
    @MainActor
    private func handle(_ url: URL) {
        guard url.scheme == "wowios", url.host == "connect" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let host = components?.queryItems?.first(where: { $0.name == "host" })?.value ?? settings.host
        let port = Int(components?.queryItems?.first(where: { $0.name == "port" })?.value ?? "") ?? settings.port
        settings.host = host
        settings.port = port
        settings.rememberHost("\(host):\(port)")
        Task { await devLink.connect(host: host, port: port) }
    }
}
