import SwiftUI

private let agentBaseURL = URL(string: "http://192.168.1.73:3000")!

struct ContentView: View {
    @EnvironmentObject private var cartService: CartService
    @EnvironmentObject private var viewModel: AgentViewModel
    @State private var showAR = false

    var body: some View {
        if !showAR {
            AgentWebView(url: agentBaseURL) {
                showAR = true
            }
            .ignoresSafeArea()
        } else {
            ZStack(alignment: .bottom) {
                ARViewContainer(
                    products: viewModel.recommendedProducts,
                    selectedProductID: viewModel.selectedProductID,
                    placementRequestID: viewModel.placementRequestID,
                    onPlaneDetectionChanged: viewModel.setPlaneDetected(_:),
                    onModelSelected: viewModel.selectProduct(id:)
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    header
                    Spacer()
                    bottomPanel
                }
                .padding()
            }
            .sheet(isPresented: $viewModel.isCartSheetPresented) {
                CartSheet()
                    .environmentObject(cartService)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            AgentOrb(isActive: viewModel.isPlaneDetected)

            VStack(alignment: .leading, spacing: 8) {
                Text("AR Shopping Camera Demo")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(viewModel.agentMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            Button {
                viewModel.isCartSheetPresented = true
            } label: {
                Label("\(cartService.totalItems)", systemImage: "cart.fill")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .foregroundStyle(.white)
        }
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                TextField("I need a monitor under $300", text: $viewModel.query)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.search)
                    .onSubmit(viewModel.runSearch)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(.white)

                Button(action: viewModel.runSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                        .frame(width: 52, height: 52)
                        .background(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                }
                .foregroundStyle(.white)
            }

            if !viewModel.recommendedProducts.isEmpty {
                ProductCarousel(
                    products: viewModel.recommendedProducts,
                    selectedProductID: viewModel.selectedProductID,
                    onSelect: viewModel.selectProduct(id:)
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
    }
}


import WebKit

struct AgentWebView: UIViewRepresentable {
    let url: URL
    var onCameraTapped: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userController = WKUserContentController()
        
        let script = """
        // Intercept camera button taps
        document.addEventListener('DOMContentLoaded', () => {
             const fileButton = document.querySelector('.file-button');
             if (fileButton) {
                 fileButton.addEventListener('click', (e) => {
                     e.preventDefault(); // Stop default file picker
                     window.webkit.messageHandlers.cameraTapped.postMessage('tapped');
                 });
             }
        });
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userController.addUserScript(userScript)
        userController.add(context.coordinator, name: "cameraTapped")
        config.userContentController = userController
        
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: AgentWebView
        private var hasTriggeredFallback = false

        init(_ parent: AgentWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "cameraTapped" {
                parent.onCameraTapped()
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard shouldFallback(for: error) else { return }
            triggerFallback()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard shouldFallback(for: error) else { return }
            triggerFallback()
        }

        private func shouldFallback(for error: Error) -> Bool {
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCannotConnectToHost
        }

        private func triggerFallback() {
            guard !hasTriggeredFallback else { return }
            hasTriggeredFallback = true
            DispatchQueue.main.async {
                self.parent.onCameraTapped()
            }
        }
    }
}
