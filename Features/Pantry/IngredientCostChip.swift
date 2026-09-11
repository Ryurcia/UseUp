import SwiftUI
import PhosphorSwift

/// Compact editable cost chip shown on scan-review cards and the edit sheet. Default state reads
/// `Est. $X.XX` with a pencil; tap to swap in an inline decimal field (no modal, matching how the
/// date strip and category chip stay inline). A crowdsourced (`openfoodfacts`) price gets a
/// subtler tag so users read it as a real price, not a guess.
struct IngredientCostChip: View {
    let cost: IngredientCost?
    /// Called with the user's corrected **total** price. The caller back-calculates the unit price.
    let onConfirm: (Double) -> Void

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    private var total: Double? { cost?.totalPriceUsd }

    private var isCrowdsourced: Bool { cost?.source == .openfoodfacts }

    private var tint: Color {
        isCrowdsourced ? Sourdough.Ramp.honey700 : Sourdough.Ramp.sage600
    }

    var body: some View {
        Group {
            if isEditing {
                editingField
            } else {
                chip
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, Sourdough.Spacing.insideChip)
        .frame(height: 24)
        .background(Sourdough.Colors.sunken)
        .clipShape(Capsule())
    }

    private var chip: some View {
        Button {
            guard total != nil else { return }
            draft = total.map { String(format: "%.2f", $0) } ?? ""
            isEditing = true
            fieldFocused = true
        } label: {
            HStack(spacing: 5) {
                if isCrowdsourced {
                    Ph.tag.fill.frame(width: 9, height: 9)
                }
                Text(label)
                if total != nil {
                    Ph.pencil.regular.frame(width: 9, height: 9)
                }
            }
            .foregroundStyle(total == nil ? Sourdough.Colors.faintInk : tint)
        }
        .buttonStyle(.plain)
        .disabled(total == nil)
    }

    private var label: String {
        guard let total else { return cost == nil ? "Est. …" : "No price" }
        return "Est. $\(String(format: "%.2f", total))"
    }

    private var editingField: some View {
        HStack(spacing: 2) {
            Text("$").foregroundStyle(tint)
            TextField("0.00", text: $draft)
                .keyboardType(.decimalPad)
                .focused($fieldFocused)
                .foregroundStyle(Sourdough.Colors.ink)
                .frame(width: 44)
                .onSubmit(commit)
            Button(action: commit) {
                Ph.check.bold.frame(width: 10, height: 10).foregroundStyle(tint)
            }
            .buttonStyle(.plain)
        }
        .onChange(of: fieldFocused) { _, focused in
            if !focused { commit() }
        }
    }

    private func commit() {
        defer { isEditing = false }
        let cleaned = draft.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned), value > 0 else { return }
        onConfirm((value * 100).rounded() / 100)
    }
}
