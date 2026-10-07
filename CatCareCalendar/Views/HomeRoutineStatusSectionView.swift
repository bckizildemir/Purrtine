import SwiftUI

struct HomeRoutineStatusSectionView: View {
    let rows: [HomeRoutineStatusPresentation.Row]
    let onTaskSelected: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.mint)
                Text(.homeRoutineStatus)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }

            if rows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(.homeRoutineStatusEmpty)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(rows) { row in
                        HomeRoutineStatusRowView(row: row) {
                            onTaskSelected(row.taskID)
                        }
                    }
                }
            }
        }
        .padding()
        .homeSectionSurface()
        .accessibilityIdentifier("home.routineStatus.section")
    }
}
