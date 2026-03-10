import Foundation
import Supabase

/// Codable row matching the Supabase `ingredients` table.
private struct IngredientRow: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let amount: String?
    let category: String
    let location: String
    let expirationDate: String?
    let loggedAt: Date?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, amount, category, location
        case expirationDate = "expiration_date"
        case loggedAt = "logged_at"
        case notes
    }

    func toIngredient() -> Ingredient {
        let cat = Ingredient.Category(rawValue: category) ?? .other
        let loc = Ingredient.StorageLocation(rawValue: location) ?? .fridge

        var expDate: Date?
        if let expirationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            expDate = formatter.date(from: expirationDate)
        }

        return Ingredient(
            id: id,
            name: name,
            amount: amount,
            category: cat,
            location: loc,
            expirationDate: expDate,
            loggedAt: loggedAt ?? Date(),
            notes: notes
        )
    }
}

/// Insert/update payload — no `id` (server generates), no read-only timestamps.
private struct IngredientInsert: Encodable {
    let userId: UUID
    let name: String
    let amount: String?
    let category: String
    let location: String
    let expirationDate: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name, amount, category, location
        case expirationDate = "expiration_date"
        case notes
    }
}

private struct IngredientUpdate: Encodable {
    let name: String
    let amount: String?
    let category: String
    let location: String
    let expirationDate: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case name, amount, category, location
        case expirationDate = "expiration_date"
        case notes
    }
}

@MainActor
final class PantryStore: ObservableObject {
    @Published private(set) var ingredients: [Ingredient] = []
    @Published private(set) var isLoading = false
    @Published var error: String?

    private let client = SupabaseManager.client

    private func getUserId() async -> UUID? {
        try? await client.auth.session.user.id
    }

    // MARK: - Fetch

    func fetchIngredients() async {
        guard let userId = await getUserId() else { return }
        isLoading = true
        error = nil

        do {
            let rows: [IngredientRow] = try await client
                .from("ingredients")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("logged_at", ascending: false)
                .execute()
                .value

            ingredients = rows.map { $0.toIngredient() }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Add

    func addIngredient(
        name: String,
        amount: String?,
        category: Ingredient.Category,
        location: Ingredient.StorageLocation,
        expirationDate: Date?
    ) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let cleanedAmount = amount?.trimmingCharacters(in: .whitespacesAndNewlines)

        let exists = ingredients.contains { $0.name.lowercased() == cleaned.lowercased() }
        guard !exists else { return }

        // Optimistic local insert
        let tempIngredient = Ingredient(
            name: cleaned.lowercased(),
            amount: cleanedAmount?.isEmpty == true ? nil : cleanedAmount,
            category: category,
            location: location,
            expirationDate: expirationDate
        )
        ingredients.insert(tempIngredient, at: 0)

        Task {
            guard let userId = await getUserId() else {
                ingredients.removeAll { $0.id == tempIngredient.id }
                return
            }

            let insert = IngredientInsert(
                userId: userId,
                name: cleaned.lowercased(),
                amount: cleanedAmount?.isEmpty == true ? nil : cleanedAmount,
                category: category.rawValue,
                location: location.rawValue,
                expirationDate: expirationDate.map { formatDate($0) },
                notes: nil
            )

            do {
                let rows: [IngredientRow] = try await client
                    .from("ingredients")
                    .insert(insert)
                    .select()
                    .execute()
                    .value

                if let row = rows.first,
                   let index = ingredients.firstIndex(where: { $0.id == tempIngredient.id }) {
                    ingredients[index] = row.toIngredient()
                }
            } catch {
                // Rollback optimistic insert
                ingredients.removeAll { $0.id == tempIngredient.id }
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Update

    func updateIngredient(
        id: UUID,
        name: String,
        amount: String?,
        category: Ingredient.Category,
        location: Ingredient.StorageLocation,
        expirationDate: Date?
    ) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let cleanedAmount = amount?.trimmingCharacters(in: .whitespacesAndNewlines)

        let duplicateExists = ingredients.contains {
            $0.id != id && $0.name.lowercased() == cleaned.lowercased()
        }
        guard !duplicateExists else { return }

        guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }
        let previous = ingredients[index]

        // Optimistic update
        ingredients[index].name = cleaned.lowercased()
        ingredients[index].amount = cleanedAmount?.isEmpty == true ? nil : cleanedAmount
        ingredients[index].category = category
        ingredients[index].location = location
        ingredients[index].expirationDate = expirationDate

        let update = IngredientUpdate(
            name: cleaned.lowercased(),
            amount: cleanedAmount?.isEmpty == true ? nil : cleanedAmount,
            category: category.rawValue,
            location: location.rawValue,
            expirationDate: expirationDate.map { formatDate($0) },
            notes: ingredients[index].notes
        )

        Task {
            do {
                try await client
                    .from("ingredients")
                    .update(update)
                    .eq("id", value: id.uuidString)
                    .execute()
            } catch {
                // Rollback
                if let idx = ingredients.firstIndex(where: { $0.id == id }) {
                    ingredients[idx] = previous
                }
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Use (update amount or delete)

    func useIngredient(id: UUID, newAmount: String?) {
        if let newAmount, !newAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }
            let previous = ingredients[index]
            ingredients[index].amount = newAmount

            Task {
                do {
                    try await client
                        .from("ingredients")
                        .update(["amount": newAmount])
                        .eq("id", value: id.uuidString)
                        .execute()
                } catch {
                    if let idx = ingredients.firstIndex(where: { $0.id == id }) {
                        ingredients[idx] = previous
                    }
                    self.error = error.localizedDescription
                }
            }
        } else {
            deleteIngredient(id: id)
        }
    }

    // MARK: - Delete

    func deleteIngredient(id: UUID) {
        guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }
        let removed = ingredients.remove(at: index)

        Task {
            do {
                try await client
                    .from("ingredients")
                    .delete()
                    .eq("id", value: id.uuidString)
                    .execute()
            } catch {
                // Rollback
                ingredients.insert(removed, at: min(index, ingredients.count))
                self.error = error.localizedDescription
            }
        }
    }

    func remove(at offsets: IndexSet) {
        let idsToRemove = offsets.map { ingredients[$0].id }
        for id in idsToRemove {
            deleteIngredient(id: id)
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
