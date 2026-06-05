import SwiftUI

struct CartSheet: View {
    @EnvironmentObject private var cartService: CartService

    var body: some View {
        NavigationStack {
            List {
                if cartService.items.isEmpty {
                    Text("Cart is empty.")
                } else {
                    ForEach(cartService.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.product.title)
                                .font(.headline)
                            Text("\(item.quantity)x · $\(item.product.price, specifier: "%.0f")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Mock Cart")
        }
    }
}
