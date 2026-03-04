import SwiftUI

struct InsightsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedMonth: Date = Date()

    var body: some View {
        VStack(spacing: 16) {
            monthPicker

            if viewModel.state.trips.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("No insights yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Finish a trip to see monthly analytics.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                summaryCard
                storeBreakdown
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .onAppear {
            if let latest = availableMonths.first {
                selectedMonth = latest
            }
        }
    }

    private var availableMonths: [Date] {
        let months = viewModel.monthTotals().keys
        return months.sorted(by: { $0 > $1 })
    }

    private var monthPicker: some View {
        HStack {
            Text("Month")
                .font(.headline)
            Spacer()
            Picker("Month", selection: $selectedMonth) {
                ForEach(availableMonths, id: \.self) { month in
                    Text(month.formatted(.dateTime.year().month()))
                        .tag(month)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var summaryCard: some View {
        let totals = viewModel.monthTotals()
        let thisMonth = totals[selectedMonth] ?? 0
        let lastMonth = totals[lastMonth(for: selectedMonth)] ?? 0
        let diff = thisMonth - lastMonth
        let percent = lastMonth == 0 ? 0 : (diff / lastMonth) * 100

        return VStack(alignment: .leading, spacing: 8) {
            Text("This Month")
                .font(.headline)
            Text(thisMonth.currencyString)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("vs last month: \(diff.currencyString) (\(percentString(percent)))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var storeBreakdown: some View {
        let breakdown = viewModel.storeBreakdown(for: selectedMonth)
        let maxTotal = breakdown.map { $0.total }.max() ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            Text("By Store")
                .font(.headline)

            ForEach(breakdown, id: \.storeName) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle()
                            .fill(StorePalette.color(for: entry.colorKey).opacity(0.3))
                            .frame(width: 10, height: 10)
                        Text(entry.storeName)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(entry.total.currencyString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(StorePalette.color(for: entry.colorKey))
                            .frame(width: width * (entry.total / maxTotal), height: 6)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.secondary.opacity(0.15))
                            )
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func lastMonth(for date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: -1, to: date) ?? date
    }

    private func percentString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        let number = formatter.string(from: NSNumber(value: value)) ?? "0"
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(number)%"
    }
}
