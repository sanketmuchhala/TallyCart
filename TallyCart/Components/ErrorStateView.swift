import SwiftUI

struct ErrorStateView: View {
    let title: String
    let message: String
    let retryTitle: String
    let retryAction: () -> Void

    init(title: String, message: String, retryTitle: String = "Retry", retryAction: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: Tokens.Spacing.m) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Tokens.ColorToken.secondaryLabel)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Tokens.ColorToken.secondaryLabel)
                .multilineTextAlignment(.center)
            SecondaryButton(retryTitle, action: retryAction)
                .frame(maxWidth: 220)
        }
        .padding(Tokens.Spacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
