import SwiftUI

// MARK: - CareTask Management Enums
enum CareTaskViewMode: String, CaseIterable {
    case list = "list"
    case calendar = "calendar"
    
    var displayName: String {
        switch self {
        case .list: return String(localized: .settingsTaskViewList)
        case .calendar: return String(localized: .settingsTaskViewCalendar)
        }
    }
    
    var iconName: String {
        switch self {
        case .list: return "list.bullet"
        case .calendar: return "calendar"
        }
    }
}

enum CareTaskFilter: String, CaseIterable {
    case all = "all"
    case overdue = "overdue"
    case today = "today"
    case upcoming = "upcoming"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .all: return String(localized: .tasksFilterAll)
        case .overdue: return String(localized: .tasksFilterOverdue)
        case .today: return String(localized: .tasksFilterToday)
        case .upcoming: return String(localized: .tasksFilterUpcoming)
        case .completed: return String(localized: .tasksFilterCompleted)
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .blue
        case .overdue: return .red
        case .today: return .orange
        case .upcoming: return .green
        case .completed: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "tray.fill"
        case .overdue: return "exclamationmark.circle.fill"
        case .today: return "calendar.circle.fill"
        case .upcoming: return "calendar.badge.clock"
        case .completed: return "checkmark.circle.fill"
        }
    }
} 
