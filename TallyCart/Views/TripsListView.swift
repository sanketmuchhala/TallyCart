import SwiftUI

struct TripsListView: View {
    @ObservedObject var viewModel: Phase2ViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showCreateTrip = false

    var body: some View {
        NavigationStack {
            AppHeaderContainer {
                HeaderRow(title: "Trips") {
                    AccountMenuButton(viewModel: authViewModel)
                        .alignmentGuide(.firstTextBaseline) { dimensions in
                            dimensions[.bottom]
                        }
                }

                if !viewModel.trips.isEmpty {
                    PrimaryButton("New Trip", systemImage: "plus") {
                        showCreateTrip = true
                    }
                    .padding(.horizontal, Tokens.Spacing.l)
                }

                if let error = viewModel.errorMessage {
                    CardContainer {
                        HStack {
                            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                                Text("Could not sync")
                                    .font(.headline)
                                Text("Pull to retry.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Retry") {
                                Task { await viewModel.refresh() }
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal, Tokens.Spacing.l)
                }

                Group {
                    if viewModel.isLoading {
                        LoadingStateView(title: "Loading trips")
                            .padding(.horizontal, Tokens.Spacing.l)
                    } else if viewModel.trips.isEmpty {
                        EmptyStateView(
                            systemImage: "cart",
                            title: "No trips yet",
                            subtitle: "Create a trip to start planning your list.",
                            primaryActionTitle: "Create Trip",
                            primaryAction: { showCreateTrip = true }
                        )
                        .padding(.horizontal, Tokens.Spacing.l)
                    } else {
                        List {
                            if !plannedTrips.isEmpty {
                                Section("Upcoming") {
                                    ForEach(plannedTrips) { trip in
                                        NavigationLink {
                                            TripDetailPhase2View(viewModel: viewModel, tripId: trip.id)
                                        } label: {
                                            TripRowView(
                                                trip: trip,
                                                store: store(for: trip),
                                                itemCount: viewModel.tripItems[trip.id]?.count ?? 0
                                            )
                                        }
                                        .standardListRowStyle()
                                    }
                                }
                            }

                            if !doneTrips.isEmpty {
                                Section("Completed") {
                                    ForEach(doneTrips) { trip in
                                        NavigationLink {
                                            TripDetailPhase2View(viewModel: viewModel, tripId: trip.id)
                                        } label: {
                                            TripRowView(
                                                trip: trip,
                                                store: store(for: trip),
                                                itemCount: viewModel.tripItems[trip.id]?.count ?? 0
                                            )
                                        }
                                        .standardListRowStyle()
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreateTrip) {
                CreateTripView(viewModel: viewModel, isPresented: $showCreateTrip)
            }
            .task {
                await viewModel.loadInitialData()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    private var plannedTrips: [TripModel] {
        viewModel.trips.filter { $0.status != .done }
    }

    private var doneTrips: [TripModel] {
        viewModel.trips.filter { $0.status == .done }
    }

    private func store(for trip: TripModel) -> StoreModel? {
        guard let storeId = trip.storeId else { return nil }
        return viewModel.stores.first { $0.id == storeId }
    }
}

private struct TripRowView: View {
    let trip: TripModel
    let store: StoreModel?
    let itemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.title)
                        .font(.headline)
                    Text(store?.name ?? "Store")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TripLifecyclePill(status: trip.status)
            }

            HStack {
                Label(trip.tripDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(itemCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let budget = trip.plannedBudgetCents {
                    Text("Budget \(budget.asCurrency)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, Tokens.Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.title), \(store?.name ?? "store"), \(trip.status.displayName), \(itemCount) items")
    }
}

private extension Int {
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: Double(self) / 100.0)) ?? "$0.00"
    }
}
