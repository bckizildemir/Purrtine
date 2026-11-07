import SwiftUI

/// The start-date row of the add-task sheet, with its expandable calendar picker.
struct TaskAddDateSection: View {
    @Binding var startDate: Date
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            RemindersOptionRow(
                icon: "calendar",
                iconColor: Theme.iconDate,
                title: String(localized: .tasksConfigDate),
                subtitle: startDate.taskDayLabel,
                value: nil,
                hasToggle: false,
                isToggled: .constant(false),
                action: onTap
            )

            if isExpanded {
                DatePicker(
                    "",
                    selection: $startDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity)
            }

            Divider()
                .padding(.horizontal, 16)
        }
    }
}

#Preview {
    @Previewable @State var startDate = Date.now
    @Previewable @State var isExpanded = true

    ScrollView {
        TaskAddDateSection(
            startDate: $startDate,
            isExpanded: isExpanded
        ) {
            isExpanded.toggle()
        }
    }
}
