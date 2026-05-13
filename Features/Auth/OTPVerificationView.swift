import SwiftUI

struct OTPVerificationView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let phoneNumber: String
    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @State private var isLoading = false
    @State private var showNicknameOnboarding = false
    @FocusState private var focusedIndex: Int?

    private var otpCode: String {
        otpDigits.joined()
    }

    private var canVerify: Bool {
        otpCode.count == 6 && !isLoading
    }

    var body: some View {
        VStack(spacing: DS.Spacing.space6) {
            Spacer(minLength: 0)

            // Icon
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(DS.ColorToken.primary)
                .padding(.bottom, DS.Spacing.space2)

            // Header
            VStack(spacing: DS.Spacing.space2) {
                Text("Verify Your Number")
                    .font(.custom("CalSans-Regular", size: 32))
                    .kerning(0)
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Text("We sent a 6-digit code to\n\(phoneNumber)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // OTP Fields
            HStack(spacing: DS.Spacing.space2) {
                ForEach(0..<6, id: \.self) { index in
                    otpField(index: index)
                }
            }
            .padding(.vertical, DS.Spacing.space2)

            // Error
            if let error = session.authError {
                Text(error)
                    .appTextStyle(.bodySM)
                    .foregroundStyle(DS.ColorToken.error)
                    .padding(.horizontal, DS.Spacing.space3)
                    .padding(.vertical, DS.Spacing.space2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.ColorToken.errorLight)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
            }

            // Verify button
            Button {
                Task {
                    isLoading = true
                    await session.verifyOTP(phone: phoneNumber, token: otpCode)
                    isLoading = false
                    if session.requiresNicknameOnboarding {
                        showNicknameOnboarding = true
                    } else if session.isAuthenticated {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: DS.Spacing.space2) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Verify")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(size: .lg, fullWidth: true))
            .disabled(!canVerify)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.space5)
        .background(DS.ColorToken.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            focusedIndex = 0
        }
        .fullScreenCover(isPresented: $showNicknameOnboarding) {
            NavigationStack {
                ProfileOnboardingContainerView()
                    .environmentObject(session)
            }
        }
    }

    private func otpField(index: Int) -> some View {
        TextField("", text: $otpDigits[index])
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .multilineTextAlignment(.center)
            .font(.custom("CalSans-Regular", size: 24))
            .foregroundStyle(DS.ColorToken.textPrimary)
            .frame(width: 48, height: 56)
            .background(DS.ColorToken.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(
                        focusedIndex == index ? DS.ColorToken.primary : DS.ColorToken.borderDefault,
                        lineWidth: focusedIndex == index ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .focused($focusedIndex, equals: index)
            .onChange(of: otpDigits[index]) { _, newValue in
                // Filter non-numeric characters
                let filtered = newValue.filter(\.isNumber)
                if filtered != newValue {
                    otpDigits[index] = filtered
                    return
                }

                // Handle paste: distribute digits across fields
                if filtered.count > 1 {
                    distributePastedCode(filtered, startingAt: index)
                    return
                }

                // Auto-advance to next field
                if !filtered.isEmpty && index < 5 {
                    focusedIndex = index + 1
                }

                // Continuous backspace: move focus to previous cell
                if filtered.isEmpty && index > 0 {
                    focusedIndex = index - 1
                }
            }
    }

    private func distributePastedCode(_ code: String, startingAt: Int) {
        let digits = Array(code.prefix(6 - startingAt))
        for (offset, digit) in digits.enumerated() {
            let targetIndex = startingAt + offset
            if targetIndex < 6 {
                otpDigits[targetIndex] = String(digit)
            }
        }
        let nextIndex = min(startingAt + digits.count, 5)
        focusedIndex = nextIndex
    }
}
