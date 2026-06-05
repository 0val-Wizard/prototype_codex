import SwiftUI

struct ProductCarousel: View {
    let products: [Product]
    let selectedProductID: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(products) { product in
                    ProductCard(
                        product: product,
                        isSelected: product.id == selectedProductID,
                        onTap: { onSelect(product.id) }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
