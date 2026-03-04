import Foundation

struct CartState: Codable, Equatable, Sendable {
    var items: [CartItem]
    var includeTax: Bool
    var taxRate: Double

    static let empty = CartState(items: [], includeTax: true, taxRate: 5.3)
}
