import Foundation
import Testing
@testable import CatCareCalendar

@MainActor
struct CareTaskReminderSelectionTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func keepsTheSixtySoonestCandidatesAcrossTasks() {
        // Three tasks, 30 candidates each, one minute apart and interleaved: 90 in all, handed over
        // latest first so the input order cannot be the answer.
        let taskIds = [UUID(), UUID(), UUID()]
        var candidates: [CareTaskReminderCandidate] = []
        for minute in 0..<90 {
            candidates.append(makeCandidate("m\(minute)", taskId: taskIds[minute % 3], minute: minute))
        }

        let selected = CareTaskReminderSelection.soonest(candidates.reversed())

        #expect(selected.count == 59)
        #expect(selected.first?.identifier == "m0")
        #expect(selected.last?.identifier == "m58")
        #expect(Set(selected.map(\.identifier)).contains("m59") == false)
        #expect(Set(selected.map(\.info.taskId)) == Set(taskIds))
    }

    @Test
    func overdueCandidatesCompeteForTheSameSlots() {
        var candidates = (0..<59).map { makeCandidate("due\($0)", minute: 10 + $0) }
        candidates.append(makeCandidate("early_overdue", minute: 5, isOverdue: true))
        candidates.append(makeCandidate("late_overdue", minute: 500, isOverdue: true))

        let selected = CareTaskReminderSelection.soonest(candidates)

        #expect(selected.count == 59)
        #expect(selected.first?.identifier == "early_overdue")
        #expect(selected.contains { $0.identifier == "late_overdue" } == false)
        #expect(selected.last?.identifier == "due57")
    }

    @Test
    func tiesBreakByIdentifierWhateverTheInputOrder() {
        let tied = [
            makeCandidate("b", minute: 1),
            makeCandidate("c", minute: 1),
            makeCandidate("a", minute: 1)
        ]

        let forward = CareTaskReminderSelection.soonest(tied, limit: 2)
        let backward = CareTaskReminderSelection.soonest(tied.reversed(), limit: 2)

        #expect(forward.map(\.identifier) == ["a", "b"])
        #expect(backward.map(\.identifier) == ["a", "b"])
    }

    @Test
    func fewerCandidatesThanTheLimitAreAllKept() {
        let candidates = [makeCandidate("late", minute: 9), makeCandidate("early", minute: 2)]

        let selected = CareTaskReminderSelection.soonest(candidates)

        #expect(selected.map(\.identifier) == ["early", "late"])
    }

    @Test
    func theDefaultLimitLeavesOneNudgeSlotAndFourSnoozeSlotsOfTheSixtyFour() {
        #expect(CareTaskReminderSelection.limit == 59)
        #expect(CareTaskReminderSelection.limit + 1 + 4 == 64)
    }

    @Test
    func theNudgeFiresADayBeforeTheLastReminderOfAFullSelection() throws {
        let now = start.addingTimeInterval(-1_000)
        let selected = (0..<3).map { makeCandidate("c\($0)", minute: 2_000 + $0) }

        let date = try #require(CareTaskReminderSelection.nudgeFireDate(selected: selected, now: now, limit: 3))

        #expect(date == selected[2].fireDate.addingTimeInterval(-86_400))
    }

    @Test
    func aSelectionShorterThanTheLimitGetsNoNudge() {
        let selected = (0..<2).map { makeCandidate("c\($0)", minute: 5_000 + $0) }

        #expect(CareTaskReminderSelection.nudgeFireDate(selected: selected, now: start, limit: 3) == nil)
    }

    @Test
    func noNudgeWhenTwentyFourHoursBeforeTheLastReminderHasPassed() {
        // The last reminder is 12 hours out, so "24 hours before" is already past.
        let selected = (0..<3).map { makeCandidate("c\($0)", minute: 720 + $0) }

        #expect(CareTaskReminderSelection.nudgeFireDate(selected: selected, now: start, limit: 3) == nil)
    }

    @Test
    func noNudgeWhenTheLastReminderIsWithinTheNextMinute() {
        let selected = (0..<3).map { _ in makeCandidate("c", minute: 0) }

        #expect(CareTaskReminderSelection.nudgeFireDate(selected: selected, now: start, limit: 3) == nil)
    }

    private func makeCandidate(
        _ identifier: String,
        taskId: UUID = UUID(),
        minute: Int,
        isOverdue: Bool = false
    ) -> CareTaskReminderCandidate {
        CareTaskReminderCandidate(
            identifier: identifier,
            fireDate: start.addingTimeInterval(TimeInterval(minute * 60)),
            info: NotificationScheduleInfo(
                scheduleId: UUID(),
                taskId: taskId,
                taskTitle: identifier,
                taskDescription: nil,
                catNames: "Mochi",
                category: .feeding,
                iconName: "fork.knife",
                priority: .medium,
                scheduledDate: start,
                scheduledTime: nil,
                frequency: .daily,
                frequencyInterval: 1,
                endDate: nil,
                customDays: nil,
                reminderMinutes: 0
            ),
            isOverdue: isOverdue
        )
    }
}
