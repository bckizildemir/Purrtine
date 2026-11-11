#if DEBUG
import SwiftUI
import UIKit

// PROTOTYPE (throwaway): variant A, Apple's native UICalendarView with category-colored dots.

struct PrototypeUICalendarView: UIViewRepresentable {
    let tasks: [CareTask]
    @Binding var selectedDate: Date

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        view.calendar = calendar
        view.locale = .current
        view.fontDesign = .rounded
        view.delegate = context.coordinator
        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.setSelected(calendar.dateComponents([.year, .month, .day], from: selectedDate), animated: false)
        view.selectionBehavior = selection
        context.coordinator.selection = selection
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    func updateUIView(_ view: UICalendarView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        let components = view.calendar.dateComponents([.year, .month, .day], from: selectedDate)
        if coordinator.selection?.selectedDate != components {
            coordinator.selection?.setSelected(components, animated: true)
        }

        let signature = coordinator.signature(for: tasks)
        if signature != coordinator.lastSignature {
            coordinator.lastSignature = signature
            coordinator.dotCache = [:]
            let visible = view.visibleDateComponents
            let days = coordinator.dayComponents(inMonthOf: visible, calendar: view.calendar)
            view.reloadDecorations(forDateComponents: days, animated: false)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UICalendarView, context: Context) -> CGSize? {
        let width = proposal.width ?? 360
        let fitted = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        // The natural fit is ~480 pt; 6-week months need ~400 so the panel below keeps room.
        return CGSize(width: width, height: min(fitted.height, 400))
    }

    @MainActor
    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: PrototypeUICalendarView
        var selection: UICalendarSelectionSingleDate?
        var lastSignature = 0
        /// Dot colors per start-of-day, cached for the months the calendar has asked about.
        var dotCache: [Date: [UIColor]] = [:]
        private var cachedMonths: Set<DateComponents> = []

        init(parent: PrototypeUICalendarView) {
            self.parent = parent
        }

        func signature(for tasks: [CareTask]) -> Int {
            var hasher = Hasher()
            for task in tasks where task.isDeleted == false && task.modelContext != nil {
                hasher.combine(task.id)
                hasher.combine(task.completions.count)
                hasher.combine(task.schedules.count)
                hasher.combine(task.status)
            }
            return hasher.finalize()
        }

        func dayComponents(inMonthOf visible: DateComponents, calendar: Calendar) -> [DateComponents] {
            guard let date = calendar.date(from: visible),
                  let range = calendar.range(of: .day, in: .month, for: date) else { return [] }
            return range.map { DateComponents(calendar: calendar, year: visible.year, month: visible.month, day: $0) }
        }

        private func colors(for components: DateComponents, calendar: Calendar) -> [UIColor] {
            guard let date = calendar.date(from: components) else { return [] }
            let day = calendar.startOfDay(for: date)
            let monthKey = DateComponents(year: components.year, month: components.month)
            if cachedMonths.contains(monthKey) == false {
                cachedMonths.insert(monthKey)
                let monthDates = dayComponents(inMonthOf: monthKey, calendar: calendar)
                    .compactMap { calendar.date(from: $0) }
                let byDate = TaskCalendarDerivation.tasksByDate(from: parent.tasks, in: monthDates, calendar: calendar)
                for (key, tasks) in byDate {
                    dotCache[key] = tasks.prefix(3).map { UIColor($0.category.prototypeTint) }
                }
            }
            return dotCache[day] ?? []
        }

        func calendarView(
            _ calendarView: UICalendarView,
            decorationFor dateComponents: DateComponents
        ) -> UICalendarView.Decoration? {
            if signature(for: parent.tasks) != lastSignature {
                lastSignature = signature(for: parent.tasks)
                dotCache = [:]
                cachedMonths = []
            }
            let dotColors = colors(for: dateComponents, calendar: calendarView.calendar)
            guard dotColors.isEmpty == false else { return nil }
            return .customView {
                let size: CGFloat = 6
                let gap: CGFloat = 2
                let width = CGFloat(dotColors.count) * size + CGFloat(dotColors.count - 1) * gap
                let stack = UIView(frame: CGRect(x: 0, y: 0, width: width, height: size))
                for (index, color) in dotColors.enumerated() {
                    let dot = UIView(frame: CGRect(x: CGFloat(index) * (size + gap), y: 0, width: size, height: size))
                    dot.backgroundColor = color
                    dot.layer.cornerRadius = size / 2
                    stack.addSubview(dot)
                }
                return stack
            }
        }

        func calendarView(
            _ calendarView: UICalendarView,
            didChangeVisibleDateComponentsFrom previousDateComponents: DateComponents
        ) {}

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents, let date = parent.calendarDate(from: dateComponents) else { return }
            parent.selectedDate = date
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool {
            true
        }
    }

    fileprivate func calendarDate(from components: DateComponents) -> Date? {
        Calendar(identifier: .gregorian).date(from: components)
    }
}
#endif
