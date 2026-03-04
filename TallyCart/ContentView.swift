import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab: RootTab = .trips

    var body: some View {
        TabView(selection: $selectedTab) {
            TripsRootView(viewModel: viewModel, authViewModel: authViewModel)
                .tabItem {
                    Label("Trips", systemImage: "clock")
                }
                .tag(RootTab.trips)

            DashboardRootView(viewModel: viewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                }
                .tag(RootTab.dashboard)

            ListsPlaceholderView()
                .tabItem {
                    Label("Lists", systemImage: "checklist")
                }
                .tag(RootTab.lists)

            StoresPlaceholderView()
                .tabItem {
                    Label("Stores", systemImage: "building.2")
                }
                .tag(RootTab.stores)
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
        NavigationStack {
            VStack(spacing: Tokens.Spacing.m) {
                HeaderRow(title: "Trips") {
                    AccountMenuButton(viewModel: authViewModel)
                        .alignmentGuide(.firstTextBaseline) { dimensions in
                            dimensions[.bottom]
                        }
                }

                Picker("Trips", selection: $selectedMode) {
                    Text("Current").tag(TripsMode.current)
                    Text("History").tag(TripsMode.history)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Tokens.Spacing.l)

                if selectedMode == .current {
                    CartView(viewModel: viewModel, authViewModel: authViewModel)
                } else {
                    HistoryView(viewModel: viewModel, authViewModel: authViewModel)
                }
            }
        }
    }
}

private enum TripsMode {
    case current
    case history
}

private enum RootTab: Hashable {
    case trips
    case dashboard
    case lists
    case stores
}

private struct DashboardRootView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            AppHeaderContainer {
                HeaderRow(title: "Dashboard") {
                    EmptyView()
                }

                Group {
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
    }
}

private struct ListsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            AppHeaderContainer {
                HeaderRow(title: "Lists") {
                    EmptyView()
                }

                EmptyStateView(
                    systemImage: "checklist",
                    title: "Lists",
                    subtitle: "Store lists will appear here."
                )
                .padding(Tokens.Spacing.l)
            }
        }
    }
}

private struct StoresPlaceholderView: View {
    var body: some View {
        NavigationStack {
            AppHeaderContainer {
                HeaderRow(title: "Stores") {
                    EmptyView()
                }

                EmptyStateView(
                    systemImage: "building.2",
                    title: "Stores",
                    subtitle: "Store summaries will appear here."
                )
                .padding(Tokens.Spacing.l)
            }
        }
    }
}

