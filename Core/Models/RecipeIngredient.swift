import Foundation

struct RecipeIngredient: Hashable, Identifiable {
    let id: UUID
    var name: String
    var quantity: String

    init(id: UUID = UUID(), name: String, quantity: String = "") {
        self.id = id
        self.name = name
        self.quantity = quantity
    }

    /// Display string: "quantity name" or just "name" if no quantity.
    var displayText: String {
        let q = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? name.capitalized : "\(q) \(name.capitalized)"
    }
}
