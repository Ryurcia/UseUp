import Foundation

struct AppUser: Hashable {
    let id: UUID
    let email: String?
    let phone: String?
}

protocol AuthServicing {
    func signUp(email: String, password: String) async throws -> AppUser
    func signIn(email: String, password: String) async throws -> AppUser
    func verifyEmailOTP(email: String, token: String) async throws -> AppUser
    func requestPasswordReset(email: String) async throws
    func verifyPasswordResetOTP(email: String, token: String) async throws -> AppUser
    func updatePassword(_ newPassword: String) async throws
    func updateEmail(_ newEmail: String) async throws
    func verifyEmailChangeOTP(newEmail: String, token: String) async throws -> AppUser
    func sendEmailVerificationCode(email: String) async throws
    func signOut()
    func deleteAccount() async throws
}

enum AuthServiceError: LocalizedError {
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case invalidCredentials
    case emailNotConfirmed
    case invalidOTP
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:       return "Please enter a valid email address."
        case .weakPassword:       return "Password must be at least 6 characters."
        case .emailAlreadyInUse:  return "An account with this email already exists."
        case .invalidCredentials: return "Incorrect email or password."
        case .emailNotConfirmed:  return "Please verify your email before signing in."
        case .invalidOTP:         return "Invalid verification code. Please try again."
        case .networkError:       return "Network error. Please check your connection."
        case .unknown(let msg):   return msg
        }
    }
}
