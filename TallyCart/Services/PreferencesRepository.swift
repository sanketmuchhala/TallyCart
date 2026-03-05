import Foundation
import Supabase

struct PreferencesRepository {
    let client: SupabaseClient

    func fetchPreferences(userId: UUID) async throws -> UserPreferencesModel? {
        let response: PostgrestResponse<[PreferencesRow]> = try await client.database
            .from("user_preferences")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
        return response.value.first?.toModel()
    }

    func upsertPreferences(_ preferences: UserPreferencesModel) async throws {
        let row = PreferencesRow(model: preferences)
        _ = try await client.database
            .from("user_preferences")
            .upsert(row, onConflict: "user_id")
            .execute()
    }
}

private struct PreferencesRow: Codable {
    let userId: UUID
    let monthlyBudgetCents: Int?
    let householdSize: Int
    let premiumSensitivity: Int
    let alwaysSuggestStaples: Bool
    let dietFlags: [String: Bool]
    let avoidItems: [String]
    let preferredBrands: [String: [String]]
    let staplesItems: [String]
    let updatedAt: Date?

    init(model: UserPreferencesModel) {
        userId = model.userId
        monthlyBudgetCents = model.monthlyBudgetCents
        householdSize = model.householdSize
        premiumSensitivity = model.premiumSensitivity
        alwaysSuggestStaples = model.alwaysSuggestStaples
        dietFlags = model.dietFlags
        avoidItems = model.avoidItems
        preferredBrands = model.preferredBrands
        staplesItems = model.staplesItems
        updatedAt = model.updatedAt
    }

    func toModel() -> UserPreferencesModel {
        UserPreferencesModel(
            userId: userId,
            monthlyBudgetCents: monthlyBudgetCents,
            householdSize: householdSize,
            premiumSensitivity: premiumSensitivity,
            alwaysSuggestStaples: alwaysSuggestStaples,
            dietFlags: dietFlags,
            avoidItems: avoidItems,
            preferredBrands: preferredBrands,
            staplesItems: staplesItems,
            updatedAt: updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case monthlyBudgetCents = "monthly_budget_cents"
        case householdSize = "household_size"
        case premiumSensitivity = "premium_sensitivity"
        case alwaysSuggestStaples = "always_suggest_staples"
        case dietFlags = "diet_flags"
        case avoidItems = "avoid_items"
        case preferredBrands = "preferred_brands"
        case staplesItems = "staples_items"
        case updatedAt = "updated_at"
    }
}
