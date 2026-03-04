import SwiftUI
import UIKit

struct CartView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var authViewModel: AuthViewModel

    @State private var itemName: String = ""
    @State private var priceText: String = ""
    @State private var quantity: Int = 1
    @State private var taxRateText: String = "5.3"
    @State private var showAddStore = false
    @State private var showClearConfirm = false
    @State private var showAddPlannedItem = false

    @FocusState private var focusedField: FocusedField?

    enum FocusedField {
        case name
        case price
        case taxRate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HeaderCard(
                        subtotal: viewModel.subtotal,
                        taxAmount: viewModel.taxAmount,
                        total: viewModel.total,
                        includeTax: viewModel.state.currentCart.includeTax
                    )

                    StorePickerView(
                        stores: viewModel.state.stores,
                        selectedStoreId: viewModel.state.selectedStoreId,
                        onSelect: { id in
                            viewModel.selectStore(id)
                        },
                        onAdd: { showAddStore = true }
                    )

                    PlannedListCard(
                        store: viewModel.selectedStore,
                        onAdd: { showAddPlannedItem = true },
                        onMoveToCart: { planned in
                            applyPlannedItem(planned)
                        },
                        onDelete: { id in
                            guard let storeId = viewModel.selectedStore?.id else { return }
                            viewModel.deletePlannedItem(storeId: storeId, itemId: id)
                        }
                    )

                    AddItemCard(
                        itemName: $itemName,
                        priceText: $priceText,
                        quantity: $quantity,
                        includeTax: viewModel.state.currentCart.includeTax,
                        taxRateText: $taxRateText,
                        focusedField: $focusedField,
                        priceError: priceError,
                        addDisabled: !canAdd,
                        onToggleTax: { include in
                            viewModel.updateIncludeTax(include)
                        },
                        onTaxRateChanged: { newValue in
                            viewModel.updateTaxRate(newValue)
                        },
                        onAdd: addItem
                    )

                    ItemList(items: viewModel.state.currentCart.items, onDelete: viewModel.deleteItem, onQuantityChange: viewModel.updateQuantity)

                    HStack(spacing: 12) {
                        Button("New Trip") {
                            triggerHaptics()
                            showClearConfirm = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.state.currentCart.items.isEmpty)

                        Button("Finish Trip") {
                            triggerHaptics()
                            viewModel.finishTrip()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.state.currentCart.items.isEmpty || viewModel.selectedStore == nil)
                    }
                }
                .padding(16)
            }
            .navigationTitle("TallyCart")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    AccountMenu(viewModel: authViewModel)
                }
            }
            .sheet(isPresented: $showAddStore) {
                AddStoreView { name, colorKey in
                    viewModel.addStore(name: name, colorKey: colorKey)
                }
            }
            .sheet(isPresented: $showAddPlannedItem) {
                AddPlannedItemView { name, quantity in
                    guard let storeId = viewModel.selectedStore?.id else { return }
                    viewModel.addPlannedItem(storeId: storeId, name: name, quantity: quantity)
                }
            }
            .alert("Start a new trip?", isPresented: $showClearConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    viewModel.clearCart(keepTaxSettings: true)
                    resetInputs()
                }
            } message: {
                Text("This will clear all items in your cart.")
            }
            .onAppear {
                taxRateText = viewModel.state.currentCart.taxRate.percentString
            }
            .onChange(of: viewModel.state.currentCart.taxRate) { _, newValue in
                let formatted = newValue.percentString
                if formatted != taxRateText {
                    taxRateText = formatted
                }
            }
        }
    }

    private var canAdd: Bool {
        if priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return priceValue != nil
    }

    private var priceError: String? {
        if priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        return priceValue == nil ? "Enter a valid price." : nil
    }

    private var priceValue: Double? {
        parseDecimal(priceText)
    }

    private func addItem() {
        guard let price = priceValue else { return }
        triggerHaptics()
        viewModel.addItem(name: itemName, price: price, quantity: quantity)
        resetInputs()
    }

    private func resetInputs() {
        itemName = ""
        priceText = ""
        quantity = 1
        focusedField = nil
    }

    private func applyPlannedItem(_ planned: PlannedItem) {
        itemName = planned.displayName
        quantity = planned.quantity
        focusedField = .price
        if let storeId = viewModel.selectedStore?.id {
            _ = viewModel.movePlannedItemToCart(storeId: storeId, itemId: planned.id)
        }
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

    private func triggerHaptics() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

private struct HeaderCard: View {
    let subtotal: Double
    let taxAmount: Double
    let total: Double
    let includeTax: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(total.currencyString)
                .font(.system(size: 36, weight: .bold, design: .rounded))
            HStack(spacing: 8) {
                InfoChip(title: "Subtotal", value: subtotal.currencyString, systemImage: "tag")
                if includeTax {
                    InfoChip(title: "Tax", value: taxAmount.currencyString, systemImage: "percent")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

private struct InfoChip: View {
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
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.regularMaterial, in: Capsule())
    }
}

private struct SyncStatusView: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AccountMenu: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        Menu {
            Text(viewModel.displayName)
                .font(.headline)
            Button("Profile") {}
            Button(role: .destructive) {
                Task { await viewModel.signOut() }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            ProfileImageView(url: viewModel.avatarURL)
        }
    }
}

private struct ProfileImageView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.crop.circle.fill")
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }
}

private struct AddItemCard: View {
    @Binding var itemName: String
    @Binding var priceText: String
    @Binding var quantity: Int
    var includeTax: Bool
    @Binding var taxRateText: String
    var focusedField: FocusState<CartView.FocusedField?>.Binding
    var priceError: String?
    var addDisabled: Bool
    var onToggleTax: (Bool) -> Void
    var onTaxRateChanged: (Double) -> Void
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Item name (optional)", text: $itemName)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .focused(focusedField, equals: .name)
                .onSubmit { focusedField.wrappedValue = .price }

            HStack(spacing: 8) {
                Text("$")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $priceText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused(focusedField, equals: .price)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let priceError {
                Text(priceError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Stepper(value: $quantity, in: 1...99) {
                    Text("Quantity")
                }
                Spacer()
                Text("x \(quantity)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: Binding(get: { includeTax }, set: onToggleTax)) {
                Text("Include tax")
            }

            if includeTax {
                HStack {
                    Text("Tax rate")
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
            }

            Button(action: onAdd) {
                Label("Add Item", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(addDisabled)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
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

private struct ItemList: View {
    let items: [CartItem]
    let onDelete: (CartItem) -> Void
    let onQuantityChange: (UUID, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.headline)
            if items.isEmpty {
                EmptyStateCard()
            } else {
                ForEach(items) { item in
                    ItemRow(item: item, onDelete: onDelete, onQuantityChange: onQuantityChange)
                }
            }
        }
    }
}

private struct PlannedListCard: View {
    let store: StoreLocation?
    let onAdd: () -> Void
    let onMoveToCart: (PlannedItem) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Planned List")
                    .font(.headline)
                Spacer()
                Button("Add") {
                    onAdd()
                }
                .buttonStyle(.bordered)
                .disabled(store == nil)
            }

            if let store {
                if store.plannedItems.isEmpty {
                    Text("Add items you plan to buy before you get to the store.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.plannedItems) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text("Qty \(item.quantity)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Add price") {
                                onMoveToCart(item)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .swipeActions {
                            Button(role: .destructive) {
                                onDelete(item.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } else {
                Text("Select a store to manage your planned list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

private struct AddPlannedItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var quantity: Int = 1

    let onSave: (String, Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Milk", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Quantity") {
                    Stepper(value: $quantity, in: 1...99) {
                        Text("Qty \(quantity)")
                    }
                }
            }
            .navigationTitle("Add to List")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, quantity)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ItemRow: View {
    let item: CartItem
    let onDelete: (CartItem) -> Void
    let onQuantityChange: (UUID, Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(StorePalette.color(for: "blue").opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: item.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                Text("\(item.quantity) x \(item.unitPrice.currencyString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(item.lineTotal.currencyString)
                    .font(.subheadline.weight(.semibold))
                Stepper("", value: Binding(get: { item.quantity }, set: { onQuantityChange(item.id, $0) }), in: 1...99)
                    .labelsHidden()
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .swipeActions {
            Button(role: .destructive) {
                onDelete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "cart")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No items yet")
                .font(.subheadline.weight(.semibold))
            Text("Add an item to begin your trip.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
