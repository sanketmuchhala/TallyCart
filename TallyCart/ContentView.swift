import SwiftUI
import Combine
import CoreLocation
import MapKit

struct AppPalette {
    static let berry = Color(red: 0.86, green: 0.25, blue: 0.43)
    static let sky = Color(red: 0.22, green: 0.62, blue: 1.0)
    static let mint = Color(red: 0.23, green: 0.86, blue: 0.64)
    static let peach = Color(red: 1.0, green: 0.55, blue: 0.38)
    static let violet = Color(red: 0.62, green: 0.4, blue: 1.0)
}

struct CartItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var unitPrice: Double
    var quantity: Int
    var symbolName: String

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Item" : trimmed
    }

    var lineTotal: Double {
        unitPrice * Double(quantity)
    }
}

struct CartState: Codable, Equatable {
    var items: [CartItem]
    var includeTax: Bool
    var taxRate: Double

    static let empty = CartState(items: [], includeTax: true, taxRate: 5.3)
}

struct TripSummary: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let items: [CartItem]
    let itemCount: Int
    let subtotal: Double
    let taxAmount: Double
    let total: Double
    let includeTax: Bool
    let taxRate: Double
    let locationName: String
    let locationLatitude: Double?
    let locationLongitude: Double?

    var displayLocationName: String {
        "[Demo] \(locationName)"
    }
}

final class CartViewModel: ObservableObject {
    @Published var state: CartState {
        didSet {
            persist()
        }
    }

    @Published var tripHistory: [TripSummary] {
        didSet {
            persistHistory()
        }
    }

    init() {
        state = Self.loadState()
        tripHistory = Self.loadHistory()
    }

    var subtotal: Double {
        state.items.reduce(0) { $0 + $1.lineTotal }
    }

    var taxAmount: Double {
        guard state.includeTax else { return 0 }
        return subtotal * (state.taxRate / 100.0)
    }

    var total: Double {
        subtotal + taxAmount
    }

    func addItem(name: String, price: Double, quantity: Int) {
        let symbol = Self.symbols[state.items.count % Self.symbols.count]
        let item = CartItem(id: UUID(), name: name, unitPrice: price, quantity: quantity, symbolName: symbol)
        state.items.append(item)
    }

    func delete(item: CartItem) {
        guard let index = state.items.firstIndex(of: item) else { return }
        state.items.remove(at: index)
    }

    func updateQuantity(id: UUID, quantity: Int) {
        guard let index = state.items.firstIndex(where: { $0.id == id }) else { return }
        state.items[index].quantity = max(1, min(99, quantity))
    }

    func updateIncludeTax(_ include: Bool) {
        state.includeTax = include
    }

    func updateTaxRate(_ rate: Double) {
        state.taxRate = rate
    }

    func clearItems(keepTaxSettings: Bool = true) {
        let includeTax = keepTaxSettings ? state.includeTax : true
        let taxRate = keepTaxSettings ? state.taxRate : Self.defaultTaxRate
        state = CartState(items: [], includeTax: includeTax, taxRate: taxRate)
    }

    func finishTrip(locationName: String, location: CLLocation?) {
        guard !state.items.isEmpty else { return }
        let locationLatitude = location?.coordinate.latitude
        let locationLongitude = location?.coordinate.longitude
        let summary = TripSummary(
            id: UUID(),
            date: Date(),
            items: state.items,
            itemCount: state.items.count,
            subtotal: subtotal,
            taxAmount: taxAmount,
            total: total,
            includeTax: state.includeTax,
            taxRate: state.taxRate,
            locationName: locationName,
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude
        )
        tripHistory.insert(summary, at: 0)
        clearItems(keepTaxSettings: true)
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
    }

    private static func loadState() -> CartState {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return .empty
        }
        do {
            return try JSONDecoder().decode(CartState.self, from: data)
        } catch {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return .empty
        }
    }

    private func persistHistory() {
        do {
            let data = try JSONEncoder().encode(tripHistory)
            UserDefaults.standard.set(data, forKey: Self.historyKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: Self.historyKey)
        }
    }

    private static func loadHistory() -> [TripSummary] {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([TripSummary].self, from: data)
        } catch {
            UserDefaults.standard.removeObject(forKey: historyKey)
            return []
        }
    }

    private static let storageKey = "tallycart_state"
    private static let historyKey = "tallycart_trip_history"
    private static let defaultTaxRate = 5.3
    private static let symbols = ["cart", "tag", "cart.fill", "bag", "creditcard", "basket", "shippingbox"]
}

enum FocusedField: Hashable {
    case name
    case price
    case taxRate
}

struct ContentView: View {
    @StateObject private var viewModel = CartViewModel()
    @StateObject private var locationProvider = LocationProvider()

    @Environment(\.colorScheme) private var colorScheme

    @State private var itemName: String = ""
    @State private var priceText: String = ""
    @State private var quantity: Int = 1
    @State private var taxRateText: String = "5.3"
    @State private var showClearConfirm = false
    @State private var activeSwipeItemID: UUID?
    @State private var showReviewSheet = false

    @FocusState private var focusedField: FocusedField?

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundLayer
                ScrollView {
                    VStack(spacing: 18) {
                        SectionHeader(title: "Trip Summary", subtitle: "Live totals")
                        HeaderCard(
                            subtotal: viewModel.subtotal,
                            taxAmount: viewModel.taxAmount,
                            total: viewModel.total,
                            includeTax: viewModel.state.includeTax
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.total)

                        ActiveTripCard(
                            date: Date(),
                            itemCount: viewModel.state.items.count,
                            includeTax: viewModel.state.includeTax,
                            taxRate: viewModel.state.taxRate
                        )

                        SectionHeader(title: "Add Item", subtitle: "Name, price, and quantity")
                        AddItemCard(
                            itemName: $itemName,
                            priceText: $priceText,
                            quantity: $quantity,
                            includeTax: viewModel.state.includeTax,
                            taxRateText: $taxRateText,
                            focusedField: $focusedField,
                            quickAddItems: quickAddItems,
                            onQuickAdd: applyQuickAdd,
                            priceError: priceError,
                            addDisabled: !canAdd,
                            onToggleTax: { include in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.updateIncludeTax(include)
                                }
                            },
                            onTaxRateChanged: { newValue in
                                viewModel.updateTaxRate(newValue)
                            },
                            onAdd: addItem
                        )

                        SectionHeader(
                            title: "Items",
                            subtitle: viewModel.state.items.isEmpty ? "No items yet" : "\(viewModel.state.items.count) items"
                        )

                        if viewModel.state.items.isEmpty {
                            EmptyStateCard()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.state.items.indices, id: \.self) { index in
                                    let item = viewModel.state.items[index]
                                    ItemRow(
                                        item: item,
                                        lineTotal: item.lineTotal,
                                        quantity: Binding(
                                            get: { viewModel.state.items[index].quantity },
                                            set: { newValue in
                                                viewModel.updateQuantity(id: item.id, quantity: newValue)
                                            }
                                        ),
                                        activeSwipeItemID: $activeSwipeItemID,
                                        onDelete: {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                viewModel.delete(item: item)
                                            }
                                        }
                                    )
                                }
                            }
                            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.state.items)
                        }

                        if !viewModel.tripHistory.isEmpty {
                            SectionHeader(title: "Trip History", subtitle: "Past totals and locations")
                            TripHistorySection(trips: viewModel.tripHistory)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("TallyCart")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                BottomActionBar(
                    canFinish: !viewModel.state.items.isEmpty,
                    canClear: !viewModel.state.items.isEmpty,
                    onFinishTrip: {
                        showReviewSheet = true
                    },
                    onNewTrip: {
                        showClearConfirm = true
                    }
                )
            }
            .safeAreaInset(edge: .top) {
                SummaryBar(
                    total: viewModel.total,
                    subtotal: viewModel.subtotal,
                    includeTax: viewModel.state.includeTax,
                    taxAmount: viewModel.taxAmount
                )
            }
            .alert("Start a new trip?", isPresented: $showClearConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("New Trip", role: .destructive) {
                    triggerHaptics()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.clearItems(keepTaxSettings: true)
                    }
                    resetInputs()
                }
            } message: {
                Text("This will clear all items in your cart.")
            }
            .onAppear {
                taxRateText = formattedTaxRate(viewModel.state.taxRate)
            }
            .onChange(of: viewModel.state.taxRate) { _, newValue in
                if formattedTaxRate(newValue) != taxRateText {
                    taxRateText = formattedTaxRate(newValue)
                }
            }
            .sheet(isPresented: $showReviewSheet) {
                TripReviewSheet(
                    items: viewModel.state.items,
                    subtotal: viewModel.subtotal,
                    taxAmount: viewModel.taxAmount,
                    total: viewModel.total,
                    includeTax: viewModel.state.includeTax,
                    taxRate: viewModel.state.taxRate,
                    onCancel: {
                        showReviewSheet = false
                    },
                    onConfirm: {
                        triggerHaptics()
                        showReviewSheet = false
                        Task {
                            let resolved = await resolveLocation()
                            await MainActor.run {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    viewModel.finishTrip(locationName: resolved.name, location: resolved.location)
                                }
                                resetInputs()
                            }
                        }
                    }
                )
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(.systemGroupedBackground))
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    AppPalette.violet.opacity(colorScheme == .dark ? 0.35 : 0.25),
                    AppPalette.sky.opacity(colorScheme == .dark ? 0.25 : 0.2),
                    AppPalette.peach.opacity(colorScheme == .dark ? 0.18 : 0.16),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(colorScheme == .dark ? .screen : .normal)
            .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppPalette.berry.opacity(colorScheme == .dark ? 0.4 : 0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 240
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: 170, y: -190)
                .blur(radius: 6)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppPalette.mint.opacity(colorScheme == .dark ? 0.3 : 0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 260
                    )
                )
                .frame(width: 320, height: 320)
                .offset(x: -170, y: 260)
                .blur(radius: 10)
        }
    }

    private var canAdd: Bool {
        if priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return priceValue != nil
    }

    private var priceError: String? {
        if priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        return priceValue == nil ? "Enter a valid price." : nil
    }

    private var priceValue: Double? {
        parseDecimal(priceText)
    }

    private func addItem() {
        guard let price = priceValue else { return }
        triggerHaptics()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            viewModel.addItem(name: itemName, price: price, quantity: quantity)
        }
        resetInputs()
    }

    private func resetInputs() {
        itemName = ""
        priceText = ""
        quantity = 1
        focusedField = nil
    }

    private func parseDecimal(_ text: String) -> Double? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.generatesDecimalNumbers = true
        return formatter.number(from: text)?.doubleValue
    }

    private func formattedTaxRate(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    private func triggerHaptics() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private var quickAddItems: [QuickAddItem] {
        [
            QuickAddItem(title: "Milk", price: 3.79),
            QuickAddItem(title: "Eggs", price: 4.29),
            QuickAddItem(title: "Bread", price: 2.69),
            QuickAddItem(title: "Coffee", price: 5.49)
        ]
    }

    private func applyQuickAdd(_ item: QuickAddItem) {
        itemName = item.title
        priceText = String(format: "%.2f", item.price)
        quantity = 1
        focusedField = .price
    }

    private func resolveLocation() async -> (name: String, location: CLLocation?) {
        if Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") == nil {
            return ("Unknown (Demo)", nil)
        }

        if locationProvider.authorizationStatus == .notDetermined {
            locationProvider.requestAuthorization()
        }

        if locationProvider.authorizationStatus == .denied || locationProvider.authorizationStatus == .restricted {
            if let cached = locationProvider.lastLocation {
                let name = await locationProvider.reverseGeocodeName(from: cached)
                return (name ?? "Unknown (Demo)", cached)
            }
            return ("Unknown (Demo)", nil)
        }

        do {
            let location = try await locationProvider.requestLocation()
            let name = await locationProvider.reverseGeocodeName(from: location)
            return (name ?? "Unknown (Demo)", location)
        } catch {
            return ("Unknown (Demo)", nil)
        }
    }
}

struct HeaderCard: View {
    let subtotal: Double
    let taxAmount: Double
    let total: Double
    let includeTax: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(total.currencyString)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: "cart.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(
                        LinearGradient(
                            colors: [AppPalette.sky, AppPalette.violet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
            }

            HStack(spacing: 10) {
                InfoChip(title: "Subtotal", value: subtotal.currencyString, systemImage: "tag")
                if includeTax {
                    InfoChip(title: "Tax", value: taxAmount.currencyString, systemImage: "percent")
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [AppPalette.sky.opacity(0.6), AppPalette.violet.opacity(0.6), AppPalette.peach.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total \(total.currencyString)")
    }
}

struct InfoChip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.regularMaterial, in: Capsule())
    }
}

struct ActiveTripCard: View {
    let date: Date
    let itemCount: Int
    let includeTax: Bool
    let taxRate: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .padding(10)
                .background(
                    LinearGradient(
                        colors: [AppPalette.mint, AppPalette.sky],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Active Trip")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(itemCount) items")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(includeTax ? "Tax \(taxRate.formattedNumber)%" : "Tax off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [AppPalette.mint.opacity(0.6), AppPalette.sky.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 8)
    }
}

struct AddItemCard: View {
    @Binding var itemName: String
    @Binding var priceText: String
    @Binding var quantity: Int
    var includeTax: Bool
    @Binding var taxRateText: String
    var focusedField: FocusState<FocusedField?>.Binding
    let quickAddItems: [QuickAddItem]
    let onQuickAdd: (QuickAddItem) -> Void
    var priceError: String?
    var addDisabled: Bool
    var onToggleTax: (Bool) -> Void
    var onTaxRateChanged: (Double) -> Void
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 12) {
                if !quickAddItems.isEmpty {
                    QuickAddRow(items: quickAddItems, onSelect: onQuickAdd)
                }

                TextField("Item name (optional)", text: $itemName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused(focusedField, equals: .name)
                    .onSubmit {
                        focusedField.wrappedValue = .price
                    }
                    .accessibilityLabel("Item name")

                priceField

                if let priceError {
                    Text(priceError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }

                HStack {
                    Stepper(value: $quantity, in: 1...99) {
                        Text("Quantity")
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Text("x \(quantity)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Toggle(isOn: Binding(get: { includeTax }, set: onToggleTax)) {
                    Text("Include tax")
                }
                .toggleStyle(.switch)
                .accessibilityLabel("Include tax")

                if includeTax {
                    HStack {
                        Text("Tax rate")
                            .foregroundStyle(.primary)
                        Spacer()
                        HStack(spacing: 6) {
                            TextField("5.3", text: $taxRateText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                                .focused(focusedField, equals: .taxRate)
                                .onChange(of: taxRateText) { _, newValue in
                                    let value = parseDecimal(newValue) ?? 0
                                    onTaxRateChanged(value)
                                }
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Button(action: onAdd) {
                Label("Add Item", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(addDisabled)
            .accessibilityLabel("Add item")
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [AppPalette.berry.opacity(0.6), AppPalette.peach.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 14, x: 0, y: 6)
    }

    private var priceField: some View {
        HStack(spacing: 8) {
            Image(systemName: "tag")
                .foregroundStyle(.secondary)
            Text("$")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("0.00", text: $priceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused(focusedField, equals: .price)
                .accessibilityLabel("Price")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func parseDecimal(_ text: String) -> Double? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.generatesDecimalNumbers = true
        return formatter.number(from: text)?.doubleValue
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}

struct QuickAddItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let price: Double
}

struct QuickAddRow: View {
    let items: [QuickAddItem]
    let onSelect: (QuickAddItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption)
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                            Text(item.price.currencyString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            LinearGradient(
                                colors: [AppPalette.sky.opacity(0.35), AppPalette.violet.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct SummaryBar: View {
    let total: Double
    let subtotal: Double
    let includeTax: Bool
    let taxAmount: Double

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(total.currencyString)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Subtotal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(subtotal.currencyString)
                    .font(.subheadline.weight(.semibold))
            }
            if includeTax {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Tax")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(taxAmount.currencyString)
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            LinearGradient(
                colors: [AppPalette.violet.opacity(0.35), AppPalette.berry.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
    }
}

struct TripReviewSheet: View {
    let items: [CartItem]
    let subtotal: Double
    let taxAmount: Double
    let total: Double
    let includeTax: Bool
    let taxRate: Double
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HeaderCard(
                        subtotal: subtotal,
                        taxAmount: taxAmount,
                        total: total,
                        includeTax: includeTax
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Review")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("\(items.count) items • Tax \(includeTax ? "\(taxRate.formattedNumber)%" : "Off")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.primary.opacity(0.05), radius: 8, x: 0, y: 4)

                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            ItemRowReadOnly(item: item)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle("Finish Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        onConfirm()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct ItemRow: View {
    let item: CartItem
    let lineTotal: Double
    @Binding var quantity: Int
    @Binding var activeSwipeItemID: UUID?
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isHorizontalDrag = false

    private let swipeThreshold: CGFloat = -90
    private let deleteThreshold: CGFloat = -160

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteBackground
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            rowContent
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
                .offset(x: offset)
                .highPriorityGesture(dragGesture)
                .onTapGesture {
                    closeSwipe()
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName), \(quantity) at \(item.unitPrice.currencyString), total \(lineTotal.currencyString)")
        .onChange(of: activeSwipeItemID) { _, newValue in
            if newValue != item.id {
                closeSwipe()
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.violet.opacity(0.7), AppPalette.sky.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: item.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(quantity) x \(item.unitPrice.currencyString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(lineTotal.currencyString)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text("Qty \(quantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper("", value: $quantity, in: 1...99)
                        .labelsHidden()
                        .accessibilityLabel("Quantity")
                        .accessibilityValue("\(quantity)")
                }
            }
        }
    }

    private var deleteBackground: some View {
        HStack {
            Spacer()
            Button(role: .destructive, action: performDelete) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Delete")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(width: 88)
                .frame(maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [AppPalette.berry, AppPalette.peach],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let translationX = value.translation.width
                let translationY = value.translation.height
                if !isHorizontalDrag {
                    isHorizontalDrag = abs(translationX) > abs(translationY)
                }
                guard isHorizontalDrag else { return }
                activeSwipeItemID = item.id
                if translationX < 0 {
                    offset = max(translationX, deleteThreshold)
                } else {
                    offset = min(translationX, 0)
                }
            }
            .onEnded { value in
                let translation = value.translation.width
                isHorizontalDrag = false
                if translation <= deleteThreshold {
                    performDelete()
                    return
                }
                if translation <= swipeThreshold {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = swipeThreshold
                    }
                } else {
                    closeSwipe()
                }
            }
    }

    private func performDelete() {
        closeSwipe()
        onDelete()
    }

    private func closeSwipe() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            offset = 0
        }
        if activeSwipeItemID == item.id {
            activeSwipeItemID = nil
        }
    }
}

struct TripHistorySection: View {
    let trips: [TripSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trip History")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                ForEach(trips) { trip in
                    NavigationLink {
                        TripDetailView(trip: trip)
                    } label: {
                        TripHistoryRow(trip: trip)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 8)
    }
}

struct TripHistoryRow: View {
    let trip: TripSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(trip.displayLocationName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(trip.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(trip.itemCount) items • \(trip.includeTax ? "Tax \(trip.taxRate.formattedNumber)%" : "No tax")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(trip.total.currencyString)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.primary.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

struct TripDetailView: View {
    let trip: TripSummary

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeaderCard(
                    subtotal: trip.subtotal,
                    taxAmount: trip.taxAmount,
                    total: trip.total,
                    includeTax: trip.includeTax
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Trip Details")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(trip.displayLocationName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(trip.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.primary.opacity(0.05), radius: 8, x: 0, y: 4)

                LazyVStack(spacing: 12) {
                    ForEach(trip.items) { item in
                        ItemRowReadOnly(item: item)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ItemRowReadOnly: View {
    let item: CartItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.peach.opacity(0.7), AppPalette.berry.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: item.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(item.quantity) x \(item.unitPrice.currencyString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.lineTotal.currencyString)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.primary.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    @Published private(set) var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func reverseGeocodeName(from location: CLLocation) async -> String? {
        if #available(iOS 26.0, *) {
            do {
                guard let request = MKReverseGeocodingRequest(location: location),
                      let address = try await request.mapItems.first?.addressRepresentations else {
                    return nil
                }
                if let city = address.cityName, let region = address.regionName {
                    return "\(city), \(region)"
                }
                if let city = address.cityName {
                    return city
                }
                return address.regionName
            } catch {
                return nil
            }
        } else {
            return await reverseGeocodeLegacy(from: location)
        }
    }

    @available(iOS, deprecated: 26.0)
    private func reverseGeocodeLegacy(from location: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            if let name = placemark.name, !name.isEmpty {
                return name
            }
            if let locality = placemark.locality, let region = placemark.administrativeArea {
                return "\(locality), \(region)"
            }
            return placemark.administrativeArea ?? placemark.country
        } catch {
            return nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        lastLocation = location
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}

struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(AppPalette.sky)
            Text("Your cart is empty")
                .font(.headline)
            Text("Add items to start tracking your trip.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
        .multilineTextAlignment(.center)
    }
}

struct BottomActionBar: View {
    let canFinish: Bool
    let canClear: Bool
    let onFinishTrip: () -> Void
    let onNewTrip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onFinishTrip) {
                Label("Finish Trip", systemImage: "checkmark.seal.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canFinish)

            Button(role: .destructive, action: onNewTrip) {
                Label("New Trip", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!canClear)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

extension Double {
    var formattedNumber: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }
}

extension Double {
    var currencyString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
}

#Preview {
    ContentView()
}
