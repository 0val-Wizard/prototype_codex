import Foundation

struct Product: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let price: Double
    let keywords: [String]
    let modelName: String
    let accentHex: String
}
