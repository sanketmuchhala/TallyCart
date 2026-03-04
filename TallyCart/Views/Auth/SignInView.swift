import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        ZStack {
            Color("BrandBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Image("LogoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)

                VStack(spacing: 8) {
                    Text("Welcome to TallyCart")
                        .font(.title2.weight(.semibold))
                    Text("Sign in to sync your trips across devices.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    startGoogleSignIn()
                } label: {
                    Label("Continue with Google", systemImage: "globe")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isLoading)

                Button("Continue offline") {
                    viewModel.enableOfflineMode()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)

                if viewModel.isLoading {
                    Button("Cancel") {
                        viewModel.cancelSignIn()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
    }

    private func startGoogleSignIn() {
        guard let anchor = presentationAnchor() else {
            viewModel.errorMessage = "Could not start sign in."
            return
        }
        Task { await viewModel.signInWithGoogle(presentationAnchor: anchor) }
    }

    private func presentationAnchor() -> ASPresentationAnchor? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        return windowScene?.windows.first { $0.isKeyWindow }
    }
}
