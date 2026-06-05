import SwiftUI

struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Product icon placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: product.accentHex).opacity(0.3),
                                    Color(hex: product.accentHex).opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 48)

                    Image(systemName: "cube.fill")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Color(hex: product.accentHex).opacity(0.7))
                }

                Text(product.title)
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Text(product.subtitle)
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.textTertiary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Spacer(minLength: 0)

                // Price row
                HStack {
                    Text("$\(product.price, specifier: "%.0f")")
                        .font(.appPrice)
                        .foregroundStyle(AppTheme.accent)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.accent)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .frame(width: 200, alignment: .leading)
            .padding(Spacing.lg)
            .appCard(isSelected: isSelected)
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// Local color helper for hex strings
private extension Color {
    init(hex: String) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
