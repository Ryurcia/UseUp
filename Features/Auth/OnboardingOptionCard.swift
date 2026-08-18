import SwiftUI
import PhosphorSwift

struct OnboardingOptionCard: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                Text(label)
                    .foregroundStyle(isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.ink)
                    .sourdoughTextStyle(.body)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isSelected {
                    Ph.checkCircle.fill
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Sourdough.Colors.onAction)
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.vertical, Sourdough.Spacing.screenMargin)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(isSelected ? Sourdough.Ramp.sage500 : Sourdough.Colors.sunken)
            .overlay(
                RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous)
                    .stroke(isSelected ? Color.clear : Sourdough.Colors.interactiveBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
