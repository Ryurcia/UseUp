import Foundation

struct RecipeCollection: Identifiable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date
}
