import Foundation

enum AIProvider: String {
    case gemini
    case sonnet
}

enum AIConfig {
    static var geminiAPIKey: String {
        guard let key = Bundle.main.infoDictionary?["GeminiAPIKey"] as? String, !key.isEmpty else {
            fatalError("GEMINI_API_KEY not set in Secrets.xcconfig")
        }
        return key
    }

    static let anthropicAPIKey = "YOUR_ANTHROPIC_API_KEY"

    static var activeProvider: AIProvider { .gemini }
}
