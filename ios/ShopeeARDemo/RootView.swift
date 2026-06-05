import SwiftUI

private let agentBaseURL = URL(string: "http://192.168.1.73:3000")!

struct RootView: View {
    @EnvironmentObject private var viewModel: ShoppingViewModel
    @State private var showCameraExperience = false

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            AgentWebView(url: agentBaseURL) {
                showCameraExperience = true
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
        .fullScreenCover(isPresented: $showCameraExperience) {
            CameraAgentExperience(onClose: {
                showCameraExperience = false
            })
        }
        .task {
            await viewModel.bootstrap()
        }
    }
}

private struct CameraAgentExperience: View {
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ARShoppingView()
                .ignoresSafeArea()

            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Button(action: onClose) {
                        Label("Back", systemImage: "chevron.left")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("AR Camera + Voice Agent")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Text("The camera stays on while the voice agent remains available below.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.78))
                    }

                    Spacer()
                }

                Spacer()

                AgentWebView(url: agentBaseURL) { }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .padding()
        }
    }
}
