import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var authViewModel: AuthViewModel
    var body: some View {
        VStack(spacing: Tokens.Spacing.m) {
            if viewModel.isLoading {
                LoadingStateView(title: "Loading trips")
            } else if viewModel.state.trips.isEmpty {
                EmptyStateView(
                    systemImage: "clock",
                    title: "No trips yet",
                    subtitle: "Finished trips will appear here."
                )
            } else {
                historyList
            }
        }
    }

    private var historyList: some View {
        List {
            ForEach(viewModel.tripsGroupedByMonth(), id: \.month) { group in
                Section {
                    ForEach(group.trips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip, viewModel: viewModel)
                        } label: {
                            TripRow(trip: trip)
                        }
                        .standardListRowStyle()
                    }
                } header: {
                    Text(group.month.formatted(.dateTime.year().month()))
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: Tokens.Spacing.m) {
            Circle()
                .fill(StorePalette.color(for: trip.storeColorKeySnapshot).opacity(0.2))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                HStack(spacing: Tokens.Spacing.s) {
                    Text(trip.storeNameSnapshot)
                        .font(.subheadline.weight(.semibold))
                    if trip.status != .finished {
                        StatusPill(status: trip.status)
                    }
                }
                Text(trip.finishedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Tokens.ColorToken.secondaryLabel)
            }
            Spacer()
            Text(trip.total.currencyString)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, Tokens.Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(trip.storeNameSnapshot), \(trip.total.currencyString)"))
    }
}
