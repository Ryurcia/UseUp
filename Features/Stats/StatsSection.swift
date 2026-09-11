import SwiftUI
import PhosphorSwift

/// Spend & waste analytics over the `pantry_events` ledger, embedded at the top of the profile
/// screen. Weekly / Monthly / Yearly toggle re-derives everything; every dollar figure is
/// `~`-hedged because `cost_value` is estimated.
struct StatsSection: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var pantryStore: PantryStore
    @EnvironmentObject private var statsStore: StatsStore

    @State private var period: StatsPeriod = .monthly
    @State private var selectedBar: Int?
    @State private var isolatedCategory: Int?

    @State private var isExporting = false
    @State private var exportURLs: [URL] = []
    @State private var showExportShare = false
    @State private var showExportError = false

    private var events: [PantryEvent] { statsStore.events }
    private var hasData: Bool { StatsReadiness.hasData(events) }
    private var yearlyAvailable: Bool { StatsReadiness.yearlyAvailable(events) }

    private var stats: PeriodStats {
        PeriodStats.make(events: events, period: period, selectedIndex: selectedBar)
    }

    private var isolatedSlice: StatsSlice? {
        guard let i = isolatedCategory, stats.slices.indices.contains(i) else { return nil }
        return stats.slices[i]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
            sectionHeader

            if hasData {
                VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                    periodToggle
                    Text(stats.rangeCaption)
                        .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
                }

                headlineCards
                barCard
                donutCard

                if !stats.offenders.isEmpty {
                    offendersSection
                }
                if let nudge = stats.nudgeText {
                    nudgeRow(nudge)
                }
            } else {
                emptyCard
            }
        }
        .task { await statsStore.refresh() }
        .sheet(isPresented: $showExportShare) { ShareSheet(items: exportURLs) }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK") {}
        } message: {
            Text("Couldn't export your stats. Please try again.")
        }
    }

    // MARK: Section header

    private var sectionHeader: some View {
        HStack {
            Text("Spending & waste")
                .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.faintInk)
                .padding(.leading, 4)
            Spacer()
            if hasData {
                exportButton
            }
        }
    }

    private var exportButton: some View {
        Button { Task { await runExport() } } label: {
            Group {
                if isExporting {
                    ProgressView()
                } else {
                    Ph.export.regular
                        .frame(width: 17, height: 17)
                        .foregroundStyle(Sourdough.Colors.ink)
                }
            }
            .frame(width: 32, height: 32)
            .background(Sourdough.Colors.navChip)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
    }

    // MARK: Period toggle

    private var periodToggle: some View {
        HStack(spacing: 4) {
            ForEach(StatsPeriod.allCases) { p in
                let selected = period == p
                let disabled = p == .yearly && !yearlyAvailable
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        period = p
                        selectedBar = nil
                        isolatedCategory = nil
                    }
                } label: {
                    Text(p.title)
                        .sourdoughTextStyle(.subhead, color: selected ? Sourdough.Colors.ink : Sourdough.Colors.mutedInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            Capsule()
                                .fill(selected ? Sourdough.Colors.card : Color.clear)
                                .shadow(color: selected ? Sourdough.Ramp.linen900.opacity(0.18) : .clear, radius: 3, x: 0, y: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                .opacity(disabled ? 0.4 : 1)
            }
        }
        .padding(4)
        .background(Sourdough.Colors.sunken)
        .clipShape(Capsule())
    }

    // MARK: Headline cards

    private var headlineCards: some View {
        HStack(alignment: .top, spacing: Sourdough.Spacing.rowInternals) {
            statCard(
                label: "Spent \(period.perLabel)",
                figure: stats.headlineSpend.asHedgedDollar,
                figureColor: Sourdough.Colors.ink,
                ground: Sourdough.Colors.card,
                labelColor: Sourdough.Colors.mutedInk
            ) {
                HStack(spacing: 4) {
                    if let pct = stats.spendTrendPct {
                        Text(pct >= 0 ? "+\(pct)%" : "\(pct)%")
                            .sourdoughTextStyle(.caption, color: pct >= 0 ? Sourdough.Colors.destructive : Sourdough.Ramp.sage600)
                        Text("vs last \(period.perWord)")
                            .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)
                    } else {
                        Text("no prior \(period.perWord)")
                            .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)
                    }
                }
            }

            statCard(
                label: "Wasted \(period.perLabel)",
                figure: stats.headlineWaste.asHedgedDollar,
                figureColor: Sourdough.Colors.destructive,
                ground: Sourdough.Ramp.terracotta50,
                labelColor: Sourdough.Ramp.terracotta600
            ) {
                HStack(spacing: 4) {
                    if let pct = stats.wastePctOfSpend {
                        Text("\(pct)%")
                            .sourdoughTextStyle(.caption, color: Sourdough.Colors.destructive)
                        Text("of your groceries")
                            .sourdoughTextStyle(.caption, color: Sourdough.Ramp.terracotta600)
                    } else {
                        Text("nothing binned")
                            .sourdoughTextStyle(.caption, color: Sourdough.Ramp.terracotta600)
                    }
                }
            }
        }
    }

    private func statCard<Trailing: View>(
        label: String,
        figure: String,
        figureColor: Color,
        ground: Color,
        labelColor: Color,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            Text(label)
                .sourdoughTextStyle(.sectionHead, color: labelColor)
            Text(figure)
                .foregroundStyle(figureColor)
                .sourdoughTextStyle(.title1)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            trailing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sourdough.Spacing.rowInternals)
        .background(ground)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous)
                .stroke(Sourdough.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous))
        .sourdoughElevation(.lifted, cornerRadius: Sourdough.Radius.hero)
    }

    // MARK: Bar chart card

    private var barCard: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            HStack(alignment: .top, spacing: Sourdough.Spacing.insideChip) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stats.chartTitle)
                        .sourdoughTextStyle(.rowTitle)
                    Text(stats.chartCaption)
                        .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 3) {
                    legendSwatch(Sourdough.Ramp.sage200, "Eaten")
                    legendSwatch(Sourdough.Ramp.terracotta500, "Binned")
                }
            }

            StatsBarChart(stats: stats) { index in
                withAnimation(.easeInOut(duration: 0.16)) {
                    selectedBar = index
                    isolatedCategory = nil
                }
            }
        }
        .pantryDashboardCard()
    }

    private func legendSwatch(_ color: Color, _ label: String) -> some View {
        HStack(spacing: Sourdough.Spacing.iconToLabel) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .sourdoughTextStyle(.caption, color: Sourdough.Colors.mutedInk)
        }
    }

    // MARK: Donut card

    private var donutCard: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Where the waste goes")
                    .sourdoughTextStyle(.rowTitle)
                Text(stats.donutCaption(isolated: isolatedSlice))
                    .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
            }

            if stats.slices.isEmpty {
                Text("Nothing binned in this period.")
                    .sourdoughTextStyle(.subhead, color: Sourdough.Colors.faintInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Sourdough.Spacing.insideChip)
            } else {
                HStack(alignment: .center, spacing: Sourdough.Spacing.rowInternals) {
                    StatsDonut(
                        slices: stats.slices,
                        isolatedIndex: isolatedCategory,
                        centre: stats.donutCentre(isolated: isolatedSlice)
                    )

                    VStack(spacing: 5) {
                        ForEach(Array(stats.slices.enumerated()), id: \.element.id) { index, slice in
                            Button {
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    isolatedCategory = (isolatedCategory == index) ? nil : index
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(slice.color)
                                        .frame(width: 8, height: 8)
                                    Text(slice.name)
                                        .sourdoughTextStyle(.subhead, color: Sourdough.Colors.ink)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text(slice.amount.asHedgedDollar)
                                        .sourdoughTextStyle(.numeric, color: Sourdough.Colors.ink)
                                }
                                .frame(minHeight: 28)
                                .contentShape(Rectangle())
                                .opacity(isolatedCategory == nil || isolatedCategory == index ? 1 : 0.4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .pantryDashboardCard()
    }

    // MARK: Repeat offenders

    private var offendersSection: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            HStack(alignment: .firstTextBaseline) {
                Text("Repeat offenders")
                    .sourdoughTextStyle(.rowTitle)
                Spacer()
                Text("Last 6 months")
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.mutedInk)
            }

            VStack(spacing: 0) {
                ForEach(Array(stats.offenders.enumerated()), id: \.element.id) { index, offender in
                    if index > 0 {
                        Divider().overlay(Sourdough.Colors.hairline)
                    }
                    offenderRow(offender)
                }
            }
            .pantryDashboardCard()
        }
    }

    private func offenderRow(_ o: StatsOffender) -> some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            Text(o.initial)
                .sourdoughTextStyle(.rowTitle, color: o.tileInk)
                .frame(width: 30, height: 30)
                .background(o.tileTint)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(o.name.capitalized)
                    .sourdoughTextStyle(.subhead, color: Sourdough.Colors.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Sourdough.Colors.sunken)
                            Capsule().fill(o.barColor)
                                .frame(width: proxy.size.width * CGFloat(min(max(o.rate, 0), 1)))
                        }
                    }
                    .frame(height: 4)
                    Text("\(o.wastedCount) of \(o.boughtCount)")
                        .sourdoughTextStyle(.caption, color: Sourdough.Colors.mutedInk)
                        .fixedSize()
                }
            }

            VStack(alignment: .trailing, spacing: 1) {
                Text(o.wastedCost.asHedgedDollar)
                    .sourdoughTextStyle(.numeric, color: Sourdough.Colors.destructive)
                Text("6-mo cost")
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)
            }
        }
        .padding(.vertical, Sourdough.Spacing.insideChip)
    }

    // MARK: Nudge

    private var liveOffenderMatch: Ingredient? {
        guard let key = stats.offenders.first?.id else { return nil }
        return pantryStore.ingredients.first { $0.name.lowercased() == key && !$0.isExpired }
    }

    private func nudgeRow(_ text: String) -> some View {
        let match = liveOffenderMatch
        return HStack(spacing: Sourdough.Spacing.insideChip) {
            Ph.sparkle.fill
                .frame(width: 12, height: 12)
                .foregroundStyle(Sourdough.Ramp.onFilled)
                .frame(width: 24, height: 24)
                .background(Sourdough.Ramp.sage500)
                .clipShape(Circle())

            Text(text)
                .sourdoughTextStyle(.subhead, color: Sourdough.Ramp.sage700)
                .frame(maxWidth: .infinity, alignment: .leading)

            if match != nil {
                Ph.caretRight.bold
                    .frame(width: 7, height: 12)
                    .foregroundStyle(Sourdough.Ramp.sage500)
            }
        }
        .padding(Sourdough.Spacing.rowInternals)
        .background(Sourdough.Ramp.sage50)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.row, style: .continuous)
                .stroke(Sourdough.Ramp.sage200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.row, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            guard let match else { return }
            session.requestedQuickGenerateIngredientID = match.id
            session.requestedTab = .generate
        }
    }

    // MARK: Empty state

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("Not enough data yet")
                .sourdoughTextStyle(.rowTitle)
            Text("Log what you buy and use — your spending and waste trends show up here after a couple of weeks.")
                .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pantryDashboardCard()
    }

    // MARK: Export

    private func runExport() async {
        guard !isExporting else { return }
        isExporting = true
        let urls = await DataExportService.exportPantryEvents(statsStore: statsStore)
        isExporting = false
        if urls.isEmpty {
            showExportError = true
        } else {
            exportURLs = urls
            showExportShare = true
        }
    }
}

#Preview("Stats section") {
    PreviewContainer {
        ScrollView {
            StatsSection()
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
        }
    }
}
