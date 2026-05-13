import SwiftUI

#Preview("Auth") {
    PreviewContainer(authenticated: false) {
        NavigationStack {
            AuthView()
        }
    }
}

struct AuthView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    var onBack: (() -> Void)? = nil

    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var showOTPVerification = false
    @FocusState private var isKeyboardActive: Bool

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: DS.Spacing.space4) {
                    HStack {
                        Button {
                            if isKeyboardActive {
                                isKeyboardActive = false
                            } else if let onBack {
                                onBack()
                            } else {
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DS.ColorToken.textPrimary)
                                .padding(.horizontal, DS.Spacing.space3)
                                .padding(.vertical, DS.Spacing.space2)
                                .background(DS.ColorToken.bgSecondary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(AuthBackButtonStyle())

                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.space5)
                    .padding(.top, DS.Spacing.space2)
                    .padding(.bottom, DS.Spacing.space6)

                    VStack(alignment: .leading, spacing: DS.Spacing.space4) {
                        Text("Enter Your Phone Number")
                            .font(.custom("CalSans-Regular", size: 32))
                            .kerning(0)
                            .foregroundStyle(DS.ColorToken.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("We'll send you a verification code to sign in or create your account")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(DS.ColorToken.textSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(width: proxy.size.width * 0.8, alignment: .leading)
                            .padding(.bottom, DS.Spacing.space2)

                        // Phone number field
                        VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                            Text("Phone Number")
                                .font(.custom("CalSans-Regular", size: 14))
                                .kerning(0)
                                .foregroundStyle(DS.ColorToken.textPrimary)

                            HStack(spacing: DS.Spacing.space2) {
                                Image(systemName: "phone")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(DS.ColorToken.textTertiary)
                                    .frame(width: 16)

                                TextField("+1 (555) 000-0000", text: $phoneNumber)
                                    .focused($isKeyboardActive)
                                    .keyboardType(.phonePad)
                                    .textContentType(.telephoneNumber)
                                    .textFieldStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 52)
                            .background(DS.ColorToken.bgSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                    .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                        }

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

                        // Continue button
                        Button {
                            Task {
                                isLoading = true
                                await session.sendOTP(phone: phoneNumber)
                                isLoading = false
                                if session.requiresOTPVerification {
                                    showOTPVerification = true
                                }
                            }
                        } label: {
                            HStack(spacing: DS.Spacing.space2) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text("Continue")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle(size: .lg, fullWidth: true))
                        .shadow(
                            color: Color.black.opacity(0.08),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                        .disabled(phoneNumber.isEmpty || isLoading)
                    }
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DS.Spacing.space5)

                    Spacer(minLength: 0)
                }
                .frame(minHeight: proxy.size.height)
            }
        }
        .modifier(FastTapScrollModifier())
        .background(DS.ColorToken.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .background(SwipeBackEnabler())
        .fullScreenCover(isPresented: $showOTPVerification) {
            OTPVerificationView(phoneNumber: phoneNumber)
                .environmentObject(session)
        }
    }
}

struct FastTapScrollModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                UIScrollView.appearance().delaysContentTouches = false
            }
            .onDisappear {
                UIScrollView.appearance().delaysContentTouches = true
            }
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

struct ProfileOnboardingContainerView: View {
    @EnvironmentObject private var session: AppSession
    @State private var currentStep = 1
    @State private var username = ""
    @State private var displayName = ""

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(progress: Double(currentStep) / 3.0)
                .padding(.horizontal, DS.Spacing.space4)
                .padding(.top, DS.Spacing.space3)

            Group {
                if currentStep == 1 {
                    NicknameOnboardingView(
                        username: $username,
                        displayName: $displayName,
                        onContinue: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 2
                            }
                        }
                    )
                    .transition(.push(from: .trailing))
                } else if currentStep == 2 {
                    DietaryPreferenceOnboardingView(
                        nickname: username,
                        displayName: displayName,
                        onContinue: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 3
                            }
                        }
                    )
                    .transition(.push(from: .trailing))
                } else {
                    CookingSkillOnboardingView(
                        nickname: username,
                        displayName: displayName
                    )
                    .transition(.push(from: .trailing))
                }
            }
        }
        .background(DS.ColorToken.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct NicknameOnboardingView: View {
    @EnvironmentObject private var session: AppSession
    @Binding var username: String
    @Binding var displayName: String
    var onContinue: () -> Void
    @State private var isLoading = false

    private var canContinue: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.space4) {
                    Text("Set Up Your Profile")
                        .font(.custom("CalSans-Regular", size: 32))
                        .kerning(0)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, DS.Spacing.space6)

                    VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                        Text("Username")
                            .font(.custom("CalSans-Regular", size: 14))
                            .kerning(0)
                            .foregroundStyle(DS.ColorToken.textPrimary)

                        TextField("Choose a unique username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(AppInputFieldStyle(size: .md))
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                        Text("Display Name")
                            .font(.custom("CalSans-Regular", size: 14))
                            .kerning(0)
                            .foregroundStyle(DS.ColorToken.textPrimary)

                        TextField("What should we call you?", text: $displayName)
                            .textFieldStyle(AppInputFieldStyle(size: .md))
                    }

                    if let error = session.nicknameError {
                        Text(error)
                            .appTextStyle(.bodySM)
                            .foregroundStyle(DS.ColorToken.error)
                            .padding(.horizontal, DS.Spacing.space3)
                            .padding(.vertical, DS.Spacing.space2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DS.ColorToken.errorLight)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                    }
                }
                .padding(.horizontal, DS.Spacing.space4)
            }

            // Pinned bottom button
            VStack(spacing: 0) {
                Button {
                    Task {
                        isLoading = true
                        let cleaned = username.trimmingCharacters(in: .whitespacesAndNewlines)
                        let available = try? await session.profileService.isNicknameAvailable(cleaned, excludingUserId: nil)
                        isLoading = false
                        if available == false {
                            session.nicknameError = "This nickname is already taken."
                        } else {
                            session.nicknameError = nil
                            onContinue()
                        }
                    }
                } label: {
                    HStack(spacing: DS.Spacing.space2) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Continue")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(size: .lg, fullWidth: true))
                .disabled(!canContinue)
            }
            .padding(.horizontal, DS.Spacing.space4)
            .padding(.bottom, DS.Spacing.space4)
        }
    }
}

struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DS.ColorToken.bgSecondary)
                    .frame(height: 4)

                Capsule()
                    .fill(DS.ColorToken.primary)
                    .frame(width: geo.size.width * progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 4)
    }
}
