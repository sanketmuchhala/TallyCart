import AuthenticationServices
import Foundation
import Combine
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isOfflineMode: Bool = false

    let configurationError: SupabaseConfigError?

    private let authService: AuthService?

    init() {
        let provider = SupabaseClientProvider.shared
        configurationError = provider.configurationError
        if let client = provider.client {
            authService = AuthService(client: client)
        } else {
            authService = nil
        }
        Task { await loadSession() }
    }

    var isAuthenticated: Bool {
        session != nil
    }

    var userEmail: String? {
        session?.user.email
    }

    var displayName: String {
        if let name = metadataString(for: "full_name") ?? metadataString(for: "name") {
            return name
        }
        return "Profile"
    }

    var avatarURL: URL? {
        if let value = metadataString(for: "avatar_url") ?? metadataString(for: "picture"),
           let url = URL(string: value) {
            return url
        }
        return nil
    }

    var userId: UUID? {
        session?.user.id
    }

    var supabaseClient: SupabaseClient? {
        authService?.client
    }

    func loadSession() async {
        guard let authService else { return }
        session = await authService.restoreSession()
    }

    func signInWithGoogle(presentationAnchor: ASPresentationAnchor) async {
        guard let authService else { return }
        isLoading = true
        errorMessage = nil
        print("[Auth] Sign-in button tapped")
        do {
            let session = try await authService.signInWithGoogle(presentationAnchor: presentationAnchor)
            print("[Auth] Sign-in completed for user \(session.user.id)")
            self.session = session
        } catch {
            print("[Auth] Sign-in failed: \(error.localizedDescription)")
            errorMessage = "Sign in failed. Please try again."
        }
        isLoading = false
    }

    func cancelSignIn() {
        authService?.cancelSignIn()
        isLoading = false
    }

    func handleOpenURL(_ url: URL) {
        guard let authService else { return }
        Task {
            do {
                let session = try await authService.handleRedirectURL(url)
                await MainActor.run {
                    self.session = session
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not complete sign in."
                }
            }
        }
    }

    func signOut() async {
        guard let authService else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signOut()
            session = nil
        } catch {
            errorMessage = "Sign out failed."
        }
        isLoading = false
    }

    func enableOfflineMode() {
        isOfflineMode = true
    }

    private func metadataString(for key: String) -> String? {
        guard let metadata = session?.user.userMetadata else { return nil }
        guard let value = metadata[key] else { return nil }
        let raw = String(describing: value)
        if raw.hasPrefix("string(\"") && raw.hasSuffix("\")") {
            return raw
                .replacingOccurrences(of: "string(\"", with: "")
                .replacingOccurrences(of: "\")", with: "")
        }
        return raw
    }
}
