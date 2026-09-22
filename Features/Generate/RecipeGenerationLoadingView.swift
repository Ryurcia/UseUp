import SwiftUI
import Lottie

/// The recipe-generation loading state — the `LOADING_ANIMATION` Lottie loop with utensils tinted
/// to the current scheme, plus a rotating phrase. Shared by `GenerateView` and `SnapChefFlow`.
struct RecipeGenerationLoadingView: View {
    var onCancel: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var phraseIndex = 0

    private static let phrases: [String] = [
        "Let me cook...",
        "Checking your pantry...",
        "Crafting the perfect dishes...",
        "Balancing the flavors...",
        "Almost ready...",
    ]

    /// `Sourdough.Colors.ink` resolved for the active scheme — Lottie value providers take a fixed
    /// color, so this is recomputed and re-applied when `colorScheme` flips.
    private var utensilColor: Lottie.LottieColor {
        UIColor(Sourdough.Colors.ink)
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light))
            .lottieColorValue
    }

    var body: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            Spacer()

            LottieView(animation: .named("LOADING_ANIMATION"))
                .playing(loopMode: .loop)
                .valueProvider(ColorValueProvider(utensilColor), for: "Fork.**.Stroke 1.Color")
                .valueProvider(ColorValueProvider(utensilColor), for: "Spoon.**.Stroke 1.Color")
                .valueProvider(ColorValueProvider(utensilColor), for: "Spoon.**.Fill 1.Color")
                .valueProvider(ColorValueProvider(utensilColor), for: "Spoon 2.**.Stroke 1.Color")
                .valueProvider(ColorValueProvider(utensilColor), for: "Spoon 2.**.Fill 1.Color")
                .id(colorScheme)
                .frame(width: 300, height: 300)
                .padding(.bottom, -60)

            Text(Self.phrases[phraseIndex])
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.title2)
                .id(phraseIndex)
                .transition(.opacity)

            Text("Finding the best dishes from your ingredients")
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.body)
                .multilineTextAlignment(.center)

            if let onCancel {
                Button(action: onCancel) {
                    Text("Cancel")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.rowTitle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                        .overlay(
                            RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                                .stroke(Sourdough.Colors.ink, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, Sourdough.Spacing.rowInternals)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .task {
            phraseIndex = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.4)) {
                    phraseIndex = (phraseIndex + 1) % Self.phrases.count
                }
            }
        }
    }
}
