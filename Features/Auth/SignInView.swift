import SwiftUI
import PhosphorSwift

struct SignInView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isLoading = false
    @State private var showOTPVerification = false
    @FocusState private var focusedField: SignInField?

    private enum SignInField { case email, password }

    private var canSignIn: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !password.isEmpty
        && !isLoading
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Sourdough.Spacing.screenMargin) {
                    HStack {
                        Button {
                            if focusedField != nil {
                                focusedField = nil
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
                            Text("Welcome Back")
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.display)

                            Text("Sign in to your account to continue")
                                .sourdoughTextStyle(.subhead)
                                .frame(width: proxy.size.width * 0.8, alignment: .leading)
                        }

                        // Email field
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
                                    .focused($focusedField, equals: .email)
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

                        // Password field
                        VStack(alignment: .leading, spacing: Sourdough.Spacing.iconToLabel) {
                            Text("Password")
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.rowTitle)

                            HStack(spacing: Sourdough.Spacing.insideChip) {
                                Ph.lock.regular
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(Sourdough.Colors.faintInk)
                                    .frame(width: 16)

                                Group {
                                    if isPasswordVisible {
                                        TextField("••••••••", text: $password)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                    } else {
                                        SecureField("••••••••", text: $password)
                                    }
                                }
                                .focused($focusedField, equals: .password)
                                .textContentType(.password)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.body)
                                .onChange(of: password) { _, _ in session.authError = nil }

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
                        }

                        // General error banner
                        if let error = session.authError {
                            AuthErrorBanner(message: error)
                        }

                        Button {
                            Task {
                                isLoading = true
                                await session.signIn(
                                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                    password: password
                                )
                                isLoading = false
                                if session.isAuthenticated {
                                    dismiss()
                                } else if session.requiresOTPVerification {
                                    showOTPVerification = true
                                }
                            }
                        } label: {
                            HStack(spacing: Sourdough.Spacing.insideChip) {
                                if isLoading { ProgressView().tint(.white) }
                                Text("Sign In")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true, isDisabled: !canSignIn))
                        .disabled(!canSignIn)

                        VStack(spacing: 2) {
                            Text("By continuing, you agree to our")
                                .foregroundStyle(Sourdough.Colors.mutedInk)
                                .sourdoughTextStyle(.caption)

                            HStack(spacing: 4) {
                                Link("Terms & Conditions", destination: URL(string: AuthLegalLinks.terms)!)
                                    .foregroundStyle(Sourdough.Colors.action)
                                    .sourdoughTextStyle(.caption)
                                Text("and")
                                    .foregroundStyle(Sourdough.Colors.mutedInk)
                                    .sourdoughTextStyle(.caption)
                                Link("Privacy Policy.", destination: URL(string: AuthLegalLinks.privacy)!)
                                    .foregroundStyle(Sourdough.Colors.action)
                                    .sourdoughTextStyle(.caption)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
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
        .fullScreenCover(isPresented: $showOTPVerification) {
            OTPVerificationView(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                .environmentObject(session)
        }
    }
}
