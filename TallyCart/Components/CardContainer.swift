import SwiftUI

struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Tokens.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.ColorToken.secondaryBackground, in: RoundedRectangle(cornerRadius: Tokens.CornerRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.CornerRadius.card, style: .continuous)
                    .stroke(Tokens.ColorToken.separator.opacity(0.5), lineWidth: 0.5)
            )
    }
}
