import SwiftUI

struct StorePickerView: View {
    let stores: [StoreLocation]
    let selectedStoreId: UUID?
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Store")
                    .font(.headline)
                Spacer()
                Button(action: onAdd) {
                    Label("Add", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel("Add store")
            }

            if stores.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No stores yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Create your first store to start tracking trips.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Create your first store") {
                        onAdd()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Menu {
                    ForEach(stores) { store in
                        Button {
                            onSelect(store.id)
                        } label: {
                            Label(store.name, systemImage: "bag")
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(selectedStoreColor)
                            .frame(width: 10, height: 10)
                        Text(selectedStoreName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityLabel("Select store")
            }
        }
    }

    private var selectedStoreName: String {
        stores.first(where: { $0.id == selectedStoreId })?.name ?? "Select store"
    }

    private var selectedStoreColor: Color {
        let key = stores.first(where: { $0.id == selectedStoreId })?.colorKey ?? "blue"
        return StorePalette.color(for: key)
    }
}
