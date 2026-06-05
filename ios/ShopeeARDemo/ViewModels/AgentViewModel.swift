import Foundation

@MainActor
final class AgentViewModel: ObservableObject {
    @Published var query = "I need a monitor under $300"
    @Published private(set) var products: [Product] = []
    @Published private(set) var recommendedProducts: [Product] = []
    @Published var selectedProductID: String?
    @Published var isPlaneDetected = false
    @Published var placementRequestID = UUID()
    @Published var agentMessage = "Point the camera at a desk or table, then search for products."
    @Published var isCartSheetPresented = false

    private let catalogService: ProductCatalogService
    private let openAIService: OpenAIService

    init(
        catalogService: ProductCatalogService = ProductCatalogService(),
        openAIService: OpenAIService = OpenAIService()
    ) {
        self.catalogService = catalogService
        self.openAIService = openAIService
    }

    var selectedProduct: Product? {
        recommendedProducts.first(where: { $0.id == selectedProductID }) ?? recommendedProducts.first
    }

    func bootstrap() async {
        do {
            products = try catalogService.loadProducts()
            runSearch()
        } catch {
            agentMessage = "Failed to load local Products.json."
        }
    }

    func runSearch() {
        let localRecommendations = catalogService.recommendProducts(for: query, from: products, limit: 4)

        Task {
            let rankedProducts = await openAIService.rankProducts(for: query, products: localRecommendations)
            await MainActor.run {
                self.recommendedProducts = Array(rankedProducts.prefix(4))
                self.selectedProductID = self.recommendedProducts.first?.id
                self.agentMessage = self.isPlaneDetected
                    ? "Detected a tabletop. Showing 4 local product recommendations."
                    : "Found 4 local products. Move the camera until a tabletop is detected."
                self.placementRequestID = UUID()
            }
        }
    }

    func setPlaneDetected(_ detected: Bool) {
        guard detected != isPlaneDetected else { return }
        isPlaneDetected = detected

        if detected {
            agentMessage = recommendedProducts.isEmpty
                ? "Plane detected. Search to place products."
                : "Tabletop detected. Products can now be placed."
            placementRequestID = UUID()
        } else {
            agentMessage = "Scanning for a horizontal desk or table surface."
        }
    }

    func selectProduct(id: String) {
        selectedProductID = id
    }
}
