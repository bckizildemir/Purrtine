import SwiftUI

// MARK: - Filter Chip Component
struct FilterChip: View {
    let filter: CareTaskFilter
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(filter.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text(count, format: .number)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? filter.color : Color(UIColor.secondarySystemGroupedBackground))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Task Summary Card Component
struct TaskSummaryCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                Text(count, format: .number)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Filter Section View
struct TaskFilterSection: View {
    let filters: [CareTaskFilter]
    let selectedFilter: CareTaskFilter
    let getTaskCount: (CareTaskFilter) -> Int
    let onFilterSelected: (CareTaskFilter) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filters, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        count: getTaskCount(filter)
                    ) {
                        onFilterSelected(filter)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Summary Tile Component (Reminders-style)
struct SummaryTile: View {
    let filter: CareTaskFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: filter.icon)
                        .font(.title2)
                        .foregroundColor(filter.color)
                    Spacer()
                    Text(count, format: .number)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Text(filter.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .frame(minHeight: 88)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? filter.color.opacity(0.15) : Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? filter.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filter.displayName)
        .accessibilityValue(Text(count, format: .number))
        .accessibilityHint(Text(.tasksFilterTileHint))
    }
}

// MARK: - Summary Tiles Grid
struct TaskSummaryGrid: View {
    let selectedFilter: CareTaskFilter
    let getCount: (CareTaskFilter) -> Int
    let onTap: (CareTaskFilter) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    private let displayFilters: [CareTaskFilter] = [
        .today, .overdue, .upcoming, .all, .completed
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(displayFilters, id: \.self) { filter in
                SummaryTile(
                    filter: filter,
                    count: getCount(filter),
                    isSelected: selectedFilter == filter,
                    action: { onTap(filter) }
                )
            }
        }
    }
}

// MARK: - Task Summary Cards Section
struct TaskSummarySection: View {
    let getTaskCount: (CareTaskFilter) -> Int
    
    var body: some View {
        HStack(spacing: 12) {
            TaskSummaryCard(
                title: String(localized: .tasksFilterToday),
                count: getTaskCount(.today),
                color: .purple,
                icon: "calendar.circle"
            )
            
            TaskSummaryCard(
                title: String(localized: .tasksFilterOverdue),
                count: getTaskCount(.overdue),
                color: .orange,
                icon: "clock.badge.exclamationmark"
            )
            
            TaskSummaryCard(
                title: String(localized: .tasksFilterCompleted),
                count: getTaskCount(.completed),
                color: .green,
                icon: "checkmark.circle"
            )
        }
    }
} 
