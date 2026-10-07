import SwiftUI

/// Advanced fields section component for cat forms.
/// Contains breed, weight, medical notes, and medical conditions.
/// Only shown when expanded.
struct AdvancedFieldsSection: View {
    @Binding var formData: CatFormData
    var focusedField: FocusState<CatFormData.Field?>.Binding

    var body: some View {
        VStack(spacing: 0) {
            // Expandable Header
            Button(action: {
                withAnimation(.bouncy(duration: 0.2)) {
                    formData.showingAdvancedSection.toggle()
                }
            }) {
                HStack {
                    Text(.catAddMoreDetails)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(formData.showingAdvancedSection ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if formData.showingAdvancedSection {
                Divider()
                    .padding(.leading, 16)

                // Breed
                breedRow
                Divider()
                    .padding(.leading, 16)

                // Weight
                weightRow
                Divider()
                    .padding(.leading, 16)

                // Medical Notes
                medicalNotesRow
                Divider()
                    .padding(.leading, 16)

                // Medical Conditions
                medicalConditionsRow
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
    }

    // MARK: - Breed Row
    @ViewBuilder
    private var breedRow: some View {
        HStack {
            Text(.catAddBreedLabel)
                .foregroundColor(.primary)
            Spacer()
            TextField(String(localized: .catAddBreedPlaceholder), text: $formData.breed)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.secondary)
                .frame(width: 140)
                .focused(focusedField, equals: .breed)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Weight Row
    @ViewBuilder
    private var weightRow: some View {
        HStack {
            Text(.catAddWeightLabel)
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 8) {
                TextField(String(localized: .catAddWeightPlaceholder), text: $formData.weight)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .foregroundColor(.secondary)
                    .frame(width: 50)
                    .focused(focusedField, equals: .weight)

                Picker("", selection: $formData.weightUnit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Medical Notes Row
    @ViewBuilder
    private var medicalNotesRow: some View {
        HStack(alignment: .top) {
            Text(.catAddMedicalNotesLabel)
                .foregroundColor(.primary)
            Spacer()
            TextField(String(localized: .catAddMedicalNotesPlaceholder), text: $formData.medicalNotes, axis: .vertical)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .top)
                .focused(focusedField, equals: .medicalNotes)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Medical Conditions Row
    @ViewBuilder
    private var medicalConditionsRow: some View {
        HStack(alignment: .top) {
            Text(.catAddMedicalConditionsLabel)
                .foregroundColor(.primary)
            Spacer()
            TextField(String(localized: .catAddMedicalConditionsPlaceholder), text: $formData.medicalConditions, axis: .vertical)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .top)
                .focused(focusedField, equals: .medicalConditions)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
