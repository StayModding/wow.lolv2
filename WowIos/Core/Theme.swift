import SwiftUI

enum WowPalette {
    static let violet = Color(red: 0.67, green: 0.53, blue: 1.00)
    static let mint = Color(red: 0.42, green: 0.94, blue: 0.78)
    static let ink = Color(red: 0.043, green: 0.043, blue: 0.059)
    static let slate = Color(red: 0.098, green: 0.098, blue: 0.125)
    static let ash = Color(red: 0.16, green: 0.16, blue: 0.19)
}

/// The resolved look of the app. Every visual tweak in the Tweaks tab lands here,
/// so a toggle can restyle the whole UI in one pass.
struct Theme {
    var flatChrome = false
    var killBarBlur = false
    var squareCorners = false
    var noMotion = false
    var amoled = false
    var highContrastHairlines = false
    var compact = false
    var mintAccent = false

    static let standard = Theme()

    var accent: Color { mintAccent ? WowPalette.mint : WowPalette.violet }
    var accentSecondary: Color { mintAccent ? WowPalette.violet : WowPalette.mint }

    var radius: CGFloat { squareCorners ? 2 : 16 }
    var cardRadius: CGFloat { squareCorners ? 2 : 22 }
    var rowSpacing: CGFloat { compact ? 6 : 12 }
    var sectionSpacing: CGFloat { compact ? 14 : 22 }

    var bg: Color { amoled ? .black : WowPalette.ink }
    var surface: Color {
        if flatChrome { return amoled ? Color(white: 0.06) : WowPalette.slate }
        return Color.white.opacity(amoled ? 0.035 : 0.07)
    }
    var solidChrome: Color { amoled ? Color(white: 0.04) : Color(red: 0.075, green: 0.075, blue: 0.095) }
    var hairline: Color {
        highContrastHairlines ? Color.white.opacity(0.55) : Color.white.opacity(0.10)
    }
    var hairlineWidth: CGFloat { highContrastHairlines ? 1 : 0.5 }
    var animation: Animation? { noMotion ? nil : .easeInOut(duration: 0.22) }
    var spring: Animation? { noMotion ? nil : .snappy(duration: 0.3) }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.standard
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Chrome

/// The one surface style used everywhere. When "Neutralize Liquid Glass" is on,
/// this stops asking the system for a material and paints an opaque fill instead,
/// which is the only way an app can hide glass it does not own.
struct ChromeSurface: ViewModifier {
    @Environment(\.theme) private var theme
    var padding: CGFloat = 14
    var radius: CGFloat? = nil

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius ?? theme.cardRadius, style: .continuous)
        content
            .padding(padding)
            .background {
                ZStack {
                    if theme.flatChrome || theme.killBarBlur {
                        shape.fill(theme.surface)
                    } else {
                        shape.fill(.ultraThinMaterial)
                    }
                    shape.strokeBorder(theme.hairline, lineWidth: theme.hairlineWidth)
                }
            }
    }
}

extension View {
    func chromeSurface(padding: CGFloat = 14, radius: CGFloat? = nil) -> some View {
        modifier(ChromeSurface(padding: padding, radius: radius))
    }

    /// Animates only when the no-motion tweak is off.
    func themeAnimation(_ animation: Animation?) -> some View {
        transaction { transaction in
            transaction.animation = animation
        }
    }
}

struct BarChrome: ViewModifier {
    @Environment(\.theme) private var theme
    func body(content: Content) -> some View {
        content.background {
            if theme.killBarBlur || theme.flatChrome {
                theme.solidChrome.ignoresSafeArea()
            } else {
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            }
        }
    }
}

extension View {
    func barChrome() -> some View { modifier(BarChrome()) }

    /// Applies the chrome tweaks to the navigation and tab bars of one screen.
    /// It has to be attached inside the TabView, so every tab calls it.
    func chromeBars() -> some View { modifier(ChromeBars()) }
}

struct ChromeBars: ViewModifier {
    @Environment(\.theme) private var theme

    @ViewBuilder
    func body(content: Content) -> some View {
        if theme.flatChrome || theme.killBarBlur {
            content
                .toolbarBackground(AnyShapeStyle(theme.solidChrome), for: .navigationBar)
                .toolbarBackground(AnyShapeStyle(theme.solidChrome), for: .tabBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(.visible, for: .tabBar)
        } else {
            content
                .toolbarBackground(.automatic, for: .navigationBar)
                .toolbarBackground(.automatic, for: .tabBar)
        }
    }
}
