import SwiftUI

struct AccountMenuButton: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        Menu {
            Text(viewModel.displayName)
                .font(.headline)
            Button("Profile") {}
            Button(role: .destructive) {
                Task { await viewModel.signOut() }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            ProfileImageView(url: viewModel.avatarURL)
        }
        .accessibilityLabel(Text("Account"))
    }
}

private struct ProfileImageView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.crop.circle.fill")
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
        .clipped()
        .accessibilityHidden(true)
    }
}
