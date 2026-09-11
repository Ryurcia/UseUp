import UIKit

/// A single queued item in a Photo Scan capture session — client-side only, never persisted as
/// its own table. `id` doubles as the `ingredients.id` sent on batch insert (see
/// `PantryStore.addIngredients`), so temp rows can be matched to server rows without relying on
/// insert order.
struct BatchScanItem: Identifiable {
    enum Status: Equatable {
        case processing
        case identified
        case needsReview
        case failed(String)
    }

    let id: UUID
    /// Groups every item produced by one shutter tap, so "undo last capture" can remove all of
    /// them together (one photo can fan out into multiple items).
    let captureToken: UUID
    var thumbnail: UIImage?
    var name: String
    var icon: String?
    var category: Ingredient.Category
    var quantityEstimate: Ingredient.QuantityEstimate
    /// Raw Gemini "estimated_quantity" string, shown/editable but not parsed into an exact amount
    /// automatically — matches how OFF's `quantity` string is handled in the existing barcode flow.
    var amountText: String?
    /// How many of `amountText`'s unit size the user has (e.g. 5 cans of "227 g" each). Neither
    /// Open Food Facts nor Gemini ever report this — only a per-unit size — so it's always
    /// user-entered in review, defaulting to 1.
    var unitCount: Int
    var storageLocation: Ingredient.StorageLocation
    var expirationDate: Date?
    var confidence: Double
    var suggestBarcodeRescan: Bool
    /// The scanned barcode, if this item came from the barcode flow — enables the Open Prices
    /// tier of cost resolution. nil for photo-scan and manual items.
    var barcode: String?
    /// Resolved cost estimate, filled in async by `BatchScanReviewView`. nil while pending or on
    /// failure (the chip shows a muted placeholder, never an error).
    var cost: IngredientCost?
    /// Set once the user corrects the cost chip — that number is theirs, don't re-resolve it, and
    /// upsert it to `ingredient_price_history` on save.
    var costConfirmed: Bool
    var status: Status
    /// Set once the user has acknowledged this item's warning (via "Keep", the storage fix, or
    /// tapping the date strip to confirm it) — lets `isFlagged` stop surfacing it without
    /// changing the underlying signal `needsAttention` is computed from.
    var warningDismissed: Bool = false

    init(
        id: UUID = UUID(),
        captureToken: UUID,
        thumbnail: UIImage? = nil,
        name: String,
        icon: String? = nil,
        category: Ingredient.Category = .other,
        quantityEstimate: Ingredient.QuantityEstimate = .some,
        amountText: String? = nil,
        unitCount: Int = 1,
        storageLocation: Ingredient.StorageLocation,
        expirationDate: Date? = nil,
        confidence: Double = 1,
        suggestBarcodeRescan: Bool = false,
        barcode: String? = nil,
        cost: IngredientCost? = nil,
        costConfirmed: Bool = false,
        status: Status = .processing,
        warningDismissed: Bool = false
    ) {
        self.id = id
        self.captureToken = captureToken
        self.thumbnail = thumbnail
        self.name = name
        self.icon = icon
        self.category = category
        self.quantityEstimate = quantityEstimate
        self.amountText = amountText
        self.unitCount = unitCount
        self.storageLocation = storageLocation
        self.expirationDate = expirationDate
        self.confidence = confidence
        self.suggestBarcodeRescan = suggestBarcodeRescan
        self.barcode = barcode
        self.cost = cost
        self.costConfirmed = costConfirmed
        self.status = status
        self.warningDismissed = warningDismissed
    }

    var needsAttention: Bool {
        if case .needsReview = status { return true }
        if case .failed = status { return true }
        return confidence < 0.6
    }

    var daysUntilExpiration: Int? {
        guard let expirationDate else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: expirationDate)
        return Calendar.current.dateComponents([.day], from: start, to: end).day
    }

    var freshnessState: Sourdough.FreshnessState {
        guard let days = daysUntilExpiration else { return .fresh }
        return Sourdough.FreshnessState(daysUntilExpiration: days)
    }

    /// Freezer storage is always a deliberate choice (Gemini's `likely_frozen` signal or an
    /// explicit session default) — never flagged, regardless of category.
    var hasStorageMismatch: Bool {
        storageLocation != .freezer && storageLocation != IngredientDefaults.defaultStorage(for: category)
    }

    /// Drives sorting, the review banner/counter, the card border, and the warning strip.
    /// `needsAttention` stays the raw, undismissable signal; this adds storage mismatch and
    /// honors `warningDismissed`.
    var isFlagged: Bool {
        (needsAttention || hasStorageMismatch) && !warningDismissed
    }

    /// `(quantity, unit)` describing one unit's size, for cost resolution — parsed from
    /// `amountText`, falling back to a single whole item when it isn't parseable (`"1 carton"`,
    /// empty, etc.). `unitCount` is passed separately.
    var costQuantityUnit: (quantity: Double, unit: String) {
        if let amountText,
           let parsed = QuantityConverter.parse(amountText),
           parsed.unit != .unknown, parsed.unit != .piece {
            return (parsed.value, parsed.unit.label)
        }
        return (1, "whole")
    }
}

// MARK: - Merging Gemini results into a BatchScanItem

extension BatchScanItem {
    /// Resolves the item's storage location: `likely_frozen` always wins (freezer), otherwise the
    /// session-level toggle wins.
    static func resolvedStorage(sessionDefault: Ingredient.StorageLocation, likelyFrozen: Bool) -> Ingredient.StorageLocation {
        likelyFrozen ? .freezer : sessionDefault
    }

    /// Translates Gemini's coarse category vocabulary into `Ingredient.Category`. Direct mapping
    /// first; for the four values with no clean match, refines via the same name-keyword fallback
    /// already used for barcode-scanned items (`OpenFoodFactsService.mapCategory(fromName:)`) so
    /// both paths land on consistent categories, falling back to a reasonable default otherwise.
    static func resolvedCategory(geminiCategory: ScannedFoodItem.Category, name: String) -> Ingredient.Category {
        switch geminiCategory {
        case .produce: return OpenFoodFactsService.mapCategory(fromName: name) ?? .produce
        case .dairy: return .dairy
        case .meat: return .proteins
        case .seafood: return .seafood
        case .condiment: return .condiments
        case .other: return .other
        case .frozen: return OpenFoodFactsService.mapCategory(fromName: name) ?? .other
        case .pantry: return OpenFoodFactsService.mapCategory(fromName: name) ?? .carbs
        case .bakery: return OpenFoodFactsService.mapCategory(fromName: name) ?? .carbs
        case .beverage: return OpenFoodFactsService.mapCategory(fromName: name) ?? .other
        }
    }

    /// The vision model saw the actual item — its ripeness, packaging, condition — so its per-item
    /// `estimatedShelfLifeDays` beats the flat category default for fridge/pantry storage. Freezer
    /// is a deliberate long-term choice the model didn't estimate for, so fall back to the category
    /// default there. The range check guards against a hallucinated / zero / absurd value.
    static func resolvedShelfLifeDays(scanned item: ScannedFoodItem, category: Ingredient.Category, resolvedStorage: Ingredient.StorageLocation) -> Int {
        if resolvedStorage != .freezer, (1...365).contains(item.estimatedShelfLifeDays) {
            return item.estimatedShelfLifeDays
        }
        return category.defaultShelfLifeDays(in: resolvedStorage)
    }

    init(scanned item: ScannedFoodItem, captureToken: UUID, thumbnail: UIImage?, sessionStorageDefault: Ingredient.StorageLocation) {
        let category = Self.resolvedCategory(geminiCategory: item.category, name: item.name)
        let storage = Self.resolvedStorage(sessionDefault: sessionStorageDefault, likelyFrozen: item.likelyFrozen)
        let shelfLifeDays = Self.resolvedShelfLifeDays(scanned: item, category: category, resolvedStorage: storage)
        self.init(
            captureToken: captureToken,
            thumbnail: thumbnail,
            name: item.name,
            icon: IngredientDefaults.icon(forName: item.name),
            category: category,
            quantityEstimate: .some,
            amountText: item.estimatedQuantity,
            storageLocation: storage,
            expirationDate: Calendar.current.date(byAdding: .day, value: shelfLifeDays, to: Date()),
            confidence: item.confidence,
            suggestBarcodeRescan: item.suggestBarcodeScan,
            status: item.suggestBarcodeScan ? .needsReview : .identified
        )
    }

    init(offProduct product: OpenFoodFactsService.ProductInfo, captureToken: UUID, thumbnail: UIImage?, sessionStorageDefault: Ingredient.StorageLocation) {
        let category = product.category ?? .other
        self.init(
            captureToken: captureToken,
            thumbnail: thumbnail,
            name: product.name,
            icon: IngredientDefaults.icon(forName: product.name),
            category: category,
            quantityEstimate: .some,
            amountText: product.quantity,
            storageLocation: sessionStorageDefault,
            expirationDate: Calendar.current.date(byAdding: .day, value: category.defaultShelfLifeDays(in: sessionStorageDefault), to: Date()),
            confidence: 1,
            suggestBarcodeRescan: false,
            barcode: product.barcode,
            status: .identified
        )
    }
}
