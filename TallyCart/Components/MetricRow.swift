import SwiftUI

struct MetricRow: View {
    let label: String
    let value: String
    let delta: String?

    init(label: String, value: String, delta: String? = nil) {
        self.label = label
        self.value = value
        self.delta = delta
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(Tokens.ColorToken.secondaryLabel)
            Spacer()
            if let delta {
                Text(delta)
                    .font(.caption)
                    .foregroundStyle(Tokens.ColorToken.secondaryLabel)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(label), \(value)"))
    }
}
