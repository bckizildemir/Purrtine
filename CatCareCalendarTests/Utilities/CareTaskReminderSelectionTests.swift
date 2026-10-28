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
    func theNudgeFiresADayBeforeTheLastReminderWhenTheLimitCutTheSet() throws {
        let now = start.addingTimeInterval(-1_000)
        let selected = (0..<3).map { makeCandidate("c\($0)", minute: 2_000 + $0) }

        let date = try #require(nudgeDate(selected: selected, candidateCount: 5, now: now))

        #expect(date == selected[2].fireDate.addingTimeInterval(-86_400))
    }

    @Test
    func aSeriesCutByItsOwnCapGetsANudgeEvenWhenTheSetIsNotFull() throws {
        let selected = (0..<3).map { makeCandidate("c\($0)", minute: 5_000 + $0) }
        let capEnd = minutes(3_000)

        let date = try #require(nudgeDate(selected: selected, candidateCount: 3, capEnds: [capEnd]))

        #expect(date == capEnd.addingTimeInterval(-86_400))
    }

    @Test
    func theEarliestCutEndWinsOverTheLastSelectedReminderAndOtherCappedSeries() throws {
        let selected = (0..<3).map { makeCandidate("c\($0)", minute: 9_000 + $0) }

        let date = try #require(
            nudgeDate(selected: selected, candidateCount: 8, capEnds: [minutes(6_000), minutes(4_000)])
        )

        #expect(date == minutes(4_000).addingTimeInterval(-86_400))
    }

    @Test
    func aLastSelectedReminderBeforeEveryCappedEndWinsWhenTheLimitCutTheSet() throws {
        let selected = (0..<3).map { makeCandidate("c\($0)", minute: 3_000 + $0) }

        let date = try #require(nudgeDate(selected: selected, candidateCount: 4, capEnds: [minutes(9_000)]))

        #expect(date == selected[2].fireDate.addingTimeInterval(-86_400))
    }

    @Test
    func theNudgeFiresAtTheMidpointWhenTwentyFourHoursBeforeTheEndHasPassed() throws {
        // The earliest end is 12 hours out, so "24 hours before" is past: fire 6 hours from now.
        let selected = (0..<3).map { makeCandidate("c\($0)", minute: 720) }

        let date = try #require(nudgeDate(selected: selected, candidateCount: 4))

        #expect(date == start.addingTimeInterval(6 * 3_600))
    }

    @Test
    func theMidpointUsesTheEarliestCappedEnd() throws {
        let selected = (0..<3).map { makeCandidate("c\($0)", minute: 5_000 + $0) }

        let date = try #require(nudgeDate(selected: selected, candidateCount: 3, capEnds: [minutes(600)]))

        #expect(date == minutes(300))
    }

    @Test
    func noNudgeWhenNothingWasCut() {
        let selected = (0..<3).map { makeCandidate("c\($0)", minute: 5_000 + $0) }

        #expect(nudgeDate(selected: selected, candidateCount: 3) == nil)
        #expect(nudgeDate(selected: [], candidateCount: 0) == nil)
    }

    @Test
    func noNudgeWhenTheEarliestEndIsNotAfterNow() {
        let selected = (0..<3).map { makeCandidate("c\($0)", minute: 0) }

        #expect(nudgeDate(selected: selected, candidateCount: 4) == nil)
        #expect(nudgeDate(selected: selected, candidateCount: 4, now: minutes(10)) == nil)
    }

    private func minutes(_ minute: Int) -> Date {
        start.addingTimeInterval(TimeInterval(minute * 60))
    }

    private func nudgeDate(
        selected: [CareTaskReminderCandidate],
        candidateCount: Int,
        capEnds: [Date] = [],
        now: Date? = nil
    ) -> Date? {
        CareTaskReminderSelection.nudgeFireDate(
            selected: selected,
            candidateCount: candidateCount,
            cappedSeriesEnds: capEnds,
            now: now ?? start
        )
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
