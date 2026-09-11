import Foundation

/// One item identified in a captured photo by the `scan-food-photo` edge function. Matches the
/// JSON schema the function sends to Gemini as `responseSchema` (see
/// `supabase/functions/scan-food-photo/prompt.ts`).
struct ScannedFoodItem: Decodable {
    enum Category: String, Decodable {
        case produce, dairy, meat, seafood, frozen, pantry, bakery, beverage, condiment, other
    }

    let name: String
    let category: Category
    let estimatedQuantity: String
    let isPackaged: Bool
    let suggestBarcodeScan: Bool
    let likelyFrozen: Bool
    /// The model's storage guess. Advisory only — actual storage is the scan session's pill
    /// (or `.freezer` when `likelyFrozen`). Still worth having the model reason about it, since it
    /// informs `estimatedShelfLifeDays`.
    let suggestedStorage: String
    let confidence: Double
    /// Typical days from today until this specific item spoils, assuming it's stored the way
    /// `suggestedStorage` suggests — see `BatchScanItem.init(scanned:...)` for how this gets
    /// reconciled against the actually-resolved storage location before use.
    let estimatedShelfLifeDays: Int

    enum CodingKeys: String, CodingKey {
        case name, category
        case estimatedQuantity = "estimated_quantity"
        case isPackaged = "is_packaged"
        case suggestBarcodeScan = "suggest_barcode_scan"
        case likelyFrozen = "likely_frozen"
        case suggestedStorage = "suggested_storage"
        case confidence
        case estimatedShelfLifeDays = "estimated_shelf_life_days"
    }
}
