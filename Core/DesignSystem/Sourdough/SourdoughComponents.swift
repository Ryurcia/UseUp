import SwiftUI
import PhosphorSwift

// MARK: - Freshness state

extension Sourdough {
    /// The 4 urgency buckets driving every freshness chip/meter/row in the app. Thresholds:
    /// ≥7 days = fresh, 1–6 days = soon, exactly today = urgent, past date = expired.
    enum FreshnessState: Equatable {
        case fresh, soon, urgent, expired

        init(daysUntilExpiration days: Int) {
            if days < 0 { self = .expired }
            else if days == 0 { self = .urgent }
            else if days <= 6 { self = .soon }
            else { self = .fresh }
        }

        var style: FreshnessStyle {
            switch self {
            case .fresh: return Sourdough.Colors.fresh
            case .soon: return Sourdough.Colors.soon
            case .urgent: return Sourdough.Colors.urgent
            case .expired: return Sourdough.Colors.expired
            }
        }

        /// Only fresh/soon carry an inner dot per §5 ("urgent" is the solid-fill chip already
        /// communicating urgency; "expired" should grey out, not shout).
        var dotColor: Color? {
            switch self {
            case .fresh: return Sourdough.Ramp.sage500
            case .soon: return Sourdough.Ramp.honey500
            case .urgent, .expired: return nil
            }
        }
    }
}

// MARK: - Freshness chip

/// Pill freshness indicator. Tint-only for fresh/soon/expired, solid fill only for `.urgent`
/// (handled automatically — see `Sourdough.Colors.urgent`, which resolves to a full-strength fill
/// in light mode and inverts to a tinted fill in dark mode per §6).
///
/// `dayCountText` is required — color alone is never sufficient (hard accessibility rule, §2).
struct FreshnessChip: View {
    let state: Sourdough.FreshnessState
    let dayCountText: String

    var body: some View {
        HStack(spacing: Sourdough.Spacing.iconToLabel) {
            if let dotColor = state.dotColor {
                Circle().fill(dotColor).frame(width: 6, height: 6)
            }
            Text(dayCountText)
                .foregroundStyle(state.style.label)
                .sourdoughTextStyle(.caption)
        }
        .padding(.horizontal, Sourdough.Spacing.insideChip + 4)
        .frame(height: 32)
        .background(state.style.tint)
        .clipShape(Capsule())
        .frame(minHeight: 44) // invisible padding to reach the 44pt hit target; chip stays 32pt visually
        .contentShape(Rectangle())
    }
}

// MARK: - Freshness meter

/// Horizontal progress bar for "days remaining", colored by the same fresh/soon/urgent logic as
/// `FreshnessChip`, with a tabular right-aligned day-count.
struct FreshnessMeter: View {
    let state: Sourdough.FreshnessState
    /// 0...1 — e.g. `daysRemaining / totalShelfLifeDays`.
    let progress: Double
    let dayCountText: String

    var body: some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Sourdough.Colors.hairline)
                    Capsule()
                        .fill(state.style.label)
                        .frame(width: proxy.size.width * max(0, min(1, progress)))
                }
            }
            .frame(height: 6)

            Text(dayCountText)
                .foregroundStyle(state.style.label)
                .sourdoughTextStyle(.numeric)
                .frame(minWidth: 40, alignment: .trailing)
        }
    }
}

// MARK: - Pantry row

/// 72pt list row: 44pt category-tinted thumbnail, Row title + Subhead/meta two-line text block,
/// one trailing chip max. Intended for use inside a `List` (swipe actions require it).
/// Swipe-left reveals delete (destructive), swipe-right marks the item used up (sage confirmation).
struct PantryRow: View {
    let icon: Image
    let categoryTint: Color
    let title: String
    let meta: String
    var chip: (state: Sourdough.FreshnessState, text: String)?
    var onMarkUsed: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            ZStack {
                RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous)
                    .fill(categoryTint.opacity(0.16))
                icon
                    .frame(width: 20, height: 20)
                    .foregroundStyle(categoryTint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .sourdoughTextStyle(.rowTitle)
                    .lineLimit(1)
                Text(meta)
                    .sourdoughTextStyle(.subhead)
                    .lineLimit(1)
            }

            Spacer(minLength: Sourdough.Spacing.rowInternals)

            if let chip {
                FreshnessChip(state: chip.state, dayCountText: chip.text)
            }
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .frame(height: 72)
        .background(Sourdough.Colors.card)
        .swipeActions(edge: .trailing) {
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label { Text("Delete") } icon: { Ph.trash.bold.frame(width: 16, height: 16) }
                }
                .tint(Sourdough.Colors.destructive)
            }
        }
        .swipeActions(edge: .leading) {
            if let onMarkUsed {
                Button(action: onMarkUsed) {
                    Label { Text("Used up") } icon: { Ph.check.bold.frame(width: 16, height: 16) }
                }
                .tint(Sourdough.Ramp.sage500)
            }
        }
    }
}

// MARK: - On-dark hero card

/// Translucent-badge chip for on-dark surfaces (hero cards, full-bleed headers). Defaults to a
/// 10%-opacity white fill; under Reduce Transparency, swaps to a solid `#3D3833` fill instead
/// (§6 accessibility override layer).
struct OnDarkBadge: View {
    let text: String
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Text(text)
            .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
            .sourdoughTextStyle(.caption)
            .padding(.horizontal, Sourdough.Spacing.insideChip)
            .padding(.vertical, 4)
            .background(reduceTransparency ? Sourdough.Colors.heroChipFillReducedTransparency : Color.white.opacity(0.10))
            .clipShape(Capsule())
    }
}

/// Full-bleed on-dark hero/feature card (§5). Titles use `heroTitleOnDark` (linen0-equivalent),
/// meta uses `heroMetaOnDark` (linen300-equivalent). Honey-300 is the only accent proven to hold
/// contrast on dark — never render base terracotta-500 here (2.9:1, fails); the lifted `action`
/// token already resolves to `#E08055` in dark mode if a terracotta accent is unavoidable.
struct OnDarkHeroCard<Footer: View>: View {
    let image: Image?
    let title: String
    let meta: String
    var tags: [String] = []
    /// e.g. a "Use today" pill — rendered with the honey-300 dark accent, not terracotta.
    var accentText: String?
    /// Extra content flowing naturally after title/meta — e.g. an ingredient-chip scroll row.
    @ViewBuilder var footer: () -> Footer
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Sourdough.Ramp.darkCard
            if let image {
                image.resizable().scaledToFill()
            }
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Sourdough.Spacing.iconToLabel) {
                if !tags.isEmpty {
                    HStack(spacing: Sourdough.Spacing.iconToLabel) {
                        ForEach(tags, id: \.self) { OnDarkBadge(text: $0) }
                    }
                }
                if let accentText {
                    Text(accentText)
                        .foregroundStyle(Sourdough.Ramp.darkCanvas)
                        .sourdoughTextStyle(.caption)
                        .padding(.horizontal, Sourdough.Spacing.insideChip)
                        .padding(.vertical, 4)
                        .background(reduceTransparency ? Sourdough.Colors.heroChipFillReducedTransparency : Sourdough.Colors.heroAccentOnDark)
                        .clipShape(Capsule())
                }
                Text(title)
                    .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                    .sourdoughTextStyle(.title2)
                    .lineLimit(2)
                Text(meta)
                    .foregroundStyle(Sourdough.Colors.heroMetaOnDark)
                    .sourdoughTextStyle(.subhead)
                    .lineLimit(1)
                footer()
            }
            .padding(Sourdough.Spacing.screenMargin)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous))
        .sourdoughElevation(.lifted, cornerRadius: Sourdough.Radius.hero)
    }
}

extension OnDarkHeroCard where Footer == EmptyView {
    init(image: Image?, title: String, meta: String, tags: [String] = [], accentText: String? = nil) {
        self.init(image: image, title: title, meta: meta, tags: tags, accentText: accentText, footer: { EmptyView() })
    }
}

// MARK: - Selectable Chip

/// Toggleable capsule chip — sage fill when selected, sunken/bordered when not. The same shape
/// was hand-rolled at every multi-select filter/preference row (diet type, dietary restrictions,
/// allergies) instead of being reused.
struct SelectableChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .foregroundStyle(isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.caption)
                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                .padding(.vertical, Sourdough.Spacing.insideChip)
                .background(isSelected ? Sourdough.Ramp.sage500 : Sourdough.Colors.sunken)
                .overlay(Capsule().stroke(isSelected ? Color.clear : Sourdough.Colors.interactiveBorder, lineWidth: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
