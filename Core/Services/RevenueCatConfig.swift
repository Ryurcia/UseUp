import Foundation

enum RevenueCatConfig {
    static var apiKey: String {
        guard let key = Bundle.main.infoDictionary?["RevenueCatAPIKey"] as? String, !key.isEmpty else {
            fatalError("REVENUECAT_API_KEY not set in Secrets.xcconfig")
        }
        return key
    }
}
