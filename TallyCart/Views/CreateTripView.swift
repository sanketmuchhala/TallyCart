import SwiftUI

struct CreateTripView: View {
    @ObservedObject var viewModel: Phase2ViewModel
    @Binding var isPresented: Bool

    @State private var tripDate: Date = Date()
    @State private var selectedStoreId: UUID?
    @State private var budgetText: String = ""
    @State private var titleText: String = ""
    @State private var copyLastTrip: Bool = false
    @State private var includeStaples: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Tokens.Spacing.l) {
                CardContainer {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.m) {
                        Text("Trip details")
                            .font(.headline)

                        DatePicker("Date", selection: $tripDate, displayedComponents: .date)

                        Picker("Store", selection: Binding(get: {
                            selectedStoreId ?? viewModel.defaultStore()?.id
                        }, set: { newValue in
                            selectedStoreId = newValue
                        })) {
                            Text("No store").tag(UUID?.none)
                            if viewModel.stores.isEmpty {
                                Text("No stores yet").tag(UUID?.none)
                            } else {
                                ForEach(viewModel.stores) { store in
                                    Text(store.name).tag(UUID?.some(store.id))
                                }
                            }
                        }

                        TextField("Title (optional)", text: $titleText)
                            .textInputAutocapitalization(.words)

                        TextField("Planned budget", text: $budgetText)
                            .keyboardType(.decimalPad)
                            .overlay(alignment: .leading) {
                                Text("$")
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                            }
                            .padding(.leading, 12)

                        Toggle("Copy last trip items", isOn: $copyLastTrip)
                        Toggle("Include staples", isOn: $includeStaples)
                    }
                }

                Spacer()
            }
            .padding(Tokens.Spacing.l)
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createTrip() }
                    }
                                    }
            }
        }
        .onAppear {
            selectedStoreId = viewModel.defaultStore()?.id
        }
    }

    private func createTrip() async {
        let budgetCents = Int((Double(budgetText) ?? 0) * 100)
        let finalBudget: Int? = budgetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : budgetCents
        if let trip = await viewModel.createTrip(
            date: tripDate,
            storeId: selectedStoreId,
            budgetCents: finalBudget,
            title: titleText
        ) {
            if copyLastTrip {
                if let lastTrip = viewModel.trips.first(where: { $0.status == .done }) {
                    await viewModel.loadItems(for: lastTrip.id)
                    let names = (viewModel.tripItems[lastTrip.id] ?? []).map { $0.name }
                    await viewModel.addItems(to: trip, names: names, source: .repeat)
                }
            }
            if includeStaples {
                let staples = viewModel.preferences?.staplesItems ?? []
                await viewModel.addItems(to: trip, names: staples, source: .template)
            }
        }
        isPresented = false
    }
}
