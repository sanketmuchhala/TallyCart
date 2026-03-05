import SwiftUI

struct StoresListView: View {
    @ObservedObject var viewModel: Phase2ViewModel
    @State private var showAdd = false
    @State private var editingStore: StoreModel?

    var body: some View {
        NavigationStack {
            AppHeaderContainer {
                HeaderRow(title: "Stores") {
                    if !viewModel.stores.isEmpty {
                        Button {
                            showAdd = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3)
                                .foregroundStyle(.primary)
                        }
                        .accessibilityLabel("Add Store")
                    }
                }

                if viewModel.stores.isEmpty {
                    EmptyStateView(
                        systemImage: "building.2",
                        title: "No stores yet",
                        subtitle: "Add a store to speed up trip setup.",
                        primaryActionTitle: "Add Store",
                        primaryAction: { showAdd = true }
                    )
                    .padding(.horizontal, Tokens.Spacing.l)
                } else {
                    List {
                        ForEach(viewModel.stores) { store in
                            Button {
                                editingStore = store
                            } label: {
                                StoreRowView(store: store)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button {
                                    Task { await viewModel.setDefaultStore(store) }
                                } label: {
                                    Label("Default", systemImage: "star")
                                }
                                .tint(.yellow)
                            }
                            .standardListRowStyle()
                        }
                    }
                    .listStyle(.plain)

                    PrimaryButton("Add Store", systemImage: "plus") {
                        showAdd = true
                    }
                    .padding(.horizontal, Tokens.Spacing.l)
                }
            }
            .navigationBarHidden(true)
            .task {
                if viewModel.stores.isEmpty {
                    await viewModel.loadInitialData()
                }
            }
            .sheet(isPresented: $showAdd) {
                StoreEditorView(viewModel: viewModel, store: nil)
            }
            .sheet(item: $editingStore) { store in
                StoreEditorView(viewModel: viewModel, store: store)
            }
            .alert("Store Error", isPresented: Binding(get: {
                viewModel.storeErrorMessage != nil
            }, set: { _ in
                viewModel.storeErrorMessage = nil
            })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.storeErrorMessage ?? "")
            }
        }
    }
}

private struct StoreRowView: View {
    let store: StoreModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.headline)
                if let location = store.locationText, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if store.isDefault {
                Text("Default")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, Tokens.Spacing.s)
                    .padding(.vertical, Tokens.Spacing.xs)
                    .background(Tokens.ColorToken.secondaryBackground, in: Capsule())
            }
        }
        .padding(.vertical, Tokens.Spacing.s)
    }
}

private struct StoreEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: Phase2ViewModel
    let store: StoreModel?

    @State private var name: String
    @State private var location: String
    @State private var notes: String
    @State private var isDefault: Bool

    init(viewModel: Phase2ViewModel, store: StoreModel?) {
        self.viewModel = viewModel
        self.store = store
        _name = State(initialValue: store?.name ?? "")
        _location = State(initialValue: store?.locationText ?? "")
        _notes = State(initialValue: store?.notes ?? "")
        _isDefault = State(initialValue: store?.isDefault ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Store name", text: $name)
                TextField("Location", text: $location)
                TextField("Notes", text: $notes)
                Toggle("Default store", isOn: $isDefault)
            }
            .navigationTitle(store == nil ? "Add Store" : "Edit Store")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let ok = await saveStore()
                            if ok { dismiss() }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveStore() async -> Bool {
        if var store {
            store.name = name
            store.locationText = location.isEmpty ? nil : location
            store.notes = notes.isEmpty ? nil : notes
            store.isDefault = isDefault
            let ok = await viewModel.updateStore(store)
            if ok, isDefault {
                await viewModel.setDefaultStore(store)
            }
            return ok
        } else {
            let ok = await viewModel.upsertStore(name: name, location: location, notes: notes, isDefault: isDefault)
            return ok
        }
    }
}
