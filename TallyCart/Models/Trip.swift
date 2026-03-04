import Foundation

enum TripStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case finished
    case archived

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .finished: return "Finished"
        case .archived: return "Archived"
        }
    }

    var isEditable: Bool {
        self == .draft
    }
}

struct Trip: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let storeId: UUID
    let storeNameSnapshot: String
    let storeColorKeySnapshot: String
    let startedAt: Date
    let finishedAt: Date
    let items: [CartItem]
    let includeTax: Bool
    let taxRate: Double
    let subtotal: Double
    let taxAmount: Double
    let total: Double
    let status: TripStatus

    init(
        id: UUID,
        storeId: UUID,
        storeNameSnapshot: String,
        storeColorKeySnapshot: String,
        startedAt: Date,
        finishedAt: Date,
        items: [CartItem],
        includeTax: Bool,
        taxRate: Double,
        subtotal: Double,
        taxAmount: Double,
        total: Double,
        status: TripStatus = .finished
    ) {
        self.id = id
        self.storeId = storeId
        self.storeNameSnapshot = storeNameSnapshot
        self.storeColorKeySnapshot = storeColorKeySnapshot
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.items = items
        self.includeTax = includeTax
        self.taxRate = taxRate
        self.subtotal = subtotal
        self.taxAmount = taxAmount
        self.total = total
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        storeId = try container.decode(UUID.self, forKey: .storeId)
        storeNameSnapshot = try container.decode(String.self, forKey: .storeNameSnapshot)
        storeColorKeySnapshot = try container.decode(String.self, forKey: .storeColorKeySnapshot)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        finishedAt = try container.decode(Date.self, forKey: .finishedAt)
        items = try container.decode([CartItem].self, forKey: .items)
        includeTax = try container.decode(Bool.self, forKey: .includeTax)
        taxRate = try container.decode(Double.self, forKey: .taxRate)
        subtotal = try container.decode(Double.self, forKey: .subtotal)
        taxAmount = try container.decode(Double.self, forKey: .taxAmount)
        total = try container.decode(Double.self, forKey: .total)
        status = try container.decodeIfPresent(TripStatus.self, forKey: .status) ?? .finished
    }
}
