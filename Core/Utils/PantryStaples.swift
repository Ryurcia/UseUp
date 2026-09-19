import Foundation

/// Common kitchen staples assumed to already be on hand — excluded from "how well does
/// this recipe match my pantry" scoring so a recipe isn't scored as a great match just
/// because it needs salt and oil. Same category the recipe-generation prompt already
/// treats as always-available (`supabase/functions/generate-recipes/prompt.ts`).
enum PantryStaples {
    private static let staples: Set<String> = [
        "salt", "pepper", "oil", "butter", "garlic", "sugar", "flour", "water",
        "vinegar", "honey", "cinnamon", "cumin", "paprika", "oregano", "basil",
        "thyme", "cayenne", "nutmeg", "ginger", "cornstarch", "yeast"
    ]

    /// Word-level check (not raw substring) so e.g. "peppermint" doesn't false-match "pepper".
    static func isStaple(_ ingredientName: String) -> Bool {
        let words = ingredientName.lowercased()
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
        return words.contains { staples.contains($0) }
    }
}
