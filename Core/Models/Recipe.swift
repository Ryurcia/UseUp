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

    /// The lowercase case name stored in the Supabase `cuisine_type` enum.
    var databaseValue: String { String(describing: self) }

    /// Reverse lookup from a database string to the Swift case.
    init?(databaseValue: String) {
        guard let match = Cuisine.allCases.first(where: { $0.databaseValue == databaseValue }) else {
            return nil
        }
        self = match
    }
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
    var imagePath: String?
    var cuisine: Cuisine
    var createdBy: String?
    var createdByName: String?
    var rating: Double
    var review: String?
    var isAIGenerated: Bool

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
        imagePath: String? = nil,
        cuisine: Cuisine = .other,
        createdBy: String? = nil,
        createdByName: String? = nil,
        rating: Double = 0,
        review: String? = nil,
        isAIGenerated: Bool = false
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
        self.imagePath = imagePath
        self.cuisine = cuisine
        self.createdBy = createdBy
        self.createdByName = createdByName
        self.rating = rating
        self.review = review
        self.isAIGenerated = isAIGenerated
    }
}
