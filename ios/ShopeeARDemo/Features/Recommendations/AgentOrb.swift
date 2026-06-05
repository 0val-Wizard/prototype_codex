import SwiftUI

struct AgentOrb: View {
    let isActive: Bool

    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    private let orbSize: CGFloat = 52

    var body: some View {
        ZStack {
            // Outer glow pulse
            Circle()
                .fill(AppTheme.accent.opacity(0.12))
                .frame(width: orbSize + 28, height: orbSize + 28)
                .scaleEffect(isActive ? pulseScale : 0.92)
                .blur(radius: 8)

            // Middle ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            AppTheme.accent.opacity(0.6),
                            AppTheme.accentSecondary.opacity(0.3),
                            AppTheme.accent.opacity(0.0),
                            AppTheme.accentSecondary.opacity(0.4),
                            AppTheme.accent.opacity(0.6)
                        ],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: orbSize + 14, height: orbSize + 14)
                .rotationEffect(.degrees(isActive ? rotationAngle : 0))

            // Inner ring
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                .frame(width: orbSize + 6, height: orbSize + 6)

            // Core orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hue: 0.50, saturation: 0.72, brightness: 0.98),
                            Color(hue: 0.55, saturation: 0.78, brightness: 0.82),
                            Color(hue: 0.62, saturation: 0.68, brightness: 0.52)
                        ],
                        center: .init(x: 0.38, y: 0.35),
                        startRadius: 2,
                        endRadius: orbSize * 0.52
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .overlay(
                    // Specular highlight
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.45), Color.clear],
                                center: .init(x: 0.35, y: 0.30),
                                startRadius: 0,
                                endRadius: orbSize * 0.35
                            )
                        )
                        .frame(width: orbSize, height: orbSize)
                )
                .blur(radius: isActive ? 0 : 1.5)

            // Center sparkle dot
            Circle()
                .fill(Color.white.opacity(isActive ? 0.9 : 0.4))
                .frame(width: 6, height: 6)
                .blur(radius: 1)
        }
        .onAppear {
            guard isActive else { return }
            startAnimations()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startAnimations()
            }
        }
    }

    private func startAnimations() {
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            pulseScale = 1.18
        }
    }
}
