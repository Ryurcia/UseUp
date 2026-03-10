import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: DS.Spacing.space4) {
            Text("UseUp")
                .font(.custom("CalSans-Regular", size: 48))
                .kerning(0)
                .foregroundStyle(DS.ColorToken.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.ColorToken.bgSecondary)
    }
}
