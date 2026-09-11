import Foundation

/// A selectable priming-question option. Lets `PrimingQuestionView` work with both plain `String`
/// options (Struggle, Goal) and `PrimingChoice` options that carry a numeric value for later math
/// (Spend, GroceryBudget, Waste) without duplicating the shared question/option-list layout.
protocol PrimingOption: Equatable {
    var label: String { get }
}

extension String: PrimingOption {
    var label: String { self }
}

/// A labeled option paired with a representative numeric value (e.g. a bucket's dollar midpoint).
struct PrimingChoice: PrimingOption, Equatable {
    let label: String
    let value: Double
}
