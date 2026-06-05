import SwiftUI

// MARK: - Color Palette

enum AppTheme {
    // Primary accent — refined teal-cyan
    static let accent = Color(hue: 0.52, saturation: 0.78, brightness: 0.92)
    // Secondary accent — softer blue
    static let accentSecondary = Color(hue: 0.62, saturation: 0.55, brightness: 0.88)
    // Warm highlight for CTAs
    static let accentWarm = Color(hue: 0.08, saturation: 0.72, brightness: 0.98)

    // Surface colors
    static let surfacePrimary = Color(hue: 0.63, saturation: 0.18, brightness: 0.11)
    static let surfaceElevated = Color(hue: 0.63, saturation: 0.14, brightness: 0.15)
    static let surfaceCard = Color.white.opacity(0.06)
    static let surfaceCardHover = Color.white.opacity(0.10)

    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textTertiary = Color.white.opacity(0.48)

    // Borders
    static let borderSubtle = Color.white.opacity(0.08)
    static let borderSelected = Color(hue: 0.52, saturation: 0.78, brightness: 0.92)

    // Status
    static let statusActive = Color(hue: 0.38, saturation: 0.72, brightness: 0.82)
    static let statusBadge = Color(hue: 0.0, saturation: 0.72, brightness: 0.92)
}

// MARK: - Gradients

enum AppGradient {
    static let accentButton = LinearGradient(
        colors: [
            Color(hue: 0.52, saturation: 0.68, brightness: 0.92),
            Color(hue: 0.60, saturation: 0.62, brightness: 0.82)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let headerScrim = LinearGradient(
        colors: [
            Color.black.opacity(0.72),
            Color.black.opacity(0.38),
            Color.black.opacity(0.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let panelBackground = LinearGradient(
        colors: [
            Color(hue: 0.63, saturation: 0.15, brightness: 0.14).opacity(0.92),
            Color(hue: 0.63, saturation: 0.18, brightness: 0.10).opacity(0.96)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let orbGlow = RadialGradient(
        colors: [
            Color(hue: 0.52, saturation: 0.82, brightness: 0.95).opacity(0.9),
            Color(hue: 0.58, saturation: 0.72, brightness: 0.78).opacity(0.6),
            Color(hue: 0.65, saturation: 0.60, brightness: 0.40).opacity(0.2),
            Color.clear
        ],
        center: .center,
        startRadius: 6,
        endRadius: 40
    )
}

// MARK: - Spacing

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
}

// MARK: - Corner Radius

enum CornerRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 28
    static let pill: CGFloat = 100
}

// MARK: - Typography Helpers

extension Font {
    static let appLargeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let appTitle = Font.system(size: 22, weight: .bold, design: .rounded)
    static let appHeadline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let appSubheadline = Font.system(size: 15, weight: .medium, design: .rounded)
    static let appBody = Font.system(size: 15, weight: .regular, design: .default)
    static let appCaption = Font.system(size: 13, weight: .medium, design: .rounded)
    static let appPrice = Font.system(size: 20, weight: .bold, design: .rounded)
    static let appPriceSmall = Font.system(size: 16, weight: .bold, design: .rounded)
    static let appBadge = Font.system(size: 11, weight: .bold, design: .rounded)
}

// MARK: - Reusable View Modifiers

struct FrostedGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = CornerRadius.xl
    var borderOpacity: Double = 0.08

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: 0.5)
            )
    }
}

struct CardModifier: ViewModifier {
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill(AppTheme.surfaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .stroke(
                        isSelected ? AppTheme.borderSelected : AppTheme.borderSubtle,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .shadow(color: isSelected ? AppTheme.accent.opacity(0.18) : .clear, radius: 12, y: 4)
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func frostedGlass(cornerRadius: CGFloat = CornerRadius.xl, borderOpacity: Double = 0.08) -> some View {
        modifier(FrostedGlassModifier(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }

    func appCard(isSelected: Bool = false) -> some View {
        modifier(CardModifier(isSelected: isSelected))
    }
}

// MARK: - Drag Handle

struct DragHandle: View {
    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.28))
            .frame(width: 36, height: 4)
    }
}

// MARK: - Status Indicator

struct StatusDot: View {
    let isActive: Bool

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(isActive ? AppTheme.statusActive : AppTheme.textTertiary)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .fill(isActive ? AppTheme.statusActive.opacity(0.4) : .clear)
                    .frame(width: 16, height: 16)
                    .scaleEffect(isAnimating ? 1.5 : 1.0)
                    .opacity(isAnimating ? 0 : 0.6)
            )
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    isAnimating = false
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                } else {
                    isAnimating = false
                }
            }
    }
}
