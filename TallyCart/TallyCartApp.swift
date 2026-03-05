import SwiftUI

@main
struct TallyCartApp: App {
    @StateObject private var appViewModel = Phase2ViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            AuthGateView(appViewModel: appViewModel, authViewModel: authViewModel)
                .onAppear {
                    locationManager.requestAuthorizationIfNeeded()
                }
        }
    }
}
