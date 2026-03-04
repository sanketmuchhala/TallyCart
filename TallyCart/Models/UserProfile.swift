import Foundation

struct UserProfile: Codable, Equatable, Sendable {
    let id: UUID
    var email: String
    var createdAt: Date
}
