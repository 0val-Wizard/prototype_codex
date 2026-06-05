import SwiftUI

struct CartView: View {
    @EnvironmentObject private var viewModel: ShoppingViewModel

    var body: some View {
        NavigationStack {
            List {
                if viewModel.cart.isEmpty {
                    Section {
                        Text("Your cart is empty. Add items from recommendations or AR preview.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Items") {
                        ForEach(viewModel.cart) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.product.title)
                                        .font(.headline)
                                    Spacer()
                                    Text("$\(item.subtotal, specifier: "%.2f")")
                                        .fontWeight(.semibold)
                                }

                                Text(item.sellerName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack {
                                    Text("\(item.quantity)x")
                                    Text(item.product.delivery.replacingOccurrences(of: "_", with: " ").capitalized)
                                    Text("★ \(item.product.rating, specifier: "%.1f")")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    Section("Summary") {
                        HStack {
                            Text("Items")
                            Spacer()
                            Text("\(viewModel.cartQuantity)")
                        }
                        HStack {
                            Text("Total")
                            Spacer()
                            Text("$\(viewModel.cartTotal, specifier: "%.2f")")
                                .fontWeight(.bold)
                        }
                    }
                }
            }
            .navigationTitle("Cart")
        }
    }
}

