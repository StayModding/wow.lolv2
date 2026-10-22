import SwiftUI

@MainActor
struct WelcomeSheet: View {
    let onDone: () -> Void
    @Environment(AppSettings.self) private var settings

    private var theme: Theme { settings.theme }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.sectionSpacing) {
                    header
                    card(symbol: "photo.stack.fill",
                         title: "Wallpapers that actually loop",
                         body: "Import a clip and wow-ios writes a paired Live Photo — the only form iOS accepts as a video wallpaper. Presets render on device, no downloads.")
                    card(symbol: "antenna.radiowaves.left.and.right",
                         title: "Pull packs over your tunnel",
                         body: "Run server/devserver.py on your machine, point your dev VPN at port 8787, and the app streams packs straight from your own library.")
                    card(symbol: "slider.horizontal.3",
                         title: "Kill the glass",
                         body: "Tweaks paints over every material, opts out of the Liquid Glass redesign, and exports an injection profile for the system chrome it cannot own.")
                    honestNote
                }
                .padding(18)
            }
            .scrollIndicators(.hidden)

            Button {
                onDone()
            } label: {
                Text("Start")
            }
            .buttonStyle(WowButtonStyle())
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .background(theme.bg.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [theme.accent, theme.accentSecondary],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                Text("w")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.black.opacity(0.8))
            }
            .frame(width: 58, height: 58)

            Text("wow-ios")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            Text("Wallpapers, Live Photos and tweaks for iOS 18 and later.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
    }

    private func card(symbol: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .chromeSurface()
    }

    private var honestNote: some View {
        Text("iOS does not let an app set the wallpaper itself, so wow-ios finishes and saves the item and then walks you through the two taps in Settings.")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .chromeSurface()
    }
}
