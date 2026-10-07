import SwiftUI

/// The caregiver picker row shared by the add-task and edit-task forms.
struct CaregiverPickerSection: View {
    let additionalCaregivers: [Caregiver]
    @Binding var assignToMe: Bool
    @Binding var selectedCaregiver: Caregiver?
    let accessibilityIdentifier: String

    private var value: String {
        if assignToMe {
            String(localized: .tasksConfigMyself)
        } else {
            selectedCaregiver?.displayName ?? String(localized: .tasksConfigNotSelected)
        }
    }

    var body: some View {
        Menu {
            Button {
                assignToMe = true
                selectedCaregiver = nil
            } label: {
                HStack {
                    Text(.tasksConfigMyself)
                    if assignToMe {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }
            .accessibilityAddTraits(assignToMe ? .isSelected : [])

            if additionalCaregivers.isEmpty == false {
                Divider()

                ForEach(additionalCaregivers) { caregiver in
                    Button {
                        assignToMe = false
                        selectedCaregiver = caregiver
                    } label: {
                        HStack {
                            Text(caregiver.displayName)
                            if assignToMe == false && selectedCaregiver?.id == caregiver.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .accessibilityAddTraits(
                        assignToMe == false && selectedCaregiver?.id == caregiver.id ? .isSelected : []
                    )
                }
            }
        } label: {
            SimpleOptionRow(
                icon: "person.fill",
                iconColor: Theme.iconCaregiver,
                title: String(localized: .tasksConfigCaregiver),
                value: value
            )
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

#if DEBUG
/// A host that owns the selection the section binds to.
private struct CaregiverPickerSectionPreview: View {
    let additionalCaregivers: [Caregiver]
    @State private var assignToMe: Bool
    @State private var selectedCaregiver: Caregiver?

    init(additionalCaregivers: [Caregiver], assignToMe: Bool) {
        self.additionalCaregivers = additionalCaregivers
        _assignToMe = State(initialValue: assignToMe)
        _selectedCaregiver = State(initialValue: assignToMe ? nil : additionalCaregivers.first)
    }

    var body: some View {
        CaregiverPickerSection(
            additionalCaregivers: additionalCaregivers,
            assignToMe: $assignToMe,
            selectedCaregiver: $selectedCaregiver,
            accessibilityIdentifier: "preview.caregiverButton"
        )
    }
}

#Preview("Assigned to me") {
    CaregiverPickerSectionPreview(additionalCaregivers: [], assignToMe: true)
}

#Preview("Assigned to another caregiver") {
    CaregiverPickerSectionPreview(
        additionalCaregivers: [Caregiver(name: "Alex"), Caregiver(name: "Sam")],
        assignToMe: false
    )
}
#endif
