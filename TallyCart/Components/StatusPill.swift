import SwiftUI

struct StatusPill: View {
    let status: TripStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, Tokens.Spacing.s)
            .padding(.vertical, Tokens.Spacing.xs)
            .background(backgroundColor, in: Capsule())
            .foregroundStyle(foregroundColor)
            .accessibilityLabel(Text("Status: \(status.displayName)"))
    }

    private var backgroundColor: Color {
        switch status {
        case .draft:
            return Tokens.ColorToken.secondaryBackground
        case .finished:
            return Tokens.ColorToken.secondaryBackground
        case .archived:
            return Tokens.ColorToken.separator.opacity(0.3)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .draft:
            return Tokens.ColorToken.label
        case .finished:
            return Tokens.ColorToken.secondaryLabel
        case .archived:
            return Tokens.ColorToken.secondaryLabel
        }
    }
}
