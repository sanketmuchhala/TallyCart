import Foundation

struct AppState: Codable, Equatable {
    var currentCart: CartState
    var stores: [StoreLocation]
    var trips: [Trip]
    var selectedStoreId: UUID?

    static let empty = AppState(currentCart: .empty, stores: [], trips: [], selectedStoreId: nil)
}
