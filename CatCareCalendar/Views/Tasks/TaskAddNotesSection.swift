import SwiftUI

/// The free-text notes field of the add-task sheet.
struct TaskAddNotesSection: View {
    @Binding var text: String
    @FocusState.Binding var focusedField: TaskAddField?

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)

            TextField(String(localized: .tasksConfigNotesPlaceholder), text: $text, axis: .vertical)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 56, alignment: .topLeading)
                .lineLimit(3...6)
                .focused($focusedField, equals: .notes)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
        }
    }
}

#if DEBUG
/// A host that owns the text and the focus state the section binds to.
private struct TaskAddNotesSectionPreview: View {
    @State private var text = "Serve breakfast and refresh both bowls."
    @FocusState private var focusedField: TaskAddField?

    var body: some View {
        TaskAddNotesSection(text: $text, focusedField: $focusedField)
    }
}

#Preview {
    TaskAddNotesSectionPreview()
}
#endif
