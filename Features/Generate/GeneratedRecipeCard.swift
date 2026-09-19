import SwiftUI
import PhosphorSwift

/// Vertical stack of full-width `GeneratedRecipeCard`s, sized to content. Relies on the outer
/// `ScrollView` at the Generate results call site for scrolling — no ScrollView of its own.
struct GeneratedRecipeCardRow: View {
    let recipes: [Recipe]
    let isSaved: (Recipe) -> Bool
    let onToggleSave: (Recipe) -> Void

    var body: some View {
        LazyVStack(spacing: Sourdough.Spacing.rowInternals) {
            ForEach(recipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe)
                } label: {
                    GeneratedRecipeCard(
                        recipe: recipe,
                        isSaved: isSaved(recipe),
                        onSave: { onToggleSave(recipe) }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
    }
}

/// Content-sized card for a single generated recipe — text only, no image. The black-gradient
/// `RecipeImagePlaceholder` treatment stays reserved for the recipe preview sheet and detail
/// screen, not repeated here.
struct GeneratedRecipeCard: View {
    let recipe: Recipe
    var isSaved: Bool = false
    var onSave: (() -> Void)? = nil

    private var cardTags: [(text: String, isDiet: Bool)] {
        var labels: [(text: String, isDiet: Bool)] = []
        if recipe.dietType != "any" {
            labels.append((recipe.dietType.capitalized, true))
        }
        for restriction in recipe.dietaryRestrictions {
            labels.append((restriction, false))
        }
        return labels
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            HStack(alignment: .top, spacing: Sourdough.Spacing.insideChip) {
                Text(recipe.title)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.title2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let onSave {
                    Button(action: onSave) {
                        (isSaved ? Ph.bookmark.fill : Ph.bookmark.regular)
                            .frame(width: 16, height: 16)
                            .foregroundStyle(isSaved ? Sourdough.Colors.action : Sourdough.Colors.faintInk)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !recipe.summary.isEmpty {
                Text(recipe.summary)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.body)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: Sourdough.Spacing.insideChip) {
                Label {
                    Text("\(recipe.timeMinutes) min")
                } icon: {
                    Ph.clock.regular.frame(width: 13, height: 13)
                }

                Label {
                    Text("\(recipe.servings) servings")
                } icon: {
                    Ph.users.regular.frame(width: 13, height: 13)
                }
            }
            .foregroundStyle(Sourdough.Colors.faintInk)
            .sourdoughTextStyle(.subhead)

            let tags = cardTags
            if !tags.isEmpty {
                let visibleTags = Array(tags.prefix(2))
                let overflow = tags.count - visibleTags.count
                HStack(spacing: 4) {
                    ForEach(visibleTags.indices, id: \.self) { i in
                        Text(visibleTags[i].text)
                            .foregroundStyle(Sourdough.Colors.onAction)
                            .sourdoughTextStyle(.subhead)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(visibleTags[i].isDiet ? Sourdough.Ramp.sage500 : Sourdough.Ramp.honey600)
                            .clipShape(Capsule())
                    }
                    if overflow > 0 {
                        Text("+\(overflow) more")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.subhead)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Sourdough.Colors.sunken)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(Sourdough.Spacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Sourdough.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        .sourdoughElevation(.lifted, cornerRadius: Sourdough.Radius.card)
    }
}
