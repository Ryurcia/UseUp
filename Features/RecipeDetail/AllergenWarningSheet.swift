import SwiftUI
import PhosphorSwift

// MARK: - Detection

func detectAllergens(
    in recipe: Recipe,
    userAllergies: Set<AllergyType>,
    customAllergy: String
) -> [String] {
    let names = (recipe.ingredientsUsed + recipe.missingIngredients)
        .map { $0.name.lowercased() }
    var found: [String] = []

    for allergy in userAllergies.sorted(by: { $0.rawValue < $1.rawValue }) {
        let hit = allergy.ingredientKeywords.contains { kw in
            names.contains { $0.contains(kw) }
        }
        if hit { found.append(allergy.rawValue) }
    }

    let customTerms = customAllergy
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        .filter { !$0.isEmpty }
    for term in customTerms where names.contains(where: { $0.contains(term) }) {
        found.append(term.capitalized)
    }

    return found
}

// MARK: - Sheet

struct AllergenWarningSheet: View {
    let recipeName: String
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sheetHeight: CGFloat = 400

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(DS.ColorToken.borderDefault)
                .frame(width: 36, height: 4)
                .padding(.top, DS.Spacing.space3)
                .padding(.bottom, DS.Spacing.space5)

            Ph.warning.fill
                .frame(width: 40, height: 40)
                .foregroundStyle(DS.ColorToken.warning)
                .padding(.bottom, DS.Spacing.space4)

            Text("Allergen Warning")
                .font(.custom("CalSans-Regular", size: 24))
                .foregroundStyle(DS.ColorToken.textPrimary)
                .padding(.bottom, DS.Spacing.space2)

            Text("\"\(recipeName)\" may contain ingredients you're allergic to.")
                .font(.custom("Satoshi Variable", size: 15))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.space6)
                .padding(.bottom, DS.Spacing.space6)

            VStack(spacing: DS.Spacing.space3) {
                Button("View Recipe Anyway") {
                    dismiss()
                    onContinue()
                }
                .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                .padding(.horizontal, DS.Spacing.space5)

                Button("Go Back") {
                    dismiss()
                }
                .font(.custom("Satoshi Variable", size: 15).weight(.medium))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(height: 44)
            }
            .padding(.bottom, DS.Spacing.space5)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(DS.ColorToken.bgPrimary)
        .background {
            GeometryReader { geo in
                Color.clear.onAppear { sheetHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, newValue in sheetHeight = newValue }
            }
        }
        .presentationDetents([.height(sheetHeight)])
        .presentationBackground(DS.ColorToken.bgPrimary)
    }
}

