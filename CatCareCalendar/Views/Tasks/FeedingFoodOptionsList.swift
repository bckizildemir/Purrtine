import SwiftUI

/// The quick-select list of food types offered by a feeding template.
struct FeedingFoodOptionsList: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(.tasksConfigFeedingDetailsQuickSelect)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    HStack {
                        Text(option)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selection == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .padding(12)
                    .background(Theme.backgroundSecondary, in: .rect(cornerRadius: 12))
                }
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
    }
}

#Preview {
    @Previewable @State var selection = "Dry food"

    ScrollView {
        FeedingFoodOptionsList(
            options: ["Dry food", "Wet food", "Prescription food"],
            selection: $selection
        )
        .padding()
    }
}
