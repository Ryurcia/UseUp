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

    func signOut() {}

    func deleteAccount() async throws {}
}
