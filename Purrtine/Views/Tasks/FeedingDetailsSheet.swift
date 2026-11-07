import SwiftUI

/// The sheet that edits the portion and the food type of a feeding task.
struct FeedingDetailsSheet: View {
    @Binding var draft: FeedingDetailsDraft
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: TaskAddField?
    @State private var initialSnapshot: [String]?

    private var currentSnapshot: [String] {
        [draft.portionAmount, draft.portionUnit.rawValue, draft.foodType]
    }

    private var hasUnsavedChanges: Bool {
        guard let initialSnapshot else { return false }
        return currentSnapshot != initialSnapshot
    }

    private var isPortionComplete: Bool {
        draft.portionAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var isFoodComplete: Bool {
        draft.foodType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FeedingTextField(
                        title: draft.portionFieldTitle,
                        placeholder: draft.portionFieldPlaceholder,
                        text: $draft.portionAmount,
                        field: .portion,
                        focusedField: $focusedField,
                        keyboardType: .decimalPad
                    )

                    Menu {
                        ForEach(FeedingPortionUnit.allCases) { unit in
                            Button {
                                draft.portionUnit = unit
                            } label: {
                                HStack {
                                    Text(unit.displayName)
                                    if unit == draft.portionUnit {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .accessibilityAddTraits(unit == draft.portionUnit ? .isSelected : [])
                        }
                    } label: {
                        FeedingMenuRow(
                            title: String(localized: .tasksConfigFeedingDetailsChoosePortionType),
                            value: draft.portionUnit.displayName
                        )
                    }

                    FeedingTextField(
                        title: draft.foodFieldTitle,
                        placeholder: draft.foodFieldPlaceholder,
                        text: $draft.foodType,
                        field: .foodType,
                        focusedField: $focusedField,
                        capitalization: .words,
                        isAutocorrectionDisabled: true
                    )

                    if draft.foodTypeOptions.isEmpty == false {
                        FeedingFoodOptionsList(options: draft.foodTypeOptions, selection: $draft.foodType)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        FeedingFieldStatusRow(
                            title: String(localized: .tasksConfigFeedingDetailsPortionSet),
                            missingTitle: String(localized: .tasksConfigFeedingDetailsPortionMissing),
                            isComplete: isPortionComplete
                        )
                        FeedingFieldStatusRow(
                            title: String(localized: .tasksConfigFeedingDetailsFoodSet),
                            missingTitle: String(localized: .tasksConfigFeedingDetailsFoodMissing),
                            isComplete: isFoodComplete
                        )
                        Text(.tasksConfigFeedingDetailsGuidance)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .navigationTitle(String(localized: .tasksConfigFeedingDetailsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetDismissButton(hasUnsavedChanges: hasUnsavedChanges, onDismiss: dismiss.callAsFunction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirmButton {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onAppear {
            focusedField = .portion
            if initialSnapshot == nil {
                initialSnapshot = currentSnapshot
            }
        }
    }
}

#if DEBUG
/// A host that owns the draft the sheet binds to.
private struct FeedingDetailsSheetPreview: View {
    @State private var draft = FeedingDetailsDraft(
        portionFieldTitle: "Portion",
        portionFieldPlaceholder: "For example, 60",
        foodFieldTitle: "Food type",
        foodFieldPlaceholder: "For example, dry food",
        foodTypeOptions: ["Dry food", "Wet food", "Prescription food"],
        portionAmount: "60"
    )

    var body: some View {
        FeedingDetailsSheet(draft: $draft, onSave: {})
    }
}

#Preview {
    FeedingDetailsSheetPreview()
}
#endif
