import SwiftUI
import SwiftData

// MARK: - CareTask Row Component with Swipe Actions
struct TaskRow: View {
    let task: CareTask
    let onTap: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void
    
    // MARK: - Computed Properties
    
    /// Formatted time display with scheduled time or relative time
    private var timeText: String {
        task.dueDisplayText()
    }
    
    /// Time text color - red if overdue
    private var timeColor: Color {
        task.isOverdue ? .red : .secondary
    }
    
    /// Determines if the task can be completed (prevents re-completing one-time tasks)
    private var canBeCompleted: Bool {
        // If task is not completed, it can be completed
        guard task.status == .completed else { return true }
        
        // If task is recurring, it can be completed again
        if task.isRecurring { return true }
        
        // If task is a one-time task and already completed, it cannot be completed again
        return false
    }
    
    /// Checkmark circle color based on task state
    private var checkmarkColor: Color {
        if task.status == .completed && !task.isRecurring {
            return .gray // One-time completed tasks stay gray
        } else if task.status == .completed {
            return categoryColor // Recurring tasks use category color when completed
        } else {
            return .clear // Uncompleted tasks have empty circle
        }
    }
    
    /// Border color for checkmark circle
    private var checkmarkBorderColor: Color {
        if task.status == .completed {
            return checkmarkColor
        } else if task.isOverdue {
            return .red
        } else {
            return categoryColor
        }
    }
    
    /// Category-based color
    private var categoryColor: Color {
        switch task.category.color {
        case "systemOrange": return .orange
        case "systemBlue": return .blue
        case "systemRed": return .red
        case "systemturquoise": return Color(red: 0.25, green: 0.78, blue: 0.88)
        case "systemPink": return .pink
        case "systemGreen": return .green
        case "systemBrown": return .brown
        case "systemPurple": return .purple
        default: return .gray
        }
    }
    
    /// Completion time text
    private var completionTimeText: String {
        task.lastCompletionDisplayText()
    }
    
    var body: some View {
        // A row can be re-evaluated after its task was deleted from the context
        // (deletion races the list refresh); reading a persisted property of a
        // dead model traps in SwiftData, so render nothing until the row is gone.
        if task.isDeleted || task.modelContext == nil {
            Color.clear.frame(height: 0)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            // Checkmark circle
            Button(action: {
                if canBeCompleted {
                    onComplete()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(checkmarkColor)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .stroke(checkmarkBorderColor, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if task.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canBeCompleted)
            .accessibilityLabel(Text(.accessibilityCompleteTask))
            .accessibilityHint(Text(.accessibilityMarkComplete))
            .accessibilityIdentifier("taskRow.complete.\(task.title)")
            .accessibilityValue(
                Text(
                    task.status == .completed
                    ? String(localized: .taskStatusCompleted)
                    : String(localized: .taskStatusPending)
                )
            )
            
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 0) {
                    taskContent
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("taskRow.\(task.title)")
            .accessibilityLabel(Text(verbatim: "\(task.title), \(task.assignedCatNames), \(timeText)"))
            .accessibilityHint(Text(.tasksRowDetailsHint))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .taskCardSurface(cornerRadius: 20, legacyCornerRadius: 12)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Delete action
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String(localized: .tasksRowDelete), systemImage: "trash")
            }
            .tint(.red)
            .accessibilityIdentifier("taskRow.delete.\(task.title)")
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            // Complete action - only show if task can be completed
            if canBeCompleted {
                Button {
                    onComplete()
                } label: {
                    Label(String(localized: .tasksRowComplete), systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
        }
    }

    private var taskContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)

            HStack(spacing: 6) {
                if !task.assignedCats.isEmpty {
                    Text(task.assignedCatNames)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if !timeText.isEmpty {
                    if !task.assignedCats.isEmpty {
                        Text(verbatim: "•")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text(timeText)
                        .font(.subheadline)
                        .foregroundColor(timeColor)
                }
            }

            Text(completionTimeText)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
    }
}

// MARK: - CareTask Status Indicator
struct CareTaskStatusIndicator: View {
    let status: CareTaskStatus
    
    var body: some View {
        Image(systemName: iconName)
            .font(.caption)
            .foregroundColor(color)
            .frame(width: 16, height: 16)
    }
    
    private var iconName: String {
        switch status {
        case .pending: return "clock"
        case .inProgress: return "arrow.right.circle"
        case .completed: return "checkmark.circle.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        case .postponed: return "pause.circle"
        case .cancelled: return "xmark.circle"
        }
    }
    
    private var color: Color {
        switch status {
        case .pending: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        case .overdue: return .red
        case .postponed: return .orange
        case .cancelled: return .gray
        }
    }
}

// MARK: - Supporting Components

struct CareTaskPriorityBadge: View {
    let priority: CareTaskPriority
    
    var body: some View {
        Text(priority.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorForPriority(priority))
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private func colorForPriority(_ priority: CareTaskPriority) -> Color {
        switch priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview("Task Rows") {
    ScrollView {
        VStack(spacing: 20) {
            if #available(iOS 26, *) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("iOS 26 · Liquid Glass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)
                    GlassEffectContainer(spacing: 8) {
                        VStack(spacing: 8) {
                            TaskRow(
                                task: CareTask(title: "Morning feeding", description: "Serve breakfast and refresh both bowls."),
                                onTap: {},
                                onComplete: {},
                                onDelete: {}
                            )
                            TaskRow(
                                task: {
                                    let t = CareTask(title: "Refresh water bowl — the fountain filter needs a full clean today", description: "Wash fountain.")
                                    t.status = .completed
                                    return t
                                }(),
                                onTap: {},
                                onComplete: {},
                                onDelete: {}
                            )
                            TaskRow(
                                task: {
                                    let t = CareTask(title: "Litter box", description: "Clean.", category: .litter, iconName: "tray.fill")
                                    t.status = .overdue
                                    return t
                                }(),
                                onTap: {},
                                onComplete: {},
                                onDelete: {}
                            )
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("iOS 18 Fallback")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
                VStack(spacing: 8) {
                    TaskRow(
                        task: CareTask(title: "Morning feeding", description: "Serve breakfast and refresh both bowls."),
                        onTap: {},
                        onComplete: {},
                        onDelete: {}
                    )
                    TaskRow(
                        task: {
                            let t = CareTask(title: "Refresh water bowl", description: "Wash fountain.")
                            t.status = .completed
                            return t
                        }(),
                        onTap: {},
                        onComplete: {},
                        onDelete: {}
                    )
                }
            }
        }
        .padding()
    }
    .background(Theme.backgroundGrouped)
}
#endif
