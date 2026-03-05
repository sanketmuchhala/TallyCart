import Foundation

enum TripItemSource: String, Codable, CaseIterable, Sendable {
    case manual
    case suggestion
    case template
    case `repeat`
}

struct TripItemModel: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    let tripId: UUID
    var name: String
    var quantity: String?
    var category: String?
    var isPurchased: Bool
    var sortOrder: Int
    var source: TripItemSource
    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: UUID,
        userId: UUID,
        tripId: UUID,
        name: String,
        quantity: String? = nil,
        category: String? = nil,
        isPurchased: Bool = false,
        sortOrder: Int = 0,
        source: TripItemSource = .manual,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.tripId = tripId
        self.name = name
        self.quantity = quantity
        self.category = category
        self.isPurchased = isPurchased
        self.sortOrder = sortOrder
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
