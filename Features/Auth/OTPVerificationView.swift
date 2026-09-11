import SwiftUI
import PhosphorSwift

struct OTPVerificationView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let email: String
    var onboardingAnswers: OnboardingAnswers? = nil
    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @State private var isLoading = false
    @State private var showRetryFinish = false
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

            OTPCodeGrid(digits: $otpDigits, focusedIndex: $focusedIndex)
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
                        if !showRetrySave {
                            await finishAccountSetupIfNeeded()
                        }
                        isLoading = false
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
            } else if showRetryFinish {
                if let error = session.nicknameError {
                    AuthErrorBanner(message: error)
                }

                Button {
                    Task {
                        isLoading = true
                        await finishAccountSetupIfNeeded()
                        isLoading = false
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
                        if !showRetrySave {
                            await finishAccountSetupIfNeeded()
                        }
                        isLoading = false
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
    }

    /// If the profile still needs a username/display-name finalized (e.g. a pre-existing account
    /// with no `nickname`, reached via sign-in rather than fresh onboarding), auto-generates a
    /// `chef_[id]` username and applies a display-name fallback chain — no manual entry screen.
    private func finishAccountSetupIfNeeded() async {
        if session.requiresNicknameOnboarding {
            await session.finalizeAccountSetup(displayName: onboardingAnswers?.preferredName ?? "")
        }
        if session.isAuthenticated {
            dismiss()
        } else if session.nicknameError != nil {
            showRetryFinish = true
        }
    }
}
