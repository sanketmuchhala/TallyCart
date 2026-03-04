import Foundation

struct Trip: Identifiable, Codable, Equatable {
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
}
