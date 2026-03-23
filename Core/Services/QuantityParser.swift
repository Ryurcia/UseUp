import Foundation

enum QuantityUnit: Equatable {
    case mass(UnitMass)
    case volume(UnitVolume)
    case count
}

struct ParsedQuantity {
    let value: Double
    let unit: QuantityUnit
}

enum QuantityParser {
    // MARK: - Unit Aliases

    private static let massAliases: [(String, UnitMass)] = [
        ("g", .grams), ("gram", .grams), ("grams", .grams),
        ("kg", .kilograms), ("kilogram", .kilograms), ("kilograms", .kilograms),
        ("lb", .pounds), ("lbs", .pounds), ("pound", .pounds), ("pounds", .pounds),
        ("oz", .ounces), ("ounce", .ounces), ("ounces", .ounces),
    ]

    private static let volumeAliases: [(String, UnitVolume)] = [
        ("ml", .milliliters), ("milliliter", .milliliters), ("milliliters", .milliliters),
        ("l", .liters), ("liter", .liters), ("liters", .liters),
        ("cup", .cups), ("cups", .cups),
        ("tbsp", .tablespoons), ("tablespoon", .tablespoons), ("tablespoons", .tablespoons),
        ("tsp", .teaspoons), ("teaspoon", .teaspoons), ("teaspoons", .teaspoons),
        ("fl oz", .fluidOunces), ("fluid ounce", .fluidOunces), ("fluid ounces", .fluidOunces),
    ]

    // MARK: - Public

    static func parse(_ string: String?) -> ParsedQuantity? {
        guard let string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Try to extract a numeric value and unit suffix
        guard let (value, unitString) = extractValueAndUnit(from: trimmed) else {
            return nil
        }

        let unit = resolveUnit(unitString)
        return ParsedQuantity(value: value, unit: unit)
    }

    // MARK: - Private

    private static func extractValueAndUnit(from string: String) -> (Double, String)? {
        // Pattern: optional leading fraction/decimal, optional space, then unit text
        // Handles: "1.5 cups", "200g", "1/2 cup", "1 1/2 cups", "3", "2 eggs"

        let pattern = #"^(\d+\s+\d+\s*/\s*\d+|\d+\s*/\s*\d+|\d+\.?\d*|\.\d+)\s*(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let numberRange = Range(match.range(at: 1), in: string) else {
            return nil
        }

        let numberStr = String(string[numberRange])
        let unitRange = Range(match.range(at: 2), in: string)
        let unitStr = unitRange.map { String(string[$0]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""

        guard let value = parseNumber(numberStr) else { return nil }
        return (value, unitStr)
    }

    private static func parseNumber(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)

        // Mixed fraction: "1 1/2"
        if trimmed.contains(" ") && trimmed.contains("/") {
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            if parts.count == 2,
               let whole = Double(parts[0]),
               let frac = parseFraction(String(parts[1])) {
                return whole + frac
            }
        }

        // Simple fraction: "1/2"
        if trimmed.contains("/") {
            return parseFraction(trimmed)
        }

        // Decimal or integer
        return Double(trimmed)
    }

    private static func parseFraction(_ string: String) -> Double? {
        let parts = string.split(separator: "/")
        guard parts.count == 2,
              let numerator = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let denominator = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              denominator != 0 else {
            return nil
        }
        return numerator / denominator
    }

    private static func resolveUnit(_ unitString: String) -> QuantityUnit {
        let cleaned = unitString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return .count }

        // Sort aliases longest-first to prefer "grams" over "g", "tablespoons" over "tbsp", etc.
        for (alias, unit) in massAliases.sorted(by: { $0.0.count > $1.0.count }) {
            if cleaned == alias || cleaned.hasPrefix(alias + " ") {
                return .mass(unit)
            }
        }
        for (alias, unit) in volumeAliases.sorted(by: { $0.0.count > $1.0.count }) {
            if cleaned == alias || cleaned.hasPrefix(alias + " ") {
                return .volume(unit)
            }
        }

        // Unrecognized unit — treat as count
        return .count
    }
}
