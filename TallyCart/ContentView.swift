import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: Phase2ViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab: RootTab = .trips

    var body: some View {
        TabView(selection: $selectedTab) {
            TripsListView(viewModel: viewModel, authViewModel: authViewModel)
                .tabItem {
                    Label("Trips", systemImage: "clock")
                }
                .tag(RootTab.trips)

            DashboardView(viewModel: viewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                }
                .tag(RootTab.dashboard)

            StaplesView(viewModel: viewModel)
                .tabItem {
                    Label("Lists", systemImage: "checklist")
                }
                .tag(RootTab.lists)

            StoresListView(viewModel: viewModel)
                .tabItem {
                    Label("Stores", systemImage: "building.2")
                }
                .tag(RootTab.stores)
        }
    }
}

#Preview {
    ContentView(viewModel: Phase2ViewModel(), authViewModel: AuthViewModel())
}

private enum RootTab: Hashable {
    case trips
    case dashboard
    case lists
    case stores
}

