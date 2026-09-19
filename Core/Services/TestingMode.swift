import Foundation

/// Single on/off switch for using local mock services instead of live ones — no network calls to
/// our Supabase edge functions (`generate-recipes`, `scan-food-photo`, `resolve-ingredient-cost`)
/// or to OpenFoodFacts. Flip `isEnabled` back to `false` to return to live data; nothing else
/// needs to change.
enum TestingMode {
    static let isEnabled = false
}
