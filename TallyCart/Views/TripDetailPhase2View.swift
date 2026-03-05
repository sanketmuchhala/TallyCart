import SwiftUI

struct TripDetailPhase2View: View {
    @ObservedObject var viewModel: Phase2ViewModel
    let tripId: UUID

    @State private var selectedSection: TripDetailSection = .items
    @State private var newItemName: String = ""
    @State private var newItemQuantity: String = ""
    @State private var showCompleteSheet = false
    @State private var showEditItem: TripItemModel?
    @State private var selectedSuggestions: Set<UUID> = []

    var body: some View {
        Group {
            if let trip = trip {
                VStack(spacing: Tokens.Spacing.m) {
                    TripHeaderView(trip: trip, store: store)

                    Picker("Trip detail", selection: $selectedSection) {
                        Text("Items").tag(TripDetailSection.items)
                        Text("Suggestions").tag(TripDetailSection.suggestions)
                        Text("Summary").tag(TripDetailSection.summary)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Tokens.Spacing.l)

                    switch selectedSection {
                    case .items:
                        TripItemsView(
                            trip: trip,
                            items: items,
                            newItemName: $newItemName,
                            newItemQuantity: $newItemQuantity,
                            showEditItem: $showEditItem,
                            onAdd: { name, qty in
                                Task { await viewModel.addItem(to: trip, name: name, quantity: qty) }
                                newItemName = ""
                                newItemQuantity = ""
                            },
                            onToggle: { item in
                                Task { await viewModel.togglePurchased(item: item) }
                            },
                            onDelete: { item in
                                Task { await viewModel.deleteItem(item) }
                            },
                            onMove: { source, destination in
                                Task { await viewModel.reorderItems(tripId: trip.id, from: source, to: destination) }
                            }
                        )
                    case .suggestions:
                        TripSuggestionsView(
                            trip: trip,
                            outputs: viewModel.suggestionOutputs[trip.id],
                            selectedSuggestions: $selectedSuggestions,
                            onGenerate: { Task { await viewModel.generateSuggestions(for: trip) } },
                            onAddSelected: {
                                let selections = selectedSuggestionModels
                                Task { await viewModel.applySuggestions(trip: trip, selections: selections) }
                                selectedSuggestions.removeAll()
                            },
                            onAddNecessary: {
                                let necessary = viewModel.suggestionOutputs[trip.id]?.necessary ?? []
                                Task { await viewModel.applySuggestions(trip: trip, selections: necessary) }
                                selectedSuggestions.removeAll()
                            },
                            onDismiss: {
                                let selections = selectedSuggestionModels
                                Task { await viewModel.dismissSuggestions(trip: trip, selections: selections) }
                                selectedSuggestions.removeAll()
                            }
                        )
                    case .summary:
                        TripSummaryView(trip: trip, items: items)
                    }

                    TripActionBar(trip: trip, onStart: {
                        Task { await viewModel.startTrip(trip) }
                    }, onComplete: {
                        showCompleteSheet = true
                    })
                }
                .navigationTitle("Trip")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
                .task {
                    await viewModel.loadItems(for: trip.id)
                }
                .sheet(item: $showEditItem) { item in
                    EditTripItemView(item: item) { updated in
                        Task { await viewModel.updateItem(updated) }
                    }
                }
                .sheet(isPresented: $showCompleteSheet) {
                    CompleteTripSheet(trip: trip) { amount in
                        Task { await viewModel.completeTrip(trip, actualSpendCents: amount) }
                    }
                }
            } else {
                LoadingStateView(title: "Loading trip")
                    .padding(.horizontal, Tokens.Spacing.l)
            }
        }
    }

    private var trip: TripModel? {
        viewModel.trips.first { $0.id == tripId }
    }

    private var store: StoreModel? {
        guard let trip = trip, let storeId = trip.storeId else { return nil }
        return viewModel.stores.first { $0.id == storeId }
    }

    private var items: [TripItemModel] {
        viewModel.tripItems[tripId] ?? []
    }

    private var selectedSuggestionModels: [SuggestionItemModel] {
        guard let outputs = viewModel.suggestionOutputs[tripId] else { return [] }
        let all = outputs.necessary + outputs.premium
        return all.filter { selectedSuggestions.contains($0.id) }
    }
}

private enum TripDetailSection {
    case items
    case suggestions
    case summary
}

private struct TripHeaderView: View {
    let trip: TripModel
    let store: StoreModel?

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                Text(trip.title)
                    .font(.title2.weight(.semibold))
                Text(store?.name ?? "Store")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Label(trip.tripDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TripLifecyclePill(status: trip.status)
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.l)
    }
}

private struct TripItemsView: View {
    let trip: TripModel
    let items: [TripItemModel]
    @Binding var newItemName: String
    @Binding var newItemQuantity: String
    @Binding var showEditItem: TripItemModel?
    let onAdd: (String, String?) -> Void
    let onToggle: (TripItemModel) -> Void
    let onDelete: (TripItemModel) -> Void
    let onMove: (IndexSet, Int) -> Void

    var body: some View {
        VStack(spacing: Tokens.Spacing.m) {
            CardContainer {
                VStack(spacing: Tokens.Spacing.s) {
                    TextField("Add item", text: $newItemName)
                        .textInputAutocapitalization(.words)
                    TextField("Quantity (optional)", text: $newItemQuantity)
                        .textInputAutocapitalization(.never)
                    PrimaryButton("Add Item", systemImage: "plus") {
                        onAdd(newItemName, newItemQuantity)
                    }
                    .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, Tokens.Spacing.l)

            List {
                ForEach(items) { item in
                    Button {
                        showEditItem = item
                    } label: {
                        HStack(spacing: Tokens.Spacing.m) {
                            Button {
                                onToggle(item)
                            } label: {
                                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(item.isPurchased ? Color.accentColor : .secondary)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.body)
                                    .strikethrough(item.isPurchased, color: .secondary)
                                if let quantity = item.quantity, !quantity.isEmpty {
                                    Text(quantity)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, Tokens.Spacing.s)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            onDelete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .standardListRowStyle()
                }
                .onMove(perform: onMove)
            }
            .listStyle(.plain)
        }
    }
}

private struct TripSuggestionsView: View {
    let trip: TripModel
    let outputs: SuggestionOutputs?
    @Binding var selectedSuggestions: Set<UUID>
    let onGenerate: () -> Void
    let onAddSelected: () -> Void
    let onAddNecessary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Spacing.m) {
            CardContainer {
                VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                    Text("Smart Suggestions")
                        .font(.headline)
                    Text("Generate suggestions based on recent trips and your staples.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PrimaryButton("Generate Suggestions", systemImage: "sparkles") {
                        onGenerate()
                    }
                }
            }
            .padding(.horizontal, Tokens.Spacing.l)

            if let outputs {
                List {
                    if !outputs.necessary.isEmpty {
                        Section("Necessary") {
                            ForEach(outputs.necessary) { item in
                                SuggestionRow(item: item, selected: selectedSuggestions.contains(item.id)) {
                                    toggleSelection(item)
                                }
                                .standardListRowStyle()
                            }
                        }
                    }

                    if !outputs.premium.isEmpty {
                        Section("Premium") {
                            ForEach(outputs.premium) { item in
                                SuggestionRow(item: item, selected: selectedSuggestions.contains(item.id)) {
                                    toggleSelection(item)
                                }
                                .standardListRowStyle()
                            }
                        }
                    }
                }
                .listStyle(.plain)

                VStack(spacing: Tokens.Spacing.s) {
                    PrimaryButton("Add Selected") { onAddSelected() }
                        .disabled(selectedSuggestions.isEmpty)
                    SecondaryButton("Add All Necessary") { onAddNecessary() }
                    SecondaryButton("Dismiss Selected") { onDismiss() }
                        .disabled(selectedSuggestions.isEmpty)
                }
                .padding(.horizontal, Tokens.Spacing.l)
            } else {
                EmptyStateView(
                    systemImage: "sparkles",
                    title: "No suggestions yet",
                    subtitle: "Generate a suggestion run to see items here."
                )
                .padding(.horizontal, Tokens.Spacing.l)
            }
        }
    }

    private func toggleSelection(_ item: SuggestionItemModel) {
        if selectedSuggestions.contains(item.id) {
            selectedSuggestions.remove(item.id)
        } else {
            selectedSuggestions.insert(item.id)
        }
    }
}

private struct SuggestionRow: View {
    let item: SuggestionItemModel
    let selected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Tokens.Spacing.m) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                    Text(item.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(item.bucket == .necessary ? "Necessary" : "Premium")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Tokens.Spacing.s)
        }
        .buttonStyle(.plain)
    }
}

private struct TripSummaryView: View {
    let trip: TripModel
    let items: [TripItemModel]

    var body: some View {
        VStack(spacing: Tokens.Spacing.m) {
            CardContainer {
                VStack(spacing: Tokens.Spacing.s) {
                    MetricRow(label: "Items", value: "\(items.count)")
                    MetricRow(label: "Status", value: trip.status.displayName)
                    MetricRow(label: "Budget", value: formattedCurrency(trip.plannedBudgetCents))
                    MetricRow(label: "Actual Spend", value: formattedCurrency(trip.actualSpendCents))
                }
            }
            .padding(.horizontal, Tokens.Spacing.l)
        }
    }

    private func formattedCurrency(_ cents: Int?) -> String {
        guard let cents else { return "-" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "$0.00"
    }
}

private struct TripActionBar: View {
    let trip: TripModel
    let onStart: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Spacing.s) {
            if trip.status == .planned {
                PrimaryButton("Start Trip") { onStart() }
            }
            if trip.status == .active {
                PrimaryButton("Complete Trip") { onComplete() }
            }
        }
        .padding(.horizontal, Tokens.Spacing.l)
    }
}

private struct EditTripItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var quantity: String
    let item: TripItemModel
    let onSave: (TripItemModel) -> Void

    init(item: TripItemModel, onSave: @escaping (TripItemModel) -> Void) {
        self.item = item
        self.onSave = onSave
        _name = State(initialValue: item.name)
        _quantity = State(initialValue: item.quantity ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item name", text: $name)
                TextField("Quantity", text: $quantity)
            }
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = item
                        updated.name = name
                        updated.quantity = quantity.isEmpty ? nil : quantity
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct CompleteTripSheet: View {
    @Environment(\.dismiss) private var dismiss
    let trip: TripModel
    let onComplete: (Int?) -> Void
    @State private var spendText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Actual spend", text: $spendText)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Complete Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let cents = Int((Double(spendText) ?? 0) * 100)
                        onComplete(spendText.isEmpty ? nil : cents)
                        dismiss()
                    }
                }
            }
        }
    }
}
