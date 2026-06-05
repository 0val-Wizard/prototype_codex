import SwiftUI

struct RecommendationSheet: View {
    @EnvironmentObject private var viewModel: ShoppingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommendations")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(viewModel.recommendationTabCount) relevant products")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button(action: viewModel.dismissRecommendations) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.recommendations) { recommendation in
                        RecommendationCard(recommendation: recommendation)
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
    }
}

struct RecommendationCard: View {
    @EnvironmentObject private var viewModel: ShoppingViewModel
    let recommendation: ProductRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(recommendation.product.category.title)
                    .font(.caption.bold())
                    .foregroundStyle(.cyan)
                Spacer()
                Button {
                    viewModel.addToCart(recommendation)
                } label: {
                    Image(systemName: "cart.badge.plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.cyan.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            Text(recommendation.product.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(recommendation.reason)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(3)

            HStack {
                Text("$\(recommendation.product.price, specifier: "%.2f")")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text(recommendation.sellerName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Button("Preview In AR") {
                viewModel.previewRecommendationInAR(recommendation)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(16)
        .frame(width: 260)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 22))
    }
}
