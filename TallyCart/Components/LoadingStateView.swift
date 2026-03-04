import SwiftUI

struct LoadingStateView: View {
    let title: String

    init(title: String = "Loading") {
        self.title = title
    }

    var body: some View {
        VStack(spacing: Tokens.Spacing.m) {
            ProgressView()
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Tokens.ColorToken.secondaryLabel)
        }
        .padding(Tokens.Spacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}
