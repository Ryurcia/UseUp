import Foundation
import Supabase

/// The resolved cost of a single logged ingredient. `source` records which cascade tier supplied
/// the base price (`personal` history, `openfoodfacts` crowdsourced price, or a pure `estimate`).
struct IngredientCost: Equatable {
    var unitPriceUsd: Double?
    var totalPriceUsd: Double?
    var source: Source
    var conversionApplied: Bool
    var confidence: Double

    enum Source: String, Decodable, Equatable {
        case personal
        case openfoodfacts
        case estimate
    }
}

enum IngredientCostError: LocalizedError {
    case apiError(String)
    case parsingError

    var errorDescription: String? {
        switch self {
        case .apiError(let message): return "Cost estimate failed: \(message)"
        case .parsingError: return "Could not read the cost estimate."
        }
    }
}

protocol IngredientCostEstimating {
    /// Resolves the cost of one logged item. `quantity`/`unit` describe one unit's size (e.g.
    /// 1 lb, 3 whole); `unitCount` is how many of that the user has. `barcode` enables the Open
    /// Prices tier — pass nil for photo-scan / manual items.
    func resolveCost(
        ingredientName: String,
        quantity: Double,
        unit: String,
        unitCount: Int,
        barcode: String?
    ) async throws -> IngredientCost
}

final class MockIngredientCostEstimator: IngredientCostEstimating {
    func resolveCost(
        ingredientName: String,
        quantity: Double,
        unit: String,
        unitCount: Int,
        barcode: String?
    ) async throws -> IngredientCost {
        IngredientCost(
            unitPriceUsd: 1.25,
            totalPriceUsd: 1.25 * quantity * Double(unitCount),
            source: .estimate,
            conversionApplied: false,
            confidence: 0.5
        )
    }
}

/// Calls the `resolve-ingredient-cost` Supabase edge function, which owns the price cascade
/// (confirmed personal history → Open Prices for a barcode → Gemini) and the Gemini API key.
final class SupabaseIngredientCostEstimator: IngredientCostEstimating {
    private let client = SupabaseManager.client

    private struct Request: Encodable {
        let ingredientName: String
        let quantity: Double
        let unit: String
        let unitCount: Int
        let barcode: String?
    }

    private struct Response: Decodable {
        let unitPriceUsd: Double?
        let totalPriceUsd: Double?
        let source: IngredientCost.Source
        let conversionApplied: Bool
        let confidence: Double
    }

    func resolveCost(
        ingredientName: String,
        quantity: Double,
        unit: String,
        unitCount: Int,
        barcode: String?
    ) async throws -> IngredientCost {
        let body = Request(
            ingredientName: ingredientName,
            quantity: quantity,
            unit: unit,
            unitCount: unitCount,
            barcode: barcode
        )

        do {
            let response: Response = try await client.functions.invoke(
                "resolve-ingredient-cost",
                options: FunctionInvokeOptions(body: body)
            )
            return IngredientCost(
                unitPriceUsd: response.unitPriceUsd,
                totalPriceUsd: response.totalPriceUsd,
                source: response.source,
                conversionApplied: response.conversionApplied,
                confidence: response.confidence
            )
        } catch let FunctionsError.httpError(code, data) {
            let detail = String(data: data, encoding: .utf8) ?? "status \(code)"
            throw IngredientCostError.apiError(detail)
        } catch is DecodingError {
            throw IngredientCostError.parsingError
        }
    }
}
