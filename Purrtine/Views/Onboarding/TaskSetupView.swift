import SwiftUI

struct TaskSetupView: View {
    let onContinue: () -> Void
    var reminderPrompt: OnboardingTaskSetupModel.ReminderPrompt = .none
    var onAllowNotifications: () -> Void = {}
    var onOpenNotificationSettings: () -> Void = {}

    let onboardingManager = OnboardingManager.shared
    @Environment(\.haptics) private var haptics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pendingTasks: [TaskType]
    @State private var tickedTasks: Set<TaskType> = []

    init(
        reminderPrompt: OnboardingTaskSetupModel.ReminderPrompt = .none,
        onAllowNotifications: @escaping () -> Void = {},
        onOpenNotificationSettings: @escaping () -> Void = {},
        onContinue: @escaping () -> Void
    ) {
        self.onContinue = onContinue
        self.reminderPrompt = reminderPrompt
        self.onAllowNotifications = onAllowNotifications
        self.onOpenNotificationSettings = onOpenNotificationSettings
        self._pendingTasks = State(
            initialValue: TaskType.allCases.filter {
                OnboardingManager.shared.selectedTasks.contains($0) == false
            }
        )
    }

    private var catName: String {
        let name = onboardingManager.tempCatData.name
        return name.isEmpty ? String(localized: .onboardingDefaultCatPossessive) : name
    }

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Text(.onboardingTaskSetupTitle(catName))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text(.onboardingTaskSetupSubtitle)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                    // Task Demo Rows
                    VStack(spacing: 12) {
                        ForEach(pendingTasks, id: \.self) { taskType in
                            TaskDemoRow(
                                taskType: taskType,
                                isTicked: tickedTasks.contains(taskType)
                            ) {
                                tick(taskType)
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)

                    // Bottom padding to ensure content doesn't hide behind buttons
                    Spacer().frame(height: 140)
                }
            }

            if reminderPrompt != .none {
                ReminderPermissionRow(
                    prompt: reminderPrompt,
                    onAllowNotifications: onAllowNotifications,
                    onOpenNotificationSettings: onOpenNotificationSettings
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            OnboardingActionFooter {
                Button(action: onContinue) {
                    Text(.onboardingTaskSetupStart)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.blue)
                        )
                }
                .accessibilityIdentifier("onboarding.taskSetup.continueButton")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    // MARK: - Tick Interaction
    private func tick(_ taskType: TaskType) {
        guard !tickedTasks.contains(taskType) else { return }

        haptics.impact(.light)
        onboardingManager.selectedTasks.insert(taskType)
        _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            tickedTasks.insert(taskType)
        }

        Task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.05 : 0.35))
            withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.35)) {
                pendingTasks.removeAll { $0 == taskType }
            }
        }
    }
}

// MARK: - Task Demo Row
private struct TaskDemoRow: View {
    let taskType: TaskType
    let isTicked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isTicked ? Color.blue : Color.gray.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))

                // Icon
                Text(taskType.icon)
                    .font(.system(size: 26))

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(taskType.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Text(taskType.description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTicked ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isTicked ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .disabled(isTicked)
        .accessibilityIdentifier("onboarding.taskDemo.\(taskType.rawValue)")
        .accessibilityValue(Text(isTicked ? .taskStatusCompleted : .taskStatusPending))
    }
}

// MARK: - Reminder Permission Row
/// Tells the caregiver the selected tasks can't remind them yet, with the one button their
/// current authorization status calls for. Shown only while that is true — see
/// `OnboardingTaskSetupModel.reminderPrompt`.
private struct ReminderPermissionRow: View {
    let prompt: OnboardingTaskSetupModel.ReminderPrompt
    let onAllowNotifications: () -> Void
    let onOpenNotificationSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(Theme.iconReminder)
                    .accessibilityHidden(true)

                Text(.onboardingTaskSetupReminderRowMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            ReminderPermissionActionButton(
                prompt: prompt,
                onAllowNotifications: onAllowNotifications,
                onOpenNotificationSettings: onOpenNotificationSettings
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(Theme.backgroundGroupedSecondary, in: .rect(cornerRadius: 12))
    }
}

/// The reminder row's one button: which action it takes depends on the prompt case.
private struct ReminderPermissionActionButton: View {
    let prompt: OnboardingTaskSetupModel.ReminderPrompt
    let onAllowNotifications: () -> Void
    let onOpenNotificationSettings: () -> Void

    var body: some View {
        switch prompt {
        case .none:
            EmptyView()
        case .askAgain:
            Button(String(localized: .onboardingTaskSetupReminderRowAllow), systemImage: "bell.badge", action: onAllowNotifications)
                .font(.footnote.bold())
        case .openSettings:
            Button(String(localized: .onboardingTaskSetupReminderRowOpenSettings), systemImage: "gearshape", action: onOpenNotificationSettings)
                .font(.footnote.bold())
        }
    }
}

#Preview {
    TaskSetupView(onContinue: { print("Continue") })
}

#Preview("Reminder row — allow") {
    TaskSetupView(reminderPrompt: .askAgain, onContinue: {})
}

#Preview("Reminder row — settings") {
    TaskSetupView(reminderPrompt: .openSettings, onContinue: {})
}
