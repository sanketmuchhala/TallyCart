import Foundation

struct AppState: Codable, Equatable, Sendable {
    var currentCart: CartState
    var stores: [StoreLocation]
    var trips: [Trip]
    var selectedStoreId: UUID?
    var pendingTripIds: [UUID]

    static let empty = AppState(currentCart: .empty, stores: [], trips: [], selectedStoreId: nil, pendingTripIds: [])

    init(currentCart: CartState, stores: [StoreLocation], trips: [Trip], selectedStoreId: UUID?, pendingTripIds: [UUID]) {
        self.currentCart = currentCart
        self.stores = stores
        self.trips = trips
        self.selectedStoreId = selectedStoreId
        self.pendingTripIds = pendingTripIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentCart = try container.decodeIfPresent(CartState.self, forKey: .currentCart) ?? .empty
        stores = try container.decodeIfPresent([StoreLocation].self, forKey: .stores) ?? []
        trips = try container.decodeIfPresent([Trip].self, forKey: .trips) ?? []
        selectedStoreId = try container.decodeIfPresent(UUID.self, forKey: .selectedStoreId)
        pendingTripIds = try container.decodeIfPresent([UUID].self, forKey: .pendingTripIds) ?? []
    }
}
