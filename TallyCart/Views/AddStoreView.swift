import SwiftUI

struct AddStoreView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedColorKey: String = StorePalette.keys.first ?? "blue"

    let onSave: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Store Name") {
                    TextField("e.g. Trader Joe's", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                        ForEach(StorePalette.keys, id: \.self) { key in
                            Button {
                                selectedColorKey = key
                            } label: {
                                Circle()
                                    .fill(StorePalette.color(for: key))
                                    .frame(height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(selectedColorKey == key ? 0.8 : 0.2), lineWidth: selectedColorKey == key ? 2 : 1)
                                    )
                                    .padding(2)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(key)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Add Store")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmed, selectedColorKey)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
