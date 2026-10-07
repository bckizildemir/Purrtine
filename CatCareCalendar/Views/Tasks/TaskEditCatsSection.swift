import SwiftUI

/// The "Cats" row in `TaskEditView`, letting the user pick which cats a task applies to.
struct TaskEditCatsSection: View {
    let allCats: [Cat]
    @Binding var selectedCats: Set<Cat>
    @Binding var assignToAllCats: Bool
    @Binding var showingCatSelector: Bool
    let horizontalSizeClass: UserInterfaceSizeClass?

    private var valueText: String {
        if allCats.isEmpty {
            return String(localized: .tasksConfigCatsNotAdded)
        } else if assignToAllCats {
            return String(localized: .tasksConfigAllCats)
        } else if selectedCats.isEmpty {
            return String(localized: .tasksConfigNotSelected)
        } else {
            let sortedNames = selectedCats.map { $0.name }.sorted()
            if sortedNames.count == 1 {
                return sortedNames[0]
            } else if sortedNames.count == 2 {
                return sortedNames.joined(separator: ", ")
            } else {
                return String(localized: .tasksConfigCatsCount(Int32(sortedNames.count)))
            }
        }
    }

    var body: some View {
        let row = Button {
            showingCatSelector = true
        } label: {
            SimpleOptionRow(
                icon: "cat.fill",
                iconColor: Theme.iconCats,
                title: String(localized: .tasksConfigCats),
                value: valueText
            )
        }
        .buttonStyle(.plain)
        .disabled(allCats.isEmpty)
        .accessibilityValue(allCats.isEmpty ? "\(valueText). \(String(localized: .tasksConfigCatsNoneHint))" : valueText)

        VStack(alignment: .leading, spacing: 0) {
            if horizontalSizeClass == .regular {
                row
                    .popover(isPresented: $showingCatSelector, arrowEdge: .trailing) {
                        TaskCatsSelectionView(
                            cats: allCats,
                            selectedCats: $selectedCats,
                            assignToAllCats: $assignToAllCats
                        )
                    }
            } else {
                row
                    .sheet(isPresented: $showingCatSelector) {
                        TaskCatsSelectionView(
                            cats: allCats,
                            selectedCats: $selectedCats,
                            assignToAllCats: $assignToAllCats
                        )
                    }
            }

            if allCats.isEmpty {
                CatsAssignmentEmptyHint()
            }
        }
    }
}
