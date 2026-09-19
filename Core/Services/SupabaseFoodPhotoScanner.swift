import Foundation
import Supabase

enum FoodPhotoScanError: LocalizedError {
    case apiError(String)
    case parsingError
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .apiError(let message): return "Photo scan failed: \(message)"
        case .parsingError: return "Could not read the scan result. Please try again."
        case .emptyResponse: return "No items were found in that photo."
        }
    }
}

protocol FoodPhotoIdentifying {
    /// `imageData` is a compressed JPEG. Returns every distinct food item found in the photo —
    /// zero, one, or several (a grocery haul photo isn't always a single item).
    func identifyItems(in imageData: Data) async throws -> [ScannedFoodItem]
}

final class MockFoodPhotoScanner: FoodPhotoIdentifying {
    func identifyItems(in imageData: Data) async throws -> [ScannedFoodItem] {
        try? await Task.sleep(for: .seconds(1))
        return [
            ScannedFoodItem(
                name: "chicken breast", category: .meat, estimatedQuantity: "1.2 lb",
                isPackaged: true, suggestBarcodeScan: false, likelyFrozen: false,
                suggestedStorage: "fridge", confidence: 0.93, estimatedShelfLifeDays: 2
            ),
            ScannedFoodItem(
                name: "broccoli", category: .produce, estimatedQuantity: "2 heads",
                isPackaged: false, suggestBarcodeScan: false, likelyFrozen: false,
                suggestedStorage: "fridge", confidence: 0.88, estimatedShelfLifeDays: 5
            ),
            ScannedFoodItem(
                name: "whole milk", category: .dairy, estimatedQuantity: "1 gal",
                isPackaged: true, suggestBarcodeScan: true, likelyFrozen: false,
                suggestedStorage: "fridge", confidence: 0.95, estimatedShelfLifeDays: 7
            ),
            ScannedFoodItem(
                name: "mystery leftovers", category: .other, estimatedQuantity: "1 container",
                isPackaged: false, suggestBarcodeScan: false, likelyFrozen: false,
                suggestedStorage: "fridge", confidence: 0.42, estimatedShelfLifeDays: 3
            ),
        ]
    }
}

/// Calls the `scan-food-photo` Supabase edge function, which holds the Gemini API key, runs the
/// two-tier (lite → standard) identification, and records scan telemetry server-side. The app only
/// uploads a compressed JPEG.
final class SupabaseFoodPhotoScanner: FoodPhotoIdentifying {
    private let client = SupabaseManager.client

    private struct ScanRequest: Encodable {
        let image: String
    }

    private struct ScanResponse: Decodable {
        let items: [ScannedFoodItem]
    }

    func identifyItems(in imageData: Data) async throws -> [ScannedFoodItem] {
        let body = ScanRequest(image: imageData.base64EncodedString())

        do {
            let response: ScanResponse = try await client.functions.invoke(
                "scan-food-photo",
                options: FunctionInvokeOptions(body: body)
            )
            return response.items
        } catch let FunctionsError.httpError(code, data) {
            let detail = String(data: data, encoding: .utf8) ?? "status \(code)"
            throw FoodPhotoScanError.apiError(detail)
        } catch is DecodingError {
            throw FoodPhotoScanError.parsingError
        }
    }
}
