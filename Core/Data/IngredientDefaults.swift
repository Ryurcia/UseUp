import Foundation

/// Name → {icon, category, storage, shelf-life} smart defaults, driving the "Add Ingredient"
/// sheet's zero-decision path. A local table for common groceries plus a category-level fallback
/// — no backing service exists for this yet.
enum IngredientDefaults {
    struct Entry {
        let icon: String
        let category: Ingredient.Category
        /// Related icons offered first in the icon picker's "Suggested" row, most-likely first.
        let suggestedIcons: [String]
    }

    /// Category → typical storage location, used when a name isn't in the lookup table (or to
    /// fill in storage even when it is — the table itself doesn't repeat this per entry).
    static func defaultStorage(for category: Ingredient.Category) -> Ingredient.StorageLocation {
        switch category {
        case .proteins, .seafood, .dairy, .produce, .vegetables, .fruits: return .fridge
        case .carbs, .condiments, .other: return .pantry
        }
    }

    /// Full resolved default bundle for a typed ingredient name.
    static func defaults(forName name: String) -> (icon: String, category: Ingredient.Category, storage: Ingredient.StorageLocation, shelfLifeDays: Int) {
        let category = entry(forName: name)?.category ?? .other
        let icon = entry(forName: name)?.icon ?? category.icon
        let storage = defaultStorage(for: category)
        let shelfLifeDays = category.defaultShelfLifeDays(in: storage)
        return (icon, category, storage, shelfLifeDays)
    }

    /// Specific icon for a recognized ingredient name, or nil if nothing in the table matches —
    /// callers should fall back to their own already-resolved category icon in that case, not
    /// `.other`, which is what `defaults(forName:)`'s own internal fallback would otherwise imply.
    static func icon(forName name: String) -> String? {
        entry(forName: name)?.icon
    }

    /// Up to 4 name-derived suggestions for the icon picker's "Suggested for …" row, falling back
    /// to the category's default icon set when the name isn't recognized.
    static func suggestedIcons(forName name: String, category: Ingredient.Category) -> [String] {
        if let entry = entry(forName: name), !entry.suggestedIcons.isEmpty {
            return Array(entry.suggestedIcons.prefix(4))
        }
        return Array((iconLibrary[category] ?? allIcons).prefix(4))
    }

    /// Icons whose category name or a known ingredient name contains `query`, deduplicated,
    /// falling back to the full library when nothing matches.
    static func searchIcons(query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allIcons }

        var seen = Set<String>()
        var results: [String] = []
        func add(_ icons: [String]) {
            for icon in icons where !seen.contains(icon) {
                seen.insert(icon)
                results.append(icon)
            }
        }

        for category in Ingredient.Category.allCases where category.title.lowercased().contains(q) {
            add(iconLibrary[category] ?? [])
        }
        for key in sortedKeys where key.contains(q) {
            add([table[key]!.icon])
        }
        return results.isEmpty ? allIcons : results
    }

    private static func entry(forName rawName: String) -> Entry? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !name.isEmpty else { return nil }
        if let exact = table[name] { return exact }
        // Longest-key-first substring match so "chicken breast, boneless" still hits "chicken breast".
        for key in sortedKeys where name.contains(key) {
            return table[key]
        }
        return nil
    }

    private static let sortedKeys: [String] = table.keys.sorted { $0.count > $1.count }

    // MARK: - Icon library (grouped by category, for the picker grid + "All icons" mode)

    static let iconLibrary: [Ingredient.Category: [String]] = [
        .proteins: ["🥩", "🍗", "🍖", "🐔", "🥓", "🥚", "🧆", "🫘", "🥜", "🍳", "🌭"],
        .seafood: ["🐟", "🦐", "🦑", "🦞", "🦀", "🐙", "🦪"],
        .produce: ["🥕", "🧅", "🧄", "🥬", "🌽", "🫑", "🥒", "🥑", "🍆", "🌶️", "🥔", "🍅"],
        .vegetables: ["🥦", "🥬", "🌽", "🫑", "🥒", "🥑", "🍆", "🌶️", "🥔", "🧅", "🧄"],
        .carbs: ["🍞", "🥐", "🥨", "🥞", "🧇", "🍚", "🍜", "🍝", "🫓", "🌾", "🥣"],
        .dairy: ["🥛", "🧀", "🧈"],
        .fruits: ["🍎", "🍊", "🍋", "🍇", "🍓", "🫐", "🍑", "🍒", "🍍", "🥭", "🍌", "🍉", "🍐", "🥝"],
        .condiments: ["🫙", "🧂", "🍯", "🫕", "🫚"],
        .other: ["🍄", "🌰", "🥗", "🧊", "🧃", "📦"],
    ]

    static let allIcons: [String] = {
        var seen = Set<String>()
        var result: [String] = []
        for category in Ingredient.Category.allCases {
            for icon in iconLibrary[category] ?? [] where !seen.contains(icon) {
                seen.insert(icon)
                result.append(icon)
            }
        }
        return result
    }()

    // MARK: - Name lookup table (common groceries)

    private static let table: [String: Entry] = [
        "chicken breast": Entry(icon: "🥩", category: .proteins, suggestedIcons: ["🥩", "🍗", "🍖", "🐔"]),
        "chicken thigh": Entry(icon: "🍗", category: .proteins, suggestedIcons: ["🍗", "🥩", "🍖", "🐔"]),
        "chicken thighs": Entry(icon: "🍗", category: .proteins, suggestedIcons: ["🍗", "🥩", "🍖", "🐔"]),
        "chicken wings": Entry(icon: "🍗", category: .proteins, suggestedIcons: ["🍗", "🐔", "🍖"]),
        "whole chicken": Entry(icon: "🐔", category: .proteins, suggestedIcons: ["🐔", "🍗", "🥩"]),
        "ground beef": Entry(icon: "🥩", category: .proteins, suggestedIcons: ["🥩", "🍖"]),
        "beef": Entry(icon: "🥩", category: .proteins, suggestedIcons: ["🥩", "🍖"]),
        "steak": Entry(icon: "🥩", category: .proteins, suggestedIcons: ["🥩", "🍖"]),
        "pork": Entry(icon: "🥓", category: .proteins, suggestedIcons: ["🥓", "🍖", "🥩"]),
        "bacon": Entry(icon: "🥓", category: .proteins, suggestedIcons: ["🥓", "🍖"]),
        "ham": Entry(icon: "🍖", category: .proteins, suggestedIcons: ["🍖", "🥓"]),
        "sausage": Entry(icon: "🌭", category: .proteins, suggestedIcons: ["🌭", "🥓"]),
        "eggs": Entry(icon: "🥚", category: .proteins, suggestedIcons: ["🥚", "🍳"]),
        "tofu": Entry(icon: "🧆", category: .proteins, suggestedIcons: ["🧆", "🫘"]),
        "beans": Entry(icon: "🫘", category: .proteins, suggestedIcons: ["🫘", "🧆"]),
        "lentils": Entry(icon: "🫘", category: .proteins, suggestedIcons: ["🫘"]),
        "peanut butter": Entry(icon: "🥜", category: .proteins, suggestedIcons: ["🥜"]),
        "salmon": Entry(icon: "🐟", category: .seafood, suggestedIcons: ["🐟", "🍣"]),
        "tuna": Entry(icon: "🐟", category: .seafood, suggestedIcons: ["🐟"]),
        "shrimp": Entry(icon: "🦐", category: .seafood, suggestedIcons: ["🦐"]),
        "crab": Entry(icon: "🦀", category: .seafood, suggestedIcons: ["🦀"]),
        "lobster": Entry(icon: "🦞", category: .seafood, suggestedIcons: ["🦞"]),
        "squid": Entry(icon: "🦑", category: .seafood, suggestedIcons: ["🦑", "🐙"]),
        "fish": Entry(icon: "🐟", category: .seafood, suggestedIcons: ["🐟"]),
        "milk": Entry(icon: "🥛", category: .dairy, suggestedIcons: ["🥛"]),
        "cheese": Entry(icon: "🧀", category: .dairy, suggestedIcons: ["🧀"]),
        "butter": Entry(icon: "🧈", category: .dairy, suggestedIcons: ["🧈"]),
        "yogurt": Entry(icon: "🥛", category: .dairy, suggestedIcons: ["🥛", "🧀"]),
        "cream": Entry(icon: "🥛", category: .dairy, suggestedIcons: ["🥛"]),
        "sour cream": Entry(icon: "🥛", category: .dairy, suggestedIcons: ["🥛"]),
        "onion": Entry(icon: "🧅", category: .produce, suggestedIcons: ["🧅"]),
        "garlic": Entry(icon: "🧄", category: .produce, suggestedIcons: ["🧄"]),
        "tomato": Entry(icon: "🍅", category: .produce, suggestedIcons: ["🍅"]),
        "potato": Entry(icon: "🥔", category: .produce, suggestedIcons: ["🥔"]),
        "carrot": Entry(icon: "🥕", category: .produce, suggestedIcons: ["🥕"]),
        "corn": Entry(icon: "🌽", category: .produce, suggestedIcons: ["🌽"]),
        "bell pepper": Entry(icon: "🫑", category: .produce, suggestedIcons: ["🫑", "🌶️"]),
        "chili pepper": Entry(icon: "🌶️", category: .produce, suggestedIcons: ["🌶️", "🫑"]),
        "cucumber": Entry(icon: "🥒", category: .produce, suggestedIcons: ["🥒"]),
        "avocado": Entry(icon: "🥑", category: .produce, suggestedIcons: ["🥑"]),
        "eggplant": Entry(icon: "🍆", category: .produce, suggestedIcons: ["🍆"]),
        "broccoli": Entry(icon: "🥦", category: .vegetables, suggestedIcons: ["🥦"]),
        "spinach": Entry(icon: "🥬", category: .vegetables, suggestedIcons: ["🥬"]),
        "lettuce": Entry(icon: "🥬", category: .vegetables, suggestedIcons: ["🥬"]),
        "kale": Entry(icon: "🥬", category: .vegetables, suggestedIcons: ["🥬"]),
        "cabbage": Entry(icon: "🥬", category: .vegetables, suggestedIcons: ["🥬"]),
        "zucchini": Entry(icon: "🥒", category: .vegetables, suggestedIcons: ["🥒"]),
        "mushroom": Entry(icon: "🍄", category: .vegetables, suggestedIcons: ["🍄"]),
        "mushrooms": Entry(icon: "🍄", category: .vegetables, suggestedIcons: ["🍄"]),
        "bread": Entry(icon: "🍞", category: .carbs, suggestedIcons: ["🍞"]),
        "rice": Entry(icon: "🍚", category: .carbs, suggestedIcons: ["🍚"]),
        "pasta": Entry(icon: "🍝", category: .carbs, suggestedIcons: ["🍝"]),
        "noodles": Entry(icon: "🍜", category: .carbs, suggestedIcons: ["🍜", "🍝"]),
        "tortilla": Entry(icon: "🫓", category: .carbs, suggestedIcons: ["🫓"]),
        "flour": Entry(icon: "🌾", category: .carbs, suggestedIcons: ["🌾"]),
        "oats": Entry(icon: "🌾", category: .carbs, suggestedIcons: ["🌾"]),
        "cereal": Entry(icon: "🥣", category: .carbs, suggestedIcons: ["🥣"]),
        "pancake": Entry(icon: "🥞", category: .carbs, suggestedIcons: ["🥞"]),
        "apple": Entry(icon: "🍎", category: .fruits, suggestedIcons: ["🍎"]),
        "banana": Entry(icon: "🍌", category: .fruits, suggestedIcons: ["🍌"]),
        "orange": Entry(icon: "🍊", category: .fruits, suggestedIcons: ["🍊"]),
        "lemon": Entry(icon: "🍋", category: .fruits, suggestedIcons: ["🍋"]),
        "lime": Entry(icon: "🍋", category: .fruits, suggestedIcons: ["🍋"]),
        "grapes": Entry(icon: "🍇", category: .fruits, suggestedIcons: ["🍇"]),
        "strawberry": Entry(icon: "🍓", category: .fruits, suggestedIcons: ["🍓"]),
        "strawberries": Entry(icon: "🍓", category: .fruits, suggestedIcons: ["🍓"]),
        "blueberries": Entry(icon: "🫐", category: .fruits, suggestedIcons: ["🫐"]),
        "peach": Entry(icon: "🍑", category: .fruits, suggestedIcons: ["🍑"]),
        "pineapple": Entry(icon: "🍍", category: .fruits, suggestedIcons: ["🍍"]),
        "mango": Entry(icon: "🥭", category: .fruits, suggestedIcons: ["🥭"]),
        "watermelon": Entry(icon: "🍉", category: .fruits, suggestedIcons: ["🍉"]),
        "pear": Entry(icon: "🍐", category: .fruits, suggestedIcons: ["🍐"]),
        "kiwi": Entry(icon: "🥝", category: .fruits, suggestedIcons: ["🥝"]),
        "soy sauce": Entry(icon: "🫙", category: .condiments, suggestedIcons: ["🫙"]),
        "olive oil": Entry(icon: "🫙", category: .condiments, suggestedIcons: ["🫙"]),
        "vinegar": Entry(icon: "🫙", category: .condiments, suggestedIcons: ["🫙"]),
        "ketchup": Entry(icon: "🫙", category: .condiments, suggestedIcons: ["🫙"]),
        "mustard": Entry(icon: "🫙", category: .condiments, suggestedIcons: ["🫙"]),
        "mayo": Entry(icon: "🫙", category: .condiments, suggestedIcons: ["🫙"]),
        "mayonnaise": Entry(icon: "🫙", category: .condiments, suggestedIcons: ["🫙"]),
        "honey": Entry(icon: "🍯", category: .condiments, suggestedIcons: ["🍯"]),
        "salt": Entry(icon: "🧂", category: .condiments, suggestedIcons: ["🧂"]),
        "pepper": Entry(icon: "🧂", category: .condiments, suggestedIcons: ["🧂"]),
        "sugar": Entry(icon: "🧂", category: .condiments, suggestedIcons: ["🧂"]),
        "bell peppers": Entry(icon: "🫑", category: .produce, suggestedIcons: ["🫑", "🌶️"]),
        "green beans": Entry(icon: "🫛", category: .vegetables, suggestedIcons: ["🫛"]),
        "celery": Entry(icon: "🥬", category: .vegetables, suggestedIcons: ["🥬"]),
        "cauliflower": Entry(icon: "🥦", category: .vegetables, suggestedIcons: ["🥦"]),
        "sweet potato": Entry(icon: "🍠", category: .vegetables, suggestedIcons: ["🍠"]),
        "sweet potatoes": Entry(icon: "🍠", category: .vegetables, suggestedIcons: ["🍠"]),
        "asparagus": Entry(icon: "🥬", category: .vegetables, suggestedIcons: ["🥬"]),
        "ginger": Entry(icon: "🫚", category: .produce, suggestedIcons: ["🫚"]),
        "scallion": Entry(icon: "🧅", category: .produce, suggestedIcons: ["🧅"]),
        "scallions": Entry(icon: "🧅", category: .produce, suggestedIcons: ["🧅"]),
        "radish": Entry(icon: "🥕", category: .produce, suggestedIcons: ["🥕"]),
        "beet": Entry(icon: "🥕", category: .produce, suggestedIcons: ["🥕"]),
        "beets": Entry(icon: "🥕", category: .produce, suggestedIcons: ["🥕"]),
        "grapefruit": Entry(icon: "🍊", category: .fruits, suggestedIcons: ["🍊"]),
        "cherries": Entry(icon: "🍒", category: .fruits, suggestedIcons: ["🍒"]),
        "raspberries": Entry(icon: "🍓", category: .fruits, suggestedIcons: ["🍓"]),
        "blackberries": Entry(icon: "🫐", category: .fruits, suggestedIcons: ["🫐"]),
        "plum": Entry(icon: "🍑", category: .fruits, suggestedIcons: ["🍑"]),
        "plums": Entry(icon: "🍑", category: .fruits, suggestedIcons: ["🍑"]),
        "cantaloupe": Entry(icon: "🍈", category: .fruits, suggestedIcons: ["🍈"]),
        "coconut": Entry(icon: "🥥", category: .fruits, suggestedIcons: ["🥥"]),
        "pomegranate": Entry(icon: "🍎", category: .fruits, suggestedIcons: ["🍎"]),
        "almond milk": Entry(icon: "🥛", category: .dairy, suggestedIcons: ["🥛"]),
        "cottage cheese": Entry(icon: "🧀", category: .dairy, suggestedIcons: ["🧀"]),
        "cream cheese": Entry(icon: "🧀", category: .dairy, suggestedIcons: ["🧀"]),
        "cheddar": Entry(icon: "🧀", category: .dairy, suggestedIcons: ["🧀"]),
        "mozzarella": Entry(icon: "🧀", category: .dairy, suggestedIcons: ["🧀"]),
        "parmesan": Entry(icon: "🧀", category: .dairy, suggestedIcons: ["🧀"]),
        "turkey": Entry(icon: "🍗", category: .proteins, suggestedIcons: ["🍗", "🥩"]),
        "ground turkey": Entry(icon: "🍗", category: .proteins, suggestedIcons: ["🍗", "🥩"]),
        "deli meat": Entry(icon: "🍖", category: .proteins, suggestedIcons: ["🍖"]),
        "salami": Entry(icon: "🍖", category: .proteins, suggestedIcons: ["🍖"]),
        "pepperoni": Entry(icon: "🍖", category: .proteins, suggestedIcons: ["🍖"]),
        "cod": Entry(icon: "🐟", category: .seafood, suggestedIcons: ["🐟"]),
        "sardines": Entry(icon: "🐟", category: .seafood, suggestedIcons: ["🐟"]),
        "anchovies": Entry(icon: "🐟", category: .seafood, suggestedIcons: ["🐟"]),
        "quinoa": Entry(icon: "🌾", category: .carbs, suggestedIcons: ["🌾"]),
        "couscous": Entry(icon: "🌾", category: .carbs, suggestedIcons: ["🌾"]),
        "crackers": Entry(icon: "🍘", category: .carbs, suggestedIcons: ["🍘"]),
        "bagel": Entry(icon: "🥯", category: .carbs, suggestedIcons: ["🥯"]),
        "bagels": Entry(icon: "🥯", category: .carbs, suggestedIcons: ["🥯"]),
        "hot sauce": Entry(icon: "🫙", category: .condiments, suggestedIcons: ["🫙"]),
        "salsa": Entry(icon: "🫙", category: .condiments, suggestedIcons: ["🫙"]),
        "jam": Entry(icon: "🫙", category: .condiments, suggestedIcons: ["🫙"]),
        "jelly": Entry(icon: "🫙", category: .condiments, suggestedIcons: ["🫙"]),
        "bbq sauce": Entry(icon: "🫙", category: .condiments, suggestedIcons: ["🫙"]),
        "pesto": Entry(icon: "🫙", category: .condiments, suggestedIcons: ["🫙"]),
    ]
}
