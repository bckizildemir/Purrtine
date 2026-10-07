#if DEBUG
import Foundation
import SwiftData

// MARK: - Debug Data Service
/// Provides sample data creation utilities for development and previews
///
/// Each method commits its change, then waits for `taskWriter` to resync the tasks it touched, so
/// when it returns their reminders match the store, as after every `CareTaskWriting` verb.
enum DebugDataService {
    // MARK: - Create Sample Data
    static func createSampleData(
        in context: ModelContext,
        taskWriter: any CareTaskWriting
    ) async {
        // Check if data already exists
        let catDescriptor = FetchDescriptor<Cat>()
        let existingCats = try? context.fetch(catDescriptor)
        
        if let cats = existingCats, !cats.isEmpty {
            print("Sample data already exists")
            return
        }
        
        // Create default caregiver if none exists
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)
        
        // Create sample cats
        let sampleCats = createSampleCats()
        for cat in sampleCats {
            context.insert(cat)
        }
        
        // Create sample tasks
        let sampleTasks = createSampleTasks(for: sampleCats)
        for task in sampleTasks {
            context.insert(task)
            
            // Add schedules
            for schedule in task.schedules {
                context.insert(schedule)
            }
        }
        
        guard commit(context) else { return }
        await refreshReminders(for: sampleTasks.map(\.id), in: context, with: taskWriter)
        print("Sample data created successfully!")
    }
    
    // MARK: - Clear Sample Data
    static func clearSampleData(
        in context: ModelContext,
        taskWriter: any CareTaskWriting
    ) async {
        // Delete all tasks
        let taskDescriptor = FetchDescriptor<CareTask>()
        var deletedTaskIds: [UUID] = []
        if let tasks = try? context.fetch(taskDescriptor) {
            deletedTaskIds = tasks.map(\.id)
            for task in tasks {
                context.delete(task)
            }
        }
        
        // Delete all cats
        let catDescriptor = FetchDescriptor<Cat>()
        if let cats = try? context.fetch(catDescriptor) {
            for cat in cats {
                context.delete(cat)
            }
        }
        
        guard commit(context) else { return }
        // A task that is gone from the store has its reminders cancelled.
        await refreshReminders(for: deletedTaskIds, in: context, with: taskWriter)
        print("Sample data cleared")
    }
    
    // MARK: - Create Overdue Tasks
    static func createOverdueTasks(
        in context: ModelContext,
        taskWriter: any CareTaskWriting
    ) async {
        let calendar = Calendar.current
        let now = Date()
        
        // Create an overdue task
        let overdueTask = CareTask(
            title: "Gecikmiş İlaç",
            description: "Bu görev gecikmiş durumda",
            category: .medication,
            iconName: "pills.fill",
            priority: .urgent,
            status: .overdue
        )
        
        let overdueTime = calendar.date(byAdding: .hour, value: -2, to: now) ?? now
        let overdueSchedule = CareTaskSchedule(
            scheduledDate: overdueTime,
            scheduledTime: overdueTime,
            frequency: .once,
            reminderMinutes: 15
        )
        overdueSchedule.task = overdueTask
        overdueTask.schedules.append(overdueSchedule)
        
        context.insert(overdueTask)
        context.insert(overdueSchedule)
        
        guard commit(context) else { return }
        await refreshReminders(for: [overdueTask.id], in: context, with: taskWriter)
        print("Overdue task created for testing")
    }

    // MARK: - Reminders

    /// Reminders are only resynced after a commit that landed.
    private static func commit(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            print("❌ Failed to save debug data: \(error.localizedDescription)")
            return false
        }
    }

    /// Runs once the commit has landed. A failure leaves the debug data in place.
    private static func refreshReminders(
        for taskIds: [UUID],
        in context: ModelContext,
        with taskWriter: any CareTaskWriting
    ) async {
        do {
            try await taskWriter.refreshReminders(for: taskIds, in: context)
        } catch is CancellationError {
            // The debug data stands; its reminders stay stale until a task is next written.
        } catch {
            print("❌ Failed to resync reminders for debug data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    private static func createSampleCats() -> [Cat] {
        return [
            Cat(
                name: "Luna",
                age: 36, // 3 years in months
                gender: .female,
                breed: "Scottish Fold",
                weight: 4.2,
                medicalNotes: "Gri renkli, çok sevimli bir kedi"
            ),
            Cat(
                name: "Simba",
                age: 24, // 2 years in months
                gender: .male,
                breed: "Maine Coon",
                weight: 6.8,
                medicalNotes: "Turuncu renkli, çok enerjik"
            ),
            Cat(
                name: "Bella",
                age: 48, // 4 years in months
                gender: .female,
                breed: "British Shorthair",
                weight: 5.1,
                medicalNotes: "Siyah renkli, çok sakin"
            )
        ]
    }
    
    private static func createSampleTasks(for cats: [Cat]) -> [CareTask] {
        var tasks: [CareTask] = []
        let calendar = Calendar.current
        let now = Date()
        
        // Morning feeding task
        let morningFeeding = CareTask(
            title: "Sabah Yemeği",
            description: "Kedilerin sabah yemeğini ver",
            category: .feeding,
            iconName: "sun.and.horizon.fill",
            priority: .high
        )
        morningFeeding.assignedCats = cats
        
        // Create morning schedule (daily at 8 AM)
        let morningTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
        let morningSchedule = CareTaskSchedule(
            scheduledDate: morningTime,
            scheduledTime: morningTime,
            frequency: .daily,
            reminderMinutes: 15
        )
        morningSchedule.task = morningFeeding
        morningFeeding.schedules.append(morningSchedule)
        
        tasks.append(morningFeeding)
        
        // Evening feeding task
        let eveningFeeding = CareTask(
            title: "Akşam Yemeği",
            description: "Kedilerin akşam yemeğini ver",
            category: .feeding,
            iconName: "moon.fill",
            priority: .high
        )
        eveningFeeding.assignedCats = cats
        
        // Create evening schedule (daily at 6 PM)
        let eveningTime = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
        let eveningSchedule = CareTaskSchedule(
            scheduledDate: eveningTime,
            scheduledTime: eveningTime,
            frequency: .daily,
            reminderMinutes: 15
        )
        eveningSchedule.task = eveningFeeding
        eveningFeeding.schedules.append(eveningSchedule)
        
        tasks.append(eveningFeeding)
        
        // Litter box cleaning (daily)
        let litterCleaning = CareTask(
            title: "Kum Kabı Temizliği",
            description: "Kum kabını temizle ve gerekirse kum ekle",
            category: .litter,
            iconName: "tray.fill",
            priority: .medium
        )
        litterCleaning.assignedCats = cats
        
        let litterTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
        let litterSchedule = CareTaskSchedule(
            scheduledDate: litterTime,
            scheduledTime: litterTime,
            frequency: .daily,
            reminderMinutes: 30
        )
        litterSchedule.task = litterCleaning
        litterCleaning.schedules.append(litterSchedule)
        
        tasks.append(litterCleaning)
        
        // Weekly grooming for Luna
        if let luna = cats.first(where: { $0.name == "Luna" }) {
            let grooming = CareTask(
                title: "Luna'yı Tara",
                description: "Luna'nın tüylerini tara ve mat kılları temizle",
                category: .grooming,
                iconName: "scissors",
                priority: .medium
            )
            grooming.assignedCats = [luna]
            
            // Weekly on Sundays at 11 AM
            let groomingTime = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: now) ?? now
            let groomingSchedule = CareTaskSchedule(
                scheduledDate: groomingTime,
                scheduledTime: groomingTime,
                frequency: .weekly,
                reminderMinutes: 60,
                customDays: [0] // Sunday
            )
            groomingSchedule.task = grooming
            grooming.schedules.append(groomingSchedule)
            
            tasks.append(grooming)
        }
        
        // Monthly vet checkup
        let vetCheckup = CareTask(
            title: "Veteriner Kontrolü",
            description: "Aylık genel sağlık kontrolü",
            category: .vet,
            iconName: "cross.case.fill",
            priority: .high
        )
        vetCheckup.assignedCats = cats
        
        // Monthly on 15th at 2 PM
        let vetTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now
        let vetSchedule = CareTaskSchedule(
            scheduledDate: vetTime,
            scheduledTime: vetTime,
            frequency: .monthly,
            reminderMinutes: 1440 // 1 day before
        )
        vetSchedule.task = vetCheckup
        vetCheckup.schedules.append(vetSchedule)
        
        tasks.append(vetCheckup)
        
        // Play time for Simba (daily)
        if let simba = cats.first(where: { $0.name == "Simba" }) {
            let playTime = CareTask(
                title: "Simba ile Oyun",
                description: "Simba ile 15 dakika oyun oyna",
                category: .exercise,
                iconName: "figure.run",
                priority: .medium
            )
            playTime.assignedCats = [simba]
            
            let playScheduleTime = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: now) ?? now
            let playSchedule = CareTaskSchedule(
                scheduledDate: playScheduleTime,
                scheduledTime: playScheduleTime,
                frequency: .daily,
                reminderMinutes: 15
            )
            playSchedule.task = playTime
            playTime.schedules.append(playSchedule)
            
            tasks.append(playTime)
        }
        
        // Water refill (daily)
        let waterRefill = CareTask(
            title: "Su Kabını Yenile",
            description: "Temiz su koy ve kabı temizle",
            category: .feeding,
            iconName: "drop.fill",
            priority: .medium
        )
        waterRefill.assignedCats = cats
        
        let waterTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let waterSchedule = CareTaskSchedule(
            scheduledDate: waterTime,
            scheduledTime: waterTime,
            frequency: .daily,
            reminderMinutes: 15
        )
        waterSchedule.task = waterRefill
        waterRefill.schedules.append(waterSchedule)
        
        tasks.append(waterRefill)
        
        // Create some completed tasks for demo
        let yesterdayFeeding = CareTask(
            title: "Dün Akşam Yemeği",
            description: "Tamamlanmış görev örneği",
            category: .feeding,
            iconName: "checkmark.circle.fill",
            priority: .high,
            status: .completed
        )
        yesterdayFeeding.assignedCats = cats
        
        let yesterdayTime = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let yesterdaySchedule = CareTaskSchedule(
            scheduledDate: yesterdayTime,
            scheduledTime: yesterdayTime,
            frequency: .once
        )
        yesterdaySchedule.task = yesterdayFeeding
        yesterdayFeeding.schedules.append(yesterdaySchedule)
        
        // Add completion
        let completion = CareTaskCompletion(
            completedAt: yesterdayTime,
            wasOnTime: true
        )
        completion.task = yesterdayFeeding
        yesterdayFeeding.completions.append(completion)
        
        tasks.append(yesterdayFeeding)
        
        return tasks
    }
}
#endif

