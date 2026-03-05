import Foundation

struct StoreModel: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var locationText: String?
    var notes: String?
    var isDefault: Bool
    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: UUID,
        userId: UUID,
        name: String,
        locationText: String? = nil,
        notes: String? = nil,
        isDefault: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.locationText = locationText
        self.notes = notes
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
