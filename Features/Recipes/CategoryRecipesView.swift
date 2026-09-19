import SwiftUI

struct CategoryRecipesView: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var pantryStore: PantryStore
    let category: RecipesView.RecipeCategory

    @State private var recipes: [Recipe] = []
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var selectedRecipe: Recipe?
    @State private var navigateToRecipe: Recipe?
    @State private var reportTarget: ReportTarget?
    @State private var ratingsRecipe: Recipe?
    @State private var recipePendingSaveFlow: Recipe?
    @State private var recipePendingCollectionPick: Recipe?

    private let pageSize = 20

    private let gridColumns = [
        GridItem(.flexible(), spacing: DS.Spacing.space4),
        GridItem(.flexible(), spacing: DS.Spacing.space4)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.space5) {
                ForEach(recipes) { recipe in
                    let actions = RecipeCardActions(
                        recipe: recipe,
                        savedRecipesStore: savedRecipesStore,
                        reportTarget: { reportTarget = $0 },
                        rateRecipe: { ratingsRecipe = $0 },
                        presentSaveFlow: { recipePendingSaveFlow = $0 }
                    )
                    Button {
                        selectedRecipe = recipe
                    } label: {
                        RecipeCard(
                            recipe: recipe,
                            showBadge: false,
                            isSaved: savedRecipesStore.isSaved(recipe),
                            onReportRecipe: actions.onReportRecipe,
                            onReportUser: actions.onReportUser,
                            onRate: actions.onRate,
                            onSave: actions.onSave
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space24)

            if hasMore {
                HStack {
                    Spacer()
                    ProgressView().padding(.vertical, DS.Spacing.space4)
                    Spacer()
                }
                .onAppear {
                    guard !isLoadingMore else { return }
                    isLoadingMore = true
                    Task {
                        let page = await savedRecipesStore.fetchCategoryRecipes(filter: category.filter, limit: pageSize, offset: recipes.count)
                        recipes.append(contentsOf: page)
                        hasMore = page.count == pageSize
                        isLoadingMore = false
                    }
                }
            }
        }
        .task {
            recipes = category.recipes
            let page = await savedRecipesStore.fetchCategoryRecipes(filter: category.filter, limit: pageSize, offset: 0)
            recipes = page
            hasMore = page.count == pageSize
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(DS.ColorToken.bgPrimary)
        .sheet(item: $selectedRecipe) { recipe in
            RecipePreviewSheet(recipe: recipe) {
                selectedRecipe = nil
                navigateToRecipe = recipe
            }
        }
        .sheet(item: $recipePendingSaveFlow) { recipe in
            SaveChoiceSheet(
                onSaveToCollection: {
                    recipePendingSaveFlow = nil
                    recipePendingCollectionPick = recipe
                },
                onJustSave: {
                    savedRecipesStore.saveRecipe(recipe)
                    recipePendingSaveFlow = nil
                }
            )
            .presentationDetents([.height(220)])
        }
        .sheet(item: $recipePendingCollectionPick) { recipe in
            CollectionPickerSheet(recipe: recipe) {
                recipePendingCollectionPick = nil
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $reportTarget) { target in
            ReportContentSheet(subject: target.subject) { category, description in
                Task {
                    switch target {
                    case .recipe(let recipe):
                        try? await savedRecipesStore.reportRecipe(recipe, category: category, description: description)
                    case .user(let id, _):
                        try? await savedRecipesStore.reportUser(id, category: category, description: description)
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(item: $navigateToRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .navigationDestination(item: $ratingsRecipe) { recipe in
            RecipeRatingsView(recipe: recipe)
        }
    }
}
