import Foundation

/// Minimal pre-publish content filter for user-submitted recipes and reviews,
/// per Apple App Store Guideline 1.2(a) (apps with UGC must filter objectionable
/// material before it's posted). This is a defensible baseline, not an exhaustive
/// profanity dictionary.
enum ContentModerationFilter {
    private static let blockedTerms: [String] = [
        "nigger", "nigga", "faggot", "fag", "retard", "chink", "spic", "kike",
        "tranny", "cunt", "whore", "rape", "kill yourself", "kys"
    ]

    static func containsObjectionableContent(_ text: String) -> Bool {
        let lowered = text.lowercased()
        for term in blockedTerms {
            if term.contains(" ") {
                if lowered.contains(term) { return true }
            } else if lowered.range(of: "\\b\(NSRegularExpression.escapedPattern(for: term))\\b", options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
}
