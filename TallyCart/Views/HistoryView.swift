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
                            TripDetailView(trip: trip, viewModel: viewModel)
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

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(StorePalette.color(for: trip.storeColorKeySnapshot).opacity(0.2))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(trip.storeNameSnapshot)
                        .font(.subheadline.weight(.semibold))
                    if trip.status != .finished {
                        StatusPill(status: trip.status)
                    }
                }
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

private struct StatusPill: View {
    let status: TripStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundStyle(.secondary)
    }
}
