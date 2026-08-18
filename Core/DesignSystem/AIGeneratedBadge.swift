import SwiftUI
import PhosphorSwift

struct AIGeneratedBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Ph.sparkle.regular
                .frame(width: 10, height: 10)
            Text("AI Generated")
                .font(.custom("Satoshi Variable", size: 11).weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
    }
}
