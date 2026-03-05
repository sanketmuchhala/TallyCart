import SwiftUI

struct TripLifecyclePill: View {
    let status: TripLifecycleStatus

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
        case .planned:
            return Tokens.ColorToken.secondaryBackground
        case .active:
            return Tokens.ColorToken.secondaryBackground
        case .done:
            return Tokens.ColorToken.separator.opacity(0.25)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .planned:
            return Tokens.ColorToken.label
        case .active:
            return Tokens.ColorToken.label
        case .done:
            return Tokens.ColorToken.secondaryLabel
        }
    }
}
