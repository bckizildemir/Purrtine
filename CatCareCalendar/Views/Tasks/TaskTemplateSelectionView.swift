import SwiftUI

struct TaskTemplateSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var selectedCategory: CareTaskCategory? = nil
    @State private var searchText = ""
    
    let onTemplateSelected: (CareTaskTemplate) -> Void
    
    init(onTemplateSelected: @escaping (CareTaskTemplate) -> Void) {
        self.onTemplateSelected = onTemplateSelected
    }
    
    private let templateManager = CareTaskTemplateManager.shared
    
    private var filteredTemplates: [CareTaskTemplate] {
        var templates = templateManager.allTemplates
        
        // Category filter
        if let category = selectedCategory {
            templates = templates.filter { $0.category == category }
        }
        
        // Search filter
        if !searchText.isEmpty {
            templates = templates.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return templates
    }
    
    private var popularTemplates: [CareTaskTemplate] {
        templateManager.popularTemplates()
    }
    
    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
        return [GridItem(.flexible())]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        //headerSection
                        categoryFilterSection
                        
                        if searchText.isEmpty && selectedCategory == nil {
                            popularTemplatesSection
                        }
                        
                        allTemplatesSection
                    }
                    .padding()
                }
                .searchable(
                    text: $searchText,
                    prompt: String(localized: .tasksTemplateSearchPlaceholder)
                )
                .searchScopes($selectedCategory) {
                    Text(.tasksTemplateAllCategories)
                        .tag(CareTaskCategory?.none)
                    ForEach(CareTaskCategory.allCases, id: \.self) { category in
                        Text(category.displayName)
                            .tag(Optional(category))
                    }
                }
                .searchSuggestions {
                    if searchText.isEmpty {
                        ForEach(popularTemplates.prefix(5)) { template in
                            Text(template.title)
                                .searchCompletion(template.title)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: .tasksTemplateTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetDismissButton {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(.taskTemplateHeaderPrimary)
                .font(.title3)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(.taskTemplateHeaderSecondary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Category Filter Section (kept for visual consistency)
    @ViewBuilder
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All categories chip
                CategoryChip(
                    title: String(localized: .tasksTemplateAllCategories),
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    accessibilityIdentifier: "taskTemplate.category.all"
                ) {
                    selectedCategory = nil
                }
                
                // Category chips
                ForEach(CareTaskCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        icon: category.iconName,
                        isSelected: selectedCategory == category,
                        accessibilityIdentifier: "taskTemplate.category.\(category.rawValue)"
                    ) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Popular Templates Section
    @ViewBuilder
    private var popularTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(.tasksTemplatePopular)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            templateGrid(popularGridContent)
        }
    }

    @ViewBuilder
    private var popularGridContent: some View {
        LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(popularTemplates) { template in
                TemplateCard(template: template) {
                    haptics.impact(.light)
                    onTemplateSelected(template)
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func templateGrid(_ content: some View) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 10) {
                content
            }
        } else {
            content
        }
    }
    
    // MARK: - All Templates Section
    @ViewBuilder
    private var allTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if filteredTemplates.isEmpty {
                ContentUnavailableView(
                    String(localized: .tasksTemplateNoMatchesTitle),
                    systemImage: "magnifyingglass",
                    description: Text(.tasksTemplateNoMatchesDescription)
                )
                .frame(minHeight: 200)
            } else {
                HStack {
                    Text(selectedCategory?.displayName ?? String(localized: .tasksTemplateAllTemplates))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(String(localized: .tasksTemplateTemplateCount(Int32(filteredTemplates.count))))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                templateGrid(allGridContent)
            }
        }
    }

    @ViewBuilder
    private var allGridContent: some View {
        LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(filteredTemplates) { template in
                TemplateCard(template: template) {
                    haptics.impact(.light)
                    onTemplateSelected(template)
                    dismiss()
                }
            }
        }
    }
    
}

// MARK: - Category Chip Component
struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

// MARK: - Template Card Component
struct TemplateCard: View {
    let template: CareTaskTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: template.iconName)
                        .font(.title2)
                        .foregroundStyle(colorForCategory(template.category))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)

                        Text(template.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Text(template.defaultFrequency.displayName)
                        .font(.caption2)
                        .foregroundStyle(.tint)
                }

                if let tips = template.tips {
                    Label {
                        Text(tips)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    } icon: {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .templateCardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("taskTemplate.\(template.kind.rawValue)")
        .accessibilityHint(Text(.tasksTemplateAddHint))
    }
    
    private func colorForCategory(_ category: CareTaskCategory) -> Color {
        switch category {
        case .feeding: return .orange
        case .medication: return .red
        case .grooming: return .cyan
        case .health: return .pink
        case .exercise: return .green
        case .litter: return .brown
        case .vet: return .orange
        case .general: return .gray
        case .water: return .blue
        }
    }
}

// MARK: - Template Card Surface

private extension View {
    @ViewBuilder
    func templateCardSurface() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        } else {
            background(
                Theme.backgroundGroupedSecondary,
                in: .rect(cornerRadius: 12)
            )
        }
    }
}

// MARK: - Preview
#Preview("Task Templates") {
    TaskTemplateSelectionView { _ in }
}
