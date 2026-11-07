import SwiftUI
import SwiftData

/// Selector used when assigning cats to a task.
struct TaskCatsSelectionView: View {
    let cats: [Cat]
    @Binding var selectedCats: Set<Cat>
    @Binding var assignToAllCats: Bool
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var workingSelection: Set<Cat>
    @State private var workingAssignToAll: Bool

    private var hasUnsavedChanges: Bool {
        workingSelection != selectedCats || workingAssignToAll != assignToAllCats
    }
    
    init(
        cats: [Cat],
        selectedCats: Binding<Set<Cat>>,
        assignToAllCats: Binding<Bool>
    ) {
        self.cats = cats
        _selectedCats = selectedCats
        _assignToAllCats = assignToAllCats
        _workingSelection = State(initialValue: selectedCats.wrappedValue)
        _workingAssignToAll = State(initialValue: assignToAllCats.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            List {
                if cats.count >= 2 {
                    Section {
                        Toggle(String(localized: .catsSelectionAssignToAll), isOn: $workingAssignToAll)
                            .accessibilityIdentifier("taskCatsSelection.assignAllToggle")
                            .onChange(of: workingAssignToAll) { _, isOn in
                                if isOn {
                                    workingSelection.removeAll()
                                }
                            }
                    }
                }
                
                Section(header: Text(selectionSummary)) {
                    if cats.isEmpty {
                        Text(.catsSelectionNeedToAdd)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else if filteredCats.isEmpty {
                        Text(.catsSelectionSelectCats)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(filteredCats) { cat in
                            let isSelected = workingAssignToAll || workingSelection.contains(cat)
                            Button {
                                if workingAssignToAll {
                                    // Convert from "All" to explicit selection set first
                                    workingAssignToAll = false
                                    workingSelection = Set(cats)
                                }
                                toggleSelection(for: cat)
                            } label: {
                                HStack {
                                    Text(cat.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("taskCatsSelection.cat.\(cat.name)")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText)
            .navigationTitle(String(localized: .catsSelectionTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetDismissButton(hasUnsavedChanges: hasUnsavedChanges, onDismiss: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirmButton {
                        complete()
                    }
                    .accessibilityIdentifier("taskCatsSelection.doneButton")
                    .disabled(!isValidSelection)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onChange(of: workingSelection) { _, newValue in
            if cats.count >= 2 && newValue.count == cats.count {
                workingAssignToAll = true
            }
        }
    }
    
    private var filteredCats: [Cat] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return cats
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return cats.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    private var selectionSummary: String {
        if workingAssignToAll {
            return String(localized: .tasksConfigAllCats)
        }
        return String(localized: .catsSelectionSelectedCount(Int32(workingSelection.count)))
    }
    
    private var isValidSelection: Bool {
        workingAssignToAll || !workingSelection.isEmpty
    }
    
    private func toggleSelection(for cat: Cat) {
        if workingSelection.contains(cat) {
            workingSelection.remove(cat)
        } else {
            workingSelection.insert(cat)
        }
    }
    
    private func complete() {
        selectedCats = workingSelection
        assignToAllCats = workingAssignToAll
        dismiss()
    }
}

#if DEBUG
#Preview("Task Cat Selection") {
    @Previewable @State var selectedCats: Set<Cat> = []
    @Previewable @State var assignsAllCats = false

    PreviewHost(scenario: .standard) {
        let cats = PreviewData.firstCat().map { [$0] } ?? []
        TaskCatsSelectionView(
            cats: cats,
            selectedCats: $selectedCats,
            assignToAllCats: $assignsAllCats
        )
    }
}
#endif
