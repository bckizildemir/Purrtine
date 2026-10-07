import SwiftUI
import SwiftData
import UserNotifications

@main
struct CatCareCalendarApp: App {
    let modelContainer: ModelContainer
    @AppStorage(SettingsPreferences.appearanceModeKey) private var appearanceModeRawValue = AppearanceMode.system.rawValue
    private let notificationActionCoordinator: NotificationActionCoordinator
    private let notificationResyncCoordinator: NotificationResyncCoordinator
    private let careTaskWriter: any CareTaskWriting
    
    init() {
        let configuration = AppLaunchConfiguration.current
        AppLaunchBootstrapper.prepareProcessState(using: configuration)

        let notificationManager = NotificationManager.shared
        let taskWriter = CareTaskWriter(scheduler: notificationManager)
        careTaskWriter = taskWriter

        // Initialize model container
        do {
            let container = try AppLaunchBootstrapper.makeModelContainer(using: configuration)
            
            // Create default caregiver synchronously on first launch
            // This prevents race conditions when creating tasks
            CaregiverBootstrapper.ensureDefaultCaregiverExists(in: container.mainContext)
            AppLaunchBootstrapper.seedInitialDataIfNeeded(in: container.mainContext, using: configuration)
            
            #if DEBUG
            Self.sanitizeInvalidCatAges(in: container.mainContext)
            #endif

            let authorizationChecker: NotificationAuthorizationChecking =
                configuration.disablesRealNotifications || configuration.isUnitTesting
                ? SimulatedNotificationAuthorizationChecker()
                : notificationManager
            let coordinator = NotificationActionCoordinator(
                modelContainer: container,
                taskWriter: taskWriter,
                authorizationChecker: authorizationChecker
            )

            modelContainer = container
            notificationActionCoordinator = coordinator
            notificationManager.actionCoordinator = coordinator
            let resyncCoordinator = NotificationResyncCoordinator(
                modelContainer: container,
                notificationManager: notificationManager
            )
            notificationResyncCoordinator = resyncCoordinator
            notificationManager.onFullResyncRequested = { resyncCoordinator.scheduleResync() }
            notificationManager.onFullResyncAwaited = { try await resyncCoordinator.resync() }

            if configuration.isUnitTesting == false {
                Task { @MainActor in
                    await notificationManager.checkAuthorizationStatus()
                }
            }

            if configuration.simulatedNotificationAction != nil {
                Task { @MainActor in
                    await AppLaunchBootstrapper.performSimulatedNotificationActionIfNeeded(
                        using: configuration,
                        modelContainer: container,
                        coordinator: coordinator
                    )
                }
            }
        } catch {
            fatalError("Failed to initialize model container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(
                    SettingsPreferences.resolvedAppearanceMode(from: appearanceModeRawValue).preferredColorScheme
                )
                .task {
                    let configuration = AppLaunchConfiguration.current
                    guard configuration.disablesCloudServices == false else { return }
                    // Bring Firebase up after the first frame rather than in App.init, keeping the
                    // SDK's setup off the launch critical path. The task-assistant cloud tier is the
                    // only consumer and it fails gracefully to the on-device heuristic if it somehow
                    // runs before this completes.
                    FirebaseBootstrapper.configureIfNeeded()
                    await FirebaseBootstrapper.ensureSignedInAnonymously()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // The unit-test host skips this, as it skips the launch-time permission check,
                    // so a test run never schedules real reminders from the host app's store.
                    guard AppLaunchConfiguration.current.isUnitTesting == false else { return }
                    Task {
                        await NotificationManager.shared.handleAppActivation()
                    }
                }
        }
        .environment(\.navigationRouter, NavigationRouter.shared)
        .environment(\.haptics, DefaultHapticsService())
        .environment(\.careTaskWriter, careTaskWriter)
        .modelContainer(modelContainer)
    }
    
    #if DEBUG
    private static func sanitizeInvalidCatAges(in context: ModelContext) {
        let descriptor = FetchDescriptor<Cat>()
        do {
            var sanitizedCount = 0
            let cats = try context.fetch(descriptor)
            for cat in cats where (cat.age ?? 0) <= 0 {
                print("[Sanitizer] Resetting invalid age for cat '\\(cat.name)' (stored: \(String(describing: cat.age)))")
                cat.age = nil
                sanitizedCount += 1
            }
            if sanitizedCount > 0 {
                try context.save()
                print("[Sanitizer] Completed age cleanup for \(sanitizedCount) cats")
            }
        } catch {
            print("[Sanitizer] Failed to sanitize cat ages: \(error)")
        }
    }
    #endif
}
