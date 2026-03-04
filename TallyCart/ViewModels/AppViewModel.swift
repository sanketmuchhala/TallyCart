import Foundation
import SwiftUI
import Combine

final class AppViewModel: ObservableObject {
    @Published var state: AppState {
        didSet {
            schedulePersist()
        }
    }

    @Published var currentTripStartedAt: Date

    private var persistTask: Task<Void, Never>?

    init() {
        state = .empty
        currentTripStartedAt = Date()
        Task { @MainActor in
            let loaded = Self.loadState()
            state = loaded
            if !loaded.currentCart.items.isEmpty {
                currentTripStartedAt = Date()
            }
            schedulePersist()
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

    func addStore(name: String, colorKey: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let store = StoreLocation(id: UUID(), name: trimmed, colorKey: colorKey, createdAt: Date(), plannedItems: [])
        state.stores.append(store)
        if state.selectedStoreId == nil {
            state.selectedStoreId = store.id
        }
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
        clearCart(keepTaxSettings: true)
        currentTripStartedAt = Date()
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

    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { [state] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            Self.persist(state: state)
        }
    }

    private static func persist(state: AppState) {
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    private static func loadState() -> AppState {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return .empty }
        do {
            return try JSONDecoder().decode(AppState.self, from: data)
        } catch {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return .empty
        }
    }

    private static let storageKey = "tallycart_app_state"
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
