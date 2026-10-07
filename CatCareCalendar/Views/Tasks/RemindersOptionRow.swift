import SwiftUI

/// A configuration row for the date, time, and notification items of the task forms.
///
/// The row shows a trailing `Toggle` when `hasToggle` is true. The leading part is a `Button` that
/// opens the matching picker. The button is disabled while the toggle is off, because the picker
/// has no meaning then.
struct RemindersOptionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let value: String?
    let hasToggle: Bool
    @Binding var isToggled: Bool
    let action: () -> Void

    private var isPickerAvailable: Bool {
        hasToggle == false || isToggled
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: action) {
                    OptionRowLabel(
                        icon: icon,
                        iconColor: iconColor,
                        title: title,
                        subtitle: subtitle,
                        value: hasToggle ? nil : value,
                        showsChevron: hasToggle == false
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(isPickerAvailable == false)

                if hasToggle {
                    Toggle(String(localized: .tasksConfigOptionToggleEnable(title)), isOn: $isToggled)
                        .labelsHidden()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 16)
        }
    }
}

#Preview {
    @Previewable @State var isToggled = true

    VStack(spacing: 0) {
        RemindersOptionRow(
            icon: "calendar",
            iconColor: .red,
            title: "Date",
            subtitle: "Today",
            value: nil,
            hasToggle: true,
            isToggled: $isToggled
        ) {
            // The preview needs no action.
        }

        RemindersOptionRow(
            icon: "clock.fill",
            iconColor: .blue,
            title: "Time",
            subtitle: nil,
            value: "09:00",
            hasToggle: false,
            isToggled: .constant(false)
        ) {
            // The preview needs no action.
        }
    }
}
