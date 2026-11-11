import SwiftUI

/// Essential fields section component for cat forms.
/// Contains name, age, and gender fields.
struct EssentialFieldsSection: View {
    @Binding var formData: CatFormData
    var focusedField: FocusState<CatFormData.Field?>.Binding
    var showsAgeAndGender: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            nameRow
            if showsAgeAndGender {
                Divider().padding(.leading, 16)
                ageRow
                Divider().padding(.leading, 16)
                genderRow
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
    }

    // MARK: - Name Row
    @ViewBuilder
    private var nameRow: some View {
        HStack {
            Text(.catAddNameLabel)
                .foregroundColor(.primary)
            Spacer()
            TextField(String(localized: .catAddNamePlaceholder), text: $formData.name)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.secondary)
                .frame(width: 140)
                .focused(focusedField, equals: .name)
                .accessibilityIdentifier("catForm.nameField")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Age Row
    @ViewBuilder
    private var ageRow: some View {
        HStack {
            Text(.catAddAgeLabel)
                .foregroundColor(.primary)
            Spacer()
            ageInputField
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var ageInputField: some View {
        HStack(spacing: 8) {
            TextField(formData.agePlaceholder, text: $formData.ageText)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .foregroundColor(.secondary)
                .frame(width: 76)
                .focused(focusedField, equals: .age)
                .accessibilityLabel(String(localized: .catAddAgeLabel))
                .accessibilityHint(String(localized: .catAddAgeHint))
                .onChange(of: formData.ageText) { _, newValue in
                    updateAge(from: newValue)
                }
                .onSubmit {
                    updateAge(from: formData.ageText)
                }

            ageUnitPicker
        }
    }

    @ViewBuilder
    private var ageUnitPicker: some View {
        Picker("", selection: $formData.ageUnit) {
            ForEach(AgeUnit.allCases, id: \.self) { unit in
                Text(unit.displayName).tag(unit)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 150)
        .accessibilityLabel(String(localized: .catAddAgeUnitLabel))
    }

    // MARK: - Gender Row
    @ViewBuilder
    private var genderRow: some View {
        HStack {
            Text(.catAddGenderLabel)
                .foregroundColor(.primary)
            Spacer()
            Picker("", selection: $formData.gender) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    Text(gender.displayName).tag(gender)
                }
            }
            .pickerStyle(.menu)
            .tint(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Age Handling
    private func updateAge(from text: String) {
        guard !text.isEmpty else {
            formData.ageValue = nil
            return
        }

        guard let parsed = Int(text) else {
            formData.ageValue = nil
            formData.ageText = ""
            return
        }

        let validated = AgeUtils.validateAge(parsed)
        formData.ageValue = validated

        if let validated {
            if formData.ageText != String(validated) {
                formData.ageText = String(validated)
            }
        } else {
            formData.ageText = ""
        }
    }
}
