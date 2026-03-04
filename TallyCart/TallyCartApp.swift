import SwiftUI

@main
struct TallyCartApp: App {
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            AuthGateView(appViewModel: appViewModel, authViewModel: authViewModel)
        }
    }
}
