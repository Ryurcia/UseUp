import SwiftUI
import PhosphorSwift

/// Editable per-unit cost row shown under each scan-review card and in the edit sheet. A static
/// "Est Price per unit" caption sits on the left; the value pill on the right reads `$X.XX` with a
/// pencil, tap to swap in an inline decimal field (no modal, matching how the date strip and
/// category chip stay inline). A crowdsourced (`openfoodfacts`) price gets a subtler tag so users
/// read it as a real price, not a guess.
struct IngredientCostChip: View {
    let cost: IngredientCost?
    /// Called with the user's corrected **per-unit** price.
    let onConfirm: (Double) -> Void

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    private var unitPrice: Double? { cost?.unitPriceUsd }

    private var isCrowdsourced: Bool { cost?.source == .openfoodfacts }

    private var tint: Color {
        isCrowdsourced ? Sourdough.Ramp.honey700 : Sourdough.Ramp.sage600
    }

    var body: some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            Text("Est Price per unit")
                .sourdoughTextStyle(.caption, color: Sourdough.Colors.mutedInk)

            Spacer()

            Group {
                if isEditing {
                    editingField
                } else {
                    chip
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .frame(height: 34)
            .background(Sourdough.Colors.sunken)
            .overlay(
                Capsule().stroke(unitPrice == nil ? Color.clear : tint.opacity(0.35), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
    }

    private var chip: some View {
        Button {
            guard let unitPrice else { return }
            draft = String(format: "%.2f", unitPrice)
            isEditing = true
            fieldFocused = true
        } label: {
            HStack(spacing: 6) {
                if isCrowdsourced {
                    Ph.tag.fill.frame(width: 12, height: 12)
                }
                Text(label)
                if unitPrice != nil {
                    Ph.pencil.fill.frame(width: 12, height: 12)
                }
            }
            .foregroundStyle(unitPrice == nil ? Sourdough.Colors.faintInk : tint)
        }
        .buttonStyle(.plain)
        .disabled(unitPrice == nil)
    }

    private var label: String {
        guard let unitPrice else { return cost == nil ? "Est. …" : "No price" }
        return "$\(String(format: "%.2f", unitPrice))"
    }

    private var editingField: some View {
        HStack(spacing: 3) {
            Text("$").foregroundStyle(tint)
            TextField("0.00", text: $draft)
                .keyboardType(.decimalPad)
                .focused($fieldFocused)
                .foregroundStyle(Sourdough.Colors.ink)
                .frame(width: 56)
                .onSubmit(commit)
            Button(action: commit) {
                Ph.check.bold.frame(width: 13, height: 13).foregroundStyle(tint)
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
