import Foundation
import UIKit
import Supabase

struct Profile: Codable {
    let id: UUID
    var nickname: String?
    var displayName: String?
    var avatarPath: String?
    var dietaryPreference: String?
    var dietaryRestrictions: String?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case displayName = "display_name"
        case avatarPath = "avatar_path"
        case dietaryPreference = "dietary_preference"
        case dietaryRestrictions = "dietary_restrictions"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum ProfileError: LocalizedError {
    case nicknameTaken
    case nicknameCooldown(daysRemaining: Int)
    case notAuthenticated
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .nicknameTaken:
            return "This nickname is already taken."
        case .nicknameCooldown(let days):
            return "You can change your nickname again in \(days) day\(days == 1 ? "" : "s")."
        case .notAuthenticated:
            return "You must be signed in."
        case .unknown(let message):
            return message
        }
    }
}

protocol ProfileServicing {
    func fetchProfile(userId: UUID) async throws -> Profile?
    func isNicknameAvailable(_ nickname: String, excludingUserId: UUID?) async throws -> Bool
    func createProfile(nickname: String, displayName: String, userId: UUID) async throws -> Profile
    func updateNickname(_ nickname: String, userId: UUID) async throws -> Profile
    func uploadAvatar(imageData: Data, userId: UUID, oldAvatarPath: String?) async throws -> String
    func fetchAvatarData(avatarPath: String) async throws -> Data
    func updateDietaryPreference(_ preference: String, userId: UUID) async throws -> Profile
    func updateDietaryRestrictions(_ restrictions: String, userId: UUID) async throws -> Profile
}

final class SupabaseProfileService: ProfileServicing {
    private let client = SupabaseManager.client
    private static let cooldownDays = 30

    func fetchProfile(userId: UUID) async throws -> Profile? {
        let rows: [Profile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value
        return rows.first
    }

    func isNicknameAvailable(_ nickname: String, excludingUserId: UUID? = nil) async throws -> Bool {
        var query = client
            .from("profiles")
            .select("id", head: true, count: .exact)
            .ilike("nickname", pattern: nickname)

        if let excludingUserId {
            query = query.neq("id", value: excludingUserId.uuidString)
        }

        let response = try await query.execute()
        return (response.count ?? 0) == 0
    }

    func createProfile(nickname: String, displayName: String, userId: UUID) async throws -> Profile {
        // Check uniqueness
        let available = try await isNicknameAvailable(nickname, excludingUserId: nil)
        guard available else {
            throw ProfileError.nicknameTaken
        }

        let rows: [Profile] = try await client
            .from("profiles")
            .update([
                "nickname": nickname,
                "display_name": displayName,
            ])
            .eq("id", value: userId.uuidString)
            .select()
            .execute()
            .value

        guard let created = rows.first else {
            throw ProfileError.unknown("Failed to create profile. Please try again.")
        }
        return created
    }

    func updateNickname(_ nickname: String, userId: UUID) async throws -> Profile {
        // Check uniqueness
        let available = try await isNicknameAvailable(nickname, excludingUserId: userId)
        guard available else {
            throw ProfileError.nicknameTaken
        }

        let rows: [Profile] = try await client
            .from("profiles")
            .update(["nickname": nickname])
            .eq("id", value: userId.uuidString)
            .select()
            .execute()
            .value

        guard let updated = rows.first else {
            throw ProfileError.unknown("Failed to save nickname. Please try again.")
        }
        return updated
    }

    func uploadAvatar(imageData: Data, userId: UUID, oldAvatarPath: String?) async throws -> String {
        guard let compressedData = UIImage(data: imageData)?.jpegData(compressionQuality: 0.7) else {
            throw ProfileError.unknown("Failed to compress image.")
        }

        // Delete old avatar if one exists
        if let oldPath = oldAvatarPath, !oldPath.isEmpty {
            _ = try? await client.storage.from("profile-photos").remove(paths: [oldPath])
        }

        let fileName = "\(userId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        try await client.storage
            .from("profile-photos")
            .upload(fileName, data: compressedData, options: .init(contentType: "image/jpeg"))

        // Update avatar_path in profiles table
        try await client
            .from("profiles")
            .update(["avatar_path": fileName])
            .eq("id", value: userId.uuidString)
            .execute()

        return fileName
    }

    func fetchAvatarData(avatarPath: String) async throws -> Data {
        try await client.storage.from("profile-photos").download(path: avatarPath)
    }

    func updateDietaryPreference(_ preference: String, userId: UUID) async throws -> Profile {
        let rows: [Profile] = try await client
            .from("profiles")
            .update(["dietary_preference": preference])
            .eq("id", value: userId.uuidString)
            .select()
            .execute()
            .value
        guard let updated = rows.first else {
            throw ProfileError.unknown("Failed to save dietary preference.")
        }
        return updated
    }

    func updateDietaryRestrictions(_ restrictions: String, userId: UUID) async throws -> Profile {
        let rows: [Profile] = try await client
            .from("profiles")
            .update(["dietary_restrictions": restrictions])
            .eq("id", value: userId.uuidString)
            .select()
            .execute()
            .value
        guard let updated = rows.first else {
            throw ProfileError.unknown("Failed to save dietary restrictions.")
        }
        return updated
    }
}

final class MockProfileService: ProfileServicing {
    func fetchProfile(userId: UUID) async throws -> Profile? {
        Profile(id: userId, nickname: "Chef", displayName: "Chef")
    }

    func isNicknameAvailable(_ nickname: String, excludingUserId: UUID?) async throws -> Bool {
        true
    }

    func createProfile(nickname: String, displayName: String, userId: UUID) async throws -> Profile {
        Profile(id: userId, nickname: nickname, displayName: displayName, updatedAt: Date())
    }

    func updateNickname(_ nickname: String, userId: UUID) async throws -> Profile {
        Profile(id: userId, nickname: nickname, updatedAt: Date())
    }

    func uploadAvatar(imageData: Data, userId: UUID, oldAvatarPath: String?) async throws -> String {
        "mock/avatar.jpg"
    }

    func fetchAvatarData(avatarPath: String) async throws -> Data {
        Data()
    }

    func updateDietaryPreference(_ preference: String, userId: UUID) async throws -> Profile {
        Profile(id: userId, nickname: "Chef", dietaryPreference: preference, updatedAt: Date())
    }

    func updateDietaryRestrictions(_ restrictions: String, userId: UUID) async throws -> Profile {
        Profile(id: userId, nickname: "Chef", dietaryRestrictions: restrictions, updatedAt: Date())
    }
}
