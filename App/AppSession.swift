import Foundation
import SwiftUI
import UserNotifications

enum ColorSchemePreference: String {
    case light, dark
}

@MainActor
final class AppSession: ObservableObject {
    @Published var isCheckingSession = true
    @Published var hasSeenGetStarted = false
    @Published var isAuthenticated = false
    @Published var currentUserId: UUID?
    @Published var currentUserEmail: String?
    @Published var currentUserNickname: String?
    @Published var currentUserDisplayName: String?
    @Published var authError: String?
    @Published var emailError: String?
    @Published var passwordError: String?
    @Published var requiresOTPVerification = false
    @Published var requiresNicknameOnboarding = false
    @Published var passwordResetEmailSent = false
    @Published var requiresNewPassword = false
    @Published var emailChangeCodeSent = false
    @Published var pendingNewEmail: String?
    @Published var hasCompletedFeatureOnboarding = false
    @AppStorage("hasSeenOnboardingPaywall") var hasSeenOnboardingPaywall = false
    @AppStorage("recipeSuggestionsEnabled") var recipeSuggestionsEnabled: Bool = true

    /// Device-local light/dark choice. Not `@AppStorage` — that wrapper only publishes changes
    /// when it lives inside a `View`, so on this class it would never trigger a re-render. Manual
    /// `UserDefaults` persistence in `didSet` keeps the same key.
    @Published var colorSchemePreference: ColorSchemePreference {
        didSet { UserDefaults.standard.set(colorSchemePreference.rawValue, forKey: "colorSchemePreference") }
    }

    var preferredColorScheme: ColorScheme {
        colorSchemePreference == .dark ? .dark : .light
    }
    @Published var profileImageData: Data?
    @Published var nicknameError: String?
    @Published var profileUpdateError: String?
    @Published var onboardingSaveError: String?
    @Published var nicknameUpdatedAt: Date?
    @Published var currentUserDietaryPreference: GenerationOptions.DietType = .any
    @Published var currentUserDietaryRestrictions: Set<GenerationOptions.DietaryRestriction> = []
    @Published var currentUserAllergies: Set<AllergyType> = []
    @Published var currentUserCustomAllergy: String = ""
    @Published var currentUserCookingSkillLevel: Int = 1
    private static let cachedIsPremiumKey = "cached_is_premium_v1"

    /// Seeded from the last known value instead of hardcoded `false` so cold launch shows the
    /// right state immediately, before the fresh Supabase/RevenueCat checks land — persisted
    /// automatically on every write (including `signOut()`'s `isPremium = false`, which also
    /// clears the cache so a different account signing in on this device doesn't briefly
    /// inherit a stale `true`).
    @Published var isPremium: Bool = UserDefaults.standard.bool(forKey: AppSession.cachedIsPremiumKey) {
        didSet { UserDefaults.standard.set(isPremium, forKey: Self.cachedIsPremiumKey) }
    }
    @Published var isEmailVerified: Bool = false
    @Published var showNotifications: Bool = false
    @Published var showProfile: Bool = false
    @Published var requestedTab: Tab? = nil
    @Published var requestedIngredientID: UUID? = nil
    @Published var requestedQuickGenerateIngredientID: UUID? = nil
    @Published var requestedQuickGenerateIngredientIDs: Set<UUID>? = nil
    @Published var requestedShowAddIngredient: Bool = false
    @Published var requestedPantryLocation: Ingredient.StorageLocation? = nil
    /// Toggled (not just set) so `PantryView` sees a change on every consecutive re-tap of an
    /// already-selected Home tab — see `MainTabView.selectTab(_:)`.
    @Published var requestedPantryHomeReset: Bool = false
    @Published var dietaryUpdatedAt: Date?
    @Published private(set) var currentAvatarPath: String?

    private let authService: AuthServicing
    let profileService: ProfileServicing

    init(authService: AuthServicing, profileService: ProfileServicing = SupabaseProfileService()) {
        self.authService = authService
        self.profileService = profileService

        // Migrate the legacy `@AppStorage("colorSchemePreference")` value (which could be "system").
        switch UserDefaults.standard.string(forKey: "colorSchemePreference") {
        case "dark":  colorSchemePreference = .dark
        case "light": colorSchemePreference = .light
        default:      colorSchemePreference = UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        }
    }

    func completeGetStarted() {
        hasSeenGetStarted = true
    }

    private static let hasLaunchedBeforeKey = "hasLaunchedBefore"

    /// Keychain survives app deletion (unlike UserDefaults, which is wiped on uninstall), so a
    /// fresh install can still have a previous install's session sitting in Keychain and silently
    /// auto-restore a stale account. `hasLaunchedBeforeKey` is guaranteed absent on a genuine
    /// fresh install; its absence is what triggers clearing whatever Supabase has cached, once,
    /// before `restoreSession()` gets a chance to read it.
    func clearSessionIfFreshInstall() async {
        guard !UserDefaults.standard.bool(forKey: Self.hasLaunchedBeforeKey) else { return }
        try? await SupabaseManager.client.auth.signOut()
        UserDefaults.standard.set(true, forKey: Self.hasLaunchedBeforeKey)
    }

    func restoreSession() async {
        do {
            let session = try await SupabaseManager.client.auth.session
            let user = session.user
            currentUserId = user.id
            currentUserEmail = user.email

            if let profile = try? await profileService.fetchProfile(userId: user.id),
               let nickname = profile.nickname, !nickname.isEmpty {
                await applyProfile(profile)
            }
        } catch {
            // No valid session — user stays logged out
        }
    }

    // MARK: - Email + Password Auth

    func signUp(email: String, password: String) async {
        authError = nil
        emailError = nil
        passwordError = nil

        do {
            let user = try await authService.signUp(email: email, password: password)
            await handleSuccessfulAuth(user: user)
        } catch let error as AuthServiceError {
            switch error {
            case .weakPassword:
                passwordError = "Password must be at least 6 characters."
            case .emailAlreadyInUse:
                emailError = "An account with this email already exists."
            case .invalidEmail:
                emailError = "Please enter a valid email address."
            case .emailNotConfirmed:
                currentUserEmail = email
                requiresOTPVerification = true
            default:
                authError = error.errorDescription
            }
        } catch {
            authError = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        authError = nil
        emailError = nil
        passwordError = nil

        do {
            let user = try await authService.signIn(email: email, password: password)
            await handleSuccessfulAuth(user: user)
        } catch let error as AuthServiceError {
            switch error {
            case .invalidCredentials:
                authError = "Incorrect email or password."
            case .emailNotConfirmed:
                currentUserEmail = email
                requiresOTPVerification = true
            case .invalidEmail:
                emailError = "Please enter a valid email address."
            case .networkError:
                authError = error.errorDescription
            default:
                authError = error.errorDescription
            }
        } catch {
            authError = error.localizedDescription
        }
    }

    func verifyEmailOTP(email: String, token: String) async {
        authError = nil

        do {
            let user = try await authService.verifyEmailOTP(email: email, token: token)
            requiresOTPVerification = false
            await handleSuccessfulAuth(user: user)
            if let userId = currentUserId {
                try? await profileService.markEmailVerified(userId: userId)
                isEmailVerified = true
            }
        } catch let error as AuthServiceError {
            authError = error.errorDescription
        } catch {
            authError = error.localizedDescription
        }
    }

    /// Sends a fresh one-time code to the signed-in user's own email, for proving inbox ownership
    /// after the fact (deferred verification) — decoupled from Supabase's own `email_confirmed_at`,
    /// which is already set at signup time on this project (see `isEmailVerified`).
    func sendEmailVerificationCode() async {
        guard let email = currentUserEmail else { return }
        authError = nil
        do {
            try await authService.sendEmailVerificationCode(email: email)
        } catch let error as AuthServiceError {
            authError = error.errorDescription
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Forgot Password

    func requestPasswordReset(email: String) async {
        authError = nil
        do {
            try await authService.requestPasswordReset(email: email)
            currentUserEmail = email
            passwordResetEmailSent = true
        } catch let error as AuthServiceError {
            authError = error.errorDescription
        } catch {
            authError = error.localizedDescription
        }
    }

    func verifyPasswordResetOTP(email: String, token: String) async {
        authError = nil
        do {
            let user = try await authService.verifyPasswordResetOTP(email: email, token: token)
            currentUserId = user.id
            requiresNewPassword = true
        } catch let error as AuthServiceError {
            authError = error.errorDescription
        } catch {
            authError = error.localizedDescription
        }
    }

    func resetPassword(newPassword: String) async {
        authError = nil
        do {
            try await authService.updatePassword(newPassword)
            requiresNewPassword = false
            // verifyOTP(type: .recovery) already established a real session — finish exactly
            // like any other successful auth, straight into the app, instead of bouncing back
            // to Sign In.
            if let userId = currentUserId {
                await handleSuccessfulAuth(user: AppUser(id: userId, email: currentUserEmail, phone: nil))
            }
        } catch let error as AuthServiceError {
            authError = error.errorDescription
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Change Password / Email

    /// Verifies `currentPassword` via a live sign-in (Supabase's update-user call doesn't require
    /// the current password itself, so this is how re-entry is actually enforced) before applying
    /// the new one.
    func changePassword(currentPassword: String, newPassword: String) async {
        authError = nil
        guard let email = currentUserEmail else { return }
        do {
            _ = try await authService.signIn(email: email, password: currentPassword)
        } catch {
            authError = "Current password is incorrect."
            return
        }
        do {
            try await authService.updatePassword(newPassword)
        } catch let error as AuthServiceError {
            authError = error.errorDescription
        } catch {
            authError = error.localizedDescription
        }
    }

    func requestEmailChange(newEmail: String) async {
        authError = nil
        do {
            try await authService.updateEmail(newEmail)
            pendingNewEmail = newEmail
            emailChangeCodeSent = true
        } catch let error as AuthServiceError {
            authError = error.errorDescription
        } catch {
            authError = error.localizedDescription
        }
    }

    func verifyEmailChangeOTP(token: String) async {
        authError = nil
        guard let newEmail = pendingNewEmail else { return }
        do {
            let user = try await authService.verifyEmailChangeOTP(newEmail: newEmail, token: token)
            currentUserEmail = user.email ?? newEmail
            emailChangeCodeSent = false
            pendingNewEmail = nil
        } catch let error as AuthServiceError {
            authError = error.errorDescription
        } catch {
            authError = error.localizedDescription
        }
    }

    private func handleSuccessfulAuth(user: AppUser) async {
        currentUserId = user.id
        currentUserEmail = user.email

        if let profile = try? await profileService.fetchProfile(userId: user.id),
           let nickname = profile.nickname, !nickname.isEmpty {
            await applyProfile(profile)
        } else {
            requiresNicknameOnboarding = true
        }
    }

    private func applyProfile(_ profile: Profile) async {
        currentUserNickname = profile.nickname
        currentUserDisplayName = profile.displayName
        nicknameUpdatedAt = profile.nicknameUpdatedAt
        loadDietaryPreference(from: profile)
        isPremium = profile.subscriptionType == "premium"
        isEmailVerified = profile.emailVerifiedAt != nil
        hasSeenGetStarted = true
        hasCompletedFeatureOnboarding = true
        hasSeenOnboardingPaywall = true
        isAuthenticated = true

        if let avatarPath = profile.avatarPath, !avatarPath.isEmpty {
            currentAvatarPath = avatarPath
            if let cached = AvatarCache.load(for: avatarPath) {
                profileImageData = cached
            } else if let data = try? await profileService.fetchAvatarData(avatarPath: avatarPath) {
                profileImageData = data
                AvatarCache.save(data, for: avatarPath)
            }
        }
    }

    // MARK: - Profile

    func finalizeAccountSetup(displayName: String) async {
        let cleaned = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackDisplayName = cleaned.isEmpty
            ? (currentUserDisplayName ?? currentUserEmail?.split(separator: "@").first.map(String.init) ?? "Chef")
            : cleaned
        guard let userId = currentUserId else { return }

        nicknameError = nil

        for attempt in 0..<5 {
            let candidate = generateChefUsername()
            do {
                let profile = try await profileService.createProfile(nickname: candidate, displayName: fallbackDisplayName, userId: userId)
                currentUserNickname = profile.nickname
                currentUserDisplayName = profile.displayName
                nicknameUpdatedAt = profile.nicknameUpdatedAt
                requiresNicknameOnboarding = false
                hasSeenGetStarted = true
                hasCompletedFeatureOnboarding = false
                isAuthenticated = true
                return
            } catch ProfileError.nicknameTaken {
                if attempt == 4 { nicknameError = "Failed to finish setting up your account. Please try again." }
            } catch {
                nicknameError = error.localizedDescription
                return
            }
        }
    }

    func updateNickname(_ nickname: String) async {
        let cleaned = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let userId = currentUserId else { return }

        nicknameError = nil

        if let remaining = cooldownRemainingDays(since: nicknameUpdatedAt, cooldownDays: 30) {
            nicknameError = "You can change your nickname again in \(remaining) day\(remaining == 1 ? "" : "s")."
            return
        }

        do {
            let profile = try await profileService.updateNickname(cleaned, userId: userId)
            currentUserNickname = profile.nickname
            nicknameUpdatedAt = profile.nicknameUpdatedAt
        } catch {
            nicknameError = error.localizedDescription
        }
    }

    func updateProfilePhoto(_ imageData: Data) async throws {
        let previousData = profileImageData
        let previousPath = currentAvatarPath
        profileImageData = imageData

        guard let userId = currentUserId else { return }
        do {
            let newPath = try await profileService.uploadAvatar(imageData: imageData, userId: userId)
            currentAvatarPath = newPath
            AvatarCache.save(imageData, for: newPath)
        } catch {
            profileImageData = previousData
            currentAvatarPath = previousPath
            throw error
        }
    }

    func updateDisplayName(_ displayName: String) async {
        let cleaned = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let userId = currentUserId else { return }
        profileUpdateError = nil
        do {
            let profile = try await profileService.updateDisplayName(cleaned, userId: userId)
            currentUserDisplayName = profile.displayName
        } catch {
            profileUpdateError = "Failed to update display name. Please try again."
        }
    }

    func updateDietaryPreference(dietType: GenerationOptions.DietType) async {
        guard let userId = currentUserId else { return }
        profileUpdateError = nil
        currentUserDietaryPreference = dietType
        do {
            _ = try await profileService.updateDietaryPreference(dietType.rawValue, userId: userId)
            dietaryUpdatedAt = Date()
        } catch {
            profileUpdateError = "Failed to save dietary preference. Please try again."
        }
    }

    func updateDietaryRestrictions(restrictions: Set<GenerationOptions.DietaryRestriction>) async {
        guard let userId = currentUserId else { return }
        profileUpdateError = nil
        currentUserDietaryRestrictions = restrictions
        let encoded = restrictions.map(\.rawValue).sorted().joined(separator: ",")
        do {
            _ = try await profileService.updateDietaryRestrictions(encoded, userId: userId)
            dietaryUpdatedAt = Date()
        } catch {
            profileUpdateError = "Failed to save dietary restrictions. Please try again."
        }
    }

    func updateAllergies(_ allergies: Set<AllergyType>, customAllergy: String = "") async {
        guard let userId = currentUserId else { return }
        profileUpdateError = nil
        currentUserAllergies = allergies
        currentUserCustomAllergy = customAllergy
        var parts = allergies.map(\.rawValue)
        parts.append(contentsOf: AllergyType.parseCustomAllergens(customAllergy))
        let encoded = parts.sorted().joined(separator: ",")
        do {
            _ = try await profileService.updateAllergies(encoded, userId: userId)
        } catch {
            profileUpdateError = "Failed to save allergies. Please try again."
        }
    }

    func updateCookingSkillLevel(level: Int) async {
        guard let userId = currentUserId else { return }
        profileUpdateError = nil
        currentUserCookingSkillLevel = level
        do {
            _ = try await profileService.updateCookingSkillLevel(level, userId: userId)
        } catch {
            profileUpdateError = "Failed to save cooking level. Please try again."
        }
    }

    func saveOnboardingAnswers(_ answers: OnboardingAnswers) async -> Bool {
        guard let userId = currentUserId else { return false }
        onboardingSaveError = nil
        let restrictionsEncoded = answers.restrictions.map(\.rawValue).sorted().joined(separator: ",")
        var allergyParts = answers.allergies.map(\.rawValue)
        allergyParts.append(contentsOf: AllergyType.parseCustomAllergens(answers.customAllergyText))
        let allergiesEncoded = allergyParts.sorted().joined(separator: ",")
        do {
            let profile = try await profileService.saveOnboardingAnswers(
                displayName: answers.preferredName.trimmingCharacters(in: .whitespacesAndNewlines),
                dietType: answers.dietType.rawValue,
                restrictions: restrictionsEncoded,
                allergies: allergiesEncoded,
                cookingSkillLevel: answers.cookingSkillLevel ?? 1,
                userId: userId
            )
            currentUserDietaryPreference = answers.dietType
            currentUserDietaryRestrictions = answers.restrictions
            currentUserAllergies = answers.allergies
            currentUserCustomAllergy = answers.customAllergyText
            currentUserCookingSkillLevel = profile.cookingSkillLevel ?? 1
            currentUserDisplayName = profile.displayName
            dietaryUpdatedAt = profile.dietaryUpdatedAt
            return true
        } catch {
            onboardingSaveError = error.localizedDescription
            return false
        }
    }

    func refreshPremiumStatus() async {
        guard let userId = currentUserId else { return }
        if let profile = try? await profileService.fetchProfile(userId: userId) {
            // OR'd with RevenueCat's on-device entitlement check (kept fresh by
            // `checkEntitlements()`, which always runs immediately before this) so a Supabase
            // read that's still lagging the `revenuecat-webhook` can't clobber a real, just-
            // completed purchase back to free — mirrors the "never push down" guard
            // `RevenueCatManager.updatePremiumState` already applies to its own writes.
            isPremium = profile.subscriptionType == "premium" || RevenueCatManager.shared.isPremium
        }
    }

    private func loadDietaryPreference(from profile: Profile) {
        if let prefString = profile.dietaryPreference,
           let pref = GenerationOptions.DietType(rawValue: prefString) {
            currentUserDietaryPreference = pref
        }
        if let restrictionsString = profile.dietaryRestrictions, !restrictionsString.isEmpty {
            let parsed = restrictionsString.split(separator: ",").compactMap { rawValue in
                GenerationOptions.DietaryRestriction(rawValue: String(rawValue))
            }
            currentUserDietaryRestrictions = Set(parsed)
        }
        if let skillLevel = profile.cookingSkillLevel {
            currentUserCookingSkillLevel = skillLevel
        }
        if let raw = profile.allergies, !raw.isEmpty {
            var standard: Set<AllergyType> = []
            var custom: [String] = []
            for part in raw.split(separator: ",") {
                let s = String(part)
                if let known = AllergyType(rawValue: s) { standard.insert(known) }
                else { custom.append(s) }
            }
            currentUserAllergies = standard
            currentUserCustomAllergy = custom.joined(separator: ", ")
        } else {
            currentUserAllergies = []
            currentUserCustomAllergy = ""
        }
        dietaryUpdatedAt = profile.dietaryUpdatedAt
    }

    func completeFeatureOnboarding() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            hasCompletedFeatureOnboarding = true
        }
    }

    func deleteAccount() async throws {
        try await authService.deleteAccount()
        signOut()
    }

    func signOut() {
        authService.signOut()
        currentUserId = nil
        currentUserEmail = nil
        currentUserNickname = nil
        currentUserDisplayName = nil
        nicknameUpdatedAt = nil
        profileImageData = nil
        currentAvatarPath = nil
        nicknameError = nil
        authError = nil
        emailError = nil
        passwordError = nil
        onboardingSaveError = nil
        currentUserDietaryPreference = .any
        currentUserDietaryRestrictions = []
        currentUserAllergies = []
        currentUserCustomAllergy = ""
        currentUserCookingSkillLevel = 1
        isPremium = false
        dietaryUpdatedAt = nil
        requiresOTPVerification = false
        passwordResetEmailSent = false
        requiresNewPassword = false
        emailChangeCodeSent = false
        pendingNewEmail = nil
        hasSeenOnboardingPaywall = false
        isAuthenticated = false
        AvatarCache.clear()
        ExpirationNotificationScheduler.cancelAll()
    }
}
