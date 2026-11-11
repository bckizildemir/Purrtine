import SwiftUI

/// A configuration row for the task add and edit forms that shows a title and its current value.
///
/// The row is presentation only. Wrap it in a `Button` when it opens a sheet, or pass it as a
/// `Menu` label when it opens a menu.
struct SimpleOptionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            OptionRowLabel(
                icon: icon,
                iconColor: iconColor,
                title: title,
                value: value
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(.rect)

            Divider()
                .padding(.horizontal, 16)
        }
    }
}

#Preview {
    Button {
        // The preview needs no action.
    } label: {
        SimpleOptionRow(
            icon: "cat.fill",
            iconColor: .orange,
            title: "Cats",
            value: "Pamuk, Zeytin"
        )
    }
    .buttonStyle(.plain)
}
