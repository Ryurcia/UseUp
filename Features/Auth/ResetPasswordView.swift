import SwiftUI
import PhosphorSwift

/// Combined code-entry + new-password screen — one round trip instead of two separate screens.
/// Presented from `ForgotPasswordView` once the recovery email has been sent.
struct ResetPasswordView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let email: String

    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isLoading = false
    @FocusState private var focusedIndex: Int?
    @FocusState private var isPasswordFieldFocused: Bool

    private var otpCode: String {
        otpDigits.joined()
    }

    private var passwordsMismatch: Bool {
        !confirmPassword.isEmpty && newPassword != confirmPassword
    }

    private var canSubmit: Bool {
        otpCode.count == 6
        && newPassword.count >= 6
        && newPassword == confirmPassword
        && !isLoading
    }

    var body: some View {
        VStack(spacing: Sourdough.Spacing.betweenBlocks) {
            Spacer(minLength: 0)

            Ph.lock.regular
                .frame(width: 48, height: 48)
                .foregroundStyle(Sourdough.Colors.actionInk)
                .padding(.bottom, Sourdough.Spacing.insideChip)

            VStack(spacing: Sourdough.Spacing.insideChip) {
                Text("Reset Your Password")
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.display)

                Text("Enter the 6-digit code sent to\n\(email) and choose a new password")
                    .sourdoughTextStyle(.subhead)
                    .multilineTextAlignment(.center)
            }

            OTPCodeGrid(digits: $otpDigits, focusedIndex: $focusedIndex)
                .padding(.vertical, Sourdough.Spacing.insideChip)

            // New password field
            VStack(alignment: .leading, spacing: Sourdough.Spacing.iconToLabel) {
                HStack(spacing: Sourdough.Spacing.insideChip) {
                    Ph.lock.regular
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                        .frame(width: 16)

                    Group {
                        if isPasswordVisible {
                            TextField("New password", text: $newPassword)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("New password", text: $newPassword)
                        }
                    }
                    .focused($isPasswordFieldFocused)
                    .textContentType(.newPassword)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.body)
                    .onChange(of: newPassword) { _, _ in session.authError = nil }

                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        (isPasswordVisible ? Ph.eyeSlash.regular : Ph.eye.regular)
                            .frame(width: 14, height: 14)
                            .foregroundStyle(Sourdough.Colors.faintInk)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .frame(height: 52)
                .background(Sourdough.Colors.sunken)
                .overlay(
                    RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                        .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

                HStack(spacing: Sourdough.Spacing.insideChip) {
                    Ph.lock.regular
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                        .frame(width: 16)

                    SecureField("Confirm new password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.body)
                        .onChange(of: confirmPassword) { _, _ in session.authError = nil }
                }
                .padding(.horizontal, 12)
                .frame(height: 52)
                .background(Sourdough.Colors.sunken)
                .overlay(
                    RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                        .stroke(
                            passwordsMismatch ? Sourdough.Colors.destructive : Sourdough.Colors.interactiveBorder,
                            lineWidth: passwordsMismatch ? 1.5 : 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

                if passwordsMismatch {
                    Label {
                        Text("Passwords don't match.")
                    } icon: {
                        Ph.warningCircle.fill
                            .frame(width: 14, height: 14)
                    }
                    .foregroundStyle(Sourdough.Colors.destructive)
                    .sourdoughTextStyle(.subhead)
                    .padding(.horizontal, Sourdough.Spacing.iconToLabel)
                }
            }

            if let error = session.authError {
                AuthErrorBanner(message: error)
            }

            Button {
                Task {
                    isLoading = true
                    if !session.requiresNewPassword {
                        await session.verifyPasswordResetOTP(email: email, token: otpCode)
                    }
                    if session.requiresNewPassword {
                        await session.resetPassword(newPassword: newPassword)
                    }
                    isLoading = false
                }
            } label: {
                HStack(spacing: Sourdough.Spacing.insideChip) {
                    if isLoading { ProgressView().tint(.white) }
                    Text("Reset Password")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true, isDisabled: !canSubmit))
            .disabled(!canSubmit)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { focusedIndex = 0 }
    }
}
