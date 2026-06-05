import Foundation

struct CatalogPayload {
    let products: [Product]
    let sellersByID: [String: Seller]
}

enum CatalogServiceError: Error {
    case missingFile(String)
}

protocol CatalogServicing {
    func loadCatalog() async throws -> CatalogPayload
}

struct CatalogService: CatalogServicing {
    func loadCatalog() async throws -> CatalogPayload {
        let products: [Product] = try load("products.json")
        let sellers: [Seller] = try load("sellers.json")
        return CatalogPayload(
            products: products,
            sellersByID: Dictionary(uniqueKeysWithValues: sellers.map { ($0.id, $0) })
        )
    }

    private func load<T: Decodable>(_ fileName: String) throws -> T {
        guard let url = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".json", with: ""), withExtension: "json") else {
            throw CatalogServiceError.missingFile(fileName)
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

