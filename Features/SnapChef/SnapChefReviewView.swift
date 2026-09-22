import SwiftUI
import PhosphorSwift

/// One identified ingredient in the Snap Chef confirm step. Ephemeral — never written to the pantry.
struct SnapChefIngredient: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var amount: String = ""
    var unit: UnitMeasurement = .none
    var lowConfidence: Bool = false
}

/// Name-only review of what the photo picked up. Edit inline, add a missed item, remove a wrong
/// one, then confirm to generate recipes. Deliberately has no price / storage / date fields
/// (that's the pantry flow).
struct SnapChefReviewView: View {
    @Binding var ingredients: [SnapChefIngredient]
    let onConfirm: () -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void

    @FocusState private var focusedID: UUID?
    @State private var showMedicationAlert = false

    private var hasUsableIngredient: Bool {
        ingredients.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: Sourdough.Spacing.insideChip) {
                    if ingredients.isEmpty {
                        emptyState
                    } else {
                        ForEach($ingredients) { $item in
                            row($item)
                        }
                    }
                    addButton
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.underTitle)
            }
        }
        .background(Sourdough.Colors.canvas)
        .safeAreaInset(edge: .bottom) { footer }
        .alert("Medication Detected", isPresented: $showMedicationAlert) {
            Button("OK") { ingredients.removeAll { MedicationDetector.isMedication($0.name) } }
        } message: {
            Text("UseUp only tracks food. This item will be removed.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: Sourdough.Spacing.rowInternals) {
            VStack(alignment: .leading, spacing: Sourdough.Spacing.iconToLabel) {
                Text("Confirm ingredients")
                    .sourdoughTextStyle(.title2, color: Sourdough.Colors.ink)
                Text("Fix anything we misread — we'll build recipes from this list.")
                    .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { onCancel() } label: {
                Ph.x.bold
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .frame(width: 30, height: 30)
                    .background(Sourdough.Colors.sunken)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.insideChip)
        .padding(.bottom, Sourdough.Spacing.rowInternals)
    }

    // MARK: Rows

    private func row(_ item: Binding<SnapChefIngredient>) -> some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            HStack(spacing: Sourdough.Spacing.rowInternals) {
                TextField("Ingredient", text: item.name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .sourdoughTextStyle(.body, color: Sourdough.Colors.ink)
                    .focused($focusedID, equals: item.wrappedValue.id)
                    .submitLabel(.done)

                Button {
                    ingredients.removeAll { $0.id == item.wrappedValue.id }
                } label: {
                    Ph.trash.regular
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                }
                .buttonStyle(.plain)
            }

            if item.wrappedValue.lowConfidence {
                HStack(spacing: Sourdough.Spacing.iconToLabel) {
                    Ph.warning.regular
                        .frame(width: 11, height: 11)
                        .foregroundStyle(Sourdough.Ramp.honey700)
                    Text("Double-check this one")
                        .sourdoughTextStyle(.caption, color: Sourdough.Ramp.honey700)
                }
                .padding(.horizontal, Sourdough.Spacing.insideChip)
                .frame(height: 22)
                .background(Sourdough.Ramp.honey100)
                .clipShape(Capsule())
            }
        }
        .padding(Sourdough.Spacing.rowInternals)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
    }

    private var addButton: some View {
        Button {
            let new = SnapChefIngredient(name: "")
            ingredients.append(new)
            focusedID = new.id
        } label: {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                Ph.plus.bold.frame(width: 14, height: 14)
                Text("Add an ingredient")
            }
            .foregroundStyle(Sourdough.Colors.action)
            .sourdoughTextStyle(.subhead)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                    .stroke(Sourdough.Colors.action, style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
        }
        .buttonStyle(.plain)
        .padding(.top, Sourdough.Spacing.iconToLabel)
    }

    private var emptyState: some View {
        VStack(spacing: Sourdough.Spacing.insideChip) {
            Ph.camera.regular
                .frame(width: 28, height: 28)
                .foregroundStyle(Sourdough.Colors.faintInk)
            Text("We couldn't read any ingredients")
                .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.ink)
            Text("Add them below, or retake the photo.")
                .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Sourdough.Spacing.betweenBlocks)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: Sourdough.Spacing.insideChip) {
            Button {
                if ingredients.contains(where: { MedicationDetector.isMedication($0.name) }) {
                    showMedicationAlert = true
                } else {
                    onConfirm()
                }
            } label: {
                Text("Get my recipes")
                    .foregroundStyle(Sourdough.Colors.onAction)
                    .sourdoughTextStyle(.rowTitle)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Sourdough.Colors.action)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!hasUsableIngredient)
            .opacity(hasUsableIngredient ? 1 : 0.5)

            Button { onRetake() } label: {
                Text("Retake photo")
                    .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.rowInternals)
        .padding(.bottom, Sourdough.Spacing.insideChip)
        .background(
            Sourdough.Colors.card
                .overlay(alignment: .top) { Rectangle().fill(Sourdough.Colors.hairline).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
