import Foundation

struct AppUser: Hashable {
    let id: UUID
    let email: String?
    let phone: String?
}

protocol AuthServicing {
    func sendOTP(phone: String) async throws
    func verifyOTP(phone: String, token: String) async throws -> AppUser
    func signOut()
}

enum AuthServiceError: LocalizedError {
    case invalidPhone
    case invalidOTP
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidPhone:
            return "Please enter a valid phone number."
        case .invalidOTP:
            return "Invalid verification code. Please try again."
        case .networkError:
            return "Network error. Please check your connection."
        case .unknown(let message):
            return message
        }
    }
}
