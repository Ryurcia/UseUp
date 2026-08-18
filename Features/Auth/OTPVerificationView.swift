import SwiftUI
import PhosphorSwift

struct OTPVerificationView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let email: String
    var onboardingAnswers: OnboardingAnswers? = nil
    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @State private var isLoading = false
    @State private var showNicknameOnboarding = false
    @State private var showRetrySave = false
    @FocusState private var focusedIndex: Int?

    private var otpCode: String {
        otpDigits.joined()
    }

    private var canVerify: Bool {
        otpCode.count == 6 && !isLoading
    }

    var body: some View {
        VStack(spacing: Sourdough.Spacing.betweenBlocks) {
            Spacer(minLength: 0)

            Ph.envelope.regular
                .frame(width: 48, height: 48)
                .foregroundStyle(Sourdough.Colors.actionInk)
                .padding(.bottom, Sourdough.Spacing.insideChip)

            VStack(spacing: Sourdough.Spacing.insideChip) {
                Text("Verify Your Email")
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.display)

                Text("We sent a 6-digit code to\n\(email)")
                    .sourdoughTextStyle(.subhead)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: Sourdough.Spacing.insideChip) {
                ForEach(0..<6, id: \.self) { index in
                    otpField(index: index)
                }
            }
            .padding(.vertical, Sourdough.Spacing.insideChip)

            if let error = session.authError {
                AuthErrorBanner(message: error)
            }

            if showRetrySave {
                if let error = session.onboardingSaveError {
                    AuthErrorBanner(message: error)
                }

                Button {
                    Task {
                        isLoading = true
                        if let onboardingAnswers {
                            let saved = await session.saveOnboardingAnswers(onboardingAnswers)
                            showRetrySave = !saved
                        }
                        isLoading = false
                        if !showRetrySave {
                            if session.requiresNicknameOnboarding {
                                showNicknameOnboarding = true
                            } else if session.isAuthenticated {
                                dismiss()
                            }
                        }
                    }
                } label: {
                    HStack(spacing: Sourdough.Spacing.insideChip) {
                        if isLoading { ProgressView().tint(.white) }
                        Text("Retry")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true, isDisabled: isLoading))
                .disabled(isLoading)
            } else {
                Button {
                    Task {
                        isLoading = true
                        await session.verifyEmailOTP(email: email, token: otpCode)
                        if session.authError == nil, let onboardingAnswers {
                            let saved = await session.saveOnboardingAnswers(onboardingAnswers)
                            showRetrySave = !saved
                        }
                        isLoading = false
                        if !showRetrySave {
                            if session.requiresNicknameOnboarding {
                                showNicknameOnboarding = true
                            } else if session.isAuthenticated {
                                dismiss()
                            }
                        }
                    }
                } label: {
                    HStack(spacing: Sourdough.Spacing.insideChip) {
                        if isLoading { ProgressView().tint(.white) }
                        Text("Verify")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true, isDisabled: !canVerify))
                .disabled(!canVerify)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { focusedIndex = 0 }
        .fullScreenCover(isPresented: $showNicknameOnboarding) {
            NavigationStack {
                NicknameSetupView()
                    .environmentObject(session)
            }
        }
    }

    private func otpField(index: Int) -> some View {
        TextField("", text: $otpDigits[index])
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
                        focusedIndex == index ? Sourdough.Colors.action : Sourdough.Colors.interactiveBorder,
                        lineWidth: focusedIndex == index ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
            .focused($focusedIndex, equals: index)
            .onChange(of: otpDigits[index]) { _, newValue in
                let filtered = newValue.filter(\.isNumber)
                if filtered != newValue {
                    otpDigits[index] = filtered
                    return
                }
                if filtered.count > 1 {
                    distributePastedCode(filtered, startingAt: index)
                    return
                }
                if !filtered.isEmpty && index < 5 {
                    focusedIndex = index + 1
                }
                if filtered.isEmpty && index > 0 {
                    focusedIndex = index - 1
                }
            }
    }

    private func distributePastedCode(_ code: String, startingAt: Int) {
        let digits = Array(code.prefix(6 - startingAt))
        for (offset, digit) in digits.enumerated() {
            let targetIndex = startingAt + offset
            if targetIndex < 6 { otpDigits[targetIndex] = String(digit) }
        }
        focusedIndex = min(startingAt + digits.count, 5)
    }
}
