import SwiftUI

/// Grow-in bar primitives for the onboarding reveal/pitch screens' evidence charts (spend
/// breakdown, waste bag chart, savings comparisons) — mirrors the Money Reveal design's
/// `bar-grow-h`/`bar-grow-v` CSS animations, timed to land just after a preceding count-up.
extension Sourdough {
    /// Horizontal capsule track + fill, growing in from the leading edge on appear.
    struct AnimatedBarH: View {
        var fraction: Double
        var fill: Color
        var track: Color = Sourdough.Colors.sunken
        var height: CGFloat = 6
        var delay: Double = 0
        @State private var grown = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(track)
                    Capsule()
                        .fill(fill)
                        .frame(width: geo.size.width * fraction)
                        .scaleEffect(x: grown ? 1 : 0, y: 1, anchor: .leading)
                }
            }
            .frame(height: height)
            .onAppear { grow() }
        }

        private func grow() {
            guard !grown else { return }
            if reduceMotion {
                grown = true
                return
            }
            withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.55).delay(delay)) {
                grown = true
            }
        }
    }

    /// A fixed-height vertical bar, growing in from the baseline on appear.
    struct AnimatedBarV: View {
        var fill: Color
        var border: Color
        var height: CGFloat
        var delay: Double = 0
        @State private var grown = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(border, lineWidth: 1)
                )
                .frame(height: height)
                .scaleEffect(x: 1, y: grown ? 1 : 0, anchor: .bottom)
                .onAppear { grow() }
        }

        private func grow() {
            guard !grown else { return }
            if reduceMotion {
                grown = true
                return
            }
            withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.48).delay(delay)) {
                grown = true
            }
        }
    }
}
