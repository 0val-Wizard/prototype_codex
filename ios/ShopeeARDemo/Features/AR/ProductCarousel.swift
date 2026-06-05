import SwiftUI

struct ProductCarousel: View {
    let products: [Product]
    let selectedProductID: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                ForEach(products) { product in
                    ProductCard(
                        product: product,
                        isSelected: product.id == selectedProductID,
                        onTap: { onSelect(product.id) }
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.xs)
        }
        .mask(
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 16)

                Color.black

                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 16)
            }
        )
    }
}
