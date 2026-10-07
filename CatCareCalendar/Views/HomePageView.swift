import Foundation
import SwiftData
import SwiftUI

struct HomePageView: View {
  @Query(sort: \CareTask.createdAt, order: .reverse) private var allCareTasks: [CareTask]
  @Binding var selectedTab: AppTab
  @Binding var selectedTaskFilter: CareTaskFilter?
  @Environment(\.haptics) private var haptics
  @Environment(\.navigationRouter) private var navigationRouter

  @State private var showingAddCareTask = false
  @State private var showingAddCat = false
  @State private var showingMamaSheet = false
  @State private var showingSuSheet = false
  @State private var showingKumSheet = false
  @State private var showingCustomTaskSheet = false
  @State private var hasLoggedStats = false

  private var currentTaskSections: [TaskListSection] {
    TaskListDerivation.homeSections(from: allCareTasks)
  }

  private var routineStatusRows: [HomeRoutineStatusPresentation.Row] {
    HomeRoutineStatusPresentation.rows(from: allCareTasks)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Theme.background.ignoresSafeArea()
        ScrollView {
          VStack(spacing: 20) {
            currentTasksSection
            HomeRoutineStatusSectionView(
              rows: routineStatusRows,
              onTaskSelected: openRoutineHistory
            )
            quickActionsSection
          }
          .padding()
        }
        .accessibilityIdentifier("home.view")
      }
      .navigationChromeTitle(
        semanticTitle: "\(greeting), \(String(localized: .homeAccessibilityTodayIs(formattedDate)))",
        visualTitle: Text(greeting),
        visualSubtitle: Text(formattedDate)
      )
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button {
              showingAddCareTask = true
            } label: {
              Label(String(localized: .taskAdd), systemImage: "plus.circle")
            }
            Button {
              showingAddCat = true
            } label: {
              Label(String(localized: .catsAdd), systemImage: "cat.circle.fill")
            }
          } label: {
            Label(String(localized: .actionAdd), systemImage: "plus")
              .labelStyle(.iconOnly)
              .foregroundStyle(.blue)
          }
        }
      }
      .sheet(isPresented: $showingAddCareTask) {
        TaskAddView(template: Optional<CareTaskTemplate>.none)
      }
      .sheet(isPresented: $showingAddCat) {
        AddCatView()
      }
      .sheet(isPresented: $showingMamaSheet) {
        TaskAddView(
          template: CareTaskTemplateManager.shared.allTemplates.first {
            $0.kind == .morningFeeding
          },
          titlePlaceholder: String(localized: .taskCategoryFeeding)
        )
      }
      .sheet(isPresented: $showingSuSheet) {
        TaskAddView(
          template: CareTaskTemplateManager.shared.allTemplates.first { $0.kind == .freshWater }
        )
      }
      .sheet(isPresented: $showingKumSheet) {
        TaskAddView(
          template: CareTaskTemplateManager.shared.allTemplates.first { $0.kind == .litterCleaning }
        )
      }
      .sheet(isPresented: $showingCustomTaskSheet) {
        TaskAddView(template: nil)
      }
      .onAppear {
        if !hasLoggedStats {
          logStats()
          hasLoggedStats = true
        }
      }
    }
  }

  @ViewBuilder
  private var currentTasksSection: some View {
    // Derive once per render; the content reads it for both the empty check and the list.
    let sections = currentTaskSections
    if #available(iOS 26, *) {
      GlassEffectContainer(spacing: 12) {
        currentTasksSectionContent(sections: sections)
      }
    } else {
      currentTasksSectionContent(sections: sections)
    }
  }

  private func currentTasksSectionContent(sections: [TaskListSection]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "list.bullet.rectangle.portrait.fill")
          .foregroundColor(.blue)
        Text(.homeCurrentTasks)
          .font(.headline)
          .foregroundStyle(.primary)
        Spacer()

        Button {
          selectedTaskFilter = .all
          goTo(.tasks)
        } label: {
          Text(.actionViewAll)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .homeViewAllSurface()
        }
        .buttonStyle(.plain)
      }

      if sections.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "checkmark.circle")
            .font(.largeTitle)
            .foregroundColor(.green)
          Text(.homeCurrentTasksEmpty)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
      } else {
        LazyVStack(alignment: .leading, spacing: 16) {
          ForEach(sections) { section in
            VStack(alignment: .leading, spacing: 8) {
              Text(section.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

              ForEach(Array(section.tasks.prefix(3))) { task in
                HomeCurrentTaskRow(task: task) {
                  selectedTaskFilter = filter(for: section.key)
                  goTo(.tasks)
                }
              }
            }
          }
        }
      }
    }
    .padding()
    .homeSectionSurface()
    .accessibilityIdentifier("home.currentTasks.section")
  }

  @ViewBuilder
  private var quickActionsSection: some View {
    if #available(iOS 26, *) {
      GlassEffectContainer(spacing: 12) {
        quickActionsSectionContent
      }
    } else {
      quickActionsSectionContent
    }
  }

  private var quickActionsSectionContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(.homeQuickActions)
        .font(.headline)
        .foregroundStyle(.primary)
      quickActionsGrid
    }
    .padding()
    .homeSectionSurface()
    .accessibilityIdentifier("home.quickActions.section")
  }

  private var quickActionsGrid: some View {
    quickActionButtons
  }

  private var quickActionButtons: some View {
    LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
      spacing: 10
    ) {
      HomeQuickActionButton(
        title: String(localized: .taskCategoryFeeding),
        icon: "fork.knife",
        color: .orange
      ) {
        showingMamaSheet = true
      }
      HomeQuickActionButton(
        title: String(localized: .taskCategoryWater),
        icon: "drop.fill",
        color: .blue
      ) {
        showingSuSheet = true
      }
      HomeQuickActionButton(
        title: String(localized: .taskCategoryLitter),
        icon: "tray.fill",
        color: .brown
      ) {
        showingKumSheet = true
      }
      HomeQuickActionButton(
        title: String(localized: .tasksCustomTask),
        icon: "pencil.and.list.clipboard",
        color: .purple,
        allowsMultilineTitle: true
      ) {
        showingCustomTaskSheet = true
      }
    }
  }

  private var greeting: String {
    let hour = Calendar.current.component(.hour, from: Date())
    let greetingText: String
    switch hour {
    case 5..<12: greetingText = String(localized: .homeGreetingMorning)
    case 12..<17: greetingText = String(localized: .homeGreetingAfternoon)
    case 17..<21: greetingText = String(localized: .homeGreetingEvening)
    default: greetingText = String(localized: .homeGreetingNight)
    }
    return greetingText
  }

  private var formattedDate: String {
    Date().formatted(
      .verbatim("\(weekday: .wide), \(month: .wide) \(day: .defaultDigits)", locale: .current, timeZone: .current, calendar: .current)
    )
  }

  // MARK: - Debug Helper
  private func logStats() {
    #if DEBUG
    let allCompletions = allCareTasks.flatMap { $0.completions }
    let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    let filteredCompletions = allCompletions.filter { $0.completedAt >= startOfWeek }

    print("🔍 DEBUG HomePageView:")
    print("  - Total tasks: \(allCareTasks.count)")
    print("  - Total completions: \(allCompletions.count)")
    print("  - This week completions: \(filteredCompletions.count)")
    print("  - Start of week: \(startOfWeek)")
    #endif
  }

  // MARK: - Navigation Helper
  private func goTo(_ tab: AppTab) {
    haptics.impact(.medium)
    selectedTab = tab
  }

  private func openRoutineHistory(_ taskID: UUID) {
    haptics.impact(.medium)
    navigationRouter.handle(.history(taskId: taskID))
  }

  private func filter(for section: TaskListSectionKey) -> CareTaskFilter {
    switch section {
    case .overdue:
      return .overdue
    case .today:
      return .today
    default:
      return .all
    }
  }
}

// MARK: - Supporting Components for Home View
struct HomeCurrentTaskRow: View {
  let task: CareTask
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: task.iconName)
          .foregroundColor(task.isOverdue ? .red : .blue)
          .font(.title3)

        VStack(alignment: .leading, spacing: 4) {
          Text(task.title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.primary)

          HStack(spacing: 6) {
            if task.assignedCatNames.isEmpty == false {
              Text(task.assignedCatNames)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            if task.dueDisplayText().isEmpty == false {
              Text(verbatim: "•")
                .font(.caption)
                .foregroundStyle(.tertiary)
              Text(task.dueDisplayText())
                .font(.caption)
                .foregroundStyle(task.isOverdue ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
            }
          }

          Text(task.lastCompletionDisplayText())
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer()
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 12)
      .contentShape(.rect)
      .homeCurrentTaskRowSurface()
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("home.currentTask.\(task.title)")
  }
}

struct HomeQuickActionButton: View {
  let title: String
  let icon: String
  let color: Color
  let allowsMultilineTitle: Bool
  let action: () -> Void

  init(
    title: String,
    icon: String,
    color: Color,
    allowsMultilineTitle: Bool = false,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.icon = icon
    self.color = color
    self.allowsMultilineTitle = allowsMultilineTitle
    self.action = action
  }

  private enum Metrics {
    static let tileHeight: CGFloat = 60
    static let iconContainerSize: CGFloat = 32
    static let cornerRadius: CGFloat = 20
    static let iconCornerRadius: CGFloat = 10
    static let contentSpacing: CGFloat = 8
    static let horizontalPadding: CGFloat = 10
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: Metrics.contentSpacing) {
        Image(systemName: icon)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(color)
          .frame(width: Metrics.iconContainerSize, height: Metrics.iconContainerSize)
          .background(
            Color(uiColor: .secondarySystemFill),
            in: .rect(cornerRadius: Metrics.iconCornerRadius)
          )

        Text(title)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.primary)
          .lineLimit(allowsMultilineTitle ? 2 : 1)
          .fixedSize(horizontal: false, vertical: allowsMultilineTitle)
          .frame(maxWidth: .infinity, alignment: .leading)

        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, minHeight: Metrics.tileHeight, alignment: .leading)
      .padding(.horizontal, Metrics.horizontalPadding)
      .homeQuickActionSurface(cornerRadius: Metrics.cornerRadius)
      .contentShape(.rect(cornerRadius: Metrics.cornerRadius))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
  }
}

private extension View {
  @ViewBuilder
  func homeViewAllSurface() -> some View {
    if #available(iOS 26, *) {
      glassEffect(.regular.interactive(), in: .capsule)
    } else {
      background(Color.blue.opacity(0.12), in: .capsule)
    }
  }

  @ViewBuilder
  func homeQuickActionSurface(cornerRadius: CGFloat) -> some View {
    if #available(iOS 26, *) {
      glassEffect(
        .regular.interactive(),
        in: .rect(cornerRadius: cornerRadius)
      )
    } else {
      background(Theme.backgroundGroupedTertiary, in: .rect(cornerRadius: cornerRadius))
    }
  }

  @ViewBuilder
  func homeCurrentTaskRowSurface() -> some View {
    if #available(iOS 26, *) {
      glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    } else {
      background(
        Color(UIColor.tertiarySystemGroupedBackground),
        in: .rect(cornerRadius: 10)
      )
    }
  }
}

#if DEBUG
#Preview {
  PreviewHost(scenario: .standard) {
    HomePageView(
      selectedTab: .constant(.home),
      selectedTaskFilter: .constant(nil)
    )
  }
}
#endif
