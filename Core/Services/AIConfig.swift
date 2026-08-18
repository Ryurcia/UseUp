import Foundation

enum AIConfig {
    static var geminiAPIKey: String {
        guard let key = Bundle.main.infoDictionary?["GeminiAPIKey"] as? String, !key.isEmpty else {
            fatalError("GEMINI_API_KEY not set in Secrets.xcconfig")
        }
        return key
    }
}
