import SwiftUI
import PhosphorSwift

struct GroceryListView: View {
    @EnvironmentObject private var pantryStore: PantryStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe

    @State private var checkedItems: Set<UUID> = []
    @State private var hasSeeded = false

    private struct GroceryItem: Identifiable {
        let id: UUID
        let ingredient: RecipeIngredient
        let isInPantry: Bool
        let isSufficient: Bool?
        let shortfall: String?
    }

    private var items: [GroceryItem] {
        (recipe.ingredientsUsed + recipe.missingIngredients).map { ingredient in
            let pantryMatch = PantryMatcher.find(for: ingredient.name, in: pantryStore.ingredients)
            let sufficient = QuantityConverter.isSufficient(have: pantryMatch?.amount, need: ingredient.quantity)
            let shortfall = sufficient == false
                ? QuantityConverter.shortfallDescription(have: pantryMatch?.amount, need: ingredient.quantity)
                : nil
            return GroceryItem(id: ingredient.id, ingredient: ingredient, isInPantry: pantryMatch != nil, isSufficient: sufficient, shortfall: shortfall)
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    groceryRow(item)
                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, Sourdough.Spacing.screenMargin + 44)
                    }
                }
            }
            .padding(.vertical, Sourdough.Spacing.insideChip)
        }
        .background(Sourdough.Colors.canvas)
        .navigationTitle("Grocery List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(Sourdough.Colors.actionInk)
                    .sourdoughTextStyle(.rowTitle)
            }
        }
        .onAppear {
            guard !hasSeeded else { return }
            hasSeeded = true
            checkedItems = Set(items.filter { $0.isInPantry && $0.isSufficient != false }.map(\.id))
        }
    }

    private func groceryRow(_ item: GroceryItem) -> some View {
        let isChecked = checkedItems.contains(item.id)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isChecked { checkedItems.remove(item.id) }
                else { checkedItems.insert(item.id) }
            }
        } label: {
            HStack(spacing: Sourdough.Spacing.rowInternals) {
                ZStack {
                    Circle()
                        .fill(isChecked ? Sourdough.Ramp.sage500 : Color.clear)
                    Circle()
                        .strokeBorder(isChecked ? Sourdough.Ramp.sage500 : Sourdough.Colors.interactiveBorder, lineWidth: 2)
                    if isChecked {
                        Ph.check.regular
                            .frame(width: 11, height: 11)
                            .foregroundStyle(Sourdough.Colors.onAction)
                    }
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.ingredient.name.capitalized)
                        .foregroundStyle(isChecked ? Sourdough.Colors.faintInk : Sourdough.Colors.ink)
                        .sourdoughTextStyle(.rowTitle)
                        .strikethrough(isChecked, color: Sourdough.Colors.faintInk)

                    if let shortfall = item.shortfall {
                        Text("Need \(shortfall) more")
                            .foregroundStyle(Sourdough.Ramp.honey600)
                            .sourdoughTextStyle(.caption)
                    }
                }

                Spacer()

                let trimmedQty = item.ingredient.quantity.trimmingCharacters(in: .whitespaces)
                if !trimmedQty.isEmpty {
                    Text(trimmedQty)
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Sourdough.Colors.sunken)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.vertical, Sourdough.Spacing.rowInternals)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Grocery List") {
    PreviewContainer {
        NavigationStack {
            GroceryListView(recipe: DummyData.sampleSavedRecipes[0])
        }
    }
}
