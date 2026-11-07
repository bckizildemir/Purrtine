import SwiftUI

struct HomeRoutineStatusRowView: View {
    let row: HomeRoutineStatusPresentation.Row
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: row.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)

                Text(row.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 12)

                Text(row.secondaryTimestampText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .monospacedDigit()
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityIdentifier("home.routineStatus.row.\(row.title)")
    }

}
