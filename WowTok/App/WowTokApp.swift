import SwiftUI

@main
@MainActor
struct WowTokApp: App {
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
        }
    }
}
