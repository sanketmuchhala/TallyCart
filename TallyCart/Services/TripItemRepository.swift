import Foundation
import Supabase

struct TripItemRepository {
    let client: SupabaseClient

    func fetchItems(tripId: UUID, userId: UUID) async throws -> [TripItemModel] {
        let response: PostgrestResponse<[TripItemRow]> = try await client.database
            .from("trip_items")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("trip_id", value: tripId.uuidString)
            .order("sort_order", ascending: true)
            .execute()
        return response.value.map { $0.toModel() }
    }

    func fetchItemsForTrips(tripIds: [UUID], userId: UUID) async throws -> [TripItemModel] {
        guard !tripIds.isEmpty else { return [] }
        let response: PostgrestResponse<[TripItemRow]> = try await client.database
            .from("trip_items")
            .select()
            .eq("user_id", value: userId.uuidString)
            .in("trip_id", values: tripIds.map { $0.uuidString })
            .execute()
        return response.value.map { $0.toModel() }
    }

    func upsertItem(_ item: TripItemModel) async throws {
        let row = TripItemRow(model: item)
        _ = try await client.database
            .from("trip_items")
            .upsert(row, onConflict: "id")
            .execute()
    }

    func upsertItems(_ items: [TripItemModel]) async throws {
        guard !items.isEmpty else { return }
        let rows = items.map { TripItemRow(model: $0) }
        _ = try await client.database
            .from("trip_items")
            .upsert(rows, onConflict: "id")
            .execute()
    }

    func deleteItem(id: UUID) async throws {
        _ = try await client.database
            .from("trip_items")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

private struct TripItemRow: Codable {
    let id: UUID
    let userId: UUID
    let tripId: UUID
    let name: String
    let quantity: LossyString?
    let category: String?
    let isPurchased: Bool?
    let sortOrder: Int?
    let source: String?
    let createdAt: Date?
    let updatedAt: Date?

    init(model: TripItemModel) {
        id = model.id
        userId = model.userId
        tripId = model.tripId
        name = model.name
        quantity = LossyString(model.quantity)
        category = model.category
        isPurchased = model.isPurchased
        sortOrder = model.sortOrder
        source = model.source.rawValue
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }

    func toModel() -> TripItemModel {
        TripItemModel(
            id: id,
            userId: userId,
            tripId: tripId,
            name: name,
            quantity: quantity?.value,
            category: category,
            isPurchased: isPurchased ?? false,
            sortOrder: sortOrder ?? 0,
            source: TripItemSource(rawValue: source ?? "manual") ?? .manual,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case tripId = "trip_id"
        case name
        case quantity
        case category
        case isPurchased = "is_purchased"
        case sortOrder = "sort_order"
        case source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
