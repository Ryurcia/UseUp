import SwiftUI
import PhosphorSwift

/// Pushed from the Pantry dashboard's "Show Expired" button. Unlike `LocationDetailView`, this
/// isn't scoped to one location — it's every expired ingredient across Pantry/Fridge/Freezer,
/// oldest-expired-first, with a bulk "Bin All" action alongside the usual per-row swipe actions.
struct ExpiredItemsView: View {
    @EnvironmentObject private var pantryStore: PantryStore
    @EnvironmentObject private var activityStore: UserActivityStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIngredient: Ingredient?
    @State private var ingredientBeingEdited: Ingredient?
    @State private var ingredientBeingUsed: Ingredient?
    @State private var showingBinAllConfirmation = false

    private var expiredItems: [Ingredient] {
        pantryStore.ingredients
            .filter { $0.isExpired }
            .sorted { ($0.daysUntilExpiration ?? Int.max) < ($1.daysUntilExpiration ?? Int.max) }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if expiredItems.isEmpty {
                Spacer()
            } else {
                List {
                    ForEach(expiredItems) { item in
                        row(item)
                    }
                }
                .listStyle(.plain)
                .listRowSpacing(Sourdough.Spacing.insideChip)
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)

                binAllButton
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.bottom, 120) // clears the floating bottom tab bar
            }
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .background(SwipeBackEnabler())
        .onChange(of: expiredItems.isEmpty) { _, isEmpty in
            if isEmpty { dismiss() }
        }
        .alert("Bin all \(expiredItems.count) expired items?", isPresented: $showingBinAllConfirmation) {
            Button("Bin All", role: .destructive) { binAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .sheet(item: $selectedIngredient) { ingredient in
            IngredientDetailSheet(
                item: ingredient,
                onUse: {
                    selectedIngredient = nil
                    ingredientBeingUsed = ingredient
                },
                onEdit: {
                    selectedIngredient = nil
                    ingredientBeingEdited = ingredient
                },
                onQuickGenerate: { selectedIngredient = nil }
            )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $ingredientBeingUsed) { ingredient in
            UseIngredientSheet(ingredient: ingredient) { newAmount in
                withAnimation { pantryStore.useIngredient(id: ingredient.id, newAmount: newAmount) }
                if newAmount == nil { activityStore.logEvent(type: .itemSaved) }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $ingredientBeingEdited) { ingredient in
            EditIngredientSheet(ingredient: ingredient) { name, amount, unitCount, quantityEstimate, quantitySource, category, location, expirationDate, icon in
                withAnimation {
                    pantryStore.updateIngredient(
                        id: ingredient.id, name: name, amount: amount, unitCount: unitCount,
                        quantityEstimate: quantityEstimate, quantitySource: quantitySource,
                        category: category, location: location, expirationDate: expirationDate, icon: icon,
                        estimatedTotalCost: ingredient.estimatedTotalCost
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ item: Ingredient) -> some View {
        ExpandableIngredientRow(
            item: item,
            onSelect: { selectedIngredient = item },
            onBin: {
                activityStore.logEvent(type: .itemWasted)
                withAnimation { pantryStore.deleteIngredient(id: item.id) }
            },
            onUse: {
                withAnimation { pantryStore.useIngredient(id: item.id, newAmount: nil) }
                activityStore.logEvent(type: .itemSaved)
            }
        )
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func binAll() {
        for item in expiredItems {
            activityStore.logEvent(type: .itemWasted)
            pantryStore.deleteIngredient(id: item.id)
        }
    }

    private var binAllButton: some View {
        Button {
            showingBinAllConfirmation = true
        } label: {
            Text("Bin All (\(expiredItems.count))")
                .foregroundStyle(Sourdough.Colors.onAction)
                .sourdoughTextStyle(.rowTitle)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Sourdough.Colors.destructive)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var topBar: some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            Button { dismiss() } label: {
                Ph.caretLeft.regular
                    .frame(width: 17, height: 17)
                    .foregroundStyle(Sourdough.Colors.ink)
            }
            .buttonStyle(.plain)

            Text("Expired")
                .foregroundStyle(Sourdough.Colors.ink)
                .font(.custom("Figtree", size: 22))
                .fontWeight(.semibold)

            Spacer()
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.iconToLabel)
        .padding(.bottom, Sourdough.Spacing.rowInternals)
    }
}
