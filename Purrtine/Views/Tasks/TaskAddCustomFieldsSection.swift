import SwiftUI

/// The template custom fields that the add-task sheet shows as plain rows.
///
/// The feeding fields are excluded, because `TaskAddFeedingDetailsRow` edits those in a sheet.
/// The remaining fields have no editor, so the rows are display only.
struct TaskAddCustomFieldsSection: View {
    let template: CareTaskTemplate
    let values: [String: String]

    private var fields: [CareTaskCustomField] {
        guard let keys = FeedingFieldSupport.keys(for: template) else {
            return template.customFields
        }
        return template.customFields.filter { $0.key != keys.portion && $0.key != keys.foodType }
    }

    var body: some View {
        ForEach(fields) { field in
            SimpleOptionRow(
                icon: "square.and.pencil",
                iconColor: Theme.iconNeutral,
                title: field.name,
                value: displayValue(for: field)
            )
        }
    }

    private func displayValue(for field: CareTaskCustomField) -> String {
        let rawValue = values[field.key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return rawValue.isEmpty ? String(localized: .tasksConfigNotEntered) : rawValue
    }
}

#Preview {
    VStack(spacing: 0) {
        if let template = CareTaskTemplateManager.shared.allTemplates.first {
            TaskAddCustomFieldsSection(template: template, values: [:])
        }
    }
}
