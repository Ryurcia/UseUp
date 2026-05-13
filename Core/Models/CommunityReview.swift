import Foundation

struct CommunityReview: Identifiable {
    var id: UUID { userId }
    let userId: UUID
    let nickname: String
    let avatarPath: String?
    let rating: Double
    let review: String?
    let createdAt: Date
}
