import SwiftUI

/// Reusable 6-box OTP code-entry grid — extracted from `OTPVerificationView` so the password-reset
/// flow can reuse the same input widget without duplicating the paste-distribute/focus-advance
/// logic. Purely a UI component: no auth semantics, just a `[String]` digit binding.
struct OTPCodeGrid: View {
    @Binding var digits: [String]
    var focusedIndex: FocusState<Int?>.Binding

    var body: some View {
        HStack(spacing: Sourdough.Spacing.insideChip) {
            ForEach(0..<digits.count, id: \.self) { index in
                field(index: index)
            }
        }
    }

    private func field(index: Int) -> some View {
        TextField("", text: $digits[index])
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .multilineTextAlignment(.center)
            .font(Font(Sourdough.SDFont.uiFont(family: .figtree, size: 24, weight: 700) as CTFont))
            .monospacedDigit()
            .foregroundStyle(Sourdough.Colors.ink)
            .frame(width: 48, height: 56)
            .background(Sourdough.Colors.sunken)
            .overlay(
                RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                    .stroke(
                        focusedIndex.wrappedValue == index ? Sourdough.Colors.action : Sourdough.Colors.interactiveBorder,
                        lineWidth: focusedIndex.wrappedValue == index ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
            .focused(focusedIndex, equals: index)
            .onChange(of: digits[index]) { _, newValue in
                let filtered = newValue.filter(\.isNumber)
                if filtered != newValue {
                    digits[index] = filtered
                    return
                }
                if filtered.count > 1 {
                    distributePastedCode(filtered, startingAt: index)
                    return
                }
                if !filtered.isEmpty && index < digits.count - 1 {
                    focusedIndex.wrappedValue = index + 1
                }
                if filtered.isEmpty && index > 0 {
                    focusedIndex.wrappedValue = index - 1
                }
            }
    }

    private func distributePastedCode(_ code: String, startingAt: Int) {
        let digitsCount = digits.count
        let pasted = Array(code.prefix(digitsCount - startingAt))
        for (offset, digit) in pasted.enumerated() {
            let targetIndex = startingAt + offset
            if targetIndex < digitsCount { digits[targetIndex] = String(digit) }
        }
        focusedIndex.wrappedValue = min(startingAt + pasted.count, digitsCount - 1)
    }
}
