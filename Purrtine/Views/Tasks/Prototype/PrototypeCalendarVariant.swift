#if DEBUG
import SwiftUI

// PROTOTYPE (throwaway): calendar look variants for the Tasks calendar mode. Delete with the branch.

enum PrototypeCalendarVariant: String, CaseIterable {
    case uiCalendar = "A"
    case calendarApp = "B"
    case current = "C"

    var label: String {
        switch self {
        case .uiCalendar: "A  UICalendarView"
        case .calendarApp: "B  Calendar-app style"
        case .current: "C  Current"
        }
    }

    func next(by step: Int) -> PrototypeCalendarVariant {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        return all[(index + step + all.count) % all.count]
    }
}

/// PROTOTYPE: holds the active variant; read from `-calendarVariant A|B|C`, default A.
@MainActor
@Observable
final class PrototypeCalendarVariantModel {
    static let shared = PrototypeCalendarVariantModel()

    var variant: PrototypeCalendarVariant

    private init() {
        let raw = AppLaunchConfiguration.current.value(for: "-calendarVariant")
        variant = raw.flatMap(PrototypeCalendarVariant.init(rawValue:)) ?? .uiCalendar
    }
}
#endif
