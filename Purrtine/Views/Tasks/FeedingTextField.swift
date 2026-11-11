import SwiftUI

/// A titled, bordered text field used by the feeding-details sheet.
struct FeedingTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let field: TaskAddField
    @FocusState.Binding var focusedField: TaskAddField?
    var keyboardType: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var isAutocorrectionDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled(isAutocorrectionDisabled)
                .focused($focusedField, equals: field)
                .padding(12)
                .background(Theme.backgroundSecondary, in: .rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.separator, lineWidth: 0.5)
                }
        }
    }
}

#if DEBUG
/// A host that owns the state the field binds to.
private struct FeedingTextFieldPreview: View {
    @State private var text = "60"
    @FocusState private var focusedField: TaskAddField?

    var body: some View {
        FeedingTextField(
            title: "Portion",
            placeholder: "For example, 60",
            text: $text,
            field: .portion,
            focusedField: $focusedField,
            keyboardType: .decimalPad
        )
        .padding()
    }
}

#Preview {
    FeedingTextFieldPreview()
}
#endif
