import SwiftUI

struct CartSheet: View {
    @EnvironmentObject private var cartService: CartService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hue: 0.63, saturation: 0.18, brightness: 0.09)
                    .ignoresSafeArea()

                if cartService.items.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        cartItemsList
                        summaryFooter
                    }
                }
            }
            .navigationTitle("Shopping Cart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.surfaceCard, in: Circle())
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(AppTheme.surfaceCard)
                    .frame(width: 96, height: 96)

                Image(systemName: "cart")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(AppTheme.textTertiary)
            }

            VStack(spacing: Spacing.sm) {
                Text("Your cart is empty")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Products you add from the agent or AR view will appear here.")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cart Items List

    private var cartItemsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                ForEach(cartService.items) { item in
                    CartItemRow(item: item)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: - Summary Footer

    private var summaryFooter: some View {
        VStack(spacing: Spacing.lg) {
            Divider()
                .background(AppTheme.borderSubtle)

            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("\(cartService.totalItems) item\(cartService.totalItems == 1 ? "" : "s")")
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.textTertiary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("Total")
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.textSecondary)

                        Text("$\(totalPrice, specifier: "%.2f")")
                            .font(.appPrice)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }

                Spacer()

                Button {
                    // Checkout placeholder
                } label: {
                    Text("Checkout")
                        .font(.appHeadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(AppGradient.accentButton, in: Capsule())
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(.ultraThinMaterial)
    }

    private var totalPrice: Double {
        cartService.items.reduce(0) { $0 + Double($1.quantity) * $1.product.price }
    }
}

// MARK: - Cart Item Row

private struct CartItemRow: View {
    let item: CartItem

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Product color indicator
            RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.accent.opacity(0.6), AppTheme.accentSecondary.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "cube.fill")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(.white.opacity(0.8))
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.product.title)
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text("\(item.quantity) × $\(item.product.price, specifier: "%.0f")")
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer()

            Text("$\(Double(item.quantity) * item.product.price, specifier: "%.0f")")
                .font(.appPriceSmall)
                .foregroundStyle(AppTheme.accent)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(AppTheme.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
        )
    }
}
