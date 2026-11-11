import SwiftUI

/// The category picker row of the add-task sheet.
struct TaskAddCategorySection: View {
    let selectedCategory: CareTaskCategory
    let iconColor: Color
    let onSelect: (CareTaskCategory) -> Void

    var body: some View {
        Menu {
            ForEach(CareTaskCategory.allCases, id: \.self) { category in
                Button {
                    onSelect(category)
                } label: {
                    HStack {
                        Image(systemName: category.iconName)
                        Text(category.displayName)
                        if selectedCategory == category {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
            }
        } label: {
            SimpleOptionRow(
                icon: selectedCategory.iconName,
                iconColor: iconColor,
                title: String(localized: .tasksConfigCategory),
                value: selectedCategory.displayName
            )
        }
    }
}

#Preview {
    @Previewable @State var selectedCategory: CareTaskCategory = .feeding

    TaskAddCategorySection(
        selectedCategory: selectedCategory,
        iconColor: .orange
    ) { category in
        selectedCategory = category
    }
}
