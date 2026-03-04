import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab: HistoryTab = .history

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("History", selection: $selectedTab) {
                    Text("History").tag(HistoryTab.history)
                    Text("Insights").tag(HistoryTab.insights)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if selectedTab == .history {
                    historyList
                } else {
                    InsightsView(viewModel: viewModel)
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AccountMenu(viewModel: authViewModel)
                }
            }
        }
    }

    private var historyList: some View {
        List {
            ForEach(viewModel.tripsGroupedByMonth(), id: \.month) { group in
                Section {
                    ForEach(group.trips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip)
                        } label: {
                            TripRow(trip: trip)
                        }
                    }
                } header: {
                    Text(group.month.formatted(.dateTime.year().month()))
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private enum HistoryTab {
    case history
    case insights
}

private struct AccountMenu: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        Menu {
            if let email = viewModel.userEmail {
                Text(email)
            }
            Button(role: .destructive) {
                Task { await viewModel.signOut() }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "person.crop.circle")
        }
    }
}

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(StorePalette.color(for: trip.storeColorKeySnapshot).opacity(0.2))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.storeNameSnapshot)
                    .font(.subheadline.weight(.semibold))
                Text(trip.finishedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(trip.total.currencyString)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 6)
    }
}
