import Foundation

enum TripLifecycleStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case active
    case done

    var displayName: String {
        switch self {
        case .planned:
            return "Planned"
        case .active:
            return "Active"
        case .done:
            return "Done"
        }
    }
}

struct TripModel: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    var storeId: UUID?
    var title: String
    var tripDate: Date
    var status: TripLifecycleStatus
    var plannedBudgetCents: Int?
    var actualSpendCents: Int?
    var currency: String
    var startedAt: Date?
    var completedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: UUID,
        userId: UUID,
        storeId: UUID?,
        title: String,
        tripDate: Date,
        status: TripLifecycleStatus,
        plannedBudgetCents: Int?,
        actualSpendCents: Int?,
        currency: String = "USD",
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.storeId = storeId
        self.title = title
        self.tripDate = tripDate
        self.status = status
        self.plannedBudgetCents = plannedBudgetCents
        self.actualSpendCents = actualSpendCents
        self.currency = currency
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
