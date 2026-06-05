import SwiftUI

struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                Text(product.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Text(product.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
                Text("$\(product.price, specifier: "%.0f")")
                    .font(.title3.bold())
                    .foregroundStyle(.cyan)
            }
            .frame(width: 220, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.black.opacity(0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isSelected ? Color.cyan : Color.white.opacity(0.12), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
