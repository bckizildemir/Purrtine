import SwiftUI

/// The priority picker row of the add-task sheet.
struct TaskAddPrioritySection: View {
    let selectedPriority: CareTaskPriority
    let onSelect: (CareTaskPriority) -> Void

    var body: some View {
        Menu {
            ForEach(CareTaskPriority.allCases, id: \.self) { priority in
                Button {
                    onSelect(priority)
                } label: {
                    HStack {
                        Text(priority.displayName)
                        if selectedPriority == priority {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .accessibilityAddTraits(selectedPriority == priority ? .isSelected : [])
            }
        } label: {
            SimpleOptionRow(
                icon: "exclamationmark",
                iconColor: Theme.iconPriority,
                title: String(localized: .tasksConfigPriority),
                value: selectedPriority.displayName
            )
        }
    }
}

#Preview {
    @Previewable @State var selectedPriority: CareTaskPriority = .high

    TaskAddPrioritySection(selectedPriority: selectedPriority) { priority in
        selectedPriority = priority
    }
}
