import Foundation

struct StoreLocation: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var colorKey: String
    var createdAt: Date
    var plannedItems: [PlannedItem]
}
