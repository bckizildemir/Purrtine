import SwiftUI

struct HistoryTaskScopeHeaderView: View {
    let taskTitle: String
    let completionCountText: String
    let clearAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(taskTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(completionCountText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 12)

            Button(String(localized: .historyShowAll), action: clearAction)
                .font(.caption.weight(.semibold))
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}
