import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            DashboardRootView(viewModel: viewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                }

            TripsRootView(viewModel: viewModel, authViewModel: authViewModel)
                .tabItem {
                    Label("Trips", systemImage: "clock")
                }

            ListsPlaceholderView()
                .tabItem {
                    Label("Lists", systemImage: "checklist")
                }

            StoresPlaceholderView()
                .tabItem {
                    Label("Stores", systemImage: "building.2")
                }
        }
    }
}

#Preview {
    ContentView(viewModel: AppViewModel(), authViewModel: AuthViewModel())
}

private struct TripsRootView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedMode: TripsMode = .current

    var body: some View {
        VStack(spacing: Tokens.Spacing.m) {
            Picker("Trips", selection: $selectedMode) {
                Text("Current").tag(TripsMode.current)
                Text("History").tag(TripsMode.history)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Tokens.Spacing.l)
            .padding(.top, Tokens.Spacing.s)

            if selectedMode == .current {
                CartView(viewModel: viewModel, authViewModel: authViewModel)
            } else {
                HistoryView(viewModel: viewModel, authViewModel: authViewModel)
            }
        }
    }
}

private enum TripsMode {
    case current
    case history
}

private struct DashboardRootView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            if viewModel.state.trips.isEmpty {
                EmptyStateView(
                    systemImage: "chart.bar.xaxis",
                    title: "Dashboard",
                    subtitle: "Monthly insights will appear here."
                )
                .padding(Tokens.Spacing.l)
            } else {
                InsightsView(viewModel: viewModel)
            }
        }
    }
}

private struct ListsPlaceholderView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "checklist",
            title: "Lists",
            subtitle: "Store lists will appear here."
        )
        .padding(Tokens.Spacing.l)
    }
}

private struct StoresPlaceholderView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "building.2",
            title: "Stores",
            subtitle: "Store summaries will appear here."
        )
        .padding(Tokens.Spacing.l)
    }
}

