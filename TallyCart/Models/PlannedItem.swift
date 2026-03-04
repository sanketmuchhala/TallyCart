import Foundation

struct PlannedItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var quantity: Int
    var createdAt: Date

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Item" : trimmed
    }
}
