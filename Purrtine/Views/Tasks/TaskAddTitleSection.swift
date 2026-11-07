import SwiftUI

/// The task-title field of the add-task sheet, with its inline validation message.
struct TaskAddTitleSection: View {
    @Binding var title: String
    let placeholder: String
    let errorMessage: String?
    @FocusState.Binding var focusedField: TaskAddField?
    let onTitleChange: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            TextField(placeholder, text: $title)
                .font(.title3)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit { focusedField = .notes }
                .accessibilityIdentifier("taskAdd.titleField")
                .onChange(of: title) { _, newValue in
                    onTitleChange(newValue)
                }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }
}

#if DEBUG
/// A host that owns the title and the focus state the section binds to.
private struct TaskAddTitleSectionPreview: View {
    let errorMessage: String?
    @State private var title: String
    @FocusState private var focusedField: TaskAddField?

    init(title: String, errorMessage: String?) {
        _title = State(initialValue: title)
        self.errorMessage = errorMessage
    }

    var body: some View {
        TaskAddTitleSection(
            title: $title,
            placeholder: "Task title",
            errorMessage: errorMessage,
            focusedField: $focusedField
        ) { _ in
            // The preview needs no validation.
        }
    }
}

#Preview("Filled") {
    TaskAddTitleSectionPreview(title: "Morning feeding", errorMessage: nil)
}

#Preview("Empty with an error") {
    TaskAddTitleSectionPreview(title: "", errorMessage: "Enter a task title.")
}
#endif
