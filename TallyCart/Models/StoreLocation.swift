import Foundation

struct StoreLocation: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var colorKey: String
    var createdAt: Date
    var plannedItems: [PlannedItem]
}
