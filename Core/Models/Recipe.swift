import Foundation

enum Cuisine: String, CaseIterable, Identifiable, Hashable {
    case american = "American"
    case asian = "Asian"
    case chinese = "Chinese"
    case filipino = "Filipino"
    case french = "French"
    case greek = "Greek"
    case indian = "Indian"
    case italian = "Italian"
    case japanese = "Japanese"
    case korean = "Korean"
    case mediterranean = "Mediterranean"
    case mexican = "Mexican"
    case middleEastern = "Middle Eastern"
    case thai = "Thai"
    case other = "Other"

    var id: String { rawValue }
}

struct Recipe: Identifiable, Hashable {
    static func == (lhs: Recipe, rhs: Recipe) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: UUID
    var title: String
    var summary: String
    var timeMinutes: Int
    var servings: Int
    var ingredientsUsed: [RecipeIngredient]
    var missingIngredients: [RecipeIngredient]
    var steps: [String]
    var macros: Macros
    var sources: [SourceLink]
    var isUserShared: Bool
    var imageData: Data?
    var cuisine: Cuisine
    var createdBy: String?
    var rating: Double
    var review: String?

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        timeMinutes: Int,
        servings: Int,
        ingredientsUsed: [RecipeIngredient],
        missingIngredients: [RecipeIngredient],
        steps: [String],
        macros: Macros,
        sources: [SourceLink],
        isUserShared: Bool = false,
        imageData: Data? = nil,
        cuisine: Cuisine = .other,
        createdBy: String? = nil,
        rating: Double = 0,
        review: String? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.timeMinutes = timeMinutes
        self.servings = servings
        self.ingredientsUsed = ingredientsUsed
        self.missingIngredients = missingIngredients
        self.steps = steps
        self.macros = macros
        self.sources = sources
        self.isUserShared = isUserShared
        self.imageData = imageData
        self.cuisine = cuisine
        self.createdBy = createdBy
        self.rating = rating
        self.review = review
    }
}
