import SwiftUI

@main
struct ShopeeARDemoApp: App {
    @StateObject private var viewModel = ShoppingViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
        }
    }
}

