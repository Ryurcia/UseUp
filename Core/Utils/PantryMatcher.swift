import Foundation

enum PantryMatcher {
    private static let stopWords: Set<String> = [
        "fresh", "dried", "ground", "minced", "chopped", "sliced", "diced",
        "cooked", "raw", "frozen", "canned", "whole", "halved", "finely",
        "roughly", "thinly", "large", "small", "medium", "extra", "virgin",
        "unsalted", "salted", "and", "or", "with", "of", "a", "the"
    ]

    private static func significantWords(from name: String) -> Set<String> {
        Set(
            name.lowercased()
                .components(separatedBy: .whitespaces)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty && $0.count > 1 && !stopWords.contains($0) }
        )
    }

    static func matches(pantryName: String, recipeName: String) -> Bool {
        let pw = significantWords(from: pantryName)
        let rw = significantWords(from: recipeName)
        guard !pw.isEmpty, !rw.isEmpty else { return false }
        return !pw.isDisjoint(with: rw)
    }

    static func find(for recipeIngredientName: String, in pantryIngredients: [Ingredient]) -> Ingredient? {
        pantryIngredients.first { matches(pantryName: $0.name, recipeName: recipeIngredientName) }
    }
}
