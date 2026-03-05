import SwiftUI

struct PreferencesView: View {
    @ObservedObject var viewModel: Phase2ViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var monthlyBudgetText: String = ""
    @State private var householdSize: Int = 1
    @State private var premiumSensitivity: Double = 50
    @State private var alwaysSuggestStaples: Bool = true
    @State private var dietFlags: [String: Bool] = [
        "Vegetarian": false,
        "Vegan": false,
        "Gluten Free": false
    ]
    @State private var avoidItems: [String] = []
    @State private var newAvoidItem: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Budget") {
                    TextField("Monthly budget", text: $monthlyBudgetText)
                        .keyboardType(.decimalPad)
                    Stepper("Household size: \(householdSize)", value: $householdSize, in: 1...10)
                }

                Section("Suggestions") {
                    Toggle("Always suggest staples", isOn: $alwaysSuggestStaples)
                    VStack(alignment: .leading) {
                        Text("Premium sensitivity")
                        Slider(value: $premiumSensitivity, in: 0...100, step: 5)
                    }
                }

                Section("Diet preferences") {
                    ForEach(dietFlags.keys.sorted(), id: \.self) { key in
                        Toggle(key, isOn: Binding(
                            get: { dietFlags[key, default: false] },
                            set: { dietFlags[key] = $0 }
                        ))
                    }
                }

                Section("Avoid items") {
                    HStack {
                        TextField("Add item", text: $newAvoidItem)
                        Button("Add") {
                            let trimmed = newAvoidItem.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            avoidItems.append(trimmed)
                            newAvoidItem = ""
                        }
                    }
                    ForEach(avoidItems, id: \.self) { item in
                        Text(item)
                    }
                    .onDelete { offsets in
                        avoidItems.remove(atOffsets: offsets)
                    }
                }
            }
            .navigationTitle("Preferences")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await savePreferences() }
                        dismiss()
                    }
                }
            }
            .onAppear {
                hydrateFromModel()
            }
        }
    }

    private func hydrateFromModel() {
        guard let preferences = viewModel.preferences else { return }
        if let budgetCents = preferences.monthlyBudgetCents {
            monthlyBudgetText = String(format: "%.2f", Double(budgetCents) / 100.0)
        }
        householdSize = preferences.householdSize
        premiumSensitivity = Double(preferences.premiumSensitivity)
        alwaysSuggestStaples = preferences.alwaysSuggestStaples
        avoidItems = preferences.avoidItems
        var flags = dietFlags
        for (key, value) in preferences.dietFlags {
            flags[key] = value
        }
        dietFlags = flags
    }

    private func savePreferences() async {
        guard let existing = viewModel.preferences else { return }
        let budgetCents = Int((Double(monthlyBudgetText) ?? 0) * 100)
        let budgetValue: Int? = monthlyBudgetText.isEmpty ? nil : budgetCents
        let updated = UserPreferencesModel(
            userId: existing.userId,
            monthlyBudgetCents: budgetValue,
            householdSize: householdSize,
            premiumSensitivity: Int(premiumSensitivity),
            alwaysSuggestStaples: alwaysSuggestStaples,
            dietFlags: dietFlags,
            avoidItems: avoidItems,
            preferredBrands: existing.preferredBrands,
            staplesItems: existing.staplesItems,
            updatedAt: Date()
        )
        await viewModel.updatePreferences(updated)
    }
}
