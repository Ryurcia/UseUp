import SwiftUI

struct AIGeneratedBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
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
