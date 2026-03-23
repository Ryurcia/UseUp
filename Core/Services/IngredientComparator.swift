import Foundation

enum IngredientSufficiency {
    case enough
    case partial(have: String, need: String)
    case unknownAmount
    case notInPantry
}

enum IngredientComparator {
    static func compare(recipeQuantity: String, pantryAmount: String?) -> IngredientSufficiency {
        guard let recipeParsed = QuantityParser.parse(recipeQuantity) else {
            return .unknownAmount
        }

        guard let pantryParsed = QuantityParser.parse(pantryAmount) else {
            return .unknownAmount
        }

        switch (recipeParsed.unit, pantryParsed.unit) {
        case let (.mass(recipeUnit), .mass(pantryUnit)):
            return compareMeasurements(
                have: Measurement(value: pantryParsed.value, unit: pantryUnit),
                need: Measurement(value: recipeParsed.value, unit: recipeUnit),
                displayUnit: recipeUnit
            )

        case let (.volume(recipeUnit), .volume(pantryUnit)):
            return compareMeasurements(
                have: Measurement(value: pantryParsed.value, unit: pantryUnit),
                need: Measurement(value: recipeParsed.value, unit: recipeUnit),
                displayUnit: recipeUnit
            )

        case (.count, .count):
            if pantryParsed.value >= recipeParsed.value {
                return .enough
            }
            return .partial(
                have: formatCount(pantryParsed.value),
                need: formatCount(recipeParsed.value)
            )

        // Bare number (count) vs typed unit — assume the bare number uses the same unit
        case let (.mass(recipeUnit), .count):
            return compareMeasurements(
                have: Measurement(value: pantryParsed.value, unit: recipeUnit),
                need: Measurement(value: recipeParsed.value, unit: recipeUnit),
                displayUnit: recipeUnit
            )
        case let (.count, .mass(pantryUnit)):
            return compareMeasurements(
                have: Measurement(value: pantryParsed.value, unit: pantryUnit),
                need: Measurement(value: recipeParsed.value, unit: pantryUnit),
                displayUnit: pantryUnit
            )
        case let (.volume(recipeUnit), .count):
            return compareMeasurements(
                have: Measurement(value: pantryParsed.value, unit: recipeUnit),
                need: Measurement(value: recipeParsed.value, unit: recipeUnit),
                displayUnit: recipeUnit
            )
        case let (.count, .volume(pantryUnit)):
            return compareMeasurements(
                have: Measurement(value: pantryParsed.value, unit: pantryUnit),
                need: Measurement(value: recipeParsed.value, unit: pantryUnit),
                displayUnit: pantryUnit
            )

        default:
            // Mass vs volume or other mismatch — can't compare
            return .unknownAmount
        }
    }

    // MARK: - Private

    private static func compareMeasurements<U: Dimension>(
        have: Measurement<U>,
        need: Measurement<U>,
        displayUnit: U
    ) -> IngredientSufficiency {
        let haveConverted = have.converted(to: displayUnit)
        let needConverted = need.converted(to: displayUnit)

        if haveConverted.value >= needConverted.value {
            return .enough
        }

        return .partial(
            have: formatMeasurement(haveConverted),
            need: formatMeasurement(needConverted)
        )
    }

    private static func formatMeasurement<U: Dimension>(_ measurement: Measurement<U>) -> String {
        let value = measurement.value
        let formatted = formatNumber(value)
        let symbol = measurement.unit.symbol
        return "\(formatted)\(symbol)"
    }

    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && value < 10000 {
            return String(Int(value))
        }
        // Round to 1 decimal place
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }

    private static func formatCount(_ value: Double) -> String {
        formatNumber(value)
    }
}
