import SwiftUI
import Foundation

/// Owns the onboarding flow's state. Every member is read or written from a
/// SwiftUI view or from `AppLaunchBootstrapper.prepareProcessState`, both of
/// which run on the main actor.
@MainActor
@Observable
final class OnboardingManager {
    static let shared = OnboardingManager()
    
    @ObservationIgnored
    private let userDefaults: UserDefaults
    
    // Onboarding tamamlanma durumu (artık stored property)
    var hasCompletedOnboarding: Bool {
        didSet {
            userDefaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    
    // Mevcut onboarding adımı
    var currentStep: OnboardingStep = .welcome
    
    // Onboarding sırasında geçici veri
    var tempCatData = TempCatData()
    var selectedTasks: Set<TaskType> = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedOnboarding")
    }
    
    /// Drops the pending photo too: this manager lives for the whole session, and a camera photo
    /// is a full-size decoded image. The rest of the temporary data stays, so the screen on its way
    /// out does not change.
    func completeOnboarding() {
        hasCompletedOnboarding = true
        tempCatData.photo = nil
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        currentStep = .welcome
        tempCatData = TempCatData()
        selectedTasks = []
    }
}

// MARK: - Onboarding Steps
enum OnboardingStep: String, CaseIterable {
    case welcome
    case notificationPermission
    case firstCatSetup
    case taskSetup

    var title: String {
        switch self {
        case .welcome:
            return String(localized: .onboardingStepWelcome)
        case .notificationPermission:
            return String(localized: .onboardingStepNotification)
        case .firstCatSetup:
            return String(localized: .onboardingStepFirstCat)
        case .taskSetup:
            return String(localized: .onboardingStepTasks)
        }
    }
}

// MARK: - Temporary Cat Data
struct TempCatData {
    var name: String = ""
    var age: Int? = nil
    var ageUnit: AgeUnit = .years
    var gender: Gender = .unknown
    var breed: String = ""
    /// The photo from the cat form, kept as it is until onboarding saves it: a picked photo stays
    /// prepared, and a camera photo is encoded once, on save.
    var photo: PendingCatPhoto?
    var notes: String = ""
}

// MARK: - Task Types for Onboarding
enum TaskType: String, CaseIterable {
    case feeding = "feeding"
    case water = "water"
    case litterBox = "litterBox"

    var title: String {
        switch self {
        case .feeding:
            return String(localized: .onboardingTaskFeedingTitle)
        case .water:
            return String(localized: .templateFreshWaterTitle)
        case .litterBox:
            return String(localized: .onboardingTaskLitterBoxTitle)
        }
    }

    var icon: String {
        switch self {
        case .feeding:
            return "🍽️"
        case .water:
            return "💧"
        case .litterBox:
            return "🧼"
        }
    }

    var description: String {
        switch self {
        case .feeding:
            return String(localized: .onboardingTaskFeedingDescription)
        case .water:
            return String(localized: .templateFreshWaterDescription)
        case .litterBox:
            return String(localized: .onboardingTaskLitterBoxDescription)
        }
    }
}
