import Foundation

protocol SuggestionEngine {
    func generate(
        trip: TripModel,
        currentItems: [TripItemModel],
        historyTrips: [TripModel],
        historyItems: [TripItemModel],
        preferences: UserPreferencesModel,
        dismissedItems: Set<String>
    ) -> SuggestionOutputs
}

struct RulesSuggestionEngineV1: SuggestionEngine {
    private let maxNecessary = 12
    private let maxPremium = 8

    func generate(
        trip: TripModel,
        currentItems: [TripItemModel],
        historyTrips: [TripModel],
        historyItems: [TripItemModel],
        preferences: UserPreferencesModel,
        dismissedItems: Set<String>
    ) -> SuggestionOutputs {
        let normalizedCurrent = Set(currentItems.map { $0.name.lowercased() })
        let avoid = Set(preferences.avoidItems.map { $0.lowercased() })
        let dismissed = dismissedItems

        let historyWindow = Array(historyTrips.prefix(5))
        let windowTripIds = Set(historyWindow.map { $0.id })
        let windowItems = historyItems.filter { windowTripIds.contains($0.tripId) }

        var frequency: [String: Int] = [:]
        var recencyBoost: [String: Int] = [:]

        for (index, trip) in historyWindow.enumerated() {
            let itemsForTrip = windowItems.filter { $0.tripId == trip.id }
            for item in itemsForTrip {
                let key = item.name.lowercased()
                frequency[key, default: 0] += 1
                if index == 0 {
                    recencyBoost[key, default: 0] += 1
                }
            }
        }

        let staples = Set(preferences.staplesItems.map { $0.lowercased() })
        let shouldSuggestStaples = preferences.alwaysSuggestStaples

        let budgetScore = paceScore(trips: historyTrips, preferences: preferences)
        let premiumAllowance = premiumCap(for: preferences.premiumSensitivity, paceScore: budgetScore)

        var necessary: [SuggestionItemModel] = []
        var premium: [SuggestionItemModel] = []

        let sortedCandidates = frequency.keys.sorted { (lhs, rhs) in
            let lhsScore = frequency[lhs, default: 0] * 2 + recencyBoost[lhs, default: 0]
            let rhsScore = frequency[rhs, default: 0] * 2 + recencyBoost[rhs, default: 0]
            return lhsScore > rhsScore
        }

        for name in sortedCandidates {
            if normalizedCurrent.contains(name) || avoid.contains(name) || dismissed.contains(name) {
                continue
            }
            let freq = frequency[name, default: 0]
            let isStaple = staples.contains(name)
            let reason: String
            if isStaple {
                reason = "Staple item you keep"
            } else if freq >= 2 {
                reason = "Bought in your last \(min(freq, 3)) trips"
            } else if recencyBoost[name, default: 0] > 0 {
                reason = "Bought on your last trip"
            } else {
                reason = "Often bought recently"
            }

            if freq >= 2 || (isStaple && shouldSuggestStaples) {
                necessary.append(SuggestionItemModel(name: name.capitalized, bucket: .necessary, reason: reason))
            } else {
                premium.append(SuggestionItemModel(name: name.capitalized, bucket: .premium, reason: "Fits your budget pace"))
            }
        }

        if shouldSuggestStaples {
            for staple in staples {
                if normalizedCurrent.contains(staple) || avoid.contains(staple) || dismissed.contains(staple) {
                    continue
                }
                if !necessary.contains(where: { $0.name.lowercased() == staple }) {
                    necessary.append(SuggestionItemModel(name: staple.capitalized, bucket: .necessary, reason: "Staple item you keep"))
                }
            }
        }

        necessary = Array(necessary.prefix(maxNecessary))
        premium = Array(premium.prefix(premiumAllowance))

        return SuggestionOutputs(necessary: necessary, premium: premium)
    }

    private func paceScore(trips: [TripModel], preferences: UserPreferencesModel) -> Double {
        guard let budget = preferences.monthlyBudgetCents, budget > 0 else { return 0 }
        let now = Date()
        let calendar = Calendar.current
        let monthTrips = trips.filter { trip in
            guard let completed = trip.completedAt else { return false }
            return calendar.isDate(completed, equalTo: now, toGranularity: .month)
        }
        let spend = monthTrips.reduce(0) { result, trip in
            result + (trip.actualSpendCents ?? 0)
        }
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let dayOfMonth = calendar.component(.day, from: now)
        let paceTarget = Double(budget) * (Double(dayOfMonth) / Double(daysInMonth))
        return (Double(spend) - paceTarget) / Double(max(budget, 1))
    }

    private func premiumCap(for sensitivity: Int, paceScore: Double) -> Int {
        let base = max(2, min(10, sensitivity / 10))
        if paceScore > 0.15 {
            return max(2, base - 2)
        }
        if paceScore < -0.15 {
            return min(10, base + 2)
        }
        return base
    }
}
