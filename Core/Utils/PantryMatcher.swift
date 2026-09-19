import Foundation

enum PantryMatcher {
    private static let stopWords: Set<String> = [
        "fresh", "dried", "ground", "minced", "chopped", "sliced", "diced",
        "cooked", "raw", "frozen", "canned", "whole", "halved", "finely",
        "roughly", "thinly", "large", "small", "medium", "extra", "virgin",
        "unsalted", "salted", "and", "or", "with", "of", "a", "the"
    ]

    private static func significantWords(from name: String) -> [String] {
        name.lowercased()
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && $0.count > 1 && !stopWords.contains($0) }
    }

    /// The head noun — the actual food, by convention the last significant word once
    /// color/size/prep modifiers are stripped (e.g. "yellow potatoes" → "potatoes").
    /// Matching on this instead of "any shared word" avoids false positives like "yellow
    /// potatoes" ~ "yellow peas", which share only the color adjective, not the food itself.
    private static func headNoun(from name: String) -> String? {
        significantWords(from: name).last
    }

    static func matches(pantryName: String, recipeName: String) -> Bool {
        guard let pantryHead = headNoun(from: pantryName),
              let recipeHead = headNoun(from: recipeName)
        else { return false }
        return pantryHead == recipeHead
    }

    static func find(for recipeIngredientName: String, in pantryIngredients: [Ingredient]) -> Ingredient? {
        pantryIngredients.first { matches(pantryName: $0.name, recipeName: recipeIngredientName) }
    }
}
