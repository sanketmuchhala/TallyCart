import Foundation
import Supabase

struct SuggestionRepository {
    let client: SupabaseClient

    func insertRun(_ run: SuggestionRunModel) async throws {
        let row = SuggestionRunRow(model: run)
        _ = try await client.database
            .from("suggestion_runs")
            .insert(row)
            .execute()
    }

    func insertActions(_ actions: [SuggestionActionModel]) async throws {
        guard !actions.isEmpty else { return }
        let rows = actions.map { SuggestionActionRow(model: $0) }
        _ = try await client.database
            .from("suggestion_actions")
            .insert(rows)
            .execute()
    }

    func fetchDismissedItems(tripId: UUID, userId: UUID) async throws -> Set<String> {
        let response: PostgrestResponse<[SuggestionActionRow]> = try await client.database
            .from("suggestion_actions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("trip_id", value: tripId.uuidString)
            .eq("action", value: SuggestionAction.dismissed.rawValue)
            .execute()
        return Set(response.value.map { $0.itemName.lowercased() })
    }
}

private struct SuggestionRunRow: Codable {
    let id: UUID
    let userId: UUID
    let tripId: UUID
    let createdAt: Date
    let engineVersion: String
    let inputs: SuggestionInputs
    let outputs: SuggestionOutputs
    let stats: [String: Double]

    init(model: SuggestionRunModel) {
        id = model.id
        userId = model.userId
        tripId = model.tripId
        createdAt = model.createdAt
        engineVersion = model.engineVersion
        inputs = model.inputs
        outputs = model.outputs
        stats = model.stats
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case tripId = "trip_id"
        case createdAt = "created_at"
        case engineVersion = "engine_version"
        case inputs
        case outputs
        case stats
    }
}

private struct SuggestionActionRow: Codable {
    let id: UUID
    let userId: UUID
    let tripId: UUID
    let suggestionRunId: UUID
    let itemName: String
    let action: String
    let createdAt: Date

    init(model: SuggestionActionModel) {
        id = model.id
        userId = model.userId
        tripId = model.tripId
        suggestionRunId = model.suggestionRunId
        itemName = model.itemName
        action = model.action.rawValue
        createdAt = model.createdAt
    }

    func toModel() -> SuggestionActionModel? {
        guard let action = SuggestionAction(rawValue: action) else { return nil }
        return SuggestionActionModel(
            id: id,
            userId: userId,
            tripId: tripId,
            suggestionRunId: suggestionRunId,
            itemName: itemName,
            action: action,
            createdAt: createdAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case tripId = "trip_id"
        case suggestionRunId = "suggestion_run_id"
        case itemName = "item_name"
        case action
        case createdAt = "created_at"
    }
}
