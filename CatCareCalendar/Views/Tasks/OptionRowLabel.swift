import SwiftUI

/// The shared interior of a task-configuration row: a tinted icon tile, a title, an optional
/// subtitle, and an optional trailing value with a chevron.
///
/// This view carries no interaction of its own. Callers wrap it in a `Button`, or use it as a
/// `Menu` label, so that the row is reachable by VoiceOver and Voice Control.
struct OptionRowLabel: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String?
    var value: String?
    var showsChevron: Bool = true
    var isChevronDimmed: Bool = false

    @ScaledMetric(relativeTo: .body) private var iconTileSize = 24

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(.white)
                .frame(width: iconTileSize, height: iconTileSize)
                .background(iconColor)
                .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Theme.label)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Theme.link)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                if let value {
                    Text(value)
                        .font(.body)
                        .foregroundStyle(Theme.labelSecondary)
                }

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.labelSecondary)
                        .opacity(isChevronDimmed ? 0.3 : 1)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        OptionRowLabel(
            icon: "repeat",
            iconColor: .green,
            title: "Repeat",
            value: "Daily"
        )

        OptionRowLabel(
            icon: "bell",
            iconColor: .purple,
            title: "Notifications",
            subtitle: "15 minutes before",
            showsChevron: false
        )
    }
    .padding()
}
