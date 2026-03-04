import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                LaunchLoadingView()
            } else {
                TabView {
                    CartView(viewModel: viewModel)
                        .tabItem {
                            Label("Cart", systemImage: "cart")
                        }

                    HistoryView(viewModel: viewModel)
                        .tabItem {
                            Label("History", systemImage: "clock")
                        }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
private struct LaunchLoadingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
                Text("TallyCart")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                ProgressView()
                    .tint(.white)
            }
        }
    }
}

