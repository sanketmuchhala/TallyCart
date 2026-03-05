import SwiftUI

struct StaplesView: View {
    @ObservedObject var viewModel: Phase2ViewModel
    @State private var newStaple: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            AppHeaderContainer {
                HeaderRow(title: "Lists") { EmptyView() }

                if staples.isEmpty {
                    EmptyStateView(
                        systemImage: "checklist",
                        title: "No staples yet",
                        subtitle: "Add staples to reuse on every trip."
                    )
                    .padding(.horizontal, Tokens.Spacing.l)
                }

                CardContainer {
                    HStack {
                        TextField("Add staple", text: $newStaple)
                            .textInputAutocapitalization(.words)
                            .focused($isInputFocused)
                        Button("Add") { addStaple() }
                            .disabled(newStaple.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, Tokens.Spacing.l)

                List {
                    ForEach(staples, id: \.self) { item in
                        Text(item)
                            .padding(.vertical, Tokens.Spacing.s)
                            .standardListRowStyle()
                    }
                    .onDelete { offsets in
                        removeStaples(at: offsets)
                    }
                }
                .listStyle(.plain)
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadInitialData()
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                }
            }
            .onTapGesture {
                isInputFocused = false
            }
        }
    }

    private var staples: [String] {
        viewModel.preferences?.staplesItems ?? []
    }

    private func addStaple() {
        guard var preferences = viewModel.preferences else { return }
        let trimmed = newStaple.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        preferences.staplesItems.append(trimmed)
        Task { await viewModel.updatePreferences(preferences) }
        newStaple = ""
    }

    private func removeStaples(at offsets: IndexSet) {
        guard var preferences = viewModel.preferences else { return }
        preferences.staplesItems.remove(atOffsets: offsets)
        Task { await viewModel.updatePreferences(preferences) }
    }
}
