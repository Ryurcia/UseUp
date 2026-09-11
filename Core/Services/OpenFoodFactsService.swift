import Foundation

enum OpenFoodFactsService {
    struct ProductInfo {
        let name: String
        let quantity: String?
        let category: Ingredient.Category?
        /// The scanned barcode, retained so downstream (cost resolution's Open Prices tier) can
        /// use it without a second scan.
        let barcode: String
    }

    enum LookupError: Error {
        case notFound
    }

    static func lookup(barcode: String) async throws -> ProductInfo {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json") else {
            throw LookupError.notFound
        }
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 1,
              let product = json["product"] as? [String: Any] else {
            throw LookupError.notFound
        }

        let rawName = (product["product_name"] as? String)
                   ?? (product["product_name_en"] as? String)
                   ?? ""
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw LookupError.notFound }

        var quantity: String? = nil
        if let raw = (product["quantity"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty {
            quantity = extractSingleQuantity(raw)
        }
        if quantity == nil {
            let numericQty: Double?
            if let d = product["product_quantity"] as? Double {
                numericQty = d
            } else if let s = product["product_quantity"] as? String, let d = Double(s) {
                numericQty = d
            } else {
                numericQty = nil
            }
            if let val = numericQty,
               let unitStr = (product["product_quantity_unit"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !unitStr.isEmpty {
                let formatted = val == val.rounded() ? "\(Int(val))" : String(format: "%.1f", val)
                quantity = "\(formatted) \(unitStr)"
            }
        }

        let hierarchy = product["categories_hierarchy"] as? [String] ?? []
        let category = mapCategory(from: hierarchy) ?? mapCategory(fromName: name)
        return ProductInfo(name: name, quantity: quantity, category: category, barcode: barcode)
    }

    // Extracts a single canonical "value unit" pair from raw strings that may contain
    // dual-unit formats like "32 fl oz / 946 ml" or "946 ml (32 fl oz)".
    // Prefers metric units over imperial when multiple are present.
    private static func extractSingleQuantity(_ raw: String) -> String? {
        // Ordered longest-first so alternation doesn't short-circuit on a prefix match
        let unitCandidates: [(spoken: String, canonical: String)] = [
            ("fluid ounces", "fl oz"), ("fluid ounce", "fl oz"),
            ("milliliters", "ml"), ("millilitres", "ml"),
            ("milliliter", "ml"), ("millilitre", "ml"),
            ("tablespoons", "tbsp"), ("tablespoon", "tbsp"),
            ("teaspoons", "tsp"), ("teaspoon", "tsp"),
            ("kilograms", "kg"), ("kilogram", "kg"),
            ("fl oz", "fl oz"),
            ("liters", "L"), ("litres", "L"), ("liter", "L"), ("litre", "L"),
            ("ounces", "oz"), ("ounce", "oz"),
            ("pounds", "lb"), ("pound", "lb"),
            ("grams", "g"), ("gram", "g"),
            ("cups", "cups"), ("cup", "cups"),
            ("tbsp", "tbsp"), ("tsp", "tsp"),
            ("lbs", "lb"), ("ml", "ml"),
            ("kg", "kg"), ("lb", "lb"), ("oz", "oz"),
            ("g", "g"), ("L", "L"), ("l", "L"),
        ]

        let unitAlt = unitCandidates
            .map { NSRegularExpression.escapedPattern(for: $0.spoken) }
            .joined(separator: "|")
        let pattern = "(\\d+\\.?\\d*)\\s*(" + unitAlt + ")(?![a-zA-Z])"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let nsStr = raw as NSString
        let matches = regex.matches(in: raw, range: NSRange(location: 0, length: nsStr.length))

        var found: [(value: String, canonical: String)] = []
        for m in matches {
            guard let vr = Range(m.range(at: 1), in: raw),
                  let ur = Range(m.range(at: 2), in: raw) else { continue }
            let valueStr = String(raw[vr])
            let unitLower = String(raw[ur]).lowercased()
            if let info = unitCandidates.first(where: { $0.spoken.lowercased() == unitLower }) {
                found.append((value: valueStr, canonical: info.canonical))
            }
        }

        guard !found.isEmpty else { return nil }

        // Prefer metric over imperial: ml > L > g > kg > fl oz > oz > lb > rest
        let preference = ["ml", "L", "g", "kg", "cups", "fl oz", "oz", "lb", "tbsp", "tsp"]
        for pref in preference {
            if let match = found.first(where: { $0.canonical == pref }) {
                return "\(match.value) \(match.canonical)"
            }
        }
        return "\(found[0].value) \(found[0].canonical)"
    }

    private static func mapCategory(from hierarchy: [String]) -> Ingredient.Category? {
        let rules: [([String], Ingredient.Category)] = [
            (["en:meats", "en:poultry", "en:beef-products", "en:pork-products", "en:chicken-products"], .proteins),
            (["en:fish-based-foods", "en:seafoods", "en:fishes", "en:shellfishes"], .seafood),
            (["en:fruits"], .fruits),
            (["en:vegetables", "en:fresh-vegetables", "en:canned-vegetables"], .vegetables),
            (["en:dairies", "en:cheeses", "en:milks", "en:yogurts", "en:butters"], .dairy),
            (["en:breads", "en:cereals-and-their-products", "en:pastas", "en:rice"], .carbs),
            (["en:condiments", "en:sauces", "en:spreads", "en:seasonings", "en:dressings-and-vinaigrettes"], .condiments),
        ]
        for (keywords, cat) in rules {
            for kw in keywords where hierarchy.contains(kw) {
                return cat
            }
        }
        return nil
    }

    // TODO(product): OFF's `categories_hierarchy` only covers a handful of taxonomy branches
    // (packaged/processed goods, drinks, baby food, etc. mostly fall outside the rules above),
    // so `mapCategory(from:)` returns nil for a large share of real scans. This is a rougher,
    // illustrative fallback over the product name itself for those cases — better than always
    // landing on "Other", but a keyword substring match, not authoritative.
    static func mapCategory(fromName name: String) -> Ingredient.Category? {
        let lowered = name.lowercased()
        let rules: [([String], Ingredient.Category)] = [
            (["chicken", "beef", "pork", "turkey", "bacon", "sausage", "ham", "steak", "meatball"], .proteins),
            (["fish", "salmon", "tuna", "shrimp", "crab", "cod", "sardine", "anchovy"], .seafood),
            (["milk", "cheese", "yogurt", "yoghurt", "butter", "cream"], .dairy),
            (["bread", "pasta", "rice", "cereal", "oats", "oatmeal", "tortilla", "bagel", "noodle", "cracker"], .carbs),
            (["apple", "banana", "berry", "berries", "orange", "grape", "mango", "pear", "peach", "melon"], .fruits),
            (["carrot", "broccoli", "spinach", "lettuce", "pepper", "onion", "potato", "tomato", "cucumber", "kale"], .vegetables),
            (["sauce", "ketchup", "mustard", "mayo", "mayonnaise", "dressing", "syrup", "jam", "honey", "salsa"], .condiments),
        ]
        for (keywords, cat) in rules {
            for kw in keywords where lowered.contains(kw) {
                return cat
            }
        }
        return nil
    }
}
