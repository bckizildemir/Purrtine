import SwiftUI

/// A bordered menu label that shows a field title above its current value.
struct FeedingMenuRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Decorative: the Menu it labels already announces itself as a control.
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(Theme.backgroundSecondary, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.separator, lineWidth: 0.5)
        }
    }
}

#Preview {
    FeedingMenuRow(
        title: "Portion type",
        value: "Grams"
    )
    .padding()
}
