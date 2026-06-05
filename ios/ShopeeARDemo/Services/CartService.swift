import Foundation

@MainActor
final class CartService: ObservableObject {
    @Published private(set) var items: [CartItem] = []

    var totalItems: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    func add(_ product: Product) {
        if let index = items.firstIndex(where: { $0.product.id == product.id }) {
            items[index].quantity += 1
        } else {
            items.append(CartItem(product: product))
        }
    }
}
