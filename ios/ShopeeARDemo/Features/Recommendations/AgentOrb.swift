import SwiftUI

struct AgentOrb: View {
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cyan.opacity(0.95),
                            Color.blue.opacity(0.7),
                            Color.black.opacity(0.2)
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 48
                    )
                )
                .frame(width: 88, height: 88)
                .blur(radius: isActive ? 0 : 2)

            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                .frame(width: 98, height: 98)
                .scaleEffect(isActive ? 1.06 : 0.98)
        }
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isActive)
    }
}
