import SwiftUI

struct StandardListRowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: Tokens.Spacing.s, leading: Tokens.Spacing.l, bottom: Tokens.Spacing.s, trailing: Tokens.Spacing.l))
            .listRowBackground(Tokens.ColorToken.secondaryBackground)
    }
}

extension View {
    func standardListRowStyle() -> some View {
        modifier(StandardListRowStyle())
    }
}
