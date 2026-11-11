#if DEBUG
import SwiftData
import Foundation

// PROTOTYPE (throwaway): `-prototypeSeed` inserts two cats and a handful of tasks when the store has no cats,
// and marks onboarding done, so the calendar prototypes have something to show on a fresh simulator.

@MainActor
enum PrototypeSeed {
    static func seedIfRequested(in context: ModelContext, configuration: AppLaunchConfiguration) {
        guard configuration.hasArgument("-prototypeSeed") else { return }
        OnboardingManager.shared.completeOnboarding()

        let existing = (try? context.fetch(FetchDescriptor<Cat>())) ?? []
        guard existing.isEmpty else { return }

        let calendar = Calendar.current
        let caregivers = (try? context.fetch(FetchDescriptor<Caregiver>())) ?? []
        let caregiver = caregivers.first(where: \.isPrimary) ?? caregivers.first

        let luna = Cat(name: "Luna", age: 36, gender: .female)
        let pamuk = Cat(name: "Pamuk", age: 60, gender: .male)
        context.insert(luna)
        context.insert(pamuk)

        func day(_ offset: Int, hour: Int = 9) -> Date {
            let start = calendar.startOfDay(for: Date())
            let shifted = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return calendar.date(byAdding: .hour, value: hour, to: shifted) ?? shifted
        }

        func add(
            _ title: String,
            _ category: CareTaskCategory,
            cats: [Cat],
            start: Date,
            frequency: CareTaskFrequency,
            priority: CareTaskPriority = .medium,
            completedOffsets: [Int] = [],
            isDone: Bool = false
        ) {
            let task = CareTask(
                title: title,
                category: category,
                iconName: category.iconName,
                priority: priority,
                status: isDone ? .completed : .pending
            )
            let schedule = CareTaskSchedule(scheduledDate: start, frequency: frequency, reminderMinutes: 15)
            schedule.task = task
            task.schedules = [schedule]
            task.assignedCats = cats
            task.assignedCaregiver = caregiver
            context.insert(task)
            context.insert(schedule)
            for offset in completedOffsets {
                let completion = CareTaskCompletion(completedAt: day(offset), completedForDate: day(offset))
                completion.task = task
                completion.cats = cats
                completion.caregiver = caregiver
                task.completions.append(completion)
                context.insert(completion)
            }
        }

        add("Morning feeding", .feeding, cats: [luna], start: day(-14), frequency: .weekly,
            completedOffsets: [-7, -1])
        add("Fresh water", .water, cats: [luna, pamuk], start: day(2), frequency: .weekly)
        add("Brush coat", .grooming, cats: [luna], start: day(-3), frequency: .weekly, completedOffsets: [-3])
        add("Flea medication", .medication, cats: [pamuk], start: day(3), frequency: .once, priority: .high)
        add("Litter deep clean", .litter, cats: [pamuk], start: day(3, hour: 18), frequency: .once)
        add("Play session", .exercise, cats: [luna, pamuk], start: day(1, hour: 19), frequency: .once)
        add("Vet check-up", .vet, cats: [pamuk], start: day(9, hour: 11), frequency: .once, priority: .urgent)
        add("Weigh Luna", .health, cats: [luna], start: day(-2), frequency: .once,
            completedOffsets: [-2], isDone: true)

        do {
            try context.save()
            print("[PrototypeSeed] seeded 2 cats and 8 tasks")
        } catch {
            print("[PrototypeSeed] save failed: \(error)")
        }
    }
}
#endif
