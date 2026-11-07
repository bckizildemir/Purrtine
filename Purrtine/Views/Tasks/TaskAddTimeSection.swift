import SwiftUI

/// The time-of-day row of the add-task sheet, with its expandable wheel picker.
struct TaskAddTimeSection: View {
    @Binding var selectedTime: Date
    @Binding var hasTime: Bool
    let isPickerExpanded: Bool
    let onTap: () -> Void

    private var isPickerVisible: Bool {
        hasTime && isPickerExpanded
    }

    var body: some View {
        VStack(spacing: 0) {
            RemindersOptionRow(
                icon: "clock.fill",
                iconColor: Theme.iconTime,
                title: String(localized: .tasksConfigTime),
                subtitle: hasTime ? selectedTime.formatted(date: .omitted, time: .shortened) : nil,
                value: nil,
                hasToggle: true,
                isToggled: $hasTime,
                action: onTap
            )

            // Kept always mounted (instead of inserted/removed via `if`) so its
            // intrinsic width is resolved once and never renegotiated mid-animation —
            // only height/opacity animate, so only this section moves, and it only
            // grows downward instead of also flashing wider.
            DatePicker(
                "",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            // Fix height only: fixing both axes made the picker report its
            // ideal (wider-than-card) width, widening every section around it.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .frame(height: isPickerVisible ? nil : 0, alignment: .top)
            .clipped()
            .opacity(isPickerVisible ? 1 : 0)
            .allowsHitTesting(isPickerVisible)
            .accessibilityHidden(isPickerVisible == false)
        }
        .animation(.easeInOut(duration: 0.3), value: isPickerVisible)
    }
}

#Preview {
    @Previewable @State var selectedTime = Date.now
    @Previewable @State var hasTime = true
    @Previewable @State var isPickerExpanded = true

    ScrollView {
        TaskAddTimeSection(
            selectedTime: $selectedTime,
            hasTime: $hasTime,
            isPickerExpanded: isPickerExpanded
        ) {
            isPickerExpanded.toggle()
        }
    }
}
