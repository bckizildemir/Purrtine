import SwiftUI

/// Reminders-style circular dismiss (X) button for sheet toolbars.
/// iOS 26 renders the system close glyph with Liquid Glass; earlier versions
/// fall back to an equivalent hand-built circular button.
struct SheetDismissButton: View {
    private let hasUnsavedChanges: Bool
    let action: () -> Void

    @State private var isShowingDiscardConfirmation = false

    init(action: @escaping () -> Void) {
        self.hasUnsavedChanges = false
        self.action = action
    }

    /// Creates a dismiss button whose discard confirmation is anchored to the button itself.
    init(hasUnsavedChanges: Bool, onDismiss: @escaping () -> Void) {
        self.hasUnsavedChanges = hasUnsavedChanges
        self.action = onDismiss
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(role: .close, action: dismissButtonTapped)
            } else {
                Button(action: dismissButtonTapped) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(.quaternary, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: .actionClose))
            }
        }
        .confirmationDialog(
            String(localized: .sheetDiscardTitle),
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: .sheetDiscardConfirm), role: .destructive, action: action)
        }
    }

    private func dismissButtonTapped() {
        if hasUnsavedChanges {
            isShowingDiscardConfirmation = true
        } else {
            action()
        }
    }
}

/// Reminders-style filled checkmark confirm button for sheet toolbars.
/// Pair with `ToolbarItem(placement: .confirmationAction)`; disable via `.disabled(...)`.
/// While `isInProgress` is true it shows an activity indicator in place of the checkmark.
struct SheetConfirmButton: View {
    var isInProgress = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        if isInProgress {
            ProgressView()
                .accessibilityLabel(String(localized: .sheetSaving))
        } else if #available(iOS 26.0, *) {
            Button(role: .confirm, action: action)
        } else {
            Button(action: action) {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isEnabled ? Color.white : Color(.secondaryLabel))
                    .frame(width: 30, height: 30)
                    .background(isEnabled ? Color.blue : Color(.systemGray4), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: .actionSave))
        }
    }
}
