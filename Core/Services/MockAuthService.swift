import Foundation

final class MockAuthService: AuthServicing {
    func sendOTP(phone: String) async throws {
        try await Task.sleep(for: .milliseconds(500))
    }

    func verifyOTP(phone: String, token: String) async throws -> AppUser {
        try await Task.sleep(for: .milliseconds(500))
        return AppUser(id: UUID(), email: nil, phone: phone)
    }

    func signOut() {}
}
