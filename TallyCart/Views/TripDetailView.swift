import SwiftUI

struct TripDetailView: View {
    let trip: Trip
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Spacing.l) {
                CardContainer {
                    HStack(alignment: .top, spacing: Tokens.Spacing.s) {
                        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                            Text(trip.storeNameSnapshot)
                                .font(.title3.weight(.semibold))
                            Text(trip.finishedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(Tokens.ColorToken.secondaryLabel)
                        }
                        Spacer()
                        StatusPill(status: trip.status)
                    }

                    if trip.status == .finished {
                        Text("Finished trips are immutable. Create a draft copy to make changes.")
                            .font(.caption)
                            .foregroundStyle(Tokens.ColorToken.secondaryLabel)
                    }
                }

                if trip.status == .finished {
                    PrimaryButton("Start Draft Copy") {
                        viewModel.startDraft(from: trip)
                    }
                    .accessibilityLabel(Text("Start draft copy"))
                }

                CardContainer {
                    MetricRow(label: "Subtotal", value: trip.subtotal.currencyString)
                    if trip.includeTax {
                        MetricRow(label: "Tax", value: trip.taxAmount.currencyString)
                    }
                    MetricRow(label: "Total", value: trip.total.currencyString)
                }

                CardContainer {
                    Text("Items")
                        .font(.headline)
                    ForEach(trip.items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                                Text(item.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(item.quantity) x \(item.unitPrice.currencyString)")
                                    .font(.caption)
                                    .foregroundStyle(Tokens.ColorToken.secondaryLabel)
                            }
                            Spacer()
                            Text(item.lineTotal.currencyString)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(Tokens.Spacing.m)
                        .background(Tokens.ColorToken.secondaryBackground, in: RoundedRectangle(cornerRadius: Tokens.CornerRadius.card, style: .continuous))
                    }
                }
            }
            .padding(Tokens.Spacing.l)
        }
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.inline)
    }
}
