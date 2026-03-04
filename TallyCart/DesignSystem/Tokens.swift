import SwiftUI

enum Tokens {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum CornerRadius {
        static let card: CGFloat = 16
        static let pill: CGFloat = 10
    }

    enum ColorToken {
        static let accent = Color.accentColor
        static let background = Color(uiColor: .systemBackground)
        static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
        static let label = Color(uiColor: .label)
        static let secondaryLabel = Color(uiColor: .secondaryLabel)
        static let separator = Color(uiColor: .separator)
    }
}
