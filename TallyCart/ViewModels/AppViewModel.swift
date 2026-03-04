import Foundation
import SwiftUI
import Combine
import Supabase

final class AppViewModel: ObservableObject {
    @Published var state: AppState {
        didSet {
            schedulePersist()
        }
    }

    @Published var currentTripStartedAt: Date
    @Published var isLoading: Bool = true
    @Published var isSyncing: Bool = false
    @Published var syncErrorMessage: String?

    private var persistTask: Task<Void, Never>?
    private var repository: TripsRepository?
    private var userId: UUID?

    init() {
        state = .empty
        currentTripStartedAt = Date()
        Task.detached(priority: .utility) {
            let loaded = await Self.loadStateAsync()
            await MainActor.run {
                self.state = loaded
                if !loaded.currentCart.items.isEmpty {
                    self.currentTripStartedAt = Date()
                }
                self.isLoading = false
                self.schedulePersist()
            }
        }
    }

    var subtotal: Double {
        state.currentCart.items.reduce(0) { $0 + $1.lineTotal }
    }

    var taxAmount: Double {
        guard state.currentCart.includeTax else { return 0 }
        return subtotal * (state.currentCart.taxRate / 100.0)
    }

    var total: Double {
        subtotal + taxAmount
    }

    var selectedStore: StoreLocation? {
        guard let id = state.selectedStoreId else { return nil }
        return state.stores.first { $0.id == id }
    }

    func configureSupabase(client: SupabaseClient, userId: UUID) {
        repository = TripsRepository(client: client)
        self.userId = userId
    }

    func clearSupabase() {
        repository = nil
        userId = nil
    }

    func addStore(name: String, colorKey: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let store = StoreLocation(id: UUID(), name: trimmed, colorKey: colorKey, createdAt: Date(), plannedItems: [])
        state.stores.append(store)
        if state.selectedStoreId == nil {
            state.selectedStoreId = store.id
        }
        Task { await uploadStoreIfPossible(store) }
    }

    func selectStore(_ storeId: UUID?) {
        state.selectedStoreId = storeId
    }

    func addPlannedItem(storeId: UUID, name: String, quantity: Int) {
        guard let index = state.stores.firstIndex(where: { $0.id == storeId }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let planned = PlannedItem(id: UUID(), name: trimmed, quantity: max(1, min(99, quantity)), createdAt: Date())
        state.stores[index].plannedItems.append(planned)
    }

    func deletePlannedItem(storeId: UUID, itemId: UUID) {
        guard let index = state.stores.firstIndex(where: { $0.id == storeId }) else { return }
        state.stores[index].plannedItems.removeAll { $0.id == itemId }
    }

    func movePlannedItemToCart(storeId: UUID, itemId: UUID) -> PlannedItem? {
        guard let storeIndex = state.stores.firstIndex(where: { $0.id == storeId }) else { return nil }
        guard let itemIndex = state.stores[storeIndex].plannedItems.firstIndex(where: { $0.id == itemId }) else { return nil }
        return state.stores[storeIndex].plannedItems.remove(at: itemIndex)
    }

    func addItem(name: String, price: Double, quantity: Int) {
        if state.currentCart.items.isEmpty {
            currentTripStartedAt = Date()
        }
        let symbol = Self.symbols[state.currentCart.items.count % Self.symbols.count]
        let item = CartItem(id: UUID(), name: name, unitPrice: price, quantity: quantity, symbolName: symbol)
        state.currentCart.items.append(item)
    }

    func deleteItem(_ item: CartItem) {
        guard let index = state.currentCart.items.firstIndex(of: item) else { return }
        state.currentCart.items.remove(at: index)
    }

    func updateQuantity(id: UUID, quantity: Int) {
        guard let index = state.currentCart.items.firstIndex(where: { $0.id == id }) else { return }
        state.currentCart.items[index].quantity = max(1, min(99, quantity))
    }

    func updateIncludeTax(_ include: Bool) {
        state.currentCart.includeTax = include
    }

    func updateTaxRate(_ rate: Double) {
        let clamped = min(max(rate, 0), 20)
        state.currentCart.taxRate = clamped
    }

    func clearCart(keepTaxSettings: Bool = true) {
        let includeTax = keepTaxSettings ? state.currentCart.includeTax : true
        let taxRate = keepTaxSettings ? state.currentCart.taxRate : 5.3
        state.currentCart = CartState(items: [], includeTax: includeTax, taxRate: taxRate)
    }

    func finishTrip() {
        guard let store = selectedStore, !state.currentCart.items.isEmpty else { return }
        let trip = Trip(
            id: UUID(),
            storeId: store.id,
            storeNameSnapshot: store.name,
            storeColorKeySnapshot: store.colorKey,
            startedAt: currentTripStartedAt,
            finishedAt: Date(),
            items: state.currentCart.items,
            includeTax: state.currentCart.includeTax,
            taxRate: state.currentCart.taxRate,
            subtotal: subtotal,
            taxAmount: taxAmount,
            total: total
        )
        state.trips.insert(trip, at: 0)
        markTripPending(trip.id)
        clearCart(keepTaxSettings: true)
        currentTripStartedAt = Date()
        Task { await uploadTripIfPossible(trip) }
    }

    func tripsGroupedByMonth() -> [(month: Date, trips: [Trip])] {
        let grouped = Dictionary(grouping: state.trips) { trip in
            Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: trip.finishedAt)) ?? trip.finishedAt
        }
        return grouped
            .map { ($0.key, $0.value.sorted(by: { $0.finishedAt > $1.finishedAt })) }
            .sorted(by: { $0.month > $1.month })
    }

    func monthTotals() -> [Date: Double] {
        var result: [Date: Double] = [:]
        for trip in state.trips {
            let key = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: trip.finishedAt)) ?? trip.finishedAt
            result[key, default: 0] += trip.total
        }
        return result
    }

    func storeBreakdown(for month: Date) -> [(storeName: String, colorKey: String, total: Double)] {
        let monthTrips = state.trips.filter {
            Calendar.current.isDate($0.finishedAt, equalTo: month, toGranularity: .month)
        }
        let grouped = Dictionary(grouping: monthTrips, by: { $0.storeId })
        return grouped.compactMap { entry in
            let trips = entry.value
            let total = trips.reduce(0) { $0 + $1.total }
            let name = trips.first?.storeNameSnapshot ?? "Store"
            let colorKey = trips.first?.storeColorKeySnapshot ?? "blue"
            return (name, colorKey, total)
        }.sorted(by: { $0.total > $1.total })
    }

    func syncFromSupabase() async {
        guard let repository, let userId else { return }
        await MainActor.run {
            isSyncing = true
            syncErrorMessage = nil
        }
        do {
            let remoteStores = try await repository.fetchStores(userId: userId)
            let remoteTrips = try await repository.fetchTrips(userId: userId)
            await MainActor.run {
                mergeStores(remoteStores)
                mergeTrips(remoteTrips)
                isSyncing = false
            }
            try await uploadMissingStores(remoteStores: remoteStores)
            await uploadPendingTrips()
        } catch {
            await MainActor.run {
                isSyncing = false
                syncErrorMessage = "Sync failed. We'll retry on the next launch."
            }
        }
    }

    func uploadPendingTrips() async {
        guard let repository, let userId else { return }
        let pendingIds = await MainActor.run { Set(state.pendingTripIds) }
        let trips = await MainActor.run { state.trips.filter { pendingIds.contains($0.id) } }
        for trip in trips {
            do {
                try await repository.insertTrip(trip, userId: userId)
                await MainActor.run { removePendingTripId(trip.id) }
            } catch {
                await MainActor.run {
                    syncErrorMessage = "Some trips are waiting to upload."
                }
                break
            }
        }
    }

    private func uploadTripIfPossible(_ trip: Trip) async {
        guard let repository, let userId else { return }
        do {
            try await repository.insertTrip(trip, userId: userId)
            await MainActor.run { removePendingTripId(trip.id) }
        } catch {
            await MainActor.run {
                syncErrorMessage = "Trip saved locally and will sync when online."
            }
        }
    }

    private func uploadStoreIfPossible(_ store: StoreLocation) async {
        guard let repository, let userId else { return }
        do {
            try await repository.insertStore(store, userId: userId)
        } catch {
            await MainActor.run {
                syncErrorMessage = "Store saved locally and will sync later."
            }
        }
    }

    private func uploadMissingStores(remoteStores: [StoreLocation]) async throws {
        guard let repository, let userId else { return }
        let remoteIds = Set(remoteStores.map { $0.id })
        let localStores = await MainActor.run { state.stores }
        let missing = localStores.filter { !remoteIds.contains($0.id) }
        for store in missing {
            try await repository.insertStore(store, userId: userId)
        }
    }

    private func mergeStores(_ remoteStores: [StoreLocation]) {
        let localById = Dictionary(uniqueKeysWithValues: state.stores.map { ($0.id, $0) })
        let remoteIds = Set(remoteStores.map { $0.id })
        var merged: [StoreLocation] = remoteStores.map { remote in
            if let local = localById[remote.id] {
                return StoreLocation(
                    id: remote.id,
                    name: remote.name,
                    colorKey: remote.colorKey,
                    createdAt: remote.createdAt,
                    plannedItems: local.plannedItems
                )
            }
            return remote
        }
        let localOnly = state.stores.filter { !remoteIds.contains($0.id) }
        merged.append(contentsOf: localOnly)
        state.stores = merged
        if state.selectedStoreId == nil {
            state.selectedStoreId = merged.first?.id
        }
    }

    private func mergeTrips(_ remoteTrips: [Trip]) {
        let remoteIds = Set(remoteTrips.map { $0.id })
        let localOnly = state.trips.filter { !remoteIds.contains($0.id) }
        state.trips = (remoteTrips + localOnly).sorted(by: { $0.finishedAt > $1.finishedAt })
        state.pendingTripIds.removeAll { remoteIds.contains($0) }
    }

    private func markTripPending(_ tripId: UUID) {
        if !state.pendingTripIds.contains(tripId) {
            state.pendingTripIds.append(tripId)
        }
    }

    private func removePendingTripId(_ tripId: UUID) {
        state.pendingTripIds.removeAll { $0 == tripId }
    }

    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { [state] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            AppStateStore.persist(state)
        }
    }

    private static func loadStateAsync() async -> AppState {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: AppStateStore.load())
            }
        }
    }

    private static let symbols = ["cart", "tag", "cart.fill", "bag", "creditcard", "basket", "shippingbox"]
}

struct StorePalette {
    static let keys = ["blue", "indigo", "purple", "pink", "red", "orange", "yellow", "green", "mint", "teal"]

    static func color(for key: String) -> Color {
        switch key {
        case "blue": return Color.blue
        case "indigo": return Color.indigo
        case "purple": return Color.purple
        case "pink": return Color.pink
        case "red": return Color.red
        case "orange": return Color.orange
        case "yellow": return Color.yellow
        case "green": return Color.green
        case "mint": return Color.mint
        case "teal": return Color.teal
        default: return Color.blue
        }
    }
}
