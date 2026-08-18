import Foundation

struct QuantityConverter {

    enum Unit {
        case gram, kilogram, ounce, pound
        case milliliter, liter, cup, tablespoon, teaspoon
        case piece
        case unknown

        enum Category { case weight, volume, count, unknown }

        var category: Category {
            switch self {
            case .gram, .kilogram, .ounce, .pound:                  return .weight
            case .milliliter, .liter, .cup, .tablespoon, .teaspoon: return .volume
            case .piece:                                             return .count
            case .unknown:                                           return .unknown
            }
        }

        func toBase(_ value: Double) -> Double {
            switch self {
            case .gram:               return value
            case .kilogram:           return value * 1_000
            case .ounce:              return value * 28.3495
            case .pound:              return value * 453.592
            case .milliliter:         return value
            case .liter:              return value * 1_000
            case .cup:                return value * 240
            case .tablespoon:         return value * 14.787
            case .teaspoon:           return value * 4.929
            case .piece, .unknown:    return value
            }
        }

        func fromBase(_ base: Double) -> Double {
            let factor = toBase(1.0)
            guard factor > 0 else { return base }
            return base / factor
        }

        var label: String {
            switch self {
            case .gram:        return "g"
            case .kilogram:    return "kg"
            case .ounce:       return "oz"
            case .pound:       return "lb"
            case .milliliter:  return "ml"
            case .liter:       return "L"
            case .cup:         return "cup"
            case .tablespoon:  return "tbsp"
            case .teaspoon:    return "tsp"
            case .piece:       return "pc"
            case .unknown:     return ""
            }
        }
    }

    struct Parsed {
        let value: Double
        let unit: Unit
        func toBase() -> Double { unit.toBase(value) }
    }

    // Longest aliases first to avoid prefix clashes (e.g. "g" matching "kg")
    private static let aliases: [(String, Unit)] = [
        ("tablespoons", .tablespoon), ("tablespoon", .tablespoon), ("tbsp", .tablespoon), ("tbs", .tablespoon),
        ("teaspoons",   .teaspoon),   ("teaspoon",   .teaspoon),   ("tsp", .teaspoon),
        ("kilograms",   .kilogram),   ("kilogram",   .kilogram),   ("kg",  .kilogram),
        ("milliliters", .milliliter), ("milliliter", .milliliter),
        ("millilitres", .milliliter), ("millilitre", .milliliter), ("ml",  .milliliter),
        ("liters",      .liter),      ("liter",      .liter),
        ("litres",      .liter),      ("litre",      .liter),      ("l",   .liter),
        ("cups",        .cup),        ("cup",        .cup),
        ("pounds",      .pound),      ("pound",      .pound),      ("lbs", .pound),  ("lb", .pound),
        ("ounces",      .ounce),      ("ounce",      .ounce),      ("oz",  .ounce),
        ("grams",       .gram),       ("gram",       .gram),       ("g",   .gram),
        ("pieces",      .piece),      ("piece",      .piece),      ("pcs", .piece),
        ("cloves",      .piece),      ("clove",      .piece),
        ("slices",      .piece),      ("slice",      .piece),
    ]

    /// Returns nil when text is unparseable ("to taste", "as needed", empty, etc.)
    static func parse(_ text: String) -> Parsed? {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty else { return nil }

        var unit: Unit = .unknown
        var numberPart = t

        for (alias, u) in aliases {
            if t.hasSuffix(" \(alias)") {
                unit = u
                numberPart = String(t.dropLast(alias.count + 1))
                break
            }
            if t.hasSuffix(alias), let rest = numericPrefix(of: t, dropping: alias) {
                unit = u
                numberPart = rest
                break
            }
        }

        guard let value = parseNumber(numberPart) else { return nil }
        return Parsed(value: value, unit: unit)
    }

    static func formatQuantity(_ value: Double) -> String {
        let s = String(format: "%.1f", value)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }

    /// Returns nil if units are incompatible (weight vs volume) or either amount is unparseable.
    static func isSufficient(have pantryAmount: String?, need recipeQuantity: String) -> Bool? {
        guard let pantryAmount,
              let have = parse(pantryAmount),
              let need = parse(recipeQuantity),
              have.unit.category == need.unit.category,
              have.unit.category != .unknown else { return nil }
        return have.toBase() >= need.toBase()
    }

    /// Human-readable remaining amount when `pantryAmount` only partially covers `recipeQuantity`.
    /// Returns nil when fully sufficient, not in pantry, or units are incompatible/unparseable.
    static func shortfallDescription(have pantryAmount: String?, need recipeQuantity: String) -> String? {
        guard let pantryAmount,
              let have = parse(pantryAmount),
              let need = parse(recipeQuantity),
              have.unit.category == need.unit.category,
              have.unit.category != .unknown else { return nil }
        let gapBase = need.toBase() - have.toBase()
        guard gapBase > 0 else { return nil }
        let gapValue = need.unit.fromBase(gapBase)
        return "\(formatQuantity(gapValue)) \(need.unit.label)"
    }

    // MARK: - Private helpers

    /// Handles: "2", "0.5", "1/2", "1 1/2", "2-3" (takes lower bound of range)
    private static func parseNumber(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }

        if let d = Double(t) { return d }

        // Range "2-3" — take lower bound
        if let dashRange = t.range(of: "-"),
           let lo = Double(t[t.startIndex..<dashRange.lowerBound]) {
            return lo
        }

        // Mixed number "1 1/2"
        let parts = t.components(separatedBy: " ")
        if parts.count == 2,
           let whole = Double(parts[0]),
           let frac = parseFraction(parts[1]) {
            return whole + frac
        }

        return parseFraction(t)
    }

    private static func parseFraction(_ s: String) -> Double? {
        let parts = s.components(separatedBy: "/")
        guard parts.count == 2,
              let n = Double(parts[0]),
              let d = Double(parts[1]),
              d != 0 else { return nil }
        return n / d
    }

    /// Drops `suffix` from `text` and returns the remainder only if it looks numeric.
    private static func numericPrefix(of text: String, dropping suffix: String) -> String? {
        guard text.hasSuffix(suffix) else { return nil }
        let remainder = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
        guard !remainder.isEmpty,
              remainder.allSatisfy({ $0.isNumber || $0 == "." || $0 == "/" || $0 == " " || $0 == "-" })
        else { return nil }
        return remainder
    }
}
