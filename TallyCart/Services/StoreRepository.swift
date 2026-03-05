import Foundation
import Supabase

struct StoreRepository {
    let client: SupabaseClient

    func fetchStores(userId: UUID) async throws -> [StoreModel] {
        let response: PostgrestResponse<[StoreRow]> = try await client.database
            .from("stores")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: true)
            .execute()
        return response.value.map { $0.toModel() }
    }

    func upsertStore(_ store: StoreModel) async throws {
        let row = StoreRow(model: store)
        _ = try await client.database
            .from("stores")
            .upsert(row, onConflict: "id")
            .execute()
    }

    func deleteStore(id: UUID) async throws {
        _ = try await client.database
            .from("stores")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

private struct StoreRow: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let locationText: String?
    let notes: String?
    let isDefault: Bool
    let createdAt: Date?
    let updatedAt: Date?

    init(model: StoreModel) {
        id = model.id
        userId = model.userId
        name = model.name
        locationText = model.locationText
        notes = model.notes
        isDefault = model.isDefault
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }

    func toModel() -> StoreModel {
        StoreModel(
            id: id,
            userId: userId,
            name: name,
            locationText: locationText,
            notes: notes,
            isDefault: isDefault,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case locationText = "location_text"
        case notes
        case isDefault = "is_default"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
