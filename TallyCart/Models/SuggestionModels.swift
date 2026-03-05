import Foundation

enum SuggestionBucket: String, Codable, CaseIterable, Sendable {
    case necessary
    case premium
}

struct SuggestionItemModel: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var bucket: SuggestionBucket
    var reason: String
    var confidence: Double?
    var tags: [String]

    init(
        id: UUID = UUID(),
        name: String,
        bucket: SuggestionBucket,
        reason: String,
        confidence: Double? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.bucket = bucket
        self.reason = reason
        self.confidence = confidence
        self.tags = tags
    }
}

struct SuggestionRunModel: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    let tripId: UUID
    let createdAt: Date
    let engineVersion: String
    let inputs: SuggestionInputs
    let outputs: SuggestionOutputs
    let stats: [String: Double]
}

struct SuggestionInputs: Codable, Equatable, Sendable {
    let tripId: UUID
    let storeId: UUID?
    let historyWindow: Int
    let budgetTargetCents: Int?
    let paceScore: Double
}

struct SuggestionOutputs: Codable, Equatable, Sendable {
    let necessary: [SuggestionItemModel]
    let premium: [SuggestionItemModel]
}

enum SuggestionAction: String, Codable, Sendable {
    case accepted
    case dismissed
}

struct SuggestionActionModel: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    let tripId: UUID
    let suggestionRunId: UUID
    let itemName: String
    let action: SuggestionAction
    let createdAt: Date
}
