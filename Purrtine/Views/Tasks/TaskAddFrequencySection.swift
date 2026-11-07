import SwiftUI

/// The repeat-frequency picker row of the add-task sheet.
struct TaskAddFrequencySection: View {
    let selectedFrequency: CareTaskFrequency
    let summary: String
    let onSelect: (CareTaskFrequency) -> Void

    var body: some View {
        Menu {
            ForEach(CareTaskFrequency.allCases, id: \.self) { frequency in
                Button {
                    onSelect(frequency)
                } label: {
                    HStack {
                        Text(frequency.displayName)
                        if selectedFrequency == frequency {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .accessibilityAddTraits(selectedFrequency == frequency ? .isSelected : [])
            }
        } label: {
            SimpleOptionRow(
                icon: "repeat",
                iconColor: Theme.iconSchedule,
                title: String(localized: .tasksConfigRepeat),
                value: summary
            )
        }
    }
}

#Preview {
    @Previewable @State var selectedFrequency: CareTaskFrequency = .daily

    TaskAddFrequencySection(
        selectedFrequency: selectedFrequency,
        summary: selectedFrequency.displayName
    ) { frequency in
        selectedFrequency = frequency
    }
}
