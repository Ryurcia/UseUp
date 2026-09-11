import SwiftUI
import PhosphorSwift

/// Pushed edit screen for changing the account email — a single staged screen (mirrors
/// `ResetPasswordView`'s combined-steps approach): enter the new address, send a code, then verify
/// it with the shared `OTPCodeGrid` (from the password-reset feature) before it takes effect.
struct ChangeEmailView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var newEmail = ""
    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @State private var isLoading = false
    @FocusState private var isEmailFocused: Bool
    @FocusState private var focusedIndex: Int?

    private var otpCode: String {
        otpDigits.joined()
    }

    private var canSendCode: Bool {
        !isLoading && !newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canVerify: Bool {
        !isLoading && otpCode.count == 6
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            Text("Current: \(session.currentUserEmail ?? "No email")")
                .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)

            TextField("New email", text: $newEmail)
                .focused($isEmailFocused)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .sourdoughTextStyle(.body)
                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                .frame(height: 52)
                .background(Sourdough.Colors.sunken)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                .disabled(session.emailChangeCodeSent)
                .opacity(session.emailChangeCodeSent ? 0.5 : 1)
                .onChange(of: newEmail) { _, _ in session.authError = nil }

            if session.emailChangeCodeSent {
                Text("Enter the 6-digit code sent to \(newEmail)")
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)
                    .padding(.top, Sourdough.Spacing.insideChip)

                OTPCodeGrid(digits: $otpDigits, focusedIndex: $focusedIndex)
                    .padding(.vertical, Sourdough.Spacing.insideChip)
            }

            if let error = session.authError {
                Text(error)
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.destructive)
            }

            if session.emailChangeCodeSent {
                Button {
                    Task {
                        isLoading = true
                        await session.verifyEmailChangeOTP(token: otpCode)
                        isLoading = false
                        if session.authError == nil {
                            dismiss()
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
            } else {
                Button {
                    Task {
                        isLoading = true
                        await session.requestEmailChange(
                            newEmail: newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        isLoading = false
                        if session.authError == nil {
                            focusedIndex = 0
                        }
                    }
                } label: {
                    HStack(spacing: Sourdough.Spacing.insideChip) {
                        if isLoading { ProgressView().tint(.white) }
                        Text("Send Code")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true, isDisabled: !canSendCode))
                .disabled(!canSendCode)
            }

            Spacer()
        }
        .padding(Sourdough.Spacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Sourdough.Colors.canvas)
        .navigationTitle("Change Email")
        .navigationBarTitleDisplayMode(.inline)
        .preference(key: HideTabBarKey.self, value: true)
        .onAppear {
            session.authError = nil
            // Always start fresh — a prior incomplete attempt (backed out before verifying)
            // shouldn't leave this screen stuck showing the code step with an empty email.
            session.emailChangeCodeSent = false
            session.pendingNewEmail = nil
        }
    }
}
