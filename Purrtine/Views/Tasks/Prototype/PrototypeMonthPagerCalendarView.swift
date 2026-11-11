#if DEBUG
import SwiftUI

// PROTOTYPE (throwaway): variant B, a SwiftUI imitation of the iOS 26 Calendar app month grid.

struct PrototypeMonthPagerCalendarView: View {
    private static let monthRange = -24...24

    let tasks: [CareTask]
    @Binding var selectedDate: Date

    @State private var pageOffset: Int? = 0

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(month(for: pageOffset ?? 0).formatted(.dateTime.month(.wide).year()))
                    .font(.largeTitle.bold())
                    .contentTransition(.numericText())
                Spacer()
                Button("Today") {
                    selectedDate = Date()
                    withAnimation { pageOffset = 0 }
                }
                .font(.subheadline)
            }
            .padding(.horizontal)

            PrototypeWeekdayHeader()
                .padding(.horizontal)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Self.monthRange, id: \.self) { offset in
                        PrototypeMonthPage(
                            month: month(for: offset),
                            tasks: tasks,
                            selectedDate: $selectedDate
                        )
                        .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $pageOffset)
        }
        .padding(.vertical)
    }

    private func month(for offset: Int) -> Date {
        let startOfThisMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        return calendar.date(byAdding: .month, value: offset, to: startOfThisMonth) ?? startOfThisMonth
    }
}

private struct PrototypeWeekdayHeader: View {
    private let calendar = Calendar.current

    var body: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        HStack(spacing: 0) {
            ForEach(ordered.indices, id: \.self) { index in
                Text(ordered[index])
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct PrototypeMonthPage: View {
    let month: Date
    let tasks: [CareTask]
    @Binding var selectedDate: Date

    private let calendar = Calendar.current

    var body: some View {
        let cells = monthCells()
        let byDate = TaskCalendarDerivation.tasksByDate(from: tasks, in: cells.compactMap { $0 }, calendar: calendar)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(cells.indices, id: \.self) { index in
                if let date = cells[index] {
                    PrototypeDayCell(
                        date: date,
                        categories: dotCategories(on: date, in: byDate),
                        isToday: calendar.isDateInToday(date),
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                    ) {
                        selectedDate = date
                    }
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
        .padding(.horizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .frame(height: 6 * 50)
    }

    private func dotCategories(on date: Date, in byDate: [Date: [CareTask]]) -> [CareTaskCategory] {
        (byDate[calendar.startOfDay(for: date)] ?? []).prefix(3).map(\.category)
    }

    /// Leading blanks, then every day of the month.
    private func monthCells() -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let days = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: interval.start)
        let blanks = (weekday - calendar.firstWeekday + 7) % 7
        let dates = days.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }
        return Array(repeating: nil, count: blanks) + dates.map(Optional.some)
    }
}

private struct PrototypeDayCell: View {
    let date: Date
    let categories: [CareTaskCategory]
    let isToday: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                Text(date.formatted(.dateTime.day()))
                    .font(.title3)
                    .foregroundStyle(numberStyle)
                    .frame(width: 34, height: 34)
                    .background(circleStyle, in: .circle)
                HStack(spacing: 3) {
                    ForEach(categories.indices, id: \.self) { index in
                        Circle()
                            .fill(categories[index].prototypeTint)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var numberStyle: Color {
        if isToday { return .white }
        return isSelected ? Color(.systemBackground) : .primary
    }

    private var circleStyle: Color {
        if isToday { return .red }
        if isSelected { return Color(.label) }
        return .clear
    }
}
#endif
