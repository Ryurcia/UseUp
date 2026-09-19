import Foundation

final class MockAuthService: AuthServicing {
    func signUp(email: String, password: String) async throws -> AppUser {
        try await Task.sleep(for: .milliseconds(500))
        return AppUser(id: UUID(), email: email, phone: nil)
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        try await Task.sleep(for: .milliseconds(500))
        return AppUser(id: UUID(), email: email, phone: nil)
    }

    func verifyEmailOTP(email: String, token: String) async throws -> AppUser {
        try await Task.sleep(for: .milliseconds(500))
        return AppUser(id: UUID(), email: email, phone: nil)
    }

    func requestPasswordReset(email: String) async throws {
        try await Task.sleep(for: .milliseconds(500))
    }

    func verifyPasswordResetOTP(email: String, token: String) async throws -> AppUser {
        try await Task.sleep(for: .milliseconds(500))
        return AppUser(id: UUID(), email: email, phone: nil)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await Task.sleep(for: .milliseconds(500))
    }

    func updateEmail(_ newEmail: String) async throws {
        try await Task.sleep(for: .milliseconds(500))
    }

    func verifyEmailChangeOTP(newEmail: String, token: String) async throws -> AppUser {
        try await Task.sleep(for: .milliseconds(500))
        return AppUser(id: UUID(), email: newEmail, phone: nil)
    }

    func sendEmailVerificationCode(email: String) async throws {
        try await Task.sleep(for: .milliseconds(500))
    }

    func signOut() {}

    func deleteAccount() async throws {}
}
