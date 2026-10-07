import SwiftUI

/// The row that opens the feeding-details sheet, summarizing the portion and the food type.
struct TaskAddFeedingDetailsRow: View {
    let portionValue: String?
    let foodTypeValue: String?
    let iconColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            SimpleOptionRow(
                icon: "fork.knife",
                iconColor: iconColor,
                title: String(localized: .tasksConfigFeedingDetailsTitle),
                value: FeedingFieldSupport.summary(portion: portionValue, foodType: foodTypeValue)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 0) {
        TaskAddFeedingDetailsRow(
            portionValue: "60|grams",
            foodTypeValue: "Dry food",
            iconColor: .orange
        ) {
            // The preview needs no action.
        }

        TaskAddFeedingDetailsRow(
            portionValue: nil,
            foodTypeValue: nil,
            iconColor: .orange
        ) {
            // The preview needs no action.
        }
    }
}
