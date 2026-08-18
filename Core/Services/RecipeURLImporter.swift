import Foundation
import SwiftSoup

enum RecipeImportError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case networkError(Error)
    case noRecipeFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Please enter a valid URL."
        case .httpError(let c): return "Could not load page (error \(c))."
        case .networkError:     return "Something went wrong. Please try again."
        case .noRecipeFound:    return "No recipe found at this URL."
        }
    }
}

final class RecipeURLImporter {

    private let knownUnits: Set<String> = [
        "tsp", "tbsp", "cup", "cups", "oz", "fl oz", "lb", "lbs",
        "g", "kg", "ml", "l", "pcs", "pinch", "can", "bunch", "cloves",
        "tablespoon", "tablespoons", "teaspoon", "teaspoons",
        "pound", "pounds", "ounce", "ounces", "gram", "grams",
        "kilogram", "kilograms", "liter", "liters", "milliliter", "milliliters",
        "piece", "pieces", "slice", "slices", "stalk", "stalks",
        "head", "heads", "clove", "sprig", "sprigs", "large", "medium", "small"
    ]

    func importRecipe(from urlString: String) async throws -> RecipeImportData {
        // Validate URL
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme, ["http", "https"].contains(scheme),
              url.host?.isEmpty == false else {
            throw RecipeImportError.invalidURL
        }

        // Fetch HTML
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let (data, response) : (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw RecipeImportError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw RecipeImportError.httpError(http.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw RecipeImportError.noRecipeFound
        }

        // Parse JSON-LD
        let doc = try SwiftSoup.parse(html)
        let scripts = try doc.select("script[type='application/ld+json']")

        for script in scripts.array() {
            let json = try script.html()
            guard let jsonData = json.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: jsonData) else { continue }

            if let recipe = extractRecipeObject(from: obj) {
                var importData = mapRecipe(recipe, sourceURL: urlString)
                if importData.title.isEmpty { continue }
                // Fill missing time/servings from Microdata when JSON-LD didn't have them
                if importData.timeMinutes.isEmpty {
                    importData.timeMinutes = extractMicrodataTime(doc) ?? ""
                }
                if importData.servings.isEmpty {
                    importData.servings = extractMicrodataServings(doc) ?? ""
                }
                if let imageURLString = extractImageURL(from: recipe),
                   let imageURL = URL(string: imageURLString) {
                    importData.imageData = try? await URLSession.shared.data(from: imageURL).0
                }
                return importData
            }
        }

        throw RecipeImportError.noRecipeFound
    }

    // MARK: - JSON-LD Helpers

    private func extractRecipeObject(from obj: Any) -> [String: Any]? {
        // Could be a single object or an array of objects
        if let array = obj as? [[String: Any]] {
            return array.first { isRecipeType($0) }
        }
        if let dict = obj as? [String: Any] {
            if isRecipeType(dict) { return dict }
            // Some sites nest in @graph
            if let graph = dict["@graph"] as? [[String: Any]] {
                return graph.first { isRecipeType($0) }
            }
        }
        return nil
    }

    private func isRecipeType(_ dict: [String: Any]) -> Bool {
        if let type_ = dict["@type"] as? String {
            return type_ == "Recipe"
        }
        if let types = dict["@type"] as? [String] {
            return types.contains("Recipe")
        }
        return false
    }

    private func extractImageURL(from recipe: [String: Any]) -> String? {
        let raw = recipe["image"]
        if let s = raw as? String { return s }
        if let arr = raw as? [String] { return arr.first }
        if let dict = raw as? [String: Any] { return dict["url"] as? String }
        if let arr = raw as? [[String: Any]] { return arr.first?["url"] as? String }
        return nil
    }

    // MARK: - Field Mapping

    private func mapRecipe(_ recipe: [String: Any], sourceURL: String) -> RecipeImportData {
        var data = RecipeImportData()

        data.title = string(recipe["name"]) ?? ""
        data.summary = stripHTML(string(recipe["description"]) ?? "")
        data.sourceURL = sourceURL
        data.sourceTitle = data.title

        // Time — prefer totalTime, fall back to prepTime + cookTime sum
        if let totalStr = string(recipe["totalTime"]), let total = parseISO8601Duration(totalStr), total > 0 {
            data.timeMinutes = String(total)
        } else {
            let prep = string(recipe["prepTime"]).flatMap { parseISO8601Duration($0) } ?? 0
            let cook = string(recipe["cookTime"]).flatMap { parseISO8601Duration($0) } ?? 0
            let sum = prep + cook
            if sum > 0 { data.timeMinutes = String(sum) }
        }

        // Servings
        let yield = string(recipe["recipeYield"]) ?? ""
        data.servings = leadingInteger(from: yield).map { String($0) } ?? ""

        // Cuisine
        let cuisineStr = string(recipe["recipeCuisine"]) ?? ""
        data.cuisine = matchCuisine(cuisineStr)

        // Ingredients
        if let raw = recipe["recipeIngredient"] as? [String] {
            data.ingredients = raw.map { parseIngredient($0) }
        }

        // Steps
        if let instructions = recipe["recipeInstructions"] {
            data.steps = parseInstructions(instructions)
        }

        // Nutrition
        if let nutrition = recipe["nutrition"] as? [String: Any] {
            data.calories = numericString(string(nutrition["calories"]) ?? "")
            data.protein  = numericString(string(nutrition["proteinContent"]) ?? "")
            data.carbs    = numericString(string(nutrition["carbohydrateContent"]) ?? "")
            data.fat      = numericString(string(nutrition["fatContent"]) ?? "")
        }

        return data
    }

    // MARK: - Ingredient Parsing

    private func parseIngredient(_ raw: String) -> (name: String, quantity: String, unit: String) {
        let cleaned = raw.trimmingCharacters(in: .whitespaces)
        var tokens = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return (name: cleaned, quantity: "", unit: "") }

        // Extract leading number (handles fractions like 1/2, 1½)
        var quantity = ""
        if let _ = parseNumber(tokens[0]) {
            quantity = tokens.removeFirst()
            // Handle mixed numbers like "1 1/2"
            if !tokens.isEmpty, let _ = parseNumber(tokens[0]), tokens[0].contains("/") {
                quantity += " " + tokens.removeFirst()
            }
        }

        // Extract unit
        var unit = ""
        if !tokens.isEmpty {
            let candidate = tokens[0].lowercased()
            if knownUnits.contains(candidate) {
                unit = tokens.removeFirst()
            }
        }

        let name = tokens.joined(separator: " ")
        return (name: name, quantity: quantity, unit: unit)
    }

    private func parseNumber(_ s: String) -> Double? {
        // Handle vulgar fractions (½ ¼ ¾ ⅓ ⅔)
        let vulgar: [Character: Double] = ["½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0/3, "⅔": 2.0/3]
        if s.count == 1, let v = vulgar[s.first!] { return v }
        if s.contains("/") {
            let parts = s.split(separator: "/")
            if parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 { return n / d }
        }
        return Double(s)
    }

    // MARK: - Instructions Parsing

    private func parseInstructions(_ value: Any) -> [String] {
        if let strings = value as? [String] {
            return strings.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        if let dicts = value as? [[String: Any]] {
            return dicts.compactMap { step -> String? in
                let text = string(step["text"]) ?? string(step["name"]) ?? ""
                return text.isEmpty ? nil : stripHTML(text)
            }
        }
        if let single = value as? String {
            return single.components(separatedBy: "\n").map { stripHTML($0.trimmingCharacters(in: .whitespaces)) }.filter { !$0.isEmpty }
        }
        return []
    }

    // MARK: - Cuisine Matching

    private func matchCuisine(_ raw: String) -> Cuisine? {
        let lower = raw.lowercased()
        return Cuisine.allCases.first { lower.contains($0.rawValue.lowercased()) || lower.contains($0.databaseValue) }
    }

    // MARK: - Utility

    private func string(_ value: Any?) -> String? {
        if let s = value as? String { return s.isEmpty ? nil : s }
        if let a = value as? [String] { return a.first }
        return nil
    }

    private func stripHTML(_ s: String) -> String {
        guard let data = s.data(using: .utf8),
              let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) else {
            return s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        return attributed.string
    }

    private func numericString(_ s: String) -> String {
        let digits = s.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return digits
    }

    private func leadingInteger(from s: String) -> Int? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard let match = trimmed.range(of: #"^\d+"#, options: .regularExpression) else { return nil }
        return Int(trimmed[match])
    }

    private func parseISO8601Duration(_ s: String) -> Int? {
        guard !s.isEmpty else { return nil }
        // PT1H30M or PT45M or P0DT1H
        let pattern = #"(?:(\d+)H)?(?:(\d+)M)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        let hours = rangeInt(match, at: 1, in: s) ?? 0
        let mins  = rangeInt(match, at: 2, in: s) ?? 0
        let total = hours * 60 + mins
        return total > 0 ? total : nil
    }

    private func rangeInt(_ match: NSTextCheckingResult, at i: Int, in s: String) -> Int? {
        let r = match.range(at: i)
        guard r.location != NSNotFound, let range = Range(r, in: s) else { return nil }
        return Int(s[range])
    }

    // MARK: - Microdata Fallbacks

    private func extractMicrodataTime(_ doc: Document) -> String? {
        for selector in ["[itemprop='totalTime']", "[itemprop='cookTime']"] {
            guard let el = try? doc.select(selector).first() else { continue }
            let value = (try? el.attr("content")).nilIfEmpty
                ?? (try? el.attr("datetime")).nilIfEmpty
                ?? (try? el.text()).nilIfEmpty
                ?? ""
            if let mins = parseISO8601Duration(value) ?? parsePlainTextTime(value), mins > 0 {
                return String(mins)
            }
        }
        // Try prepTime + cookTime from Microdata
        let prep = microdataMinutes(doc, itemprop: "prepTime") ?? 0
        let cook = microdataMinutes(doc, itemprop: "cookTime") ?? 0
        let sum = prep + cook
        return sum > 0 ? String(sum) : nil
    }

    private func microdataMinutes(_ doc: Document, itemprop: String) -> Int? {
        guard let el = try? doc.select("[itemprop='\(itemprop)']").first() else { return nil }
        let value = (try? el.attr("content")).nilIfEmpty
            ?? (try? el.attr("datetime")).nilIfEmpty
            ?? (try? el.text()).nilIfEmpty
            ?? ""
        return parseISO8601Duration(value) ?? parsePlainTextTime(value)
    }

    private func extractMicrodataServings(_ doc: Document) -> String? {
        guard let el = try? doc.select("[itemprop='recipeYield']").first() else { return nil }
        let value = (try? el.attr("content")).nilIfEmpty ?? (try? el.text()) ?? ""
        return leadingInteger(from: value).map { String($0) }
    }

    private func parsePlainTextTime(_ s: String) -> Int? {
        let lower = s.lowercased()
        var total = 0
        let hourPattern = #"(\d+)\s*(?:hours?|hrs?)"#
        let minPattern  = #"(\d+)\s*(?:minutes?|mins?)"#
        if let m = try? NSRegularExpression(pattern: hourPattern).firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let r = Range(m.range(at: 1), in: lower), let h = Int(lower[r]) {
            total += h * 60
        }
        if let m = try? NSRegularExpression(pattern: minPattern).firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let r = Range(m.range(at: 1), in: lower), let min = Int(lower[r]) {
            total += min
        }
        return total > 0 ? total : nil
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? { self.flatMap { $0.isEmpty ? nil : $0 } }
}
