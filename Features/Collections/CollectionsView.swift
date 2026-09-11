import SwiftUI
import PhosphorSwift

// MARK: - Collections Grid

/// Cookbook's Pinterest-style Collections tab — a full grid of every collection the user has,
/// matching CategoryRecipesView's 2-column grid pattern.
struct CollectionsSection: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @Binding var navigateToCollection: RecipeCollection?
    @Binding var collectionPendingDelete: RecipeCollection?
    var searchQuery: String = ""

    @State private var showCreateSheet = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals),
        GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals)
    ]

    private var filteredCollections: [RecipeCollection] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return savedRecipesStore.collections }
        return savedRecipesStore.collections.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if savedRecipesStore.collections.isEmpty {
                VStack(spacing: Sourdough.Spacing.rowInternals) {
                    Ph.folders.regular
                        .frame(width: 48, height: 48)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                    Text("No collections yet")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.title2)
                    Text("Create one to organize your favorite recipes.")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.subhead)
                        .multilineTextAlignment(.center)

                    Button { showCreateSheet = true } label: {
                        Text("New Collection")
                            .foregroundStyle(Sourdough.Colors.onAction)
                            .sourdoughTextStyle(.rowTitle)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Sourdough.Colors.action)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.top, Sourdough.Spacing.insideChip)
                }
                .padding(.horizontal, Sourdough.Spacing.aboveSectionHead)
                .padding(.top, Sourdough.Spacing.aboveSectionHead)
            } else if filteredCollections.isEmpty {
                VStack(spacing: Sourdough.Spacing.rowInternals) {
                    Ph.magnifyingGlass.regular
                        .frame(width: 40, height: 40)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                    Text("No results for \"\(searchQuery)\"")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.title2)
                    Text("Try a different search term.")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.subhead)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Sourdough.Spacing.aboveSectionHead)
                .padding(.top, Sourdough.Spacing.aboveSectionHead)
            } else {
                LazyVGrid(columns: gridColumns, spacing: Sourdough.Spacing.rowInternals) {
                    ForEach(filteredCollections) { collection in
                        CollectionCard(collection: collection) {
                            navigateToCollection = collection
                        }
                        .contextMenu {
                            Button(role: .destructive) { collectionPendingDelete = collection } label: {
                                Label {
                                    Text("Delete Collection")
                                } icon: {
                                    Ph.trash.regular.frame(width: 16, height: 16)
                                }
                            }
                        }
                    }

                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, 96)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            newCollectionFAB
                .padding(.trailing, Sourdough.Spacing.screenMargin)
                .padding(.bottom, 96 + Sourdough.Spacing.rowInternals)
        }
        .task {
            await savedRecipesStore.fetchCollections()
        }
        .sheet(isPresented: $showCreateSheet) {
            NewCollectionSheet()
        }
    }

    private var newCollectionFAB: some View {
        Button { showCreateSheet = true } label: {
            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                Ph.plus.bold
                    .frame(width: 16, height: 16)
                Text("New Collection")
                    .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.onAction)
            }
            .foregroundStyle(Sourdough.Colors.onAction)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .frame(height: 52)
            .background(Sourdough.Ramp.sage500)
            .clipShape(Capsule())
            .shadow(color: Sourdough.Ramp.linen900.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collection Card

private struct CollectionCard: View {
    let collection: RecipeCollection
    let onTap: () -> Void

    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @State private var coverRecipes: [Recipe] = []

    /// Rotation of light tints for photo-less tiles — no "blush" token exists in the design
    /// system, so these are the closest existing light tones rather than a new addition.
    private static let placeholderTints: [Color] = [
        Sourdough.Ramp.sage100, Sourdough.Ramp.honey100, Sourdough.Ramp.linen100, Sourdough.Ramp.terracotta100
    ]

    private var recipeCount: Int {
        savedRecipesStore.recipes(in: collection.id).count
    }

    /// Lower than the cover's old 1.5 (both to read as "slightly bigger" and because the
    /// name/count text now adds its own height below the image, rather than overlaying it).
    private static let coverAspectRatio: CGFloat = 1.3

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = width / Self.coverAspectRatio
                    coverView(width: width, height: height)
                }
                .aspectRatio(Self.coverAspectRatio, contentMode: .fit)

                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                        .sourdoughTextStyle(.title2, color: Sourdough.Colors.ink)
                        .lineLimit(1)
                    Text("\(recipeCount) recipe\(recipeCount == 1 ? "" : "s")")
                        .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
                }
                .padding(Sourdough.Spacing.rowInternals)
            }
            .background(Sourdough.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
            .shadow(color: Sourdough.Ramp.linen900.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onAppear {
            coverRecipes = savedRecipesStore.collectionCoverRecipes(for: collection.id)
        }
    }

    /// Pinterest-style: always one large tile on the left and two stacked tiles on the right —
    /// exactly 3 slots regardless of recipe count. Never a 4th tile/overflow indicator; the total
    /// count is shown as text below the cover instead (`"\(recipeCount) recipe(s)"`). `width`/
    /// `height` come from the `GeometryReader` in `body` — every tile gets an explicit, computed
    /// frame rather than a flexible one, so the card's size is fixed by the grid column alone and
    /// can't shift once a photo loads, and `CachedRecipeImage` always has an exact target to fill.
    private func coverView(width: CGFloat, height: CGFloat) -> some View {
        let gap: CGFloat = 1
        let leftWidth = (width - gap) / 2
        let rightHeight = (height - gap) / 2
        return HStack(spacing: gap) {
            tile(at: 0, width: leftWidth, height: height)
            VStack(spacing: gap) {
                tile(at: 1, width: leftWidth, height: rightHeight)
                tile(at: 2, width: leftWidth, height: rightHeight)
            }
        }
    }

    /// A slot with no recipe at all (collection has fewer than 3 recipes) renders as a plain
    /// neutral surface; a slot whose recipe exists but has no photo of its own keeps the pastel
    /// tint rotation — two different situations that happened to look the same before this split.
    @ViewBuilder
    private func tile(at index: Int, width: CGFloat, height: CGFloat) -> some View {
        if coverRecipes.indices.contains(index) {
            coverImage(coverRecipes[index], tint: Self.placeholderTints[index % Self.placeholderTints.count], width: width, height: height)
        } else {
            placeholderTile(tint: Sourdough.Colors.sunken, width: width, height: height)
        }
    }

    /// Explicit `width`/`height` all the way down to `CachedRecipeImage` itself, rather than a
    /// flexible frame propagated through the wrapping `Group` — gives `.scaledToFill()` an exact,
    /// unambiguous target so the photo genuinely covers the tile edge-to-edge.
    private func coverImage(_ recipe: Recipe, tint: Color, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if recipe.imageData == nil && recipe.imagePath == nil {
                placeholderTile(tint: tint, width: width, height: height)
            } else {
                CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath, thumbnail: true)
                    .frame(width: width, height: height)
            }
        }
        .clipped()
    }

    private func placeholderTile(tint: Color, width: CGFloat, height: CGFloat) -> some View {
        tint
            .frame(width: width, height: height)
            .overlay {
                Ph.forkKnife.regular
                    .frame(width: min(width, height) * 0.28, height: min(width, height) * 0.28)
                    .foregroundStyle(Sourdough.Colors.mutedInk.opacity(0.5))
            }
    }
}

// MARK: - New Collection Sheet

private struct NewCollectionSheet: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            Capsule()
                .fill(Sourdough.Colors.hairline)
                .frame(width: 36, height: 5)
                .padding(.top, Sourdough.Spacing.rowInternals)

            Text("New Collection")
                .sourdoughTextStyle(.title2, color: Sourdough.Colors.ink)

            TextField("Collection name", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .sourdoughTextStyle(.body, color: Sourdough.Colors.ink)
                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                .frame(height: 48)
                .background(Sourdough.Colors.sunken)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                .padding(.horizontal, Sourdough.Spacing.screenMargin)

            Button {
                createCollection()
            } label: {
                Text("Create")
                    .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.onAction)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Sourdough.Colors.action)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)

            Spacer()
        }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.hidden)
    }

    private func createCollection() {
        let trimmed = name
        isCreating = true
        Task {
            defer { isCreating = false }
            if (try? await savedRecipesStore.createCollection(name: trimmed)) != nil {
                dismiss()
            }
        }
    }
}

// MARK: - Collection Detail

struct CollectionDetailView: View {
    let collection: RecipeCollection
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore

    @State private var navigateToRecipe: Recipe?
    @State private var allergenPendingRecipe: Recipe?
    @State private var allergenWarningDetected: [String] = []

    private var recipes: [Recipe] {
        savedRecipesStore.recipes(in: collection.id)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                if recipes.isEmpty {
                    VStack(spacing: Sourdough.Spacing.rowInternals) {
                        Ph.folders.regular
                            .frame(width: 40, height: 40)
                            .foregroundStyle(Sourdough.Colors.faintInk)
                        Text("No recipes yet")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.rowTitle)
                        Text("Save a recipe to this collection to see it here.")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.subhead)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Sourdough.Spacing.aboveSectionHead)
                    .padding(.top, Sourdough.Spacing.aboveSectionHead)
                } else {
                    ForEach(recipes) { recipe in
                        CookbookListRow(
                            recipe: recipe,
                            onTap: { r in
                                allergenWarningDetected = []
                                let detected = detectAllergens(
                                    in: r,
                                    userAllergies: session.currentUserAllergies,
                                    customAllergy: session.currentUserCustomAllergy
                                )
                                if detected.isEmpty {
                                    navigateToRecipe = r
                                } else {
                                    allergenWarningDetected = detected
                                    allergenPendingRecipe = r
                                }
                            },
                            onRemoveFromCollection: {
                                savedRecipesStore.removeRecipe(recipe, from: collection.id)
                            }
                        )
                        .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    }
                }
            }
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, 96)
        }
        .background(Sourdough.Colors.canvas)
        .navigationTitle(collection.name)
        .navigationDestination(item: $navigateToRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .sheet(item: $allergenPendingRecipe) { recipe in
            AllergenWarningSheet(recipeName: recipe.title) {
                navigateToRecipe = recipe
            }
        }
        .task {
            // Makes this view self-sufficient regardless of how it's reached, rather than relying
            // on CollectionsSection's own .task having already run first.
            await savedRecipesStore.fetchCollections()
        }
    }
}
