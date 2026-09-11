import SwiftUI
import UIKit

extension Sourdough {
    /// Animates a numeric value toward `value` whenever it changes under `withAnimation` at the
    /// call site, via `Animatable` frame interpolation. Used by the onboarding reveal/pitch
    /// screens for their big dollar figures.
    struct CountUpText: View, Animatable {
        var value: Double
        var content: (Double) -> Text

        var animatableData: Double {
            get { value }
            set { value = newValue }
        }

        var body: some View {
            content(value)
                .monospacedDigit()
        }
    }

    /// Steps a value from 0 to `target` over `duration`, firing a light haptic tick on each step —
    /// gives a count-up a felt "ticking" cadence rather than a silent continuous interpolation.
    /// Call from `.onAppear`: `Sourdough.animatedCountUp(to: target) { animatedValue = $0 }`.
    static func animatedCountUp(to target: Double, steps: Int = 24, duration: Double = 1.0, update: @escaping (Double) -> Void) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        let stepDuration = duration / Double(steps)
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                withAnimation(.linear(duration: stepDuration)) {
                    update(target * (Double(step) / Double(steps)))
                }
                generator.impactOccurred()
            }
        }
    }
}

extension Sourdough.CountUpText {
    /// Convenience for the common case: the whole value renders as one plain formatted string
    /// (no mixed styling). Use the `content:` initializer directly when a value needs to sit
    /// inside a larger `Text` built by `+`-concatenation (bold/colored inline spans, etc).
    init(value: Double, format: @escaping (Double) -> String) {
        self.init(value: value, content: { Text(format($0)) })
    }
}

extension Double {
    /// "$1,234" — whole dollars, thousands-separated. Onboarding figures are estimates, no cents.
    var asWholeDollarString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "$\(Int(self))"
    }

    /// "$1,284.53" — dollars and cents, thousands-separated. For exact figures (pantry value).
    var asExactDollarString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "$%.2f", self)
    }

    /// "~$284" / "~$4.60" — a `~`-hedged dollar figure for the Stats screen, where every amount is
    /// derived from AI cost estimates rather than receipts. Cents only below $100 (small category /
    /// per-item figures); whole dollars above.
    var asHedgedDollar: String {
        "~" + (abs(self) < 100 ? asExactDollarString : asWholeDollarString)
    }

    /// "1,234" — thousands-separated, no currency symbol. For layouts that style the `$` prefix
    /// separately from the digits (e.g. the reveal screens' hero number).
    var asWholeNumberString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
    }
}
