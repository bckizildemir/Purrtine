import Foundation
import Observation
import SwiftUI

/// Owns the app's navigation state. Every member is read or written from a
/// SwiftUI view or from a `Task { @MainActor }` in `NotificationManager`, so the
/// type is isolated to the main actor.
@MainActor
@Observable
final class NavigationRouter {
  /// `nonisolated` so the `@Entry` environment default below, which is read
  /// outside the main actor, can name it. The instance it holds is still
  /// main-actor isolated; only the reference to it is not.
  nonisolated static let shared = NavigationRouter()

  var path = NavigationPath()
  var selectedTab: AppTab = .home
  var selectedTaskId: UUID?
  var selectedTaskFilter: CareTaskFilter?
  var selectedHistoryTaskId: UUID?
  var shouldNavigateToMyCats: Bool = false
  var shouldNavigateToHistory: Bool = false
  var shouldTriggerAddTask: Bool = false

  nonisolated init() {}

  func reset() {
    path = NavigationPath()
    selectedTab = .home
    selectedTaskId = nil
    selectedTaskFilter = nil
    selectedHistoryTaskId = nil
    shouldNavigateToMyCats = false
    shouldNavigateToHistory = false
    shouldTriggerAddTask = false
  }

  // MARK: - Navigation Methods
  func navigateTo<T: Hashable>(_ destination: T) {
    path.append(destination)
  }

  func goBack() {
    guard !path.isEmpty else { return }
    path.removeLast()
  }

  func goToRoot() {
    path = NavigationPath()
  }

  func popToRoot() {
    path.removeLast(path.count)
  }

  // MARK: - Route Handling
  func handle(_ route: AppRoute) {
    switch route {
    case .home:
      reset()
    case .tasks(let taskId, let filter):
      selectedTab = .tasks
      shouldNavigateToMyCats = false
      shouldNavigateToHistory = false
      shouldTriggerAddTask = false
      selectedHistoryTaskId = nil
      if let filter {
        selectedTaskFilter = filter
      } else {
        selectedTaskFilter = nil
      }
      if let taskId {
        selectedTaskId = taskId
      } else {
        selectedTaskId = nil
      }
    case .assistant:
      selectedTab = .assistant
      shouldNavigateToMyCats = false
      shouldNavigateToHistory = false
      shouldTriggerAddTask = false
      selectedHistoryTaskId = nil
      selectedTaskId = nil
      selectedTaskFilter = nil
    case .settings:
      selectedTab = .settings
      shouldNavigateToMyCats = false
      shouldNavigateToHistory = false
      shouldTriggerAddTask = false
      selectedHistoryTaskId = nil
      selectedTaskId = nil
      selectedTaskFilter = nil
    case .cats:
      selectedTab = .settings
      shouldNavigateToMyCats = true
      shouldNavigateToHistory = false
      shouldTriggerAddTask = false
      selectedHistoryTaskId = nil
      selectedTaskId = nil
      selectedTaskFilter = nil
    case .history(let taskId):
      selectedTab = .settings
      shouldNavigateToMyCats = false
      shouldNavigateToHistory = true
      shouldTriggerAddTask = false
      selectedHistoryTaskId = taskId
      selectedTaskId = nil
      selectedTaskFilter = nil
    case .catDetail(let catId):
      selectedTab = .home
      shouldNavigateToMyCats = false
      shouldNavigateToHistory = false
      shouldTriggerAddTask = false
      selectedHistoryTaskId = nil
      selectedTaskId = nil
      selectedTaskFilter = nil
      navigateTo(AppDestination.catDetail(catId))
    case .onboarding:
      reset()
    }
  }
}

// MARK: - Route Definitions
enum AppRoute: Equatable {
  case home
  case tasks(taskId: UUID? = nil, filter: CareTaskFilter? = nil)
  case assistant
  case settings
  case cats
  case history(taskId: UUID? = nil)
  case catDetail(UUID)
  case onboarding

  init?(url: URL) {
    guard let scheme = url.scheme?.lowercased(), scheme == "catcarecalendar" else {
      return nil
    }
    let components = url.pathComponents.filter { $0 != "/" }
    guard let first = components.first else {
      self = .home
      return
    }
    switch first.lowercased() {
    case "home":
      self = .home
    case "tasks":
      let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
      let filterValue = queryItems?.first { $0.name == "filter" }?.value
      let filter = filterValue.flatMap { CareTaskFilter(rawValue: $0) }
      self = .tasks(taskId: nil, filter: filter)
    case "assistant":
      self = .assistant
    case "task":
      if components.count >= 2, let id = UUID(uuidString: components[1]) {
        self = .tasks(taskId: id, filter: nil)
      } else {
        return nil
      }
    case "settings":
      self = .settings
    case "history":
      let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
      let taskId = queryItems?
        .first { $0.name == "taskId" }?
        .value
        .flatMap(UUID.init(uuidString:))
      self = .history(taskId: taskId)
    case "cats":
      if components.count >= 2, let id = UUID(uuidString: components[1]) {
        self = .catDetail(id)
      } else {
        self = .cats
      }
    default:
      return nil
    }
  }
}

// MARK: - Navigation Destinations
enum AppDestination: Hashable {
  case catDetail(UUID)
  case addCat
  case editCat(UUID)
  case catGallery
  case taskList
  case taskCreation
  case taskTemplateSelection
  case taskDetails(CareTaskTemplate?)
  case editTask(UUID)
  case settings
  case onboarding

  // MARK: - Hashable Conformance
  func hash(into hasher: inout Hasher) {
    switch self {
    case .catDetail(let id):
      hasher.combine("catDetail")
      hasher.combine(id)
    case .addCat:
      hasher.combine("addCat")
    case .editCat(let id):
      hasher.combine("editCat")
      hasher.combine(id)
    case .catGallery:
      hasher.combine("catGallery")
    case .taskList:
      hasher.combine("taskList")
    case .taskCreation:
      hasher.combine("taskCreation")
    case .taskTemplateSelection:
      hasher.combine("taskTemplateSelection")
    case .taskDetails(let template):
      hasher.combine("taskDetails")
      hasher.combine(template)
    case .editTask(let id):
      hasher.combine("editTask")
      hasher.combine(id)
    case .settings:
      hasher.combine("settings")
    case .onboarding:
      hasher.combine("onboarding")
    }
  }

  static func == (lhs: AppDestination, rhs: AppDestination) -> Bool {
    switch (lhs, rhs) {
    case (.catDetail(let id1), .catDetail(let id2)):
      return id1 == id2
    case (.addCat, .addCat):
      return true
    case (.editCat(let id1), .editCat(let id2)):
      return id1 == id2
    case (.catGallery, .catGallery):
      return true
    case (.taskList, .taskList):
      return true
    case (.taskCreation, .taskCreation):
      return true
    case (.taskTemplateSelection, .taskTemplateSelection):
      return true
    case (.taskDetails(let template1), .taskDetails(let template2)):
      return template1 == template2
    case (.editTask(let id1), .editTask(let id2)):
      return id1 == id2
    case (.settings, .settings):
      return true
    case (.onboarding, .onboarding):
      return true
    default:
      return false
    }
  }
}

extension EnvironmentValues {
  @Entry var navigationRouter: NavigationRouter = .shared
}
