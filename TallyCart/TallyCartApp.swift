import SwiftUI

@main
struct TallyCartApp: App {
    @StateObject private var appViewModel = AppViewModel()
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
