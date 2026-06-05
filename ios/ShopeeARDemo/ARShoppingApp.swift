import SwiftUI

@main
struct ARShoppingApp: App {
    @StateObject private var cartService = CartService()
    @StateObject private var viewModel = AgentViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cartService)
                .environmentObject(viewModel)
                .task {
                    await viewModel.bootstrap()
                }
        }
    }
}

