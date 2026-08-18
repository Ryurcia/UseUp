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
    var allergies: String?
    var cookingSkillLevel: Int?
    var subscriptionType: String?
    var dietaryUpdatedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case displayName = "display_name"
        case avatarPath = "avatar_path"
        case dietaryPreference = "dietary_preference"
        case dietaryRestrictions = "dietary_restrictions"
        case allergies
        case cookingSkillLevel = "cooking_skill_level"
        case subscriptionType = "subscription_type"
        case dietaryUpdatedAt = "dietary_updated_at"
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
    func uploadAvatar(imageData: Data, userId: UUID) async throws -> String
    func fetchAvatarData(avatarPath: String) async throws -> Data
    func updateDietaryPreference(_ preference: String, userId: UUID) async throws -> Profile
    func updateDietaryRestrictions(_ restrictions: String, userId: UUID) async throws -> Profile
    func updateAllergies(_ allergies: String, userId: UUID) async throws -> Profile
    func updateDisplayName(_ displayName: String, userId: UUID) async throws -> Profile
    func updateCookingSkillLevel(_ level: Int, userId: UUID) async throws -> Profile
    func saveOnboardingAnswers(displayName: String, dietType: String, restrictions: String, allergies: String, cookingSkillLevel: Int, userId: UUID) async throws -> Profile
}

final class SupabaseProfileService: ProfileServicing {
    private let client = SupabaseManager.client
    private static let cooldownDays = 30
    private static let iso8601 = ISO8601DateFormatter()

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

    func uploadAvatar(imageData: Data, userId: UUID) async throws -> String {
        guard let compressedData = UIImage(data: imageData)?.jpegData(compressionQuality: 0.8) else {
            throw ProfileError.unknown("Failed to compress image.")
        }

        let fileName = userId.uuidString.lowercased()
        let options = FileOptions(contentType: "image/jpeg", upsert: false)

        // update() replaces existing; upload() creates for first-time
        do {
            try await client.storage
                .from("profile-pics")
                .update(fileName, data: compressedData, options: options)
        } catch {
            try await client.storage
                .from("profile-pics")
                .upload(fileName, data: compressedData, options: options)
        }

        try await client
            .from("profiles")
            .update(["avatar_path": fileName])
            .eq("id", value: userId.uuidString)
            .execute()

        return fileName
    }

    func fetchAvatarData(avatarPath: String) async throws -> Data {
        try await client.storage.from("profile-pics").download(path: avatarPath)
    }

    /// Shared implementation for the `profiles` update-then-refetch pattern used by every
    /// preference-editing method below: update the given columns, select the row back, and throw
    /// a caller-supplied message if Supabase unexpectedly returns nothing.
    private func updateProfile(_ fields: [String: String], userId: UUID, errorMessage: String) async throws -> Profile {
        let rows: [Profile] = try await client
            .from("profiles")
            .update(fields)
            .eq("id", value: userId.uuidString)
            .select()
            .execute()
            .value
        guard let updated = rows.first else {
            throw ProfileError.unknown(errorMessage)
        }
        return updated
    }

    func updateDietaryPreference(_ preference: String, userId: UUID) async throws -> Profile {
        let now = Self.iso8601.string(from: Date())
        return try await updateProfile(
            ["dietary_preference": preference, "dietary_updated_at": now],
            userId: userId,
            errorMessage: "Failed to save dietary preference."
        )
    }

    func updateDietaryRestrictions(_ restrictions: String, userId: UUID) async throws -> Profile {
        let now = Self.iso8601.string(from: Date())
        return try await updateProfile(
            ["dietary_restrictions": restrictions, "dietary_updated_at": now],
            userId: userId,
            errorMessage: "Failed to save dietary restrictions."
        )
    }

    func updateAllergies(_ allergies: String, userId: UUID) async throws -> Profile {
        try await updateProfile(
            ["allergies": allergies],
            userId: userId,
            errorMessage: "Failed to save allergies."
        )
    }

    func updateDisplayName(_ displayName: String, userId: UUID) async throws -> Profile {
        try await updateProfile(
            ["display_name": displayName],
            userId: userId,
            errorMessage: "Failed to save display name."
        )
    }

    func updateCookingSkillLevel(_ level: Int, userId: UUID) async throws -> Profile {
        // Not routed through `updateProfile` — `cooking_skill_level` is a Postgres integer column,
        // and that helper's `[String: String]` signature would send a JSON string instead of a number.
        let rows: [Profile] = try await client
            .from("profiles")
            .update(["cooking_skill_level": level])
            .eq("id", value: userId.uuidString)
            .select()
            .execute()
            .value
        guard let updated = rows.first else {
            throw ProfileError.unknown("Failed to save cooking skill level.")
        }
        return updated
    }

    func saveOnboardingAnswers(displayName: String, dietType: String, restrictions: String, allergies: String, cookingSkillLevel: Int, userId: UUID) async throws -> Profile {
        let now = Self.iso8601.string(from: Date())
        return try await updateProfile(
            [
                "display_name": displayName,
                "dietary_preference": dietType,
                "dietary_restrictions": restrictions,
                "allergies": allergies,
                "cooking_skill_level": String(cookingSkillLevel),
                "dietary_updated_at": now,
            ],
            userId: userId,
            errorMessage: "Failed to save your preferences. Please try again."
        )
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

    func uploadAvatar(imageData: Data, userId: UUID) async throws -> String {
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

    func updateAllergies(_ allergies: String, userId: UUID) async throws -> Profile {
        Profile(id: userId, nickname: "Chef", allergies: allergies, updatedAt: Date())
    }

    func updateDisplayName(_ displayName: String, userId: UUID) async throws -> Profile {
        Profile(id: userId, nickname: "Chef", displayName: displayName, updatedAt: Date())
    }

    func updateCookingSkillLevel(_ level: Int, userId: UUID) async throws -> Profile {
        Profile(id: userId, nickname: "Chef", cookingSkillLevel: level, updatedAt: Date())
    }

    func saveOnboardingAnswers(displayName: String, dietType: String, restrictions: String, allergies: String, cookingSkillLevel: Int, userId: UUID) async throws -> Profile {
        Profile(id: userId, nickname: "Chef", displayName: displayName, dietaryPreference: dietType, dietaryRestrictions: restrictions, allergies: allergies, cookingSkillLevel: cookingSkillLevel, updatedAt: Date())
    }
}
