import Foundation

extension NotificationScheduleInfo {
    /// The one place a schedule is projected into the value `NotificationManager` schedules from.
    /// Every caller that resyncs reminders needs the same fifteen fields, and each hand-rolled copy
    /// was a chance for one of them to drift — a stale `taskTitle` or a dropped `reminderMinutes`
    /// shows up as a wrong reminder rather than as a compile error.
    init(task: CareTask, schedule: CareTaskSchedule) {
        self.init(
            scheduleId: schedule.id,
            taskId: task.id,
            taskTitle: task.title,
            taskDescription: task.taskDescription,
            catNames: task.assignedCatNames,
            category: task.category,
            iconName: task.iconName,
            priority: task.priority,
            scheduledDate: schedule.scheduledDate,
            scheduledTime: schedule.scheduledTime,
            frequency: schedule.frequency,
            frequencyInterval: schedule.frequencyInterval,
            endDate: schedule.endDate,
            customDays: schedule.customDays,
            reminderMinutes: schedule.reminderMinutes
        )
    }

    /// The active schedules of `task`, projected in the order `activeSchedules` returns them.
    static func activeInfos(for task: CareTask) -> [NotificationScheduleInfo] {
        task.activeSchedules.map { NotificationScheduleInfo(task: task, schedule: $0) }
    }

    /// A one-off reminder for `task` that fires at `fireDate`. A snooze belongs to no stored
    /// schedule, so it gets a fresh `scheduleId` and repeats nowhere.
    init(snoozing task: CareTask, firingAt fireDate: Date) {
        self.init(
            scheduleId: UUID(),
            taskId: task.id,
            taskTitle: task.title,
            taskDescription: task.taskDescription,
            catNames: task.assignedCatNames,
            category: task.category,
            iconName: task.iconName,
            priority: task.priority,
            scheduledDate: fireDate,
            scheduledTime: nil,
            frequency: .once,
            frequencyInterval: 1,
            endDate: nil,
            customDays: nil,
            reminderMinutes: 0
        )
    }
}
