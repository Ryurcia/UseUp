import SwiftUI

/// "Sourdough" design system v1 — buttons (§5). 44pt minimum hit target everywhere.
///
/// Note: `.foregroundStyle(_:)` must be applied BEFORE `.sourdoughTextStyle(_:)` in each of these —
/// SwiftUI resolves environment values (like foreground style) from the nearest ancestor to the
/// leaf, so whichever modifier sits closer to the `Text` wins. `sourdoughTextStyle` bakes in a
/// default ink color, so it must be the outer (later-applied) wrapper for a caller's explicit
/// color choice — applied first, closer to the leaf — to actually take effect.
extension Sourdough {
    /// Filled CTA. Background = `action`, pressed = `actionInk`, disabled = linen300/linen400.
    struct PrimaryButtonStyle: ButtonStyle {
        var fullWidth = false
        var isDisabled = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(isDisabled ? Sourdough.Ramp.linen400 : Sourdough.Colors.onAction)
                .sourdoughTextStyle(.rowTitle)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(minHeight: 52)
                .padding(.horizontal, Sourdough.Spacing.rowInternals + 8)
                .background(backgroundColor(isPressed: configuration.isPressed))
                .clipShape(Capsule())
                .opacity(isDisabled ? 0.7 : 1)
        }

        private func backgroundColor(isPressed: Bool) -> Color {
            if isDisabled { return Sourdough.Ramp.linen300 }
            return isPressed ? Sourdough.Colors.actionPressed : Sourdough.Colors.action
        }
    }

    /// Outline secondary button ("Add to list" style) — bg `card`, border `interactiveBorder`.
    struct SecondaryButtonStyle: ButtonStyle {
        var fullWidth = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.rowTitle)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(minHeight: 52)
                .padding(.horizontal, Sourdough.Spacing.rowInternals + 8)
                .background(Sourdough.Colors.card)
                .overlay(
                    Capsule().stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
                )
                .clipShape(Capsule())
                .opacity(configuration.isPressed ? 0.82 : 1)
        }
    }

    /// Text/link button. Always `actionInk` (terracotta600) — never the terracotta500 base, which
    /// fails contrast as body-sized text.
    struct TextButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(Sourdough.Colors.actionInk)
                .sourdoughTextStyle(.rowTitle)
                .frame(minHeight: 44)
                .opacity(configuration.isPressed ? 0.6 : 1)
        }
    }

    /// Destructive text variant (delete/discard only) — deliberately darker than brand so it never
    /// reads as a CTA.
    struct DestructiveTextButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(Sourdough.Colors.destructive)
                .sourdoughTextStyle(.rowTitle)
                .frame(minHeight: 44)
                .opacity(configuration.isPressed ? 0.6 : 1)
        }
    }
}
