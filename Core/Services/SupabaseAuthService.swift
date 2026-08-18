import Foundation
import Supabase

final class SupabaseAuthService: AuthServicing {
    private let client = SupabaseManager.client

    func signUp(email: String, password: String) async throws -> AppUser {
        let response: AuthResponse
        do {
            response = try await client.auth.signUp(email: email, password: password)
        } catch {
            throw mapError(error)
        }
        guard let session = response.session else {
            throw AuthServiceError.emailNotConfirmed
        }
        let user = session.user
        return AppUser(id: user.id, email: user.email, phone: user.phone)
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            let user = session.user
            return AppUser(id: user.id, email: user.email, phone: user.phone)
        } catch {
            throw mapError(error)
        }
    }

    func verifyEmailOTP(email: String, token: String) async throws -> AppUser {
        do {
            let response = try await client.auth.verifyOTP(
                email: email,
                token: token,
                type: .email
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

    func deleteAccount() async throws {
        do {
            try await client.rpc("delete_user").execute()
        } catch {
            throw mapError(error)
        }
        signOut()
    }

    private func mapError(_ error: Error) -> AuthServiceError {
        let message = error.localizedDescription.lowercased()

        if message.contains("user already exists") || message.contains("already registered") {
            return .emailAlreadyInUse
        }
        if message.contains("email not confirmed") {
            return .emailNotConfirmed
        }
        if message.contains("invalid login credentials") || message.contains("invalid credentials") {
            return .invalidCredentials
        }
        if message.contains("password") && (message.contains("weak") || message.contains("short") || message.contains("character") || message.contains("least")) {
            return .weakPassword
        }
        if message.contains("email") && (message.contains("invalid") || message.contains("format") || message.contains("valid")) {
            return .invalidEmail
        }
        if message.contains("otp") || message.contains("token has expired") || message.contains("invalid token") {
            return .invalidOTP
        }
        if message.contains("network") || message.contains("connection") || message.contains("offline") {
            return .networkError
        }

        return .unknown(error.localizedDescription)
    }
}
