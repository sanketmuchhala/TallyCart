import AuthenticationServices
import Foundation
import Supabase

final class AuthService: NSObject {
    let client: SupabaseClient

    private var authSession: ASWebAuthenticationSession?
    private weak var presentationAnchor: ASPresentationAnchor?

    init(client: SupabaseClient) {
        self.client = client
    }

    func restoreSession() async -> Session? {
        try? await client.auth.session
    }

    func signInWithGoogle(presentationAnchor: ASPresentationAnchor) async throws -> Session {
        self.presentationAnchor = presentationAnchor
        let redirectURL = URL(string: "\(SupabaseClientProvider.callbackScheme)://login-callback")!
        let url = try client.auth.getOAuthSignInURL(provider: .google, redirectTo: redirectURL)
        let startTime = Date()
        print("[Auth] Starting Google OAuth")
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: SupabaseClientProvider.callbackScheme
            ) { callbackURL, error in
                if let error {
                    print("[Auth] OAuth failed after \(Date().timeIntervalSince(startTime))s: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    print("[Auth] OAuth callback missing after \(Date().timeIntervalSince(startTime))s")
                    continuation.resume(throwing: URLError(.badURL))
                    return
                }
                print("[Auth] OAuth callback received after \(Date().timeIntervalSince(startTime))s")
                Task {
                    do {
                        let session = try await self.client.auth.session(from: callbackURL)
                        print("[Auth] Session exchange finished after \(Date().timeIntervalSince(startTime))s")
                        continuation.resume(returning: session)
                    } catch {
                        print("[Auth] Session exchange failed after \(Date().timeIntervalSince(startTime))s: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.authSession = session
            session.start()
        }
    }

    func handleRedirectURL(_ url: URL) async throws -> Session {
        try await client.auth.session(from: url)
    }

    func cancelSignIn() {
        authSession?.cancel()
        authSession = nil
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        presentationAnchor ?? ASPresentationAnchor()
    }
}
