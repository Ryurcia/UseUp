import SwiftUI
import PhosphorSwift

/// The freshness dashboard sitting between the greeting and search bar on `PantryView` — total item
/// count, percent still fresh, a 3-segment tiered bar, and tappable legend chips that drive the same
/// filter state as `selectedFreshnessTier` on `PantryView`.
///
/// Fresh/soon/urgent tallies only count dated, non-expired items — expired items are excluded from
/// the denominator entirely and surfaced separately ("N expired · review"), and undated items
/// (`expirationDate == nil`) are excluded from both numerator and denominator, shown as "· N undated".
struct PantryFreshnessDashboard: View {
    let ingredients: [Ingredient]
    let isLoading: Bool
    let isPantryEmpty: Bool
    @Binding var selectedTier: FreshnessTier?
    let onReviewExpired: () -> Void
    let onAddFirstItem: () -> Void

    private struct Tally {
        var fresh = 0, soon = 0, urgent = 0, expired = 0, undated = 0
    }

    /// Computed once at init (a single pass over `ingredients`) rather than as a computed property,
    /// so the five derived counts below don't each independently re-scan the array.
    private let tally: Tally

    init(
        ingredients: [Ingredient],
        isLoading: Bool,
        isPantryEmpty: Bool,
        selectedTier: Binding<FreshnessTier?>,
        onReviewExpired: @escaping () -> Void,
        onAddFirstItem: @escaping () -> Void
    ) {
        self.ingredients = ingredients
        self.isLoading = isLoading
        self.isPantryEmpty = isPantryEmpty
        self._selectedTier = selectedTier
        self.onReviewExpired = onReviewExpired
        self.onAddFirstItem = onAddFirstItem
        self.tally = ingredients.reduce(into: Tally()) { result, ingredient in
            switch ingredient.freshnessState {
            case .fresh:   result.fresh += 1
            case .soon:    result.soon += 1
            case .urgent:  result.urgent += 1
            case .expired: result.expired += 1
            }
            if ingredient.expirationDate == nil { result.undated += 1 }
        }
    }

    private var freshCount: Int { tally.fresh }
    private var soonCount: Int { tally.soon }
    private var urgentCount: Int { tally.urgent }
    private var expiredCount: Int { tally.expired }
    private var undatedCount: Int { tally.undated }
    private var total: Int { freshCount + soonCount + urgentCount }
    private var pct: Int {
        total > 0 ? Int((Double(freshCount) / Double(total) * 100).rounded()) : 0
    }
    private var pctColor: Color {
        pct < 40 ? Sourdough.Colors.actionInk : Sourdough.Ramp.sage600
    }

    var body: some View {
        Group {
            if isLoading {
                skeletonCard
            } else if isPantryEmpty {
                emptyCard
            } else {
                statsCard
            }
        }
    }

    // MARK: - Expanded

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            HStack(alignment: .bottom, spacing: Sourdough.Spacing.rowInternals) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("IN YOUR PANTRY")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.sectionHead)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(total)")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.display)
                        Text("items")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.numeric)
                    }
                    if undatedCount > 0 {
                        Text("· \(undatedCount) undated")
                            .foregroundStyle(Sourdough.Colors.faintInk)
                            .sourdoughTextStyle(.caption)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("STILL FRESH")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.sectionHead)
                    Text(total > 0 ? "\(pct)%" : "—")
                        .foregroundStyle(pctColor)
                        .sourdoughTextStyle(.title1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(total) items. \(pct) percent fresh. \(freshCount) fresh, \(soonCount) use soon, \(urgentCount) use today."
            )

            tierBar

            HStack(spacing: Sourdough.Spacing.insideChip) {
                legendChip(tier: .fresh, count: freshCount, style: Sourdough.Colors.fresh, dot: Sourdough.Ramp.sage500)
                legendChip(tier: .soon, count: soonCount, style: Sourdough.Colors.soon, dot: Sourdough.Ramp.honey500)
                legendChip(tier: .urgent, count: urgentCount, style: Sourdough.Colors.urgent, dot: Sourdough.Colors.onAction)
            }

            if expiredCount > 0 {
                Button(action: onReviewExpired) {
                    Text("\(expiredCount) expired · review")
                        .foregroundStyle(Sourdough.Colors.destructive)
                        .sourdoughTextStyle(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Sourdough.Spacing.screenMargin)
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous)
                .stroke(Sourdough.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous))
        .sourdoughElevation(.lifted, cornerRadius: Sourdough.Radius.hero)
    }

    private var tierBar: some View {
        GeometryReader { proxy in
            HStack(spacing: 3) {
                tierBarSegment(count: freshCount, color: Sourdough.Ramp.sage500, totalWidth: proxy.size.width)
                tierBarSegment(count: soonCount, color: Sourdough.Ramp.honey500, totalWidth: proxy.size.width)
                tierBarSegment(count: urgentCount, color: Sourdough.Ramp.terracotta500, totalWidth: proxy.size.width)
            }
        }
        .frame(height: 8)
    }

    private func tierBarSegment(count: Int, color: Color, totalWidth: CGFloat) -> some View {
        let proportion = total > 0 ? CGFloat(count) / CGFloat(total) : 0
        let width = max(count > 0 ? 4 : 0, totalWidth * proportion)
        return Capsule()
            .fill(color)
            .frame(width: width)
    }

    private func legendChip(tier: FreshnessTier, count: Int, style: Sourdough.FreshnessStyle, dot: Color) -> some View {
        let isSelected = selectedTier == tier
        return Button {
            selectedTier = (selectedTier == tier) ? nil : tier
        } label: {
            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                Circle().fill(dot).frame(width: 6, height: 6)
                Text(tier.label)
                    .foregroundStyle(style.label)
                    .sourdoughTextStyle(.caption)
                Text("\(count)")
                    .foregroundStyle(style.label)
                    .sourdoughTextStyle(.numeric)
            }
            .padding(.horizontal, Sourdough.Spacing.insideChip + 4)
            .frame(height: 32)
            .background(style.tint)
            .overlay(
                Capsule().stroke(isSelected ? Sourdough.Colors.ink : Color.clear, lineWidth: 1.5)
            )
            .clipShape(Capsule())
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("Your pantry is empty")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.title2)
            Text("Add or scan a few things and we'll start counting the days for you.")
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.subhead)
            Button(action: onAddFirstItem) {
                Text("Add your first item")
                    .foregroundStyle(Sourdough.Colors.onAction)
                    .sourdoughTextStyle(.caption)
                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                    .frame(height: 34)
                    .background(Sourdough.Colors.action)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, Sourdough.Spacing.iconToLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sourdough.Spacing.screenMargin)
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous)
                .stroke(Sourdough.Colors.interactiveBorder, style: StrokeStyle(lineWidth: 1, dash: [6]))
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous))
    }

    // MARK: - Skeleton

    private var skeletonCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Sourdough.Colors.sunken)
                    .frame(width: 78, height: 8)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Sourdough.Colors.sunken)
                    .frame(width: 46, height: 26)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 7) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Sourdough.Colors.sunken)
                    .frame(width: 62, height: 8)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Sourdough.Colors.sunken)
                    .frame(width: 68, height: 26)
            }
        }
        .padding(Sourdough.Spacing.screenMargin)
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous)
                .stroke(Sourdough.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous))
        .redacted(reason: .placeholder)
    }
}

private extension FreshnessTier {
    var label: String {
        switch self {
        case .fresh:  return "Fresh"
        case .soon:   return "Use soon"
        case .urgent: return "Use today"
        }
    }
}
