import SwiftUI

@MainActor
struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DevLink.self) private var devLink

    @State private var selection: Tab = .wallpapers
    @State private var didAutoConnect = false

    enum Tab: Hashable {
        case wallpapers
        case devLink
        case tweaks
        case settings
    }

    var body: some View {
        let theme = settings.theme
        TabView(selection: $selection) {
            WallpaperLibraryView()
                .tabItem { Label("Wallpapers", systemImage: "photo.stack.fill") }
                .tag(Tab.wallpapers)

            DevLinkView()
                .tabItem { Label("Dev Link", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(Tab.devLink)

            TweaksView()
                .tabItem { Label("Tweaks", systemImage: "slider.horizontal.3") }
                .tag(Tab.tweaks)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(theme.accent)
        .task {
            guard !didAutoConnect else { return }
            didAutoConnect = true
            if settings.isOn(.autoConnectDevLink), !devLink.isConnected {
                await devLink.connect(host: settings.host, port: settings.port)
            }
        }
    }
}
