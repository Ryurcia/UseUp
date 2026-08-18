import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Image("GetStarted")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            Color.black.opacity(0.60)
                .ignoresSafeArea()

            VStack(spacing: Sourdough.Spacing.rowInternals) {
                Text("UseUp")
                    .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                    .sourdoughTextStyle(.display)

                Text("Use what you have.")
                    .foregroundStyle(Sourdough.Colors.heroMetaOnDark)
                    .sourdoughTextStyle(.body)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
