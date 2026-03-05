import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: Phase2ViewModel
    @State private var showPreferences = false

    var body: some View {
        NavigationStack {
            AppHeaderContainer {
                HeaderRow(title: "Dashboard") {
                    Button {
                        showPreferences = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Settings")
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

                if viewModel.isLoading {
                    LoadingStateView(title: "Loading dashboard")
                        .padding(.horizontal, Tokens.Spacing.l)
                } else if viewModel.trips.isEmpty {
                    EmptyStateView(
                        systemImage: "chart.bar.xaxis",
                        title: "No data yet",
                        subtitle: "Create a trip to start tracking."
                    )
                    .padding(.horizontal, Tokens.Spacing.l)
                } else {
                    VStack(spacing: Tokens.Spacing.m) {
                        CardContainer {
                            VStack(spacing: Tokens.Spacing.s) {
                                MetricRow(label: "This month", value: formattedCurrency(monthSpend))
                                MetricRow(label: "Budget remaining", value: formattedCurrency(remainingBudget))
                                MetricRow(label: "Trips", value: "\(monthTrips.count)")
                            }
                        }

                        CardContainer {
                            VStack(alignment: .leading, spacing: Tokens.Spacing.s) {
                                Text("Top items")
                                    .font(.headline)
                                ForEach(topItems, id: \.name) { item in
                                    MetricRow(label: item.name, value: "\(item.count)")
                                }
                                if topItems.isEmpty {
                                    Text("Add items to see trends.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Tokens.Spacing.l)
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadInitialData()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showPreferences) {
                PreferencesView(viewModel: viewModel)
            }
        }
    }

    private var monthTrips: [TripModel] {
        let now = Date()
        return viewModel.trips.filter { trip in
            guard let completed = trip.completedAt else { return false }
            return Calendar.current.isDate(completed, equalTo: now, toGranularity: .month)
        }
    }

    private var monthSpend: Int {
        monthTrips.reduce(0) { $0 + ( $1.actualSpendCents ?? 0 ) }
    }

    private var remainingBudget: Int {
        guard let budget = viewModel.preferences?.monthlyBudgetCents else { return 0 }
        return max(budget - monthSpend, 0)
    }

    private var topItems: [(name: String, count: Int)] {
        let allItems = viewModel.tripItems.values.flatMap { $0 }
        var counts: [String: Int] = [:]
        for item in allItems {
            counts[item.name, default: 0] += 1
        }
        return counts
            .map { (name: $0.key, count: $0.value) }
            .sorted(by: { $0.count > $1.count })
            .prefix(5)
            .map { $0 }
    }

    private func formattedCurrency(_ cents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "$0.00"
    }
}