import Foundation
import Supabase

final class SupabaseAuthService: AuthServicing {
    private let client = SupabaseManager.client

    func sendOTP(phone: String) async throws {
        do {
            try await client.auth.signInWithOTP(phone: phone)
        } catch {
            throw mapError(error)
        }
    }

    func verifyOTP(phone: String, token: String) async throws -> AppUser {
        do {
            let response = try await client.auth.verifyOTP(
                phone: phone,
                token: token,
                type: .sms
            )
            let user = response.user
            return AppUser(id: user.id, email: user.email, phone: user.phone)
        } catch {
            throw mapError(error)
        }
    }

    func signOut() {
        Task { try? await client.auth.signOut() }
    }

    private func mapError(_ error: Error) -> AuthServiceError {
        let message = error.localizedDescription.lowercased()

        if message.contains("otp") || message.contains("token has expired")
            || message.contains("invalid token") {
            return .invalidOTP
        }
        if message.contains("phone") && (message.contains("invalid") || message.contains("valid")) {
            return .invalidPhone
        }
        if message.contains("network") || message.contains("connection")
            || message.contains("offline") {
            return .networkError
        }

        return .unknown(error.localizedDescription)
    }
}
