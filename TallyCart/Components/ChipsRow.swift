import SwiftUI

struct ChipsRow: View {
    let chips: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Spacing.s) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, Tokens.Spacing.m)
                        .padding(.vertical, Tokens.Spacing.xs)
                        .background(Tokens.ColorToken.secondaryBackground, in: Capsule())
                        .foregroundStyle(Tokens.ColorToken.label)
                }
            }
            .padding(.horizontal, Tokens.Spacing.l)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
