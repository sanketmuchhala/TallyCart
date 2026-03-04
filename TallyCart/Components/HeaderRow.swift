import SwiftUI

struct HeaderRow<RightContent: View>: View {
    let title: String
    let rightContent: RightContent

    init(title: String, @ViewBuilder rightContent: () -> RightContent) {
        self.title = title
        self.rightContent = rightContent()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            rightContent
        }
        .padding(.horizontal, Tokens.Spacing.l)
        .padding(.top, Tokens.Spacing.s)
    }
}
