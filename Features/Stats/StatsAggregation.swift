import SwiftUI

/// The Weekly / Monthly / Yearly lens. Bucket counts match the source design (7 weeks, 6 months,
/// 4 years).
enum StatsPeriod: CaseIterable, Identifiable {
    case weekly, monthly, yearly
    var id: Self { self }

    var title: String {
        switch self {
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        }
    }

    /// "this week" — used in card labels ("SPENT THIS WEEK").
    var perLabel: String {
        switch self {
        case .weekly:  return "this week"
        case .monthly: return "this month"
        case .yearly:  return "this year"
        }
    }

    /// "week" — used in "vs last week".
    var perWord: String {
        switch self {
        case .weekly:  return "week"
        case .monthly: return "month"
        case .yearly:  return "year"
        }
    }

    var bucketCount: Int {
        switch self {
        case .weekly:  return 7
        case .monthly: return 6
        case .yearly:  return 4
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .weekly:  return .weekOfYear
        case .monthly: return .month
        case .yearly:  return .year
        }
    }

    var barGap: CGFloat {
        switch self {
        case .weekly:  return 5
        case .monthly: return 6
        case .yearly:  return 10
        }
    }
}

// MARK: - Row types

struct StatsBar: Identifiable {
    let id: Int
    let label: String
    let spend: Double
    let waste: Double
    var eaten: Double { max(0, spend - waste) }
}

struct StatsSlice: Identifiable {
    let id: Int
    let name: String
    let amount: Double
    let color: Color
}

struct StatsOffender: Identifiable {
    let id: String          // ingredient_key
    let name: String
    let initial: String
    let boughtCount: Int
    let wastedCount: Int
    let wastedCost: Double

    var rate: Double { boughtCount > 0 ? Double(wastedCount) / Double(boughtCount) : 0 }

    var tileTint: Color {
        rate >= 0.7 ? Sourdough.Ramp.terracotta100
            : rate >= 0.5 ? Sourdough.Ramp.honey100
            : Sourdough.Ramp.sage100
    }
    var tileInk: Color {
        rate >= 0.7 ? Sourdough.Ramp.terracotta600
            : rate >= 0.5 ? Sourdough.Ramp.honey700
            : Sourdough.Ramp.sage600
    }
    var barColor: Color {
        rate >= 0.7 ? Sourdough.Ramp.terracotta500
            : rate >= 0.5 ? Sourdough.Ramp.honey500
            : Sourdough.Ramp.sage500
    }
}

// MARK: - Aggregation

struct PeriodStats {
    let period: StatsPeriod
    let bars: [StatsBar]
    let selectedIndex: Int
    let slices: [StatsSlice]
    let offenders: [StatsOffender]
    let selectedBucketStart: Date?

    /// Sage → terracotta walk so the worst waste category is always the warmest.
    static let slicePalette: [Color] = [
        Sourdough.Ramp.terracotta500,
        Sourdough.Ramp.terracottaDark,
        Sourdough.Ramp.honey300,
        Sourdough.Ramp.sage300,
        Sourdough.Ramp.linen300,
    ]

    var selectedBar: StatsBar? { bars.indices.contains(selectedIndex) ? bars[selectedIndex] : nil }

    var headlineSpend: Double { selectedBar?.spend ?? 0 }
    var headlineWaste: Double { selectedBar?.waste ?? 0 }

    var peakSpend: Double { max(bars.map(\.spend).max() ?? 0, 1) }

    /// % change in spend vs the bar immediately before the selected one. `nil` when there's no
    /// prior bar or it was zero.
    var spendTrendPct: Int? {
        guard selectedIndex > 0 else { return nil }
        let prev = bars[selectedIndex - 1].spend
        guard prev > 0 else { return nil }
        return Int(((headlineSpend - prev) / prev * 100).rounded())
    }

    var wastePctOfSpend: Int? {
        guard headlineSpend > 0 else { return nil }
        return Int((headlineWaste / headlineSpend * 100).rounded())
    }

    var binnedTotal: Double { slices.reduce(0) { $0 + $1.amount } }

    // Copy: captions

    var rangeCaption: String {
        let head: String
        if let start = selectedBucketStart {
            switch period {
            case .weekly:  head = "Week of \(StatsDates.longWeek(start))"
            case .monthly: head = StatsDates.longMonth(start)
            case .yearly:  head = currentBarLabel
            }
        } else {
            head = currentBarLabel
        }
        switch period {
        case .weekly:  return "\(head) · vs prior weeks"
        case .monthly: return "\(head) · vs last 6 months"
        case .yearly:  return "\(head) · vs last 4 years"
        }
    }

    private var currentBarLabel: String { selectedBar?.label ?? "" }

    var chartTitle: String {
        switch period {
        case .weekly:  return "Last 7 weeks"
        case .monthly: return "Last 6 months"
        case .yearly:  return "Last 4 years"
        }
    }

    var chartCaption: String { "Each bar is one \(period.perWord)'s spend, split into eaten and binned" }

    func donutCaption(isolated: StatsSlice?) -> String {
        if let isolated, binnedTotal > 0 {
            return "\(isolated.name) · \(Int((isolated.amount / binnedTotal * 100).rounded()))% of your waste"
        }
        let isCurrent = selectedIndex == bars.count - 1
        return isCurrent
            ? "\(binnedTotal.asHedgedDollar) binned \(period.perLabel)"
            : "\(binnedTotal.asHedgedDollar) binned in \(currentBarLabel)"
    }

    func donutCentre(isolated: StatsSlice?) -> (figure: String, label: String) {
        if let isolated {
            return (isolated.amount.asHedgedDollar, isolated.name)
        }
        return (binnedTotal.asHedgedDollar, "binned \(period.perWord == "week" ? "weekly" : period.perWord == "month" ? "monthly" : "yearly")")
    }

    var nudgeText: String? {
        guard let top = offenders.first else { return nil }
        return "\(top.name.capitalized) expired \(top.wastedCount) of the \(top.boughtCount) times you bought it. Cook it first next time."
    }

    // MARK: build

    static func make(
        events: [PantryEvent],
        period: StatsPeriod,
        selectedIndex: Int?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PeriodStats {
        let buckets = StatsDates.buckets(period: period, now: now, calendar: calendar)

        let bars: [StatsBar] = buckets.enumerated().map { index, interval in
            var spend = 0.0
            var waste = 0.0
            for e in events where interval.contains(e.occurredAt) {
                guard let cost = e.costValue else { continue }
                switch e.outcome {
                case .bought: spend += cost
                case .wasted: waste += cost
                case .used:   break
                }
            }
            return StatsBar(
                id: index,
                label: StatsDates.label(period, intervalStart: interval.start),
                spend: spend,
                waste: waste
            )
        }

        let resolvedIndex = min(max(selectedIndex ?? (bars.count - 1), 0), max(bars.count - 1, 0))

        // Donut: wasted-by-category over the selected bucket.
        let slices: [StatsSlice]
        if buckets.indices.contains(resolvedIndex) {
            let bucket = buckets[resolvedIndex]
            var byCategory: [Ingredient.Category: Double] = [:]
            for e in events where e.outcome == .wasted && bucket.contains(e.occurredAt) {
                guard let cost = e.costValue else { continue }
                byCategory[e.category, default: 0] += cost
            }
            let sorted = byCategory.sorted { $0.value > $1.value }
            var built: [StatsSlice] = []
            let headCount = min(sorted.count, 4)
            for i in 0..<headCount {
                built.append(StatsSlice(id: i, name: sorted[i].key.title, amount: sorted[i].value, color: slicePalette[min(i, slicePalette.count - 1)]))
            }
            if sorted.count > headCount {
                let rest = sorted[headCount...].reduce(0) { $0 + $1.value }
                if rest > 0 {
                    built.append(StatsSlice(id: headCount, name: "Other", amount: rest, color: slicePalette[slicePalette.count - 1]))
                }
            }
            slices = built
        } else {
            slices = []
        }

        let offenders = repeatOffenders(events: events, limit: 4, now: now, calendar: calendar)

        return PeriodStats(
            period: period,
            bars: bars,
            selectedIndex: resolvedIndex,
            slices: slices,
            offenders: offenders,
            selectedBucketStart: buckets.indices.contains(resolvedIndex) ? buckets[resolvedIndex].start : nil
        )
    }

    // MARK: offender tallies

    private struct OffenderAcc { var name = ""; var bought = 0; var wasted = 0; var wastedCost = 0.0 }

    private static func tally(events: [PantryEvent], since cutoff: Date) -> [String: OffenderAcc] {
        var accs: [String: OffenderAcc] = [:]
        for e in events where e.occurredAt >= cutoff {
            var acc = accs[e.ingredientKey] ?? OffenderAcc()
            if acc.name.isEmpty { acc.name = e.ingredientName }
            switch e.outcome {
            case .bought: acc.bought += 1
            case .wasted: acc.wasted += 1; acc.wastedCost += e.costValue ?? 0
            case .used:   break
            }
            accs[e.ingredientKey] = acc
        }
        return accs
    }

    private static func offender(_ key: String, _ acc: OffenderAcc) -> StatsOffender {
        StatsOffender(
            id: key,
            name: acc.name,
            initial: String(acc.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased(),
            boughtCount: acc.bought,
            wastedCount: acc.wasted,
            wastedCost: acc.wastedCost
        )
    }

    /// Trailing 6 months, ranked by how *reliably* the ingredient goes bad (rate, then cost).
    /// Needs `bought >= 2` so a one-off isn't flagged as a pattern.
    static func repeatOffenders(events: [PantryEvent], limit: Int, now: Date = Date(), calendar: Calendar = .current) -> [StatsOffender] {
        let cutoff = calendar.date(byAdding: .month, value: -6, to: now) ?? .distantPast
        return tally(events: events, since: cutoff)
            .filter { $0.value.bought >= 2 && $0.value.wasted >= 1 }
            .map { offender($0.key, $0.value) }
            .sorted { ($0.rate, $0.wastedCost) > ($1.rate, $1.wastedCost) }
            .prefix(limit)
            .map { $0 }
    }

    /// Trailing 6 months, ranked by raw waste volume — how *often* it lands in the bin, then $.
    /// For the exported report's "most thrown-away ingredients" page.
    static func mostWasted(events: [PantryEvent], limit: Int, now: Date = Date(), calendar: Calendar = .current) -> [StatsOffender] {
        let cutoff = calendar.date(byAdding: .month, value: -6, to: now) ?? .distantPast
        return tally(events: events, since: cutoff)
            .filter { $0.value.wasted >= 1 }
            .map { offender($0.key, $0.value) }
            .sorted { ($0.wastedCount, $0.wastedCost) > ($1.wastedCount, $1.wastedCost) }
            .prefix(limit)
            .map { $0 }
    }
}

/// All-time spend vs. waste, for the report's cover summary.
struct StatsTotals {
    let spent: Double
    let wasted: Double

    var wasteRate: Int? { spent > 0 ? Int((wasted / spent * 100).rounded()) : nil }

    static func allTime(_ events: [PantryEvent]) -> StatsTotals {
        var spent = 0.0
        var wasted = 0.0
        for e in events {
            guard let cost = e.costValue else { continue }
            switch e.outcome {
            case .bought: spent += cost
            case .wasted: wasted += cost
            case .used:   break
            }
        }
        return StatsTotals(spent: spent, wasted: wasted)
    }
}

// MARK: - Data-readiness

enum StatsReadiness {
    static func hasData(_ events: [PantryEvent]) -> Bool {
        events.contains { $0.costValue != nil }
    }

    /// Yearly needs roughly a year of history behind it, else it's four fabricated-looking bars.
    static func yearlyAvailable(_ events: [PantryEvent], now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let earliest = events.map(\.occurredAt).min(),
              let threshold = calendar.date(byAdding: .month, value: -12, to: now) else { return false }
        return earliest <= threshold
    }
}

// One snapshot serves every card in a render. Donut highlighting and export UI do not
// change these inputs, so they can reuse the same aggregation without rescanning events.
struct StatsSnapshot {
    let stats: PeriodStats
    let hasData: Bool
    let yearlyAvailable: Bool
}

final class StatsSnapshotCache {
    private struct Key: Equatable {
        let revision: UInt64
        let period: StatsPeriod
        let selectedIndex: Int?
        let day: Date
        let calendar: Calendar
        let localeIdentifier: String
    }
    private var cached: (key: Key, snapshot: StatsSnapshot)?

    func snapshot(events: [PantryEvent], revision: UInt64, period: StatsPeriod,
                  selectedIndex: Int?, now: Date, calendar: Calendar = .current) -> StatsSnapshot {
        let key = Key(revision: revision, period: period, selectedIndex: selectedIndex,
                      day: calendar.startOfDay(for: now), calendar: calendar,
                      localeIdentifier: Locale.current.identifier)
        if let cached, cached.key == key { return cached.snapshot }
        let snapshot = StatsSnapshot(
            stats: PeriodStats.make(events: events, period: period, selectedIndex: selectedIndex, now: now, calendar: calendar),
            hasData: StatsReadiness.hasData(events),
            yearlyAvailable: StatsReadiness.yearlyAvailable(events, now: now, calendar: calendar)
        )
        cached = (key, snapshot)
        return snapshot
    }
}

// MARK: - Date helpers

enum StatsDates {
    private static let monthDay: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    private static let month: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f
    }()
    private static let year: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy"; return f
    }()
    private static let longMonthF: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()
    private static let longWeekF: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()

    static func longMonth(_ date: Date) -> String { longMonthF.string(from: date) }
    static func longWeek(_ date: Date) -> String { longWeekF.string(from: date) }

    static func buckets(period: StatsPeriod, now: Date, calendar: Calendar) -> [DateInterval] {
        let comp = period.calendarComponent
        guard let current = calendar.dateInterval(of: comp, for: now) else { return [] }
        var result: [DateInterval] = []
        for offset in stride(from: period.bucketCount - 1, through: 0, by: -1) {
            guard let start = calendar.date(byAdding: comp, value: -offset, to: current.start),
                  let interval = calendar.dateInterval(of: comp, for: start) else { continue }
            result.append(interval)
        }
        return result
    }

    static func label(_ period: StatsPeriod, intervalStart start: Date) -> String {
        switch period {
        case .weekly:  return monthDay.string(from: start)
        case .monthly: return month.string(from: start)
        case .yearly:  return year.string(from: start)
        }
    }
}
