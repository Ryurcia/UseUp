import SwiftUI
import PhosphorSwift

#Preview("Auth") {
    PreviewContainer(authenticated: false) {
        NavigationStack {
            AuthView()
                .environmentObject(OnboardingAnswers())
        }
    }
}

struct AuthView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    @Environment(\.dismiss) private var dismiss
    var onBack: (() -> Void)? = nil

    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isLoading = false
    @State private var showRetrySave = false
    @State private var showRetryFinish = false
    @State private var showOTPVerification = false
    @FocusState private var focusedField: AuthField?

    private enum AuthField { case email, password }

    private var canContinue: Bool {
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
                            } else if let onBack {
                                onBack()
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
                            Text("Create Account")
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.display)

                            Text("Enter your email and choose a password to get started")
                                .sourdoughTextStyle(.subhead)
                                .frame(width: proxy.size.width * 0.8, alignment: .leading)

                            Text("Create your account to save your profile.")
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
                                .textContentType(.newPassword)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.body)
                                .onChange(of: password) { _, _ in session.passwordError = nil }

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
                                    .stroke(
                                        session.passwordError != nil ? Sourdough.Colors.destructive : Sourdough.Colors.interactiveBorder,
                                        lineWidth: session.passwordError != nil ? 1.5 : 1
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

                            if let error = session.passwordError {
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

                        // General auth error banner
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
                                    let saved = await session.saveOnboardingAnswers(onboardingAnswers)
                                    showRetrySave = !saved
                                    if !showRetrySave {
                                        await session.finalizeAccountSetup(
                                            displayName: onboardingAnswers.preferredName
                                        )
                                        showRetryFinish = !session.isAuthenticated
                                    }
                                    isLoading = false
                                }
                            } label: {
                                HStack(spacing: Sourdough.Spacing.insideChip) {
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    }
                                    Text("Retry")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true))
                        } else if showRetryFinish {
                            if let error = session.nicknameError {
                                AuthErrorBanner(message: error)
                            }

                            Button {
                                Task {
                                    isLoading = true
                                    await session.finalizeAccountSetup(
                                        displayName: onboardingAnswers.preferredName
                                    )
                                    showRetryFinish = !session.isAuthenticated
                                    isLoading = false
                                }
                            } label: {
                                HStack(spacing: Sourdough.Spacing.insideChip) {
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    }
                                    Text("Retry")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true))
                        } else {
                            Button {
                                Task {
                                    isLoading = true
                                    await session.signUp(
                                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                        password: password
                                    )
                                    if session.requiresOTPVerification {
                                        showOTPVerification = true
                                    } else if session.authError == nil, session.emailError == nil, session.passwordError == nil {
                                        let saved = await session.saveOnboardingAnswers(onboardingAnswers)
                                        showRetrySave = !saved
                                        if !showRetrySave {
                                            await session.finalizeAccountSetup(
                                                displayName: onboardingAnswers.preferredName
                                            )
                                            showRetryFinish = !session.isAuthenticated
                                        }
                                    }
                                    isLoading = false
                                }
                            } label: {
                                HStack(spacing: Sourdough.Spacing.insideChip) {
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    }
                                    Text("Continue")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true, isDisabled: !canContinue))
                            .disabled(!canContinue)
                        }

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
        .background(SwipeBackEnabler())
        .fullScreenCover(isPresented: $showOTPVerification) {
            OTPVerificationView(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                onboardingAnswers: onboardingAnswers
            )
            .environmentObject(session)
        }
    }
}

enum AuthLegalLinks {
    static let terms = "https://www.useupnow.com/terms"
    static let privacy = "https://www.useupnow.com/privacy"
}

struct FastTapScrollModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { UIScrollView.appearance().delaysContentTouches = false }
            .onDisappear { UIScrollView.appearance().delaysContentTouches = true }
    }
}

struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackViewController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private class SwipeBackViewController: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

/// Destructive-tinted pill banner for surfacing an auth/onboarding error message — the same shape
/// was hand-rolled at every error-display site across the auth flow.
struct AuthErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .foregroundStyle(Sourdough.Colors.destructive)
            .sourdoughTextStyle(.subhead)
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .padding(.vertical, Sourdough.Spacing.insideChip)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Sourdough.Colors.destructive.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
    }
}

struct AuthBackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.03 : 0.08),
                radius: configuration.isPressed ? 1 : 4,
                x: 0,
                y: configuration.isPressed ? 1 : 2
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Sourdough.Colors.sunken)
                    .frame(height: 4)

                Capsule()
                    .fill(Sourdough.Colors.action)
                    .frame(width: geo.size.width * progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 4)
    }
}
