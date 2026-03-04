import SwiftUI
import Combine

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

    static let empty = CartState(items: [], includeTax: false, taxRate: 0)
}

final class CartViewModel: ObservableObject {
    @Published var state: CartState {
        didSet {
            persist()
        }
    }

    init() {
        state = Self.loadState()
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

    func clear() {
        state = .empty
    }

    func updateIncludeTax(_ include: Bool) {
        state.includeTax = include
    }

    func updateTaxRate(_ rate: Double) {
        state.taxRate = rate
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

    private static let storageKey = "tallycart_state"
    private static let symbols = ["cart", "tag", "cart.fill", "bag", "creditcard", "basket", "shippingbox"]
}

enum FocusedField: Hashable {
    case name
    case price
    case taxRate
}

struct ContentView: View {
    @StateObject private var viewModel = CartViewModel()

    @State private var itemName: String = ""
    @State private var priceText: String = ""
    @State private var quantity: Int = 1
    @State private var taxRateText: String = "0.0"
    @State private var showClearConfirm = false

    @FocusState private var focusedField: FocusedField?

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundLayer
                ScrollView {
                    VStack(spacing: 16) {
                        HeaderCard(
                            subtotal: viewModel.subtotal,
                            taxAmount: viewModel.taxAmount,
                            total: viewModel.total,
                            includeTax: viewModel.state.includeTax
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.total)

                        AddItemCard(
                            itemName: $itemName,
                            priceText: $priceText,
                            quantity: $quantity,
                            includeTax: viewModel.state.includeTax,
                            taxRateText: $taxRateText,
                            focusedField: $focusedField,
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

                        if viewModel.state.items.isEmpty {
                            EmptyStateCard()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.state.items) { item in
                                    ItemRow(item: item, lineTotal: item.lineTotal)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                    viewModel.delete(item: item)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.state.items)
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
                    canClear: !viewModel.state.items.isEmpty,
                    onNewTrip: {
                        showClearConfirm = true
                    }
                )
            }
            .alert("Start a new trip?", isPresented: $showClearConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("New Trip", role: .destructive) {
                    triggerHaptics()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.clear()
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
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color.primary.opacity(0.04),
                Color.primary.opacity(0.01),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
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
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
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
        .shadow(color: Color.primary.opacity(0.08), radius: 18, x: 0, y: 8)
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

struct AddItemCard: View {
    @Binding var itemName: String
    @Binding var priceText: String
    @Binding var quantity: Int
    var includeTax: Bool
    @Binding var taxRateText: String
    var focusedField: FocusState<FocusedField?>.Binding
    var priceError: String?
    var addDisabled: Bool
    var onToggleTax: (Bool) -> Void
    var onTaxRateChanged: (Double) -> Void
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Item")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
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
                            TextField("0.0", text: $taxRateText)
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
        .shadow(color: Color.primary.opacity(0.06), radius: 14, x: 0, y: 6)
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

struct ItemRow: View {
    let item: CartItem
    let lineTotal: Double

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                Image(systemName: item.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
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

            Text(lineTotal.currencyString)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.primary.opacity(0.05), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName), \(item.quantity) at \(item.unitPrice.currencyString), total \(lineTotal.currencyString)")
    }
}

struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Your cart is empty")
                .font(.headline)
            Text("Add items to start tracking your trip.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.primary.opacity(0.05), radius: 12, x: 0, y: 6)
        .multilineTextAlignment(.center)
    }
}

struct BottomActionBar: View {
    let canClear: Bool
    let onNewTrip: () -> Void

    var body: some View {
        HStack {
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
