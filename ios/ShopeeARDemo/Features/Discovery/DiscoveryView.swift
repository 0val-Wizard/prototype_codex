import SwiftUI

struct DiscoveryView: View {
    @EnvironmentObject private var viewModel: ShoppingViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.10, blue: 0.16), Color(red: 0.03, green: 0.06, blue: 0.11)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        searchPanel
                        previewPanel
                        cartSummary
                    }
                    .padding(20)
                    .padding(.bottom, 140)
                }

                if viewModel.hasDismissedRecommendations && !viewModel.recommendations.isEmpty {
                    Button(action: viewModel.reopenRecommendations) {
                        HStack(spacing: 10) {
                            Text("Recommendations")
                                .font(.headline)
                            Text("\(viewModel.recommendationTabCount)")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.12), in: Capsule())
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.bottom, 20)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.isRecommendationsOpen {
                    RecommendationSheet()
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.selectedTab = .cart
                    } label: {
                        Label("\(viewModel.cartQuantity)", systemImage: "cart.fill")
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AR Shopping Demo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.cyan)
            Text("Native product discovery for live placement")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(viewModel.assistantMessage)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Describe what you need")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                TextField("My sink is leaking. What should I buy?", text: $viewModel.searchText)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.search)
                    .onSubmit(viewModel.submitSearch)
                    .padding()
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(.white)

                Button(action: viewModel.toggleVoiceSearch) {
                    Image(systemName: viewModel.isListening ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            viewModel.isListening ? Color.cyan : .white.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                }
            }

            Text(viewModel.voiceInputStatus)
                .font(.footnote)
                .foregroundStyle(viewModel.isListening ? .cyan : .white.opacity(0.68))

            Button(action: viewModel.submitSearch) {
                HStack {
                    Image(systemName: "sparkle.magnifyingglass")
                    Text("Find Products")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .foregroundStyle(.white)
            }
        }
        .padding(18)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Selected for AR")
                .font(.headline)
                .foregroundStyle(.white)

            if let selected = viewModel.selectedProduct {
                VStack(alignment: .leading, spacing: 10) {
                    Text(selected.product.title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(selected.product.description)
                        .foregroundStyle(.white.opacity(0.72))
                    Label(selected.reason, systemImage: "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundStyle(.cyan)
                    Label("\(viewModel.placedProductCount) placed in AR", systemImage: "cube.transparent")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.72))
                }
            } else {
                Text("Search the catalog to pick a product and preview it in AR.")
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(18)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
    }

    private var cartSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cart")
                .font(.headline)
                .foregroundStyle(.white)
            Text("\(viewModel.cartQuantity) items · $\(viewModel.cartTotal, specifier: "%.2f")")
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
    }
}
