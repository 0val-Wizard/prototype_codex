import Foundation

enum ProductCatalogError: Error {
    case missingCatalog
}

struct ProductCatalogService {
    func loadProducts() throws -> [Product] {
        guard let url = Bundle.main.url(forResource: "Products", withExtension: "json") else {
            throw ProductCatalogError.missingCatalog
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Product].self, from: data)
    }

    func recommendProducts(for query: String, from products: [Product], limit: Int = 3) -> [Product] {
        let normalizedQuery = query.lowercased()
        let budgetCap = extractBudget(from: normalizedQuery) ?? 300
        let tokens = tokenize(normalizedQuery)

        return products
            .map { product in
                let matches = product.keywords.filter { tokens.contains($0.lowercased()) }
                var score = matches.count * 3

                if normalizedQuery.contains("monitor") {
                    score += product.title.lowercased().contains("monitor") ? 5 : 0
                }
                if product.price <= budgetCap {
                    score += 3
                }

                return (product, score)
            }
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.price < rhs.0.price
                }
                return lhs.1 > rhs.1
            }
            .prefix(limit)
            .map(\.0)
    }

    private func extractBudget(from query: String) -> Double? {
        let pattern = "(?:under|below|less than)\\s*\\$?(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(query.startIndex..., in: query)
        guard
            let match = regex.firstMatch(in: query, range: range),
            let valueRange = Range(match.range(at: 1), in: query)
        else {
            return nil
        }

        return Double(query[valueRange])
    }

    private func tokenize(_ query: String) -> Set<String> {
        Set(
            query
                .replacingOccurrences(of: "[^a-z0-9\\s-]", with: " ", options: .regularExpression)
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
        )
    }
}
