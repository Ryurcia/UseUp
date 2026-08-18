import Foundation
import SwiftUI
import UserNotifications

enum ColorSchemePreference: String {
    case system, light, dark
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
    @Published var hasCompletedFeatureOnboarding = false
    @AppStorage("hasSeenOnboardingPaywall") var hasSeenOnboardingPaywall = false
    @AppStorage("colorSchemePreference") var colorSchemePreference: ColorSchemePreference = .system
    @AppStorage("recipeSuggestionsEnabled") var recipeSuggestionsEnabled: Bool = true

    var preferredColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
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
    @Published var isPremium: Bool = false
    @Published var requiresBiometricAuth: Bool = false
    @Published var showNotifications: Bool = false
    @Published var requestedTab: Tab? = nil
    @Published var requestedIngredientID: UUID? = nil
    @Published var dietaryUpdatedAt: Date?
    @Published private(set) var currentAvatarPath: String?

    private let authService: AuthServicing
    let profileService: ProfileServicing

    init(authService: AuthServicing, profileService: ProfileServicing = SupabaseProfileService()) {
        self.authService = authService
        self.profileService = profileService
    }

    func completeGetStarted() {
        hasSeenGetStarted = true
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
                if UserDefaults.standard.bool(forKey: "biometricLoginEnabled") {
                    requiresBiometricAuth = true
                }
            }
        } catch {
            // No valid session — user stays logged out
        }
    }

    func completeBiometricAuth() {
        requiresBiometricAuth = false
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
                authError = "Please check your email to confirm your account, then log in."
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
        nicknameUpdatedAt = profile.updatedAt
        loadDietaryPreference(from: profile)
        isPremium = profile.subscriptionType == "premium"
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

    func completeNicknameOnboarding(nickname: String, displayName: String) async {
        let cleanedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedNickname.isEmpty, !cleanedDisplayName.isEmpty, let userId = currentUserId else { return }

        nicknameError = nil
        var candidate = cleanedNickname

        for attempt in 0..<5 {
            do {
                let profile = try await profileService.createProfile(nickname: candidate, displayName: cleanedDisplayName, userId: userId)
                currentUserNickname = profile.nickname
                currentUserDisplayName = profile.displayName
                nicknameUpdatedAt = profile.updatedAt
                requiresNicknameOnboarding = false
                hasSeenGetStarted = true
                hasCompletedFeatureOnboarding = false
                isAuthenticated = true
                return
            } catch ProfileError.nicknameTaken {
                candidate = "\(cleanedNickname)\(Int.random(in: 100...999))"
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
            nicknameUpdatedAt = profile.updatedAt
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
            isPremium = profile.subscriptionType == "premium"
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
        requiresBiometricAuth = false
        requiresOTPVerification = false
        hasSeenOnboardingPaywall = false
        isAuthenticated = false
        AvatarCache.clear()
        ExpirationNotificationScheduler.cancelAll()
    }
}
