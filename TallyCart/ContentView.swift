import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                SplashView()
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
// Match the static launch screen and provide a smooth handoff with a subtle animation.
private struct SplashView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Color("BrandBackground").ignoresSafeArea()
            VStack(spacing: 16) {
                Image("LogoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .scaleEffect(animate ? 1.0 : 0.92)
                    .opacity(animate ? 1.0 : 0.7)
                Text("TallyCart")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color("BrandForeground"))
                ProgressView()
                    .tint(Color("BrandAccent"))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

