import SwiftUI

struct TripDetailView: View {
    let trip: Trip

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.storeNameSnapshot)
                        .font(.title3.weight(.semibold))
                    Text(trip.finishedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    SummaryRow(title: "Subtotal", value: trip.subtotal.currencyString)
                    if trip.includeTax {
                        SummaryRow(title: "Tax", value: trip.taxAmount.currencyString)
                    }
                    SummaryRow(title: "Total", value: trip.total.currencyString, bold: true)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Items")
                        .font(.headline)
                    ForEach(trip.items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(item.quantity) x \(item.unitPrice.currencyString)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.lineTotal.currencyString)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SummaryRow: View {
    let title: String
    let value: String
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(bold ? .headline : .subheadline.weight(.semibold))
        }
    }
}
