import SwiftUI

private let agentBaseURL = URL(string: "http://192.168.1.73:3000")!

struct RootView: View {
    @EnvironmentObject private var viewModel: ShoppingViewModel

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            AgentWebView(url: agentBaseURL) {
                viewModel.selectedTab = .ar
            }
            .ignoresSafeArea()
            .tag(AppTab.discover)
            .tabItem {
                Label("Agent", systemImage: "sparkles")
            }

            ARShoppingView()
                .tag(AppTab.ar)
                .tabItem {
                    Label("AR View", systemImage: "camera.viewfinder")
                }

            CartView()
                .tag(AppTab.cart)
                .tabItem {
                    Label("Cart", systemImage: "cart")
                }
                .badge(viewModel.cartQuantity)
        }
        .tint(Color.cyan)
        .task {
            await viewModel.bootstrap()
        }
    }
}
