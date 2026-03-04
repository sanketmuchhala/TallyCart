import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var authViewModel: AuthViewModel
    var body: some View {
        NavigationStack {
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
            .navigationTitle("Trips")
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
        .accessibilityLabel(Text("Account"))
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
        .accessibilityHidden(true)
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
