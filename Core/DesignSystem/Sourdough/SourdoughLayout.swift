import SwiftUI

/// "Sourdough" design system v1 — spacing, radii, elevation (§4).
extension Sourdough {
    /// Fixed 8pt-grid step tokens, named by their canonical usage rather than numbered — reach for
    /// the name matching what you're spacing, not an arbitrary value.
    enum Spacing {
        static let iconToLabel: CGFloat = 4
        static let insideChip: CGFloat = 8
        static let rowInternals: CGFloat = 12
        static let screenMargin: CGFloat = 16
        static let betweenBlocks: CGFloat = 24
        static let aboveSectionHead: CGFloat = 32
        static let underTitle: CGFloat = 48
    }

    /// Corner radii. Nothing squarer than 8, nothing squircle-heavy except pill controls —
    /// "soft but not bubbly."
    enum Radius {
        static let thumbnail: CGFloat = 8
        static let input: CGFloat = 8
        static let tile: CGFloat = 12       // item tiles
        static let row: CGFloat = 16        // list rows
        static let card: CGFloat = 16
        static let sheet: CGFloat = 22
        static let hero: CGFloat = 22        // hero cards
        static let pill: CGFloat = 9_999     // chips, buttons
    }

    /// 3 elevation levels only. Shadows are brown-tinted (derived from linen900), never neutral
    /// grey — a grey shadow on this warm palette reads dirty. No drop shadows in dark mode;
    /// elevation there is conveyed purely by surface lightness (card vs. canvas).
    enum Elevation {
        case hairline // rows, cards — border only, no shadow
        case lifted   // shadow 0/6/14/-8 @ 30%
        case sheet    // shadow 0/18/34/-20 @ 42%
    }
}

private struct SourdoughElevationModifier: ViewModifier {
    let level: Sourdough.Elevation
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        switch level {
        case .hairline:
            content.overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Sourdough.Colors.hairline, lineWidth: 1)
            )
        case .lifted:
            // CSS "0 6 14 -8 @30%" ported to SwiftUI's (radius, x, y) shadow model — spread isn't
            // directly representable, approximated by radius ≈ blur/2.
            content.shadow(color: shadowTint(opacity: 0.30), radius: 7, x: 0, y: 6)
        case .sheet:
            content.shadow(color: shadowTint(opacity: 0.42), radius: 17, x: 0, y: 18)
        }
    }

    private func shadowTint(opacity: Double) -> Color {
        colorScheme == .dark ? .clear : Sourdough.Ramp.linen900.opacity(opacity)
    }
}

extension View {
    /// Applies one of the 3 Sourdough elevation levels. `cornerRadius` only matters for
    /// `.hairline` (used to draw a matching border) — shadow levels follow the view's silhouette.
    func sourdoughElevation(_ level: Sourdough.Elevation, cornerRadius: CGFloat = Sourdough.Radius.card) -> some View {
        modifier(SourdoughElevationModifier(level: level, cornerRadius: cornerRadius))
    }
}
