import SwiftUI

struct IngredientChip: View {
    let title: String
    var selected = false
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .appTextStyle(.bodySM)
                .foregroundStyle(selected ? Color.white : DS.ColorToken.textPrimary)
                .frame(minHeight: 32)
                .padding(.horizontal, DS.Spacing.space3)
                .padding(.vertical, DS.Spacing.space2)
                .background(selected ? DS.ColorToken.primary : DS.ColorToken.bgSecondary)
                .overlay(
                    Capsule()
                        .stroke(selected ? DS.ColorToken.primary : DS.ColorToken.borderDefault, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
