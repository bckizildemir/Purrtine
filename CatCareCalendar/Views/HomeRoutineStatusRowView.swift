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

                Text(formattedCompletionTimestamp)
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

    private var formattedCompletionTimestamp: String {
        guard let lastCompletionDate = row.lastCompletionDate else {
            return row.secondaryTimestampText
        }

        return lastCompletionDate.formatted(.verbatim(
            "\(day: .twoDigits)/\(month: .twoDigits)/\(year: .defaultDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
            locale: Locale(identifier: "en_GB_POSIX"), timeZone: .current, calendar: .current
        ))
    }
}
