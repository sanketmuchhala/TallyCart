import Foundation

struct CartItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var unitPrice: Double
    var quantity: Int
    var symbolName: String

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Item" : trimmed
    }

    var lineTotal: Double {
        unitPrice * Double(quantity)
    }
}
