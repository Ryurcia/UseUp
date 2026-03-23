import Foundation
import SwiftUI

@MainActor
final class AppSession: ObservableObject {
    @Published var isCheckingSession = true
    @Published var hasSeenGetStarted = false
    @Published var isAuthenticated = false
    @Published var currentUserId: UUID?
    @Published var currentUserPhone: String?
    @Published var currentUserEmail: String?
    @Published var currentUserNickname: String?
    @Published var currentUserDisplayName: String?
    @Published var authError: String?
    @Published var requiresOTPVerification = false
    @Published var requiresNicknameOnboarding = false
    @Published var hasCompletedFeatureOnboarding = false
    @AppStorage("isDarkMode") var isDarkMode = false
    @AppStorage("hasCompletedTutorial") var hasCompletedTutorial = false
    @Published var tutorialStep: Int = 0
    @Published var profileImageData: Data?
    @Published var nicknameError: String?
    @Published var nicknameUpdatedAt: Date?
    @Published var currentUserDietaryPreference: GenerationOptions.DietType = .any
    @Published var currentUserDietaryRestrictions: Set<GenerationOptions.DietaryRestriction> = []
    private(set) var currentAvatarPath: String?

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
        defer { isCheckingSession = false }

        do {
            let session = try await SupabaseManager.client.auth.session
            let user = session.user
            currentUserId = user.id
            currentUserPhone = user.phone
            currentUserEmail = user.email

            if let profile = try? await profileService.fetchProfile(userId: user.id),
               let nickname = profile.nickname, !nickname.isEmpty {
                currentUserNickname = nickname
                currentUserDisplayName = profile.displayName
                nicknameUpdatedAt = profile.updatedAt
                loadDietaryPreference(from: profile)
                hasSeenGetStarted = true
                hasCompletedFeatureOnboarding = true
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
        } catch {
            // No valid session — user stays logged out
        }
    }

    func sendOTP(phone: String) async {
        authError = nil

        do {
            try await authService.sendOTP(phone: phone)
            requiresOTPVerification = true
        } catch {
            authError = error.localizedDescription
        }
    }

    func verifyOTP(phone: String, token: String) async {
        authError = nil

        do {
            let user = try await authService.verifyOTP(phone: phone, token: token)
            currentUserId = user.id
            currentUserPhone = user.phone
            currentUserEmail = user.email
            requiresOTPVerification = false

            // Check if user has a profile (existing user)
            if let profile = try? await profileService.fetchProfile(userId: user.id),
               let nickname = profile.nickname, !nickname.isEmpty {
                currentUserNickname = nickname
                currentUserDisplayName = profile.displayName
                nicknameUpdatedAt = profile.updatedAt
                loadDietaryPreference(from: profile)
                hasSeenGetStarted = true
                hasCompletedFeatureOnboarding = true
                isAuthenticated = true
            } else {
                // New user — needs nickname
                requiresNicknameOnboarding = true
            }
        } catch {
            authError = error.localizedDescription
        }
    }

    func completeNicknameOnboarding(nickname: String, displayName: String) async {
        let cleanedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedNickname.isEmpty, !cleanedDisplayName.isEmpty, let userId = currentUserId else { return }

        nicknameError = nil

        do {
            let profile = try await profileService.createProfile(nickname: cleanedNickname, displayName: cleanedDisplayName, userId: userId)
            currentUserNickname = profile.nickname
            currentUserDisplayName = profile.displayName
            nicknameUpdatedAt = profile.updatedAt
            requiresNicknameOnboarding = false
            hasSeenGetStarted = true
            hasCompletedFeatureOnboarding = false
            isAuthenticated = true
        } catch {
            nicknameError = error.localizedDescription
        }
    }

    func updateNickname(_ nickname: String) async {
        let cleaned = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let userId = currentUserId else { return }

        nicknameError = nil

        if let lastUpdated = nicknameUpdatedAt {
            let daysSince = Calendar.current.dateComponents([.day], from: lastUpdated, to: Date()).day ?? 0
            if daysSince < 30 {
                let remaining = 30 - daysSince
                nicknameError = "You can change your nickname again in \(remaining) day\(remaining == 1 ? "" : "s")."
                return
            }
        }

        do {
            let profile = try await profileService.updateNickname(cleaned, userId: userId)
            currentUserNickname = profile.nickname
            nicknameUpdatedAt = profile.updatedAt
        } catch {
            nicknameError = error.localizedDescription
        }
    }

    func updateProfilePhoto(_ imageData: Data) async {
        let previousData = profileImageData
        let previousPath = currentAvatarPath
        profileImageData = imageData

        guard let userId = currentUserId else {
            print("[AvatarUpload] No currentUserId — skipping upload")
            return
        }
        do {
            let newPath = try await profileService.uploadAvatar(imageData: imageData, userId: userId, oldAvatarPath: currentAvatarPath)
            currentAvatarPath = newPath
            AvatarCache.save(imageData, for: newPath)
        } catch {
            print("[AvatarUpload] Failed: \(error)")
            profileImageData = previousData
            currentAvatarPath = previousPath
        }
    }

    func updateDietaryPreference(dietType: GenerationOptions.DietType) async {
        guard let userId = currentUserId else { return }
        currentUserDietaryPreference = dietType
        _ = try? await profileService.updateDietaryPreference(dietType.rawValue, userId: userId)
    }

    func updateDietaryRestrictions(restrictions: Set<GenerationOptions.DietaryRestriction>) async {
        guard let userId = currentUserId else { return }
        currentUserDietaryRestrictions = restrictions
        let encoded = restrictions.map(\.rawValue).sorted().joined(separator: ",")
        _ = try? await profileService.updateDietaryRestrictions(encoded, userId: userId)
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
    }

    func completeFeatureOnboarding() {
        hasCompletedFeatureOnboarding = true
        tutorialStep = 1
    }

    func dismissTutorial() {
        hasCompletedTutorial = true
        tutorialStep = 0
    }

    func signOut() {
        authService.signOut()
        currentUserId = nil
        currentUserPhone = nil
        currentUserEmail = nil
        currentUserNickname = nil
        currentUserDisplayName = nil
        nicknameUpdatedAt = nil
        profileImageData = nil
        currentAvatarPath = nil
        nicknameError = nil
        currentUserDietaryPreference = .any
        currentUserDietaryRestrictions = []
        requiresOTPVerification = false
        isAuthenticated = false
        authError = nil
        hasCompletedTutorial = false
        AvatarCache.clear()
        ExpirationNotificationScheduler.cancelAll()
    }
}
