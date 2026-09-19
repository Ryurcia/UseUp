import SwiftUI

// MARK: - Stacked bar chart

/// Each bar is one period's grocery spend, split into eaten (sage, bottom) and binned (terracotta,
/// top). Tapping a column selects it — the parent re-derives the headline figures + donut to that
/// period. Selected column keeps full-strength fill; the rest drop to 55% opacity (the palette
/// stays two colours).
struct StatsBarChart: View {
    let stats: PeriodStats
    /// `false` for static renders (the PDF report) — the grow-in never applies in `ImageRenderer`.
    var animated: Bool = true
    let onSelectBar: (Int) -> Void

    private let maxBarPixels: CGFloat = 88
    private let barAreaHeight: CGFloat = 92

    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let eaten = Sourdough.Ramp.sage200
    private let binned = Sourdough.Ramp.terracotta500

    var body: some View {
        HStack(alignment: .bottom, spacing: stats.period.barGap) {
            ForEach(stats.bars) { bar in
                let selected = bar.id == stats.selectedIndex
                let heights = barHeights(for: bar)

                VStack(spacing: 0) {
                    Text(selected ? bar.spend.asHedgedDollar : " ")
                        .sourdoughTextStyle(.caption, color: Sourdough.Colors.mutedInk)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(height: 13)
                        .padding(.bottom, 4)

                    VStack(spacing: heights.waste > 0 && heights.eaten > 0 ? 1 : 0) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(binned)
                            .frame(height: heights.waste)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(eaten)
                            .frame(height: heights.eaten)
                    }
                    .opacity(selected ? 1 : 0.55)
                    .scaleEffect(x: 1, y: (grown || !animated) ? 1 : 0, anchor: .bottom)
                    .frame(height: barAreaHeight, alignment: .bottom)

                    Text(bar.label)
                        .sourdoughTextStyle(.caption, color: selected ? Sourdough.Colors.ink : Sourdough.Colors.faintInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 5)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onSelectBar(bar.id) }
            }
        }
        .onAppear {
            guard animated, !grown else { return }
            if reduceMotion { grown = true; return }
            withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.5)) { grown = true }
        }
    }

    private func barHeights(for bar: StatsBar) -> (eaten: CGFloat, waste: CGFloat) {
        guard bar.spend > 0 else { return (0, 0) }
        let scale = maxBarPixels / CGFloat(stats.peakSpend)
        let total = CGFloat(bar.spend) * scale
        let waste = bar.waste > 0 ? max(3, CGFloat(bar.waste) * scale) : 0
        let eaten = max(3, total - waste)

        // bar.waste isn't bounded by bar.spend (an item bought in an earlier period can
        // be wasted in this one), so the combined height can exceed maxBarPixels even
        // though `total` alone never does. Scale both segments down together so the bar
        // never pokes out past the chart's peak reference line.
        let combined = eaten + waste
        guard combined > maxBarPixels else { return (eaten, waste) }
        let overflowScale = maxBarPixels / combined
        return (eaten * overflowScale, waste * overflowScale)
    }
}

// MARK: - Donut

/// Hand-built 5-arc ring — no Charts framework. Tapping a legend row (in the parent) isolates a
/// category: that arc stays full-strength and thickens, the rest fade to 30%.
struct StatsDonut: View {
    let slices: [StatsSlice]
    let isolatedIndex: Int?
    let centre: (figure: String, label: String)

    private let diameter: CGFloat = 104
    private let baseWidth: CGFloat = 16
    private let isolatedWidth: CGFloat = 20

    private var total: Double { max(slices.reduce(0) { $0 + $1.amount }, 0.0001) }

    var body: some View {
        ZStack {
            ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                let fraction = slice.amount / total
                let start = slices.prefix(index).reduce(0.0) { $0 + $1.amount / total }
                let isolated = isolatedIndex == index
                let dimmed = isolatedIndex != nil && !isolated

                Circle()
                    .trim(from: start, to: min(start + fraction, 1))
                    .stroke(
                        slice.color,
                        style: StrokeStyle(lineWidth: isolated ? isolatedWidth : baseWidth, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
                    .opacity(dimmed ? 0.3 : 1)
            }

            VStack(spacing: 3) {
                Text(centre.figure)
                    .sourdoughTextStyle(.title2, color: isolatedIndex == nil ? Sourdough.Colors.ink : Sourdough.Colors.destructive)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(centre.label)
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 64)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}
