import SwiftUI

/// The "Cats" row in `TaskAddView`, letting the user pick which cats a task applies to, with an
/// inline error state shown when no cats are selected at save time.
struct TaskAddCatsSection: View {
    let allCats: [Cat]
    @Binding var selectedCats: Set<Cat>
    @Binding var assignToAllCats: Bool
    @Binding var showingCatSelector: Bool
    let showCatError: Bool
    let horizontalSizeClass: UserInterfaceSizeClass?
    let onCatSelectionChange: (Set<Cat>) -> Void
    let onAssignAllChange: (Bool) -> Void

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

    private var isNotSelected: Bool {
        allCats.isEmpty || (!assignToAllCats && selectedCats.isEmpty)
    }

    var body: some View {
        let baseTrigger = Button {
            showingCatSelector = true
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "cat.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(showCatError ? Color.red : Color.orange)
                        .clipShape(.rect(cornerRadius: 6))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCatError)

                    Text(.tasksConfigCats)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text(valueText)
                            .font(.body)
                            .foregroundStyle(showCatError && isNotSelected ? .red : .secondary)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCatError)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(showCatError && isNotSelected ? Color.red.opacity(0.1) : Color.clear)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCatError)
                )

                Divider()
                    .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("taskAdd.catsButton")
        .buttonStyle(.plain)
        .disabled(allCats.isEmpty)
        .accessibilityValue(allCats.isEmpty ? String(localized: .tasksConfigCatsNoneHint) : valueText)

        VStack(alignment: .leading, spacing: 0) {
            if horizontalSizeClass == .regular {
                baseTrigger
                    .popover(isPresented: $showingCatSelector, arrowEdge: .trailing) {
                        TaskCatsSelectionView(
                            cats: allCats,
                            selectedCats: $selectedCats,
                            assignToAllCats: $assignToAllCats
                        )
                    }
                    .onChange(of: selectedCats) { oldValue, newValue in
                        onCatSelectionChange(newValue)
                    }
                    .onChange(of: assignToAllCats) { oldValue, newValue in
                        onAssignAllChange(newValue)
                    }
            } else {
                baseTrigger
                    .sheet(isPresented: $showingCatSelector) {
                        TaskCatsSelectionView(
                            cats: allCats,
                            selectedCats: $selectedCats,
                            assignToAllCats: $assignToAllCats
                        )
                    }
                    .onChange(of: selectedCats) { oldValue, newValue in
                        onCatSelectionChange(newValue)
                    }
                    .onChange(of: assignToAllCats) { oldValue, newValue in
                        onAssignAllChange(newValue)
                    }
            }

            if allCats.isEmpty {
                CatsAssignmentEmptyHint()
            }
        }
    }
}
