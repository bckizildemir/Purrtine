import SwiftUI

/// The notification row of the task add and edit forms.
///
/// The toggle turns the reminder on and off. The rest of the row opens a menu that selects how
/// long before the task the notification arrives.
struct ReminderMenuRow: View {
    let options: [(value: Int, label: String)]
    @Binding var selectedMinutes: Int
    @Binding var isEnabled: Bool

    private var selectedLabel: String {
        options.first { $0.value == selectedMinutes }?.label ?? String(localized: .tasksConfigCustom)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Menu {
                    ForEach(options, id: \.value) { option in
                        Button {
                            selectedMinutes = option.value
                        } label: {
                            HStack {
                                Text(option.label)
                                if selectedMinutes == option.value {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    OptionRowLabel(
                        icon: "bell",
                        iconColor: Theme.iconReminder,
                        title: String(localized: .tasksConfigNotifications),
                        subtitle: isEnabled ? selectedLabel : nil,
                        isChevronDimmed: isEnabled == false
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(isEnabled == false)
                .accessibilityIdentifier("reminderRow.notificationsMenu")

                Toggle(String(localized: .tasksConfigNotificationsEnableToggle), isOn: $isEnabled)
                    .labelsHidden()
                    .accessibilityIdentifier("reminderRow.notificationsToggle")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 16)
        }
    }
}
