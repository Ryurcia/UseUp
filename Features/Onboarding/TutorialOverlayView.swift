import SwiftUI

struct TutorialOverlayView: View {
    let addButtonFrame: CGRect
    let onDismiss: () -> Void

    var body: some View {
        let spotlightSize = addButtonFrame.width + 20

        ZStack {
            // Dimmed background with spotlight cutout
            Color.black.opacity(0.6)
                .reverseMask {
                    Circle()
                        .frame(width: spotlightSize, height: spotlightSize)
                        .position(x: addButtonFrame.midX, y: addButtonFrame.midY)
                }

            // Tooltip card
            VStack(spacing: DS.Spacing.space3) {
                Text("Quick Actions")
                    .font(.custom("CalSans-Regular", size: 22))
                    .foregroundStyle(.white)

                Text("Tap + to add ingredients to your pantry or generate a recipe.")
                    .appTextStyle(.bodySM)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                Button(action: onDismiss) {
                    Text("Got it")
                        .font(.custom("Satoshi Variable", size: 15).weight(.bold))
                        .foregroundStyle(DS.ColorToken.accent)
                        .padding(.horizontal, DS.Spacing.space5)
                        .padding(.vertical, DS.Spacing.space2)
                        .background(
                            Capsule()
                                .fill(.white)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, DS.Spacing.space1)
            }
            .padding(DS.Spacing.space5)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .fill(DS.ColorToken.accent.opacity(0.95))
            )
            .padding(.horizontal, DS.Spacing.space5)
            .position(
                x: UIScreen.main.bounds.width / 2,
                y: addButtonFrame.minY - 100
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Reverse Mask

private extension View {
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            Rectangle()
                .ignoresSafeArea()
                .overlay(mask().blendMode(.destinationOut))
        )
    }
}
