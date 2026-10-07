import SwiftUI

/// The footnote shown under a task's cats-assignment row when no cats exist yet.
///
/// `TaskAddView` and `TaskEditView` both render this identical hint, so it lives here to keep
/// the styling in one place. The same `tasksConfigCatsNoneHint` string is also used as the
/// cats row's `accessibilityValue`, so VoiceOver users hear the hint even though this footnote
/// is a separate view.
struct CatsAssignmentEmptyHint: View {
    var body: some View {
        Text(.tasksConfigCatsNoneHint)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }
}

#Preview {
    CatsAssignmentEmptyHint()
}
