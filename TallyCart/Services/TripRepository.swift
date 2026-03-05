import Foundation
import Supabase

struct TripRepository {
    let client: SupabaseClient

    func fetchTrips(userId: UUID) async throws -> [TripModel] {
        let response: PostgrestResponse<[TripRow]> = try await client.database
            .from("trips")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("trip_date", ascending: false)
            .execute()
        return response.value.map { $0.toModel() }
    }

    func fetchRecentDoneTrips(userId: UUID, limit: Int) async throws -> [TripModel] {
        let response: PostgrestResponse<[TripRow]> = try await client.database
            .from("trips")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: TripLifecycleStatus.done.rawValue)
            .order("completed_at", ascending: false)
            .limit(limit)
            .execute()
        return response.value.map { $0.toModel() }
    }

    func upsertTrip(_ trip: TripModel) async throws {
        let row = TripRow(model: trip)
        _ = try await client.database
            .from("trips")
            .upsert(row, onConflict: "id")
            .execute()
    }

    func deleteTrip(id: UUID) async throws {
        _ = try await client.database
            .from("trips")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

private struct TripRow: Codable {
    let id: UUID
    let userId: UUID
    let storeId: UUID?
    let title: String?
    let tripDate: Date?
    let status: String?
    let plannedBudgetCents: Int?
    let actualSpendCents: Int?
    let currency: String?
    let startedAt: Date?
    let completedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?
    let legacyFinishedAt: Date?

    init(model: TripModel) {
        id = model.id
        userId = model.userId
        storeId = model.storeId
        title = model.title
        tripDate = model.tripDate
        status = model.status.rawValue
        plannedBudgetCents = model.plannedBudgetCents
        actualSpendCents = model.actualSpendCents
        currency = model.currency
        startedAt = model.startedAt
        completedAt = model.completedAt
        createdAt = model.createdAt
        updatedAt = model.updatedAt
        legacyFinishedAt = nil
    }

    func toModel() -> TripModel {
        let derivedDate = tripDate ?? completedAt ?? startedAt ?? legacyFinishedAt ?? Date()
        let derivedStatus = TripLifecycleStatus(rawValue: status ?? "") ?? ((completedAt ?? legacyFinishedAt) != nil ? .done : .planned)
        return TripModel(
            id: id,
            userId: userId,
            storeId: storeId,
            title: title ?? "Grocery Trip",
            tripDate: derivedDate,
            status: derivedStatus,
            plannedBudgetCents: plannedBudgetCents,
            actualSpendCents: actualSpendCents,
            currency: currency ?? "USD",
            startedAt: startedAt,
            completedAt: completedAt ?? legacyFinishedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case storeId = "store_id"
        case title
        case tripDate = "trip_date"
        case status
        case plannedBudgetCents = "planned_budget_cents"
        case actualSpendCents = "actual_spend_cents"
        case currency
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case legacyFinishedAt = "finished_at"
    }
}
