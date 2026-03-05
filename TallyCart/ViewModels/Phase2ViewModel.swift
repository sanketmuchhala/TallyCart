import Foundation
import Combine
import SwiftUI
import Supabase

@MainActor
final class Phase2ViewModel: ObservableObject {
    @Published var trips: [TripModel] = []
    @Published var tripItems: [UUID: [TripItemModel]] = [:]
    @Published var stores: [StoreModel] = []
    @Published var preferences: UserPreferencesModel?
    @Published var suggestionOutputs: [UUID: SuggestionOutputs] = [:]
    @Published var isLoading: Bool = false
    @Published private(set) var suggestionRunIds: [UUID: UUID] = [:]
    @Published var isSyncing: Bool = false
    @Published var errorMessage: String?
    @Published var storeErrorMessage: String?

    private var client: SupabaseClient?
    private var userId: UUID?
    private var tripRepository: TripRepository?
    private var tripItemRepository: TripItemRepository?
    private var storeRepository: StoreRepository?
    private var preferencesRepository: PreferencesRepository?
    private var suggestionRepository: SuggestionRepository?
    private let suggestionEngine: SuggestionEngine = RulesSuggestionEngineV1()

    func configure(client: SupabaseClient, userId: UUID) {
        self.client = client
        self.userId = userId
        tripRepository = TripRepository(client: client)
        tripItemRepository = TripItemRepository(client: client)
        storeRepository = StoreRepository(client: client)
        preferencesRepository = PreferencesRepository(client: client)
        suggestionRepository = SuggestionRepository(client: client)
    }

    func clear() {
        client = nil
        userId = nil
        tripRepository = nil
        tripItemRepository = nil
        storeRepository = nil
        preferencesRepository = nil
        suggestionRepository = nil
    }

    func loadInitialData() async {
        guard let userId, let tripRepository, let storeRepository, let preferencesRepository else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            async let storesTask = storeRepository.fetchStores(userId: userId)
            async let tripsTask = tripRepository.fetchTrips(userId: userId)
            async let prefsTask = preferencesRepository.fetchPreferences(userId: userId)
            let (stores, trips, prefs) = try await (storesTask, tripsTask, prefsTask)
            self.stores = stores
            self.trips = trips.sorted(by: { $0.tripDate > $1.tripDate })
            self.preferences = prefs ?? UserPreferencesModel.empty(userId: userId)
            try await prefetchTripItems(for: trips)
        } catch {
            print("[Sync] Failed: \(error)")
            errorMessage = "Could not sync data."
        }
        isLoading = false
    }

    func refresh() async {
        isSyncing = true
        await loadInitialData()
        isSyncing = false
    }

    func defaultStore() -> StoreModel? {
        stores.first(where: { $0.isDefault }) ?? stores.first
    }

    func createTrip(
        date: Date,
        storeId: UUID?,
        budgetCents: Int?,
        title: String?
    ) async -> TripModel? {
        guard let userId, let tripRepository else { return nil }
        let displayTitle = (title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        ? title!
        : "Grocery Trip"
        let trip = TripModel(
            id: UUID(),
            userId: userId,
            storeId: storeId,
            title: displayTitle,
            tripDate: date,
            status: .planned,
            plannedBudgetCents: budgetCents,
            actualSpendCents: nil
        )
        trips.insert(trip, at: 0)
        do {
            try await tripRepository.upsertTrip(trip)
            return trip
        } catch {
            print("[Sync] Trip create failed: \(error)")
            errorMessage = "Could not sync trip. It will retry on refresh."
            return trip
        }
    }

    func updateTrip(_ trip: TripModel) async {
        guard let tripRepository else { return }
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
        }
        do {
            try await tripRepository.upsertTrip(trip)
        } catch {
            errorMessage = "Could not update trip."
        }
    }

    func deleteTrip(_ trip: TripModel) async {
        guard let tripRepository else { return }
        let snapshot = trips
        trips.removeAll { $0.id == trip.id }
        do {
            try await tripRepository.deleteTrip(id: trip.id)
        } catch {
            trips = snapshot
            errorMessage = "Could not delete trip."
        }
    }

    func startTrip(_ trip: TripModel) async {
        var updated = trip
        updated.status = .active
        updated.startedAt = Date()
        await updateTrip(updated)
    }

    func completeTrip(_ trip: TripModel, actualSpendCents: Int?) async {
        var updated = trip
        updated.status = .done
        updated.completedAt = Date()
        updated.actualSpendCents = actualSpendCents
        await updateTrip(updated)
    }

    func loadItems(for tripId: UUID) async {
        guard let tripItemRepository, let userId else { return }
        do {
            let items = try await tripItemRepository.fetchItems(tripId: tripId, userId: userId)
            tripItems[tripId] = items.sorted(by: { $0.sortOrder < $1.sortOrder })
        } catch {
            errorMessage = "Could not load items."
        }
    }

    func addItem(to trip: TripModel, name: String, quantity: String?) async {
        guard let tripItemRepository, let userId else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newItem = TripItemModel(
            id: UUID(),
            userId: userId,
            tripId: trip.id,
            name: trimmed,
            quantity: quantity?.trimmingCharacters(in: .whitespacesAndNewlines),
            isPurchased: false,
            sortOrder: nextSortOrder(for: trip.id),
            source: .manual
        )
        var items = tripItems[trip.id] ?? []
        items.append(newItem)
        tripItems[trip.id] = items
        do {
            try await tripItemRepository.upsertItem(newItem)
        } catch {
            print("[Sync] Add item failed: \(error)")
            errorMessage = "Could not sync item. It will retry on refresh."
        }
    }

    func addItems(to trip: TripModel, names: [String], source: TripItemSource) async {
        guard let tripItemRepository, let userId else { return }
        let trimmed = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return }
        let snapshot = tripItems[trip.id] ?? []
        var items = snapshot
        let startingOrder = nextSortOrder(for: trip.id)
        let newItems = trimmed.enumerated().map { index, name in
            TripItemModel(
                id: UUID(),
                userId: userId,
                tripId: trip.id,
                name: name,
                quantity: nil,
                isPurchased: false,
                sortOrder: startingOrder + index,
                source: source
            )
        }
        items.append(contentsOf: newItems)
        tripItems[trip.id] = items
        do {
            try await tripItemRepository.upsertItems(newItems)
        } catch {
            print("[Sync] Add items failed: \(error)")
            errorMessage = "Could not sync items. It will retry on refresh."
        }
    }

    func togglePurchased(item: TripItemModel) async {
        guard let tripItemRepository else { return }
        var updated = item
        updated.isPurchased.toggle()
        updateItemInMemory(updated)
        do {
            try await tripItemRepository.upsertItem(updated)
        } catch {
            updateItemInMemory(item)
            errorMessage = "Could not update item."
        }
    }

    func updateItem(_ item: TripItemModel) async {
        guard let tripItemRepository else { return }
        updateItemInMemory(item)
        do {
            try await tripItemRepository.upsertItem(item)
        } catch {
            errorMessage = "Could not update item."
        }
    }

    func deleteItem(_ item: TripItemModel) async {
        guard let tripItemRepository else { return }
        let itemsSnapshot = tripItems[item.tripId] ?? []
        tripItems[item.tripId] = itemsSnapshot.filter { $0.id != item.id }
        do {
            try await tripItemRepository.deleteItem(id: item.id)
        } catch {
            tripItems[item.tripId] = itemsSnapshot
            errorMessage = "Could not delete item."
        }
    }

    func reorderItems(tripId: UUID, from source: IndexSet, to destination: Int) async {
        guard let tripItemRepository else { return }
        var items = tripItems[tripId] ?? []
        items.move(fromOffsets: source, toOffset: destination)
        items = items.enumerated().map { index, item in
            var updated = item
            updated.sortOrder = index
            return updated
        }
        tripItems[tripId] = items
        do {
            try await tripItemRepository.upsertItems(items)
        } catch {
            errorMessage = "Could not reorder items."
        }
    }

    func generateSuggestions(for trip: TripModel) async {
        guard let tripRepository,
              let tripItemRepository,
              let suggestionRepository,
              let userId else { return }
        do {
            let historyTrips = try await tripRepository.fetchRecentDoneTrips(userId: userId, limit: 5)
            let historyTripIds = historyTrips.map { $0.id }
            let historyItems = try await tripItemRepository.fetchItemsForTrips(tripIds: historyTripIds, userId: userId)
            let dismissed = try await suggestionRepository.fetchDismissedItems(tripId: trip.id, userId: userId)
            let prefs = preferences ?? UserPreferencesModel.empty(userId: userId)
            let outputs = suggestionEngine.generate(
                trip: trip,
                currentItems: tripItems[trip.id] ?? [],
                historyTrips: historyTrips,
                historyItems: historyItems,
                preferences: prefs,
                dismissedItems: dismissed
            )
            suggestionOutputs[trip.id] = outputs

            let run = SuggestionRunModel(
                id: UUID(),
                userId: userId,
                tripId: trip.id,
                createdAt: Date(),
                engineVersion: "rules_v1",
                inputs: SuggestionInputs(
                    tripId: trip.id,
                    storeId: trip.storeId,
                    historyWindow: 5,
                    budgetTargetCents: prefs.monthlyBudgetCents,
                    paceScore: 0
                ),
                outputs: outputs,
                stats: [:]
            )
            suggestionRunIds[trip.id] = run.id
            try await suggestionRepository.insertRun(run)
        } catch {
            errorMessage = "Could not generate suggestions."
        }
    }

    func applySuggestions(trip: TripModel, selections: [SuggestionItemModel]) async {
        guard let userId, let suggestionRepository else { return }
        for suggestion in selections {
            await addItem(to: trip, name: suggestion.name, quantity: nil)
        }
        let runId = suggestionRunIds[trip.id] ?? UUID()
        let actions = selections.map {
            SuggestionActionModel(
                id: UUID(),
                userId: userId,
                tripId: trip.id,
                suggestionRunId: runId,
                itemName: $0.name,
                action: .accepted,
                createdAt: Date()
            )
        }
        do {
            try await suggestionRepository.insertActions(actions)
            removeSuggestions(tripId: trip.id, selections: selections)
        } catch {
            errorMessage = "Could not save suggestion actions."
        }
    }

    func dismissSuggestions(trip: TripModel, selections: [SuggestionItemModel]) async {
        guard let userId, let suggestionRepository else { return }
        let runId = suggestionRunIds[trip.id] ?? UUID()
        let actions = selections.map {
            SuggestionActionModel(
                id: UUID(),
                userId: userId,
                tripId: trip.id,
                suggestionRunId: runId,
                itemName: $0.name,
                action: .dismissed,
                createdAt: Date()
            )
        }
        do {
            try await suggestionRepository.insertActions(actions)
            removeSuggestions(tripId: trip.id, selections: selections)
        } catch {
            errorMessage = "Could not save suggestion actions."
        }
    }

    func upsertStore(name: String, location: String?, notes: String?, isDefault: Bool) async -> Bool {
        guard let storeRepository, let userId else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let store = StoreModel(
            id: UUID(),
            userId: userId,
            name: trimmed,
            locationText: location?.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            isDefault: isDefault
        )
        stores.append(store)
        do {
            try await storeRepository.upsertStore(store)
            return true
        } catch {
            stores.removeAll { $0.id == store.id }
            storeErrorMessage = "Could not save store."
            return false
        }
    }

    func updateStore(_ store: StoreModel) async -> Bool {
        guard let storeRepository else { return false }
        if let index = stores.firstIndex(where: { $0.id == store.id }) {
            stores[index] = store
        }
        do {
            try await storeRepository.upsertStore(store)
            return true
        } catch {
            storeErrorMessage = "Could not update store."
            return false
        }
    }

    func setDefaultStore(_ store: StoreModel) async {
        var updatedStores = stores
        updatedStores = updatedStores.map { current in
            var adjusted = current
            adjusted.isDefault = current.id == store.id
            return adjusted
        }
        stores = updatedStores
        for store in updatedStores {
            await updateStore(store)
        }
    }

    func updatePreferences(_ preferences: UserPreferencesModel) async {
        guard let preferencesRepository else { return }
        self.preferences = preferences
        do {
            try await preferencesRepository.upsertPreferences(preferences)
        } catch {
            errorMessage = "Could not save preferences."
        }
    }

    private func updateItemInMemory(_ item: TripItemModel) {
        var items = tripItems[item.tripId] ?? []
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
        tripItems[item.tripId] = items
    }

    private func nextSortOrder(for tripId: UUID) -> Int {
        let items = tripItems[tripId] ?? []
        return (items.map { $0.sortOrder }.max() ?? -1) + 1
    }

    private func removeSuggestions(tripId: UUID, selections: [SuggestionItemModel]) {
        guard let outputs = suggestionOutputs[tripId], !selections.isEmpty else { return }
        let ids = Set(selections.map { $0.id })
        let updated = SuggestionOutputs(
            necessary: outputs.necessary.filter { !ids.contains($0.id) },
            premium: outputs.premium.filter { !ids.contains($0.id) }
        )
        suggestionOutputs[tripId] = updated
    }

    private func prefetchTripItems(for trips: [TripModel]) async throws {
        guard let tripItemRepository, let userId else { return }
        let ids = trips.map { $0.id }
        let items = try await tripItemRepository.fetchItemsForTrips(tripIds: ids, userId: userId)
        let grouped = Dictionary(grouping: items, by: { $0.tripId })
        tripItems = grouped
    }
}
