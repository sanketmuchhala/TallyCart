import SwiftUI

struct AuthGateView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @State private var didSync = false
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else if let error = authViewModel.configurationError {
                ConfigErrorView(error: error)
            } else if authViewModel.isAuthenticated || authViewModel.isOfflineMode {
                ContentView(viewModel: appViewModel, authViewModel: authViewModel)
                    .task {
                        await syncIfNeeded()
                    }
            } else {
                SignInView(viewModel: authViewModel)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            showSplash = false
        }
        .onOpenURL { url in
            authViewModel.handleOpenURL(url)
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                didSync = false
                appViewModel.clearSupabase()
            }
        }
    }

    private func syncIfNeeded() async {
        guard !didSync,
              authViewModel.isAuthenticated,
              let client = authViewModel.supabaseClient,
              let userId = authViewModel.userId else { return }
        didSync = true
        appViewModel.configureSupabase(client: client, userId: userId)
        await appViewModel.syncFromSupabase()
    }
}

private struct ConfigErrorView: View {
    let error: SupabaseConfigError

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Supabase not configured")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("BrandBackground"))
    }
}
