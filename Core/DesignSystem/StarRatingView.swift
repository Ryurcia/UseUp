import SwiftUI
import PhosphorSwift

struct StarRatingView: View {
    let rating: Double
    var size: CGFloat = 16
    var interactive: Bool = false
    var onRate: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: size * 0.1) {
            ForEach(1...5, id: \.self) { index in
                starImage(for: index)
                    .frame(width: size, height: size)
                    .foregroundStyle(index <= Int(rating.rounded(.up)) && rating > 0 ? DS.ColorToken.warning : DS.ColorToken.textTertiary)
                    .onTapGesture {
                        if interactive {
                            onRate?(index)
                        }
                    }
            }
        }
    }

    private func starImage(for index: Int) -> Image {
        let floor = Int(rating)
        let hasHalf = rating - Double(floor) >= 0.25 && rating - Double(floor) < 0.75

        if index <= floor {
            return Ph.star.fill
        } else if index == floor + 1 && hasHalf {
            return Ph.starHalf.regular
        } else {
            return Ph.star.regular
        }
    }
}
