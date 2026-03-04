import Foundation
import Supabase

struct TripsRepository {
    let client: SupabaseClient

    func fetchStores(userId: UUID) async throws -> [StoreLocation] {
        let response: PostgrestResponse<[StoreRow]> = try await client.database
            .from("stores")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: true)
            .execute()
        return response.value.map { $0.toStoreLocation() }
    }

    func fetchTrips(userId: UUID) async throws -> [Trip] {
        let tripsResponse: PostgrestResponse<[TripRow]> = try await client.database
            .from("trips")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("finished_at", ascending: false)
            .execute()

        let itemsResponse: PostgrestResponse<[TripItemRow]> = try await client.database
            .from("trip_items")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()

        let itemsByTrip = Dictionary(grouping: itemsResponse.value, by: { $0.tripId })
        return tripsResponse.value.map { row in
            let items = (itemsByTrip[row.id] ?? []).map { $0.toCartItem() }
            return row.toTrip(items: items)
        }
    }

    func insertStore(_ store: StoreLocation, userId: UUID) async throws {
        let row = StoreRow(store: store, userId: userId)
        _ = try await client.database
            .from("stores")
            .upsert(row, onConflict: "id")
            .execute()
    }

    func insertTrip(_ trip: Trip, userId: UUID) async throws {
        let tripRow = TripRow(trip: trip, userId: userId)
        _ = try await client.database
            .from("trips")
            .upsert(tripRow, onConflict: "id")
            .execute()

        let itemRows = trip.items.map { TripItemRow(item: $0, tripId: trip.id, userId: userId) }
        if !itemRows.isEmpty {
            _ = try await client.database
                .from("trip_items")
                .upsert(itemRows, onConflict: "id")
                .execute()
        }
    }
}

private struct StoreRow: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let colorKey: String
    let createdAt: Date

    init(store: StoreLocation, userId: UUID) {
        id = store.id
        self.userId = userId
        name = store.name
        colorKey = store.colorKey
        createdAt = store.createdAt
    }

    func toStoreLocation() -> StoreLocation {
        StoreLocation(id: id, name: name, colorKey: colorKey, createdAt: createdAt, plannedItems: [])
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case colorKey = "color_key"
        case createdAt = "created_at"
    }
}

private struct TripRow: Codable {
    let id: UUID
    let userId: UUID
    let storeId: UUID
    let storeNameSnapshot: String
    let storeColorKeySnapshot: String
    let startedAt: Date
    let finishedAt: Date
    let includeTax: Bool
    let taxRate: Double
    let subtotal: Double
    let taxAmount: Double
    let total: Double

    init(trip: Trip, userId: UUID) {
        id = trip.id
        self.userId = userId
        storeId = trip.storeId
        storeNameSnapshot = trip.storeNameSnapshot
        storeColorKeySnapshot = trip.storeColorKeySnapshot
        startedAt = trip.startedAt
        finishedAt = trip.finishedAt
        includeTax = trip.includeTax
        taxRate = trip.taxRate
        subtotal = trip.subtotal
        taxAmount = trip.taxAmount
        total = trip.total
    }

    func toTrip(items: [CartItem]) -> Trip {
        Trip(
            id: id,
            storeId: storeId,
            storeNameSnapshot: storeNameSnapshot,
            storeColorKeySnapshot: storeColorKeySnapshot,
            startedAt: startedAt,
            finishedAt: finishedAt,
            items: items,
            includeTax: includeTax,
            taxRate: taxRate,
            subtotal: subtotal,
            taxAmount: taxAmount,
            total: total
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case storeId = "store_id"
        case storeNameSnapshot = "store_name_snapshot"
        case storeColorKeySnapshot = "store_color_key_snapshot"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case includeTax = "include_tax"
        case taxRate = "tax_rate"
        case subtotal
        case taxAmount = "tax_amount"
        case total
    }
}

private struct TripItemRow: Codable {
    let id: UUID
    let tripId: UUID
    let userId: UUID
    let name: String
    let unitPrice: Double
    let quantity: Int
    let symbolName: String
    let lineTotal: Double

    init(item: CartItem, tripId: UUID, userId: UUID) {
        id = item.id
        self.tripId = tripId
        self.userId = userId
        name = item.name
        unitPrice = item.unitPrice
        quantity = item.quantity
        symbolName = item.symbolName
        lineTotal = item.lineTotal
    }

    func toCartItem() -> CartItem {
        CartItem(id: id, name: name, unitPrice: unitPrice, quantity: quantity, symbolName: symbolName)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case userId = "user_id"
        case name
        case unitPrice = "unit_price"
        case quantity
        case symbolName = "symbol_name"
        case lineTotal = "line_total"
    }
}
