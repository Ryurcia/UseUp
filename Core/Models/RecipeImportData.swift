import Foundation

struct RecipeImportData: Identifiable {
    var id = UUID()
    var title: String = ""
    var summary: String = ""
    var cuisine: Cuisine? = nil
    var timeMinutes: String = ""
    var servings: String = ""
    var ingredients: [(name: String, quantity: String, unit: String)] = []
    var steps: [String] = []
    var calories: String = ""
    var protein: String = ""
    var carbs: String = ""
    var fat: String = ""
    var sourceURL: String = ""
    var sourceTitle: String = ""
    var imageData: Data? = nil
}
