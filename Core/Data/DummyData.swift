import Foundation

enum DummyData {
    private static func recipeImageData(_ name: String) -> Data? {
        guard let path = Bundle.main.path(forResource: name, ofType: "jpg") else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    static let suggestedIngredientInputs: [String] = [
        "chicken breast",
        "eggs",
        "spinach",
        "greek yogurt",
        "rice",
        "black beans",
        "tomatoes",
        "onion",
        "garlic",
        "olive oil",
        "bell pepper",
        "tofu"
    ]

    static let seedPantryIngredients: [Ingredient] = {
        let cal = Calendar.current
        let today = Date()
        return [
            Ingredient(
                name: "chicken breast",
                amount: "35g",
                category: .proteins,
                location: .fridge,
                expirationDate: cal.date(byAdding: .day, value: 1, to: today),
                loggedAt: cal.date(byAdding: .day, value: -2, to: today) ?? today
            ),
            Ingredient(
                name: "spinach",
                amount: "120g",
                category: .vegetables,
                location: .fridge,
                expirationDate: cal.date(byAdding: .day, value: 2, to: today),
                loggedAt: cal.date(byAdding: .day, value: -1, to: today) ?? today,
                notes: "Already opened"
            ),
            Ingredient(
                name: "rice",
                amount: "1.5kg",
                category: .carbs,
                location: .pantry,
                loggedAt: cal.date(byAdding: .day, value: -6, to: today) ?? today
            ),
            Ingredient(
                name: "eggs",
                amount: "12 pcs",
                category: .proteins,
                location: .fridge,
                expirationDate: cal.date(byAdding: .day, value: 10, to: today),
                loggedAt: cal.date(byAdding: .day, value: -3, to: today) ?? today
            ),
            Ingredient(
                name: "black beans",
                amount: "2 cans",
                category: .proteins,
                location: .pantry,
                loggedAt: cal.date(byAdding: .day, value: -7, to: today) ?? today
            ),
            Ingredient(
                name: "frozen peas",
                amount: "500g",
                category: .vegetables,
                location: .freezer,
                loggedAt: cal.date(byAdding: .day, value: -10, to: today) ?? today
            )
        ]
    }()

    static let sampleSharedRecipes: [Recipe] = [
        Recipe(
            title: "Grandma's Garlic Fried Rice",
            summary: "Simple comfort fried rice passed down from my grandmother.",
            timeMinutes: 15,
            servings: 2,
            ingredientsUsed: [.init(name: "rice", quantity: "2 cups"), .init(name: "garlic", quantity: "4 cloves"), .init(name: "eggs", quantity: "2"), .init(name: "soy sauce", quantity: "2 tbsp")],
            missingIngredients: [],
            steps: [
                "Heat oil in a wok over high heat.",
                "Sauté minced garlic until golden.",
                "Add cold rice and stir-fry for 3 minutes.",
                "Push rice to the side, scramble eggs, then mix together.",
                "Season with soy sauce and serve."
            ],
            macros: Macros(calories: 340, proteinG: 12, carbsG: 52, fatG: 10),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("garlic_fried_rice"),
            cuisine: .asian,
            createdBy: "UseUp",
            rating: 4.5
        ),
        Recipe(
            title: "Easy Black Bean Tacos",
            summary: "Quick weeknight tacos with canned black beans and fresh toppings.",
            timeMinutes: 10,
            servings: 3,
            ingredientsUsed: [.init(name: "black beans", quantity: "1 can"), .init(name: "tortillas", quantity: "6"), .init(name: "tomatoes", quantity: "2"), .init(name: "onion", quantity: "1/2")],
            missingIngredients: [.init(name: "tortillas"), .init(name: "lime")],
            steps: [
                "Warm beans with cumin and a pinch of salt.",
                "Heat tortillas in a dry pan.",
                "Assemble tacos with beans, diced tomatoes, and onion.",
                "Squeeze lime on top and enjoy."
            ],
            macros: Macros(calories: 280, proteinG: 14, carbsG: 44, fatG: 5),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("black_bean_tacos"),
            cuisine: .mexican,
            createdBy: "UseUp",
            rating: 4
        ),
        Recipe(
            title: "Chicken Adobo",
            summary: "Filipino braised chicken in soy sauce and vinegar.",
            timeMinutes: 45,
            servings: 4,
            ingredientsUsed: [.init(name: "chicken breast", quantity: "500g"), .init(name: "soy sauce", quantity: "1/3 cup"), .init(name: "vinegar", quantity: "1/4 cup"), .init(name: "garlic", quantity: "6 cloves"), .init(name: "onion", quantity: "1")],
            missingIngredients: [.init(name: "bay leaves"), .init(name: "peppercorns")],
            steps: [
                "Marinate chicken in soy sauce and vinegar for 15 min.",
                "Brown chicken in a hot pan.",
                "Add marinade, garlic, onion, and bay leaves.",
                "Simmer until sauce thickens and chicken is tender."
            ],
            macros: Macros(calories: 310, proteinG: 38, carbsG: 8, fatG: 14),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("chicken_adobo"),
            cuisine: .filipino,
            createdBy: "UseUp",
            rating: 4.5
        ),
        Recipe(
            title: "Spaghetti Aglio e Olio",
            summary: "Classic Italian pasta with garlic, chili, and olive oil.",
            timeMinutes: 20,
            servings: 2,
            ingredientsUsed: [.init(name: "pasta"), .init(name: "garlic"), .init(name: "olive oil"), .init(name: "chili flakes")],
            missingIngredients: [.init(name: "parsley")],
            steps: [
                "Cook spaghetti until al dente.",
                "Sauté sliced garlic and chili in olive oil.",
                "Toss pasta in the garlic oil with pasta water.",
                "Finish with parsley and parmesan."
            ],
            macros: Macros(calories: 420, proteinG: 12, carbsG: 58, fatG: 16),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("spaghetti_aglio_e_olio"),
            cuisine: .italian,
            createdBy: "UseUp",
            rating: 3.5
        ),
        Recipe(
            title: "Greek Chicken Salad",
            summary: "Fresh Mediterranean salad with grilled chicken.",
            timeMinutes: 20,
            servings: 2,
            ingredientsUsed: [.init(name: "chicken breast"), .init(name: "tomatoes"), .init(name: "cucumber"), .init(name: "olive oil")],
            missingIngredients: [.init(name: "feta cheese"), .init(name: "kalamata olives")],
            steps: [
                "Grill seasoned chicken and slice.",
                "Chop tomatoes, cucumber, and onion.",
                "Toss with olive oil and lemon juice.",
                "Top with feta and olives."
            ],
            macros: Macros(calories: 290, proteinG: 32, carbsG: 12, fatG: 14),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("greek_chicken_salad"),
            cuisine: .greek,
            createdBy: "UseUp",
            rating: 4
        ),
        Recipe(
            title: "Egg Fried Noodles",
            summary: "Quick stir-fried noodles with egg and vegetables.",
            timeMinutes: 12,
            servings: 2,
            ingredientsUsed: [.init(name: "noodles"), .init(name: "eggs"), .init(name: "garlic"), .init(name: "soy sauce"), .init(name: "bell pepper")],
            missingIngredients: [.init(name: "sesame oil")],
            steps: [
                "Cook noodles and drain.",
                "Scramble eggs in a hot wok.",
                "Add garlic, bell pepper, and noodles.",
                "Season with soy sauce and sesame oil."
            ],
            macros: Macros(calories: 380, proteinG: 16, carbsG: 48, fatG: 14),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("egg_fried_noodles"),
            cuisine: .chinese,
            createdBy: "UseUp",
            rating: 3.5
        ),
        Recipe(
            title: "Grilled Chicken Breast",
            summary: "Simple high-protein grilled chicken with herbs.",
            timeMinutes: 25,
            servings: 2,
            ingredientsUsed: [.init(name: "chicken breast"), .init(name: "olive oil"), .init(name: "garlic"), .init(name: "lemon")],
            missingIngredients: [.init(name: "rosemary")],
            steps: [
                "Marinate chicken with olive oil, garlic, and lemon.",
                "Preheat grill to medium-high.",
                "Grill 6-7 minutes per side.",
                "Rest for 5 minutes before slicing."
            ],
            macros: Macros(calories: 220, proteinG: 42, carbsG: 2, fatG: 5),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("grilled_chicken_breast"),
            cuisine: .american,
            createdBy: "UseUp",
            rating: 3
        ),
        Recipe(
            title: "Tofu Pad Thai",
            summary: "Sweet and tangy Thai noodles with crispy tofu.",
            timeMinutes: 30,
            servings: 2,
            ingredientsUsed: [.init(name: "tofu"), .init(name: "rice noodles"), .init(name: "eggs"), .init(name: "garlic"), .init(name: "bean sprouts")],
            missingIngredients: [.init(name: "tamarind paste"), .init(name: "peanuts")],
            steps: [
                "Press and cube tofu, fry until crispy.",
                "Soak rice noodles in warm water.",
                "Stir-fry garlic, add noodles and sauce.",
                "Toss with egg, tofu, and bean sprouts."
            ],
            macros: Macros(calories: 350, proteinG: 18, carbsG: 44, fatG: 12),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("tofu_pad_thai"),
            cuisine: .thai,
            createdBy: "UseUp",
            rating: 4.5
        ),
        Recipe(
            title: "Spinach & Egg White Scramble",
            summary: "Ultra-low calorie high-protein breakfast.",
            timeMinutes: 8,
            servings: 1,
            ingredientsUsed: [.init(name: "eggs"), .init(name: "spinach"), .init(name: "tomatoes")],
            missingIngredients: [],
            steps: [
                "Separate egg whites from 3 eggs.",
                "Sauté spinach until wilted.",
                "Add egg whites and scramble.",
                "Top with diced tomatoes."
            ],
            macros: Macros(calories: 120, proteinG: 18, carbsG: 4, fatG: 2),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("spinach_egg_scramble"),
            cuisine: .american,
            createdBy: "UseUp",
            rating: 2.5
        ),
        Recipe(
            title: "Korean Bibimbap",
            summary: "Colorful rice bowl with vegetables and gochujang.",
            timeMinutes: 35,
            servings: 2,
            ingredientsUsed: [.init(name: "rice"), .init(name: "spinach"), .init(name: "eggs"), .init(name: "garlic"), .init(name: "carrots")],
            missingIngredients: [.init(name: "gochujang"), .init(name: "sesame oil")],
            steps: [
                "Cook rice and prepare vegetables separately.",
                "Sauté spinach, carrots, and other vegetables.",
                "Fry an egg sunny-side up.",
                "Assemble bowl with rice, vegetables, egg, and gochujang."
            ],
            macros: Macros(calories: 410, proteinG: 16, carbsG: 62, fatG: 12),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("korean_bibimbap"),
            cuisine: .korean,
            createdBy: "UseUp",
            rating: 5
        ),
        Recipe(
            title: "Caprese Salad",
            summary: "Fresh tomato, mozzarella, and basil drizzled with olive oil.",
            timeMinutes: 5,
            servings: 2,
            ingredientsUsed: [.init(name: "tomatoes"), .init(name: "mozzarella"), .init(name: "olive oil")],
            missingIngredients: [.init(name: "fresh basil"), .init(name: "balsamic glaze")],
            steps: [
                "Slice tomatoes and mozzarella.",
                "Arrange alternating on a plate.",
                "Drizzle with olive oil and balsamic.",
                "Season with salt and pepper."
            ],
            macros: Macros(calories: 180, proteinG: 10, carbsG: 6, fatG: 14),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("caprese_salad"),
            cuisine: .italian,
            createdBy: "UseUp",
            rating: 4
        ),
        Recipe(
            title: "Chicken Tikka Bowl",
            summary: "Spiced yogurt-marinated chicken with rice.",
            timeMinutes: 40,
            servings: 2,
            ingredientsUsed: [.init(name: "chicken breast"), .init(name: "greek yogurt"), .init(name: "rice"), .init(name: "onion"), .init(name: "garlic")],
            missingIngredients: [.init(name: "garam masala"), .init(name: "turmeric")],
            steps: [
                "Marinate chicken in yogurt and spices for 20 min.",
                "Grill or bake chicken until charred.",
                "Cook basmati rice.",
                "Serve chicken over rice with onion salad."
            ],
            macros: Macros(calories: 380, proteinG: 40, carbsG: 38, fatG: 8),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("chicken_tikka_bowl"),
            cuisine: .indian,
            createdBy: "UseUp",
            rating: 4.5
        ),
        Recipe(
            title: "Zucchini Noodle Stir Fry",
            summary: "Low-carb veggie noodles with a savory sauce.",
            timeMinutes: 15,
            servings: 2,
            ingredientsUsed: [.init(name: "zucchini"), .init(name: "garlic"), .init(name: "bell pepper"), .init(name: "soy sauce")],
            missingIngredients: [.init(name: "zucchini")],
            steps: [
                "Spiralize zucchini into noodles.",
                "Sauté garlic and bell pepper.",
                "Add zucchini noodles and soy sauce.",
                "Cook 2-3 minutes until just tender."
            ],
            macros: Macros(calories: 95, proteinG: 4, carbsG: 12, fatG: 3),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("zucchini_noodle_stir_fry"),
            cuisine: .asian,
            createdBy: "UseUp",
            rating: 3
        ),
        Recipe(
            title: "Mediterranean Quinoa Bowl",
            summary: "Protein-packed quinoa with hummus and roasted vegetables.",
            timeMinutes: 30,
            servings: 2,
            ingredientsUsed: [.init(name: "quinoa"), .init(name: "tomatoes"), .init(name: "cucumber"), .init(name: "olive oil")],
            missingIngredients: [.init(name: "hummus"), .init(name: "quinoa")],
            steps: [
                "Cook quinoa according to package.",
                "Chop tomatoes, cucumber, and red onion.",
                "Assemble bowls with quinoa and vegetables.",
                "Top with hummus and a drizzle of olive oil."
            ],
            macros: Macros(calories: 320, proteinG: 14, carbsG: 42, fatG: 12),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("mediterranean_quinoa_bowl"),
            cuisine: .mediterranean,
            createdBy: "UseUp",
            rating: 4
        ),
        Recipe(
            title: "Japanese Miso Soup",
            summary: "Light and comforting traditional miso broth.",
            timeMinutes: 10,
            servings: 2,
            ingredientsUsed: [.init(name: "tofu"), .init(name: "spinach"), .init(name: "garlic")],
            missingIngredients: [.init(name: "miso paste"), .init(name: "dashi")],
            steps: [
                "Heat water and dissolve dashi.",
                "Add cubed tofu and simmer.",
                "Stir in miso paste off heat.",
                "Add spinach and serve immediately."
            ],
            macros: Macros(calories: 70, proteinG: 6, carbsG: 5, fatG: 3),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("japanese_miso_soup"),
            cuisine: .japanese,
            createdBy: "UseUp",
            rating: 3.5
        ),
        Recipe(
            title: "Burrito Bowl",
            summary: "Loaded rice bowl with beans, salsa, and guacamole.",
            timeMinutes: 20,
            servings: 2,
            ingredientsUsed: [.init(name: "rice"), .init(name: "black beans"), .init(name: "tomatoes"), .init(name: "onion")],
            missingIngredients: [.init(name: "avocado"), .init(name: "sour cream")],
            steps: [
                "Cook cilantro-lime rice.",
                "Warm black beans with cumin.",
                "Make quick pico de gallo.",
                "Assemble bowls and top with guacamole."
            ],
            macros: Macros(calories: 450, proteinG: 18, carbsG: 64, fatG: 14),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("burrito_bowl"),
            cuisine: .mexican,
            createdBy: "UseUp",
            rating: 4.5
        ),
        Recipe(
            title: "Tuna Protein Salad",
            summary: "High-protein tuna salad with minimal carbs.",
            timeMinutes: 10,
            servings: 1,
            ingredientsUsed: [.init(name: "tuna"), .init(name: "eggs"), .init(name: "olive oil"), .init(name: "onion")],
            missingIngredients: [.init(name: "tuna can")],
            steps: [
                "Hard boil eggs and chop.",
                "Mix tuna with diced onion and olive oil.",
                "Combine with eggs.",
                "Season with salt, pepper, and lemon."
            ],
            macros: Macros(calories: 250, proteinG: 36, carbsG: 3, fatG: 11),
            sources: [],
            isUserShared: true,
            imageData: recipeImageData("tuna_protein_salad"),
            cuisine: .american,
            createdBy: "UseUp",
            rating: 2
        )
    ]

    static let sampleSavedRecipes: [Recipe] = [
        Recipe(
            title: "Quick Bean and Rice Bowl",
            summary: "A simple bowl from pantry staples.",
            timeMinutes: 18,
            servings: 2,
            ingredientsUsed: [.init(name: "rice"), .init(name: "black beans"), .init(name: "tomatoes"), .init(name: "onion")],
            missingIngredients: [.init(name: "lime"), .init(name: "cilantro")],
            steps: [
                "Heat beans with tomatoes and onion.",
                "Serve over warm rice.",
                "Top with fresh lime if available."
            ],
            macros: Macros(calories: 390, proteinG: 16, carbsG: 62, fatG: 8),
            sources: [
                SourceLink(title: "Reference", url: URL(string: "https://example.com/recipe/bean-rice-bowl")!)
            ],
            imageData: recipeImageData("bean_rice_bowl"),
            cuisine: .mexican,
            rating: 3.5
        )
    ]

    /// Synthetic `pantry_events` spanning ~6 months so the Stats preview renders populated charts.
    static let samplePantryEvents: [PantryEvent] = {
        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: now) ?? now }

        struct Spec { let name: String; let category: Ingredient.Category; let cost: Double }
        let bought: [(Spec, Int)] = [
            (Spec(name: "baby spinach", category: .vegetables, cost: 3.80), 4),
            (Spec(name: "baby spinach", category: .vegetables, cost: 3.80), 40),
            (Spec(name: "baby spinach", category: .vegetables, cost: 3.80), 74),
            (Spec(name: "baby spinach", category: .vegetables, cost: 3.80), 110),
            (Spec(name: "whole milk", category: .dairy, cost: 4.20), 6),
            (Spec(name: "whole milk", category: .dairy, cost: 4.20), 33),
            (Spec(name: "whole milk", category: .dairy, cost: 4.20), 61),
            (Spec(name: "sourdough loaf", category: .carbs, cost: 5.50), 9),
            (Spec(name: "sourdough loaf", category: .carbs, cost: 5.50), 52),
            (Spec(name: "chicken breast", category: .proteins, cost: 9.40), 12),
            (Spec(name: "chicken breast", category: .proteins, cost: 9.40), 70),
            (Spec(name: "cheddar", category: .dairy, cost: 6.10), 20),
            (Spec(name: "roma tomatoes", category: .produce, cost: 2.90), 15),
            (Spec(name: "roma tomatoes", category: .produce, cost: 2.90), 88),
            (Spec(name: "basil", category: .produce, cost: 2.40), 18),
            (Spec(name: "greek yogurt", category: .dairy, cost: 5.30), 25),
        ]
        let wasted: [(Spec, Int)] = [
            (Spec(name: "baby spinach", category: .vegetables, cost: 3.80), 3),
            (Spec(name: "baby spinach", category: .vegetables, cost: 3.80), 44),
            (Spec(name: "baby spinach", category: .vegetables, cost: 3.80), 78),
            (Spec(name: "whole milk", category: .dairy, cost: 4.20), 5),
            (Spec(name: "whole milk", category: .dairy, cost: 4.20), 64),
            (Spec(name: "sourdough loaf", category: .carbs, cost: 5.50), 55),
            (Spec(name: "roma tomatoes", category: .produce, cost: 2.90), 90),
            (Spec(name: "basil", category: .produce, cost: 2.40), 20),
        ]
        func rows(_ specs: [(Spec, Int)], _ outcome: PantryEventOutcome) -> [PantryEvent] {
            specs.map { spec, day in
                PantryEvent(
                    ingredientName: spec.name,
                    ingredientKey: spec.name,
                    category: spec.category,
                    outcome: outcome,
                    costValue: spec.cost,
                    occurredAt: daysAgo(day)
                )
            }
        }
        return rows(bought, .bought) + rows(wasted, .wasted)
    }()
}
