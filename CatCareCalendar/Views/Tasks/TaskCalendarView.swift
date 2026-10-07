import SwiftUI
import SwiftData

struct TaskCalendarView: View {
    let tasks: [CareTask]
    @Binding var selectedDate: Date
    let viewModel: TaskManagementViewModel
    
    @State private var currentMonth: Date = Date()
    @State private var showingWeekView: Bool = false
    
    // Calendar helpers
    private let calendar = Calendar.current

    // Task grouping by date - includes both pending and completed tasks.
    // Computed once per body render (below) and threaded into the grid/panel, instead of being
    // recomputed inside every calendar cell and each panel access.
    private var currentTasksByDate: [Date: [CareTask]] {
        let relevantDates = showingWeekView ? weekDates : monthDates
        return TaskCalendarDerivation.tasksByDate(from: tasks, in: relevantDates, calendar: calendar)
    }

    // Check if a task has been completed for a specific date
    private func hasCompletionForDate(_ task: CareTask, date: Date) -> Bool {
        TaskCalendarDerivation.hasCompletion(for: task, on: date, calendar: calendar)
    }

    var body: some View {
        let tasksByDate = currentTasksByDate
        return VStack(spacing: 0) {
            calendarHeader

            if showingWeekView {
                weekView(tasksByDate: tasksByDate)
            } else {
                monthView(tasksByDate: tasksByDate)
            }
            Spacer()
            Divider()
                .background(Color(.systemFill))
                .padding(.horizontal, 12)

            if tasks.isEmpty {
                emptyStateView
            } else {
                selectedDateTasks(tasksByDate: tasksByDate)
            }
        }
    }
    
    // MARK: - Calendar Header
    @ViewBuilder
    private var calendarHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text(currentMonth.formatted(
                        .verbatim("\(month: .wide) \(year: .defaultDigits)", locale: .current, timeZone: .current, calendar: calendar)
                    ))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(String(localized: .taskCalendarMonthTotal(Int32(tasksForCurrentMonth.count))))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                }
            }
            
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingWeekView = false
                    }
                } label: {
                    Text(.taskCalendarTabMonth)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(showingWeekView ? Color.secondary : Color.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(showingWeekView ? Color.clear : Color.blue)
                        )
                }
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingWeekView = true
                    }
                } label: {
                    Text(.taskCalendarTabWeek)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(showingWeekView ? Color.white : Color.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(showingWeekView ? Color.blue : Color.clear)
                        )
                }
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentMonth = Date()
                        selectedDate = Date()
                    }
                } label: {
                    Text(.generalToday)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                }
            }
        }
        .padding()
    }
    
    // MARK: - Month View
    @ViewBuilder
    private func monthView(tasksByDate: [Date: [CareTask]]) -> some View {
        VStack(spacing: 0) {
            // Days of week header
            HStack {
                ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(monthDates, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        tasksForDate: TaskCalendarDerivation.tasksForDate(date, in: tasksByDate, calendar: calendar),
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                        isToday: calendar.isDateInToday(date)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Week View
    @ViewBuilder
    private func weekView(tasksByDate: [Date: [CareTask]]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(weekDates, id: \.self) { date in
                    CalendarWeekCell(
                        date: date,
                        tasksForDate: TaskCalendarDerivation.tasksForDate(date, in: tasksByDate, calendar: calendar),
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Empty State View
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text(.tasksNoTasksFound)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(.tasksNoTasksFilterDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .padding(.bottom, floatingTabBarClearance)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16, corners: [.topLeft, .topRight])
    }
    
    // MARK: - Selected Date Tasks
    @ViewBuilder
    private func selectedDateTasks(tasksByDate: [Date: [CareTask]]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedDate.formatted(date: .complete, time: .omitted))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let tasksForDay = tasksByDate[calendar.startOfDay(for: selectedDate)] {
                        Text(String(localized: .taskCalendarDayTaskCount(Int32(tasksForDay.count))))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(.taskCalendarNoTasks)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            if let tasksForDay = tasksByDate[calendar.startOfDay(for: selectedDate)], !tasksForDay.isEmpty {
                selectedDateTasksList(for: tasksForDay)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)

                    Text(.taskCalendarNoTasksDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .padding(.bottom, floatingTabBarClearance)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16, corners: [.topLeft, .topRight])
    }

    /// Keeps the last row reachable above the iOS 26 floating tab bar while
    /// letting the panel background itself extend to the screen edge.
    private var floatingTabBarClearance: CGFloat {
        if #available(iOS 26.0, *) {
            return 128
        }
        return 0
    }

    @ViewBuilder
    private func selectedDateTasksList(for tasksForDay: [CareTask]) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 8) {
                selectedDateTasksStack(for: tasksForDay)
            }
        } else {
            selectedDateTasksStack(for: tasksForDay)
        }
    }

    private func selectedDateTasksStack(for tasksForDay: [CareTask]) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(tasksForDay.sorted { ($0.nextDueDate ?? Date()) < ($1.nextDueDate ?? Date()) }) { task in
                TaskRow(
                    task: task
                ) {
                    viewModel.presentTaskEdit(task)
                } onComplete: {
                    handleTaskCompletion(task)
                } onDelete: {
                    deleteTask(task)
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Helper Methods
    private func handleTaskCompletion(_ task: CareTask) {
        guard hasCompletionForDate(task, date: selectedDate) == false else { return }

        if task.assignedCats.count > 1 {
            // For multi-cat tasks, show completion sheet
            viewModel.presentTaskCompletion(task, completedForDate: selectedDate)
        } else {
            // Complete directly for single cat or no specific cat
            let cats = task.assignedCats.first.map { [$0] } ?? []
            viewModel.completeCareTask(task, for: cats, by: nil, completedForDate: selectedDate)
        }
    }
    
    private func deleteTask(_ task: CareTask) {
        withAnimation {
            _ = viewModel.deleteCareTask(task)
        }
    }
    
    // MARK: - Computed Properties
    private var monthDates: [Date] {
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let startOfCalendar = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
        
        var dates: [Date] = []
        var date = startOfCalendar
        
        for _ in 0..<42 { // 6 weeks * 7 days
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        
        return dates
    }
    
    private var weekDates: [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        var dates: [Date] = []
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    private var tasksForCurrentMonth: [CareTask] {
        let monthStart = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let monthEnd = calendar.dateInterval(of: .month, for: currentMonth)?.end ?? currentMonth

        // Create a range of dates for the entire month
        var monthDates: [Date] = []
        var date = monthStart
        while date < monthEnd {
            monthDates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }

        // Find tasks that have occurrences in this month
        var tasksInMonth: Set<CareTask> = []
        let derivedTasksByDate = TaskCalendarDerivation.tasksByDate(from: tasks, in: monthDates, calendar: calendar)
        for tasksForDate in derivedTasksByDate.values {
            for task in tasksForDate {
                tasksInMonth.insert(task)
            }
        }

        return Array(tasksInMonth)
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let date: Date
    let tasksForDate: (pending: [CareTask], completed: [CareTask])
    let isSelected: Bool
    let isCurrentMonth: Bool
    let isToday: Bool
    let onTap: () -> Void

    var tasks: [CareTask] {
        tasksForDate.pending + tasksForDate.completed
    }
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(verbatim: "\(calendar.component(.day, from: date))")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(textColor)
                
                if !tasks.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(Array(tasks.prefix(3).enumerated()), id: \.offset) { index, task in
                            Circle()
                                .fill(colorForTask(task))
                                .frame(width: 4, height: 4)
                        }
                        
                        if tasks.count > 3 {
                            Text(verbatim: "+\(tasks.count - 3)")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isCurrentMonth {
            return .primary
        } else {
            return .gray.opacity(0.5)
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue
        } else if isToday {
            return .blue.opacity(0.2)
        } else {
            return .clear
        }
    }

    private func colorForTask(_ task: CareTask) -> Color {
        // Show completed tasks in gray
        if tasksForDate.completed.contains(task) {
            return .gray
        }

        switch task.priority {
        case .urgent:
            return .red
        case .high:
            return .orange
        case .medium:
            return .blue
        case .low:
            return .green
        }
    }
}

// MARK: - Calendar Week Cell
struct CalendarWeekCell: View {
    let date: Date
    let tasksForDate: (pending: [CareTask], completed: [CareTask])
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    var tasks: [CareTask] {
        tasksForDate.pending + tasksForDate.completed
    }
    
    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(date.formatted(
                    .verbatim("\(weekday: .abbreviated)", locale: .current, timeZone: .current, calendar: calendar)
                ))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                
                Text(verbatim: "\(calendar.component(.day, from: date))")
                    .font(.title2)
                    .fontWeight(isToday ? .bold : .semibold)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                
                VStack(spacing: 2) {
                    ForEach(Array(tasks.prefix(2).enumerated()), id: \.offset) { index, task in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorForTask(task))
                            .frame(width: 30, height: 3)
                    }
                    
                    if tasks.count > 2 {
                        Text(verbatim: "+\(tasks.count - 2)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                .frame(height: 20)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue.opacity(0.8)
        } else if isToday {
            return .blue.opacity(0.2)
        } else {
            return Color(.systemFill)
        }
    }

    private func colorForTask(_ task: CareTask) -> Color {
        // Show completed tasks in gray
        if tasksForDate.completed.contains(task) {
            return .gray
        }

        switch task.priority {
        case .urgent:
            return .red
        case .high:
            return .orange
        case .medium:
            return .blue
        case .low:
            return .green
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

nonisolated struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#if DEBUG
#Preview {
    PreviewHost(scenario: .standard) {
        TaskCalendarView(
            tasks: PreviewData.firstTask().map { [$0] } ?? [],
            selectedDate: .constant(Date()),
            viewModel: TaskManagementViewModel()
        )
    }
} 
#endif
