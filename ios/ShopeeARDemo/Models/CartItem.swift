import Foundation

struct CartItem: Identifiable, Hashable {
    let id: UUID
    let product: Product
    var quantity: Int

    init(id: UUID = UUID(), product: Product, quantity: Int = 1) {
        self.id = id
        self.product = product
        self.quantity = quantity
    }
}
