import SwiftUI

/// A completion indicator for one feeding field, shown under the feeding-details form.
struct FeedingFieldStatusRow: View {
    let title: String
    let missingTitle: String
    let isComplete: Bool

    var body: some View {
        Label {
            Text(isComplete ? title : missingTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .bold()
                .foregroundStyle(isComplete ? Theme.success : Color.secondary)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        FeedingFieldStatusRow(
            title: "Portion set",
            missingTitle: "Portion missing",
            isComplete: true
        )

        FeedingFieldStatusRow(
            title: "Food set",
            missingTitle: "Food missing",
            isComplete: false
        )
    }
    .padding()
}
