import SwiftUI

/// The single pantry dashboard between the greeting and the list: freshness percent (with a
/// 3-segment tier bar), total estimated pantry value, and the estimated value at risk from items
/// expiring soon.
///
/// Freshness math is unchanged from before: fresh/soon/urgent tallies only count dated,
/// non-expired items; expired items are surfaced separately ("N expired · review"); undated items
/// (`expirationDate == nil`) resolve to `.fresh` and are also flagged as "· N undated".
struct PantryDashboard: View {
    let ingredients: [Ingredient]
    let isLoading: Bool
    let isPantryEmpty: Bool
    let onReviewExpired: () -> Void
    let onAddFirstItem: () -> Void

    private struct Tally {
        var fresh = 0, soon = 0, urgent = 0, expired = 0, undated = 0
        var pantryValue = 0.0, pricedCount = 0
        var atRiskValue = 0.0, atRiskCount = 0
    }

    /// One pass over `ingredients` at init so the derived figures below don't each re-scan.
    private let tally: Tally

    init(
        ingredients: [Ingredient],
        isLoading: Bool,
        isPantryEmpty: Bool,
        onReviewExpired: @escaping () -> Void,
        onAddFirstItem: @escaping () -> Void
    ) {
        self.ingredients = ingredients
        self.isLoading = isLoading
        self.isPantryEmpty = isPantryEmpty
        self.onReviewExpired = onReviewExpired
        self.onAddFirstItem = onAddFirstItem
        self.tally = ingredients.reduce(into: Tally()) { result, ingredient in
            let state = ingredient.freshnessState
            switch state {
            case .fresh:   result.fresh += 1
            case .soon:    result.soon += 1
            case .urgent:  result.urgent += 1
            case .expired: result.expired += 1
            }
            if ingredient.expirationDate == nil { result.undated += 1 }

            if let cost = ingredient.estimatedTotalCost {
                result.pantryValue += cost
                result.pricedCount += 1
            }
            if state == .soon || state == .urgent {
                result.atRiskCount += 1
                if let cost = ingredient.estimatedTotalCost { result.atRiskValue += cost }
            }
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

    // MARK: - Stats

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
            VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                Text("STILL FRESH")
                    .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.mutedInk)

                HStack(alignment: .firstTextBaseline) {
                    Text(total > 0 ? "\(pct)%" : "—")
                        .foregroundStyle(pctColor)
                        .sourdoughTextStyle(.display)
                    Spacer(minLength: Sourdough.Spacing.insideChip)
                    if undatedCount > 0 {
                        Text("\(undatedCount) undated")
                            .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)
                    }
                }

                tierBar
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(pct) percent still fresh. \(freshCount) fresh, \(soonCount) use soon, \(urgentCount) use today.")

            HStack(alignment: .top, spacing: Sourdough.Spacing.screenMargin) {
                metric(
                    "PANTRY VALUE",
                    value: tally.pricedCount > 0 ? tally.pantryValue.asExactDollarString : "—",
                    color: Sourdough.Colors.ink
                )
                metric(
                    "AT RISK",
                    value: tally.atRiskCount > 0 ? tally.atRiskValue.asWholeDollarString : "—",
                    color: tally.atRiskCount > 0 ? Sourdough.Ramp.honey700 : Sourdough.Colors.mutedInk
                )
            }

            if expiredCount > 0 {
                Button(action: onReviewExpired) {
                    Text("\(expiredCount) expired · review")
                        .sourdoughTextStyle(.caption, color: Sourdough.Colors.destructive)
                }
                .buttonStyle(.plain)
            }
        }
        .pantryDashboardCard()
    }

    private func metric(_ label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            Text(label)
                .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.mutedInk)
            Text(value)
                .foregroundStyle(color)
                .sourdoughTextStyle(.title1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
            VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Sourdough.Colors.sunken)
                    .frame(width: 78, height: 8)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Sourdough.Colors.sunken)
                    .frame(width: 64, height: 30)
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Sourdough.Colors.sunken)
                    .frame(height: 8)
            }
            HStack(spacing: Sourdough.Spacing.screenMargin) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Sourdough.Colors.sunken)
                            .frame(width: 70, height: 8)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Sourdough.Colors.sunken)
                            .frame(width: 54, height: 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .pantryDashboardCard()
        .redacted(reason: .placeholder)
    }
}
