import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let primaryActionTitle: String?
    let primaryAction: (() -> Void)?

    init(systemImage: String, title: String, subtitle: String, primaryActionTitle: String? = nil, primaryAction: (() -> Void)? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
    }

    var body: some View {
        VStack(spacing: Tokens.Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Tokens.ColorToken.secondaryLabel)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Tokens.ColorToken.secondaryLabel)
                .multilineTextAlignment(.center)

            if let primaryActionTitle, let primaryAction {
                PrimaryButton(primaryActionTitle, action: primaryAction)
                    .frame(maxWidth: 220)
            }
        }
        .padding(Tokens.Spacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
