import SwiftUI

struct RootView: View {
    @StateObject private var cartService = CartService()
    @StateObject private var viewModel = AgentViewModel()

    var body: some View {
        ContentView()
            .environmentObject(cartService)
            .environmentObject(viewModel)
            .preferredColorScheme(.dark)
            .tint(AppTheme.accent)
            .task {
                await viewModel.bootstrap()
            }
    }
}
