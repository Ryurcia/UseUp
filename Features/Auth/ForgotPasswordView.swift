import SwiftUI
import PhosphorSwift

/// Entry point for password reset — collects the account email and triggers Supabase's recovery
/// email (which contains a 6-digit code, same mechanism as sign-up email confirmation). Presented
/// from `SignInView`.
struct ForgotPasswordView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var isLoading = false
    @FocusState private var isEmailFocused: Bool

    init(email: String = "") {
        _email = State(initialValue: email)
    }

    private var canContinue: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Sourdough.Spacing.screenMargin) {
                    HStack {
                        Button {
                            if isEmailFocused {
                                isEmailFocused = false
                            } else {
                                dismiss()
                            }
                        } label: {
                            Ph.caretLeft.regular
                                .frame(width: 16, height: 16)
                                .foregroundStyle(Sourdough.Colors.ink)
                                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                                .padding(.vertical, Sourdough.Spacing.insideChip)
                                .background(Sourdough.Colors.sunken)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(AuthBackButtonStyle())

                        Spacer()
                    }
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.top, Sourdough.Spacing.insideChip)
                    .padding(.bottom, Sourdough.Spacing.betweenBlocks)

                    VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
                        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                            Text("Forgot Password")
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.display)

                            Text("Enter your email and we'll send you a code to reset your password")
                                .sourdoughTextStyle(.subhead)
                                .frame(width: proxy.size.width * 0.8, alignment: .leading)
                        }

                        VStack(alignment: .leading, spacing: Sourdough.Spacing.iconToLabel) {
                            Text("Email")
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.rowTitle)

                            HStack(spacing: Sourdough.Spacing.insideChip) {
                                Ph.envelope.regular
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(Sourdough.Colors.faintInk)
                                    .frame(width: 16)

                                TextField("you@example.com", text: $email)
                                    .focused($isEmailFocused)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(Sourdough.Colors.ink)
                                    .sourdoughTextStyle(.body)
                                    .onChange(of: email) { _, _ in session.emailError = nil }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 52)
                            .background(Sourdough.Colors.sunken)
                            .overlay(
                                RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                                    .stroke(
                                        session.emailError != nil ? Sourdough.Colors.destructive : Sourdough.Colors.interactiveBorder,
                                        lineWidth: session.emailError != nil ? 1.5 : 1
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

                            if let error = session.emailError {
                                Label {
                                    Text(error)
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
                                await session.requestPasswordReset(
                                    email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                                )
                                isLoading = false
                            }
                        } label: {
                            HStack(spacing: Sourdough.Spacing.insideChip) {
                                if isLoading { ProgressView().tint(.white) }
                                Text("Send Code")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true, isDisabled: !canContinue))
                        .disabled(!canContinue)
                    }
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)

                    Spacer(minLength: 0)
                }
                .frame(minHeight: proxy.size.height)
            }
        }
        .modifier(FastTapScrollModifier())
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .background(SwipeBackEnabler())
        .fullScreenCover(isPresented: $session.passwordResetEmailSent) {
            ResetPasswordView(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                .environmentObject(session)
        }
    }
}
