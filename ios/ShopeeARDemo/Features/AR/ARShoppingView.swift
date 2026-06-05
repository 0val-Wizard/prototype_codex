import SwiftUI

struct ARShoppingView: View {
    @EnvironmentObject private var viewModel: ShoppingViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            ARPreviewContainer(
                selectedProduct: viewModel.selectedProduct,
                placedAnchors: viewModel.placedAnchors,
                onTapPlacement: viewModel.placeSelectedProduct(at:),
                onSceneMessage: { viewModel.arStatusMessage = $0 }
            )
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                if let selection = viewModel.selectedProduct {
                    Text(selection.product.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(selection.reason)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))

                    HStack {
                        Text("$\(selection.product.price, specifier: "%.2f")")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            viewModel.clearPlacedProducts()
                        } label: {
                            Label("Clear", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)

                        Button {
                            viewModel.addToCart(selection)
                        } label: {
                            Label("Add To Cart", systemImage: "cart.badge.plus")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                    }
                    Text(viewModel.arStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.78))
                    Label("\(viewModel.placedProductCount) placed anchors", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.footnote)
                        .foregroundStyle(.cyan)
                } else {
                    Text("Choose a recommendation to place it into the AR scene.")
                        .foregroundStyle(.white)
                }
            }
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding()
        }
    }
}
