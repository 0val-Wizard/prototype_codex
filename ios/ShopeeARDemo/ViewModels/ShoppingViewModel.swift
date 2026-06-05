import Foundation
import simd

@MainActor
final class ShoppingViewModel: ObservableObject {
    @Published private(set) var catalog: [Product] = []
    @Published private(set) var sellersByID: [String: Seller] = [:]
    @Published var selectedTab: AppTab = .discover
    @Published var searchText = ""
    @Published var recommendations: [ProductRecommendation] = []
    @Published var cart: [CartItem] = []
    @Published var selectedProduct: ProductRecommendation?
    @Published var placedAnchors: [PlacedProductAnchor] = []
    @Published var isRecommendationsOpen = false
    @Published var hasDismissedRecommendations = false
    @Published var isLoading = false
    @Published var isListening = false
    @Published var assistantMessage = "Describe the problem, room, or outfit you want help with."
    @Published var voiceInputStatus = "Use the mic or type a request."
    @Published var arStatusMessage = "Select a product, then tap a detected surface to place it."

    private let catalogService: CatalogServicing
    private let voiceSearchService: VoiceSearchServicing

    init(
        catalogService: CatalogServicing = CatalogService(),
        voiceSearchService: VoiceSearchServicing = VoiceSearchService()
    ) {
        self.catalogService = catalogService
        self.voiceSearchService = voiceSearchService
        self.voiceSearchService.onTranscript = { [weak self] transcript, isFinal in
            guard let self else { return }
            self.searchText = transcript
            self.voiceInputStatus = isFinal ? "Voice search complete." : "Listening… \(transcript)"
            if isFinal {
                self.finishVoiceSearchAndSubmit()
            }
        }
        self.voiceSearchService.onAvailabilityChange = { [weak self] available in
            guard let self else { return }
            self.voiceInputStatus = available ? "Voice search ready." : "Speech recognition is unavailable."
        }
    }

    var cartQuantity: Int {
        cart.reduce(0) { $0 + $1.quantity }
    }

    var cartTotal: Double {
        cart.reduce(0) { $0 + $1.subtotal }
    }

    var recommendationTabCount: Int {
        recommendations.count
    }

    var placedProductCount: Int {
        placedAnchors.count
    }

    func bootstrap() async {
        guard catalog.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let payload = try await catalogService.loadCatalog()
            catalog = payload.products
            sellersByID = payload.sellersByID
            assistantMessage = "Search for a repair, skincare, outfit, or gadget problem to see AR-ready suggestions."
            voiceInputStatus = "Use the mic or type a request."
        } catch {
            assistantMessage = "The local demo catalog failed to load."
        }
    }

    func submitSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        let category = inferCategory(from: query)
        let tokens = tokenize(query)
        let ranked = catalog.compactMap { product -> ProductRecommendation? in
            let keywordMatches = product.keywords.filter { tokens.contains($0.lowercased()) }
            let categoryMatches = product.category == category

            var score = 0
            if categoryMatches { score += 5 }
            score += keywordMatches.count * 2
            if product.rating >= 4.7 { score += 1 }
            if product.delivery == "same_day" || product.delivery == "next_day" { score += 1 }
            if product.stock > 0 { score += 1 }

            guard score > 0 else { return nil }
            guard !keywordMatches.isEmpty || (categoryMatches && score >= 7) else { return nil }

            let sellerName = sellersByID[product.sellerId]?.name ?? "Unknown seller"
            let reason = buildReason(matches: keywordMatches, product: product)
            return ProductRecommendation(product: product, sellerName: sellerName, reason: reason, score: score)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.product.rating > rhs.product.rating
            }
            return lhs.score > rhs.score
        }

        recommendations = Array(ranked.prefix(4))
        selectedProduct = recommendations.first
        selectedTab = .discover
        assistantMessage = recommendations.isEmpty
            ? "I need one more detail to narrow this down. Try a material, color, device type, or room context."
            : "I found \(recommendations.count) relevant products. Open one in AR or add it to the cart."
        isRecommendationsOpen = !recommendations.isEmpty
        hasDismissedRecommendations = false
        arStatusMessage = recommendations.isEmpty
            ? "No product is ready for placement yet."
            : "Tap a surface in AR to place \(recommendations[0].product.title)."
    }

    func dismissRecommendations() {
        guard !recommendations.isEmpty else { return }
        isRecommendationsOpen = false
        hasDismissedRecommendations = true
    }

    func reopenRecommendations() {
        guard !recommendations.isEmpty else { return }
        isRecommendationsOpen = true
        hasDismissedRecommendations = false
    }

    func selectRecommendation(_ recommendation: ProductRecommendation) {
        selectedProduct = recommendation
        arStatusMessage = "Tap a surface in AR to place \(recommendation.product.title)."
    }

    func previewRecommendationInAR(_ recommendation: ProductRecommendation) {
        selectRecommendation(recommendation)
        selectedTab = .ar
    }

    func addToCart(_ recommendation: ProductRecommendation) {
        if let index = cart.firstIndex(where: { $0.product.id == recommendation.product.id }) {
            cart[index].quantity += 1
        } else {
            cart.append(
                CartItem(
                    product: recommendation.product,
                    quantity: 1,
                    sellerName: recommendation.sellerName
                )
            )
        }
        assistantMessage = "\(recommendation.product.title) added to cart."
    }

    func placeSelectedProduct(at transform: simd_float4x4) {
        guard let selectedProduct else {
            arStatusMessage = "Choose a recommendation before placing an item."
            return
        }

        placedAnchors.append(PlacedProductAnchor(recommendation: selectedProduct, transform: transform))
        arStatusMessage = "\(selectedProduct.product.title) placed in your scene."
    }

    func clearPlacedProducts() {
        placedAnchors.removeAll()
        arStatusMessage = "Cleared placed products. Tap again to place a new item."
    }

    func toggleVoiceSearch() {
        if isListening {
            finishVoiceSearchAndSubmit()
            return
        }

        Task {
            await startVoiceSearch()
        }
    }

    private func startVoiceSearch() async {
        do {
            voiceInputStatus = "Starting voice search…"
            try await voiceSearchService.startTranscribing()
            isListening = true
            assistantMessage = "Listening for your shopping request."
            voiceInputStatus = "Listening… say what you need."
        } catch {
            isListening = false
            voiceInputStatus = error.localizedDescription
            assistantMessage = "Voice search could not start."
        }
    }

    private func finishVoiceSearchAndSubmit() {
        if isListening {
            voiceSearchService.stopTranscribing()
            isListening = false
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            voiceInputStatus = "No voice input captured yet."
            return
        }

        voiceInputStatus = "Searching for “\(query)”"
        submitSearch()
    }

    private func inferCategory(from query: String) -> ProductCategory {
        let lowercased = query.lowercased()
        let mappings: [(ProductCategory, [String])] = [
            (.homeRepair, ["sink", "pipe", "leak", "repair", "pvc", "plumbing"]),
            (.beauty, ["moisturizer", "skincare", "barrier", "dry skin"]),
            (.fashion, ["boots", "jacket", "pants", "jeans", "outfit"]),
            (.electronics, ["monitor", "laptop", "usb-c", "hdmi", "adapter"]),
            (.grocery, ["grocery", "pantry", "oats", "breakfast"]),
            (.homeDecor, ["decor", "lamp", "rug", "room"])
        ]

        for (category, terms) in mappings where terms.contains(where: lowercased.contains) {
            return category
        }
        return .general
    }

    private func tokenize(_ query: String) -> Set<String> {
        Set(
            query
                .lowercased()
                .replacingOccurrences(of: "[^a-z0-9\\s-]", with: " ", options: .regularExpression)
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
        )
    }

    private func buildReason(matches: [String], product: Product) -> String {
        var parts: [String] = []
        if !matches.isEmpty {
            parts.append("Matches \(matches.prefix(2).joined(separator: " and "))")
        }
        if product.delivery == "same_day" {
            parts.append("same-day delivery")
        } else if product.delivery == "next_day" {
            parts.append("next-day delivery")
        }
        if product.rating >= 4.7 {
            parts.append("rated \(String(format: "%.1f", product.rating))")
        }
        return parts.joined(separator: ", ")
    }
}
