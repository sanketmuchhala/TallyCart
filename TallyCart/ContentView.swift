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
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .scaleEffect(animate ? 1.0 : 0.9)
                    .opacity(animate ? 1.0 : 0.6)
                Text("TallyCart")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

