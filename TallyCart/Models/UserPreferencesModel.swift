import Foundation

struct UserPreferencesModel: Codable, Equatable, Sendable {
    let userId: UUID
    var monthlyBudgetCents: Int?
    var householdSize: Int
    var premiumSensitivity: Int
    var alwaysSuggestStaples: Bool
    var dietFlags: [String: Bool]
    var avoidItems: [String]
    var preferredBrands: [String: [String]]
    var staplesItems: [String]
    var updatedAt: Date?

    init(
        userId: UUID,
        monthlyBudgetCents: Int? = nil,
        householdSize: Int = 1,
        premiumSensitivity: Int = 50,
        alwaysSuggestStaples: Bool = true,
        dietFlags: [String: Bool] = [:],
        avoidItems: [String] = [],
        preferredBrands: [String: [String]] = [:],
        staplesItems: [String] = [],
        updatedAt: Date? = nil
    ) {
        self.userId = userId
        self.monthlyBudgetCents = monthlyBudgetCents
        self.householdSize = householdSize
        self.premiumSensitivity = premiumSensitivity
        self.alwaysSuggestStaples = alwaysSuggestStaples
        self.dietFlags = dietFlags
        self.avoidItems = avoidItems
        self.preferredBrands = preferredBrands
        self.staplesItems = staplesItems
        self.updatedAt = updatedAt
    }

    static func empty(userId: UUID) -> UserPreferencesModel {
        UserPreferencesModel(userId: userId)
    }
}
