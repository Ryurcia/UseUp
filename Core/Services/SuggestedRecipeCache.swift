import Foundation

@MainActor
final class SuggestedRecipeCache: ObservableObject {
    static let shared = SuggestedRecipeCache()

    @Published private(set) var cached: [UUID: [Suggestion]] = [:]

    private let defaultsKey = "suggested_recipe_cache_v1"

    struct Suggestion: Codable, Identifiable {
        let id: UUID
        let title: String
        let timeMinutes: Int
        let cuisineRaw: String
    }

    private init() {
        loadFromDisk()
    }

    func suggestions(for ingredient: Ingredient) -> [Suggestion] {
        cached[ingredient.id] ?? []
    }

    func refresh(expiringIngredients: [Ingredient], allRecipes: [Recipe]) {
        guard !expiringIngredients.isEmpty, !allRecipes.isEmpty else { return }
        let ingredients = expiringIngredients
        let recipes = allRecipes
        Task.detached(priority: .utility) { [weak self] in
            var result: [UUID: [SuggestedRecipeCache.Suggestion]] = [:]
            for ingredient in ingredients {
                let name = ingredient.name.lowercased()
                let matches = recipes
                    .filter { recipe in
                        recipe.ingredientsUsed.contains(where: {
                            $0.name.lowercased().contains(name) || name.contains($0.name.lowercased())
                        })
                    }
                    .map {
                        SuggestedRecipeCache.Suggestion(
                            id: $0.id,
                            title: $0.title,
                            timeMinutes: $0.timeMinutes,
                            cuisineRaw: $0.cuisine.rawValue
                        )
                    }
                if !matches.isEmpty {
                    result[ingredient.id] = matches
                }
            }
            let snapshot = result
            await MainActor.run { [weak self] in
                self?.cached = snapshot
                self?.persist(snapshot)
            }
        }
    }

    private func persist(_ cache: [UUID: [Suggestion]]) {
        let stringKeyed = Dictionary(uniqueKeysWithValues: cache.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(stringKeyed) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: [Suggestion]].self, from: data)
        else { return }
        cached = Dictionary(uniqueKeysWithValues: decoded.compactMap { idStr, suggestions -> (UUID, [Suggestion])? in
            guard let id = UUID(uuidString: idStr) else { return nil }
            return (id, suggestions)
        })
    }
}
