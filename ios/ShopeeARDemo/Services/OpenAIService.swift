import Foundation

struct OpenAIService {
    let apiKey: String?

    init(apiKey: String? = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]) {
        self.apiKey = apiKey
    }

    func rankProducts(for query: String, products: [Product]) async -> [Product] {
        guard let apiKey, !apiKey.isEmpty else {
            return products
        }

        _ = apiKey
        return products
    }
}
