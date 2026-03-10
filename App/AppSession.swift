import Foundation

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
    @Published var isDarkMode = false
    @Published var profileImageData: Data?
    @Published var nicknameError: String?
    @Published var nicknameUpdatedAt: Date?

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
                hasSeenGetStarted = true
                hasCompletedFeatureOnboarding = true
                isAuthenticated = true
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

        do {
            let profile = try await profileService.updateNickname(cleaned, userId: userId)
            currentUserNickname = profile.nickname
            nicknameUpdatedAt = profile.updatedAt
        } catch {
            nicknameError = error.localizedDescription
        }
    }

    func completeFeatureOnboarding() {
        hasCompletedFeatureOnboarding = true
    }

    func signOut() {
        authService.signOut()
        currentUserId = nil
        currentUserPhone = nil
        currentUserEmail = nil
        currentUserNickname = nil
        currentUserDisplayName = nil
        nicknameUpdatedAt = nil
        nicknameError = nil
        requiresOTPVerification = false
        isAuthenticated = false
        authError = nil
    }
}
