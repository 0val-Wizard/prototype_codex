import SwiftUI
import RealityKit
import UIKit
import WebKit

private let agentBaseURL = AppConfiguration.agentBaseURL

struct ContentView: View {
    @EnvironmentObject private var cartService: CartService
    @EnvironmentObject private var viewModel: AgentViewModel
    @StateObject private var agentWebViewStore = AgentWebViewStore(url: agentBaseURL)
    @StateObject private var cameraSnapshotStore = ARCameraSnapshotStore()
    @State private var showCameraExperience = false

    var body: some View {
        ZStack {
            if showCameraExperience {
                CameraAgentView(
                    showCameraExperience: $showCameraExperience,
                    agentWebViewStore: agentWebViewStore,
                    cameraSnapshotStore: cameraSnapshotStore
                )
            } else {
                SharedAgentWebView(store: agentWebViewStore)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .ignoresSafeArea()
            }
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $viewModel.isCartSheetPresented) {
            CartSheet()
                .environmentObject(cartService)
        }
        .task {
            agentWebViewStore.onCameraTapped = {
                showCameraExperience = true
            }
            agentWebViewStore.cameraSnapshotProvider = {
                throw ARCameraSnapshotStore.SnapshotError.cameraUnavailable
            }
        }
    }
}

private struct CameraAgentView: View {
    @EnvironmentObject private var cartService: CartService
    @EnvironmentObject private var viewModel: AgentViewModel

    @Binding var showCameraExperience: Bool
    @ObservedObject var agentWebViewStore: AgentWebViewStore
    @ObservedObject var cameraSnapshotStore: ARCameraSnapshotStore
    @State private var isAgentPanelExpanded = false

    var body: some View {
        ZStack(alignment: .top) {
            ARViewContainer(
                products: viewModel.recommendedProducts,
                selectedProductID: viewModel.selectedProductID,
                placementRequestID: viewModel.placementRequestID,
                onPlaneDetectionChanged: viewModel.setPlaneDetected(_:),
                onModelSelected: viewModel.selectProduct(id:),
                snapshotStore: cameraSnapshotStore
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                agentPanel
            }
        }
        .ignoresSafeArea()
        .onAppear {
            agentWebViewStore.cameraSnapshotProvider = { [cameraSnapshotStore] in
                try await cameraSnapshotStore.captureSnapshotPayload()
            }
        }
        .onDisappear {
            agentWebViewStore.cameraSnapshotProvider = {
                throw ARCameraSnapshotStore.SnapshotError.cameraUnavailable
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.md) {
                // Back button — frosted glass circle
                Button {
                    showCameraExperience = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .frostedGlass(cornerRadius: 20, borderOpacity: 0.12)
                }
                .buttonStyle(PressableButtonStyle())

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: 6) {
                        StatusDot(isActive: true)
                        Text("AI Agent + Camera")
                            .font(.appHeadline)
                            .foregroundStyle(.white)
                    }
                    Text(viewModel.agentMessage)
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                // Cart button with badge
                Button {
                    viewModel.isCartSheetPresented = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .frostedGlass(cornerRadius: 20, borderOpacity: 0.12)

                        if cartService.totalItems > 0 {
                            Text("\(cartService.totalItems)")
                                .font(.appBadge)
                                .foregroundStyle(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(AppTheme.statusBadge, in: Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
        }
        .background(
            AppGradient.headerScrim
                .allowsHitTesting(false)
        )
    }

    private var agentPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Drag handle
            DragHandle()
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xs)

            HStack(spacing: Spacing.md) {
                AgentOrb(isActive: viewModel.isPlaneDetected)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Realtime Agent")
                        .font(.appHeadline)
                        .foregroundStyle(.white)
                    Text("Live agent stays active while the camera is on.")
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        isAgentPanelExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(isAgentPanelExpanded ? "Hide" : "Open")
                            .font(.appCaption)
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .bold))
                            .rotationEffect(.degrees(isAgentPanelExpanded ? 180 : 0))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(AppTheme.surfaceCardHover, in: Capsule())
                    .overlay(
                        Capsule().stroke(AppTheme.borderSubtle, lineWidth: 0.5)
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }

            if isAgentPanelExpanded {
                SharedAgentWebView(store: agentWebViewStore)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .stroke(AppTheme.borderSubtle, lineWidth: 0.5)
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            } else {
                HStack(spacing: Spacing.sm) {
                    StatusDot(isActive: true)
                    Text("Camera is live — expand to talk or inspect recommendations.")
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frostedGlass(cornerRadius: CornerRadius.xl, borderOpacity: 0.10)
        .shadow(color: .black.opacity(0.32), radius: 20, y: -4)
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }
}

private struct SharedAgentWebView: UIViewRepresentable {
    @ObservedObject var store: AgentWebViewStore

    func makeUIView(context: Context) -> WKWebView {
        store.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        store.loadIfNeeded()
    }
}

final class AgentWebViewStore: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    let url: URL
    let webView: WKWebView

    var onCameraTapped: (() -> Void)?
    var cameraSnapshotProvider: (() async throws -> [String: String])?

    private var hasTriggeredFallback = false
    private var lastLoadedURL: URL?

    init(url: URL) {
        self.url = url

        let config = WKWebViewConfiguration()
        let userController = WKUserContentController()
        let script = """
        (() => {
             if (window.__nativeCameraBridgeInstalled) {
                 return;
             }
             window.__nativeCameraBridgeInstalled = true;
             window.__pendingNativeCameraCaptures = new Map();

             window.captureNativeCameraView = ({ question = "" } = {}) => {
                 return new Promise((resolve, reject) => {
                     const requestId = `capture-${Date.now()}-${Math.random().toString(36).slice(2)}`;
                     const timeoutId = window.setTimeout(() => {
                         window.__pendingNativeCameraCaptures.delete(requestId);
                         reject(new Error("Timed out waiting for native camera snapshot."));
                     }, 15000);

                     window.__pendingNativeCameraCaptures.set(requestId, { resolve, reject, timeoutId });
                     window.webkit.messageHandlers.captureSurroundings.postMessage({ requestId, question });
                 });
             };

             window.__resolveNativeCameraCapture = (requestId, payload) => {
                 const pending = window.__pendingNativeCameraCaptures.get(requestId);
                 if (!pending) {
                     return;
                 }
                 window.clearTimeout(pending.timeoutId);
                 window.__pendingNativeCameraCaptures.delete(requestId);
                 pending.resolve(payload);
             };

             window.__rejectNativeCameraCapture = (requestId, message) => {
                 const pending = window.__pendingNativeCameraCaptures.get(requestId);
                 if (!pending) {
                     return;
                 }
                 window.clearTimeout(pending.timeoutId);
                 window.__pendingNativeCameraCaptures.delete(requestId);
                 pending.reject(new Error(message));
             };

             document.addEventListener('click', (event) => {
                 const cameraButton = event.target?.closest?.('#camera-button, .file-button');
                 if (!cameraButton) {
                     return;
                 }
                 event.preventDefault();
                 event.stopPropagation();
                 window.webkit.messageHandlers.cameraTapped.postMessage('tapped');
             }, true);
        })();
        """

        let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userController.addUserScript(userScript)
        config.userContentController = userController
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        self.webView = webView

        super.init()

        userController.add(self, name: "cameraTapped")
        userController.add(self, name: "captureSurroundings")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
    }

    func loadIfNeeded() {
        guard lastLoadedURL != url else { return }
        lastLoadedURL = url
        webView.load(URLRequest(url: url))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "cameraTapped" {
            onCameraTapped?()
            return
        }

        if message.name == "captureSurroundings" {
            handleCaptureRequest(message.body)
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

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }

    @available(iOS 15.0, *)
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(.grant)
    }

    private func shouldFallback(for error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCannotConnectToHost
    }

    private func triggerFallback() {
        guard !hasTriggeredFallback else { return }
        hasTriggeredFallback = true
        DispatchQueue.main.async {
            self.onCameraTapped?()
        }
    }

    private func handleCaptureRequest(_ body: Any) {
        guard
            let payload = body as? [String: Any],
            let requestID = payload["requestId"] as? String
        else {
            return
        }

        Task {
            do {
                guard let cameraSnapshotProvider else {
                    throw ARCameraSnapshotStore.SnapshotError.cameraUnavailable
                }

                let snapshotPayload = try await cameraSnapshotProvider()
                await MainActor.run {
                    self.resolveNativeCapture(requestID: requestID, payload: snapshotPayload)
                }
            } catch {
                await MainActor.run {
                    self.rejectNativeCapture(requestID: requestID, message: error.localizedDescription)
                }
            }
        }
    }

    private func resolveNativeCapture(requestID: String, payload: [String: String]) {
        guard let payloadJSON = jsonString(for: payload) else {
            rejectNativeCapture(requestID: requestID, message: "Failed to encode camera snapshot payload.")
            return
        }

        let escapedRequestID = jsStringLiteral(requestID)
        let script = "window.__resolveNativeCameraCapture(\(escapedRequestID), \(payloadJSON));"
        webView.evaluateJavaScript(script)
    }

    private func rejectNativeCapture(requestID: String, message: String) {
        let script = "window.__rejectNativeCameraCapture(\(jsStringLiteral(requestID)), \(jsStringLiteral(message)));"
        webView.evaluateJavaScript(script)
    }

    private func jsonString(for payload: [String: String]) -> String? {
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let json = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return json
    }

    private func jsStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }
}

private enum AppConfiguration {
    static let agentBaseURL: URL = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "AgentBaseURL") as? String,
            let url = URL(string: value)
        else {
            preconditionFailure("AgentBaseURL must be set in Info.plist")
        }
        return url
    }()
}

@MainActor
final class ARCameraSnapshotStore: ObservableObject {
    enum SnapshotError: LocalizedError {
        case cameraUnavailable
        case snapshotFailed
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable:
                return "Camera mode is not active."
            case .snapshotFailed:
                return "Failed to capture the current camera view."
            case .encodingFailed:
                return "Failed to encode the camera snapshot."
            }
        }
    }

    weak var arView: ARView?

    func captureSnapshotPayload() async throws -> [String: String] {
        guard let arView else {
            throw SnapshotError.cameraUnavailable
        }

        let image = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            arView.snapshot(saveToHDR: false) { image in
                guard let image else {
                    continuation.resume(throwing: SnapshotError.snapshotFailed)
                    return
                }
                continuation.resume(returning: image)
            }
        }

        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw SnapshotError.encodingFailed
        }

        return [
            "mimeType": "image/jpeg",
            "imageBase64": imageData.base64EncodedString()
        ]
    }
}
