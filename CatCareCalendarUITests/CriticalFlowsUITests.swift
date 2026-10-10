import XCTest

@MainActor
final class CriticalFlowsUITests: XCTestCase {
    /// `error.reminder_schedule`. The tests force `en_US`, so the literal is stable.
    private let scheduleFailureAlertTitle = "Could not set up reminders"

    /// `sheet.discard.confirm`, the destructive button of `SheetDismissButton`'s dialog.
    private let discardChangesButtonTitle = "Discard Changes"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        guard let testRun, testRun.failureCount > 0 else { return }
        attachScreenshot(named: "\(name)-failure-screenshot")
    }

    func testOnboardingHappyPathCreatesStarterTask() {
        let app = makeApp(additionalArguments: ["-reset-onboarding"])
        app.launch()

        XCTAssertTrue(app.buttons["onboarding.welcome.continueButton"].waitForExistence(timeout: 5))
        app.buttons["onboarding.welcome.continueButton"].tap()

        XCTAssertTrue(app.buttons["onboarding.notification.skipButton"].waitForExistence(timeout: 5))
        app.buttons["onboarding.notification.skipButton"].tap()

        let nameField = app.textFields["catForm.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Mochi")

        app.buttons["onboarding.firstCat.continueButton"].tap()

        let feedingDemo = app.buttons["onboarding.taskDemo.feeding"]
        XCTAssertTrue(feedingDemo.waitForExistence(timeout: 5))
        feedingDemo.tap()

        app.buttons["onboarding.taskSetup.continueButton"].tap()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5))
        tasksTab.tap()

        XCTAssertTrue(app.buttons["taskRow.Daily Feeding"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["taskRow.Refresh Water"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["taskRow.Litter Box Cleaning"].waitForExistence(timeout: 1))
    }

    func testOnboardingWithoutStarterTasksShowsTasksEmptyState() {
        let app = makeApp(additionalArguments: ["-reset-onboarding"])
        app.launch()

        XCTAssertTrue(app.buttons["onboarding.welcome.continueButton"].waitForExistence(timeout: 5))
        app.buttons["onboarding.welcome.continueButton"].tap()
        XCTAssertTrue(app.buttons["onboarding.notification.skipButton"].waitForExistence(timeout: 5))
        app.buttons["onboarding.notification.skipButton"].tap()

        let nameField = app.textFields["catForm.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Mochi")
        app.buttons["onboarding.firstCat.continueButton"].tap()

        let startButton = app.buttons["onboarding.taskSetup.continueButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5))
        tasksTab.tap()

        XCTAssertTrue(app.staticTexts["No Tasks Found"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow.'")).firstMatch.exists)
    }

    func testOnboardingActionFootersStayAligned() {
        let app = makeApp(additionalArguments: ["-reset-onboarding"])
        app.launch()

        let welcomeContinue = app.buttons["onboarding.welcome.continueButton"]
        XCTAssertTrue(welcomeContinue.waitForExistence(timeout: 5))
        let primaryActionY = welcomeContinue.frame.minY
        welcomeContinue.tap()

        let notificationContinue = app.buttons["onboarding.notification.enableButton"]
        let notificationSkip = app.buttons["onboarding.notification.skipButton"]
        XCTAssertTrue(notificationContinue.waitForExistence(timeout: 5))
        XCTAssertTrue(notificationSkip.exists)
        XCTAssertEqual(notificationContinue.frame.minY, primaryActionY, accuracy: 1)
        let secondaryActionY = notificationSkip.frame.minY
        notificationSkip.tap()

        let firstCatContinue = app.buttons["onboarding.firstCat.continueButton"]
        let firstCatSkip = app.buttons["onboarding.firstCat.skipButton"]
        XCTAssertTrue(firstCatContinue.waitForExistence(timeout: 5))
        XCTAssertTrue(firstCatSkip.exists)
        XCTAssertEqual(firstCatContinue.frame.minY, primaryActionY, accuracy: 1)
        XCTAssertEqual(firstCatSkip.frame.minY, secondaryActionY, accuracy: 1)

        firstCatSkip.tap()

        let taskContinue = app.buttons["onboarding.taskSetup.continueButton"]
        XCTAssertTrue(taskContinue.waitForExistence(timeout: 5))
        XCTAssertEqual(taskContinue.frame.minY, primaryActionY, accuracy: 1)
    }

    func testTaskCreateAndCompleteFlow() async {
        let taskTitle = "UI Test One-Time Task"
        let app = makeApp(additionalArguments: ["-complete-onboarding", "-seed-single-cat"])
        app.launch()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5))
        tasksTab.tap()

        let addMenuButton = app.buttons["taskManagement.addMenuButton"]
        XCTAssertTrue(addMenuButton.waitForExistence(timeout: 5))
        addMenuButton.tap()

        let customTaskButton = app.buttons["taskManagement.customTaskButton"]
        XCTAssertTrue(customTaskButton.waitForExistence(timeout: 5))
        customTaskButton.tap()

        let titleField = app.textFields["taskAdd.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(taskTitle)

        // Dismiss the keyboard before tapping rows near its edge; on iOS 26 the
        // keyboard-avoidance layout shift can otherwise swallow the tap.
        let keyboardDoneButton = app.toolbars.buttons["Done"]
        if keyboardDoneButton.waitForExistence(timeout: 2) {
            keyboardDoneButton.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        }

        let catsButton = app.buttons["taskAdd.catsButton"]
        XCTAssertTrue(catsButton.waitForExistence(timeout: 5))
        catsButton.tap()

        let catOption = app.buttons["taskCatsSelection.cat.UI Test Cat"]
        XCTAssertTrue(catOption.waitForExistence(timeout: 5))
        catOption.tap()

        let doneButton = app.buttons["taskCatsSelection.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        let saveButton = app.buttons["taskAdd.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        XCTAssertTrue(app.buttons["taskRow.\(taskTitle)"].waitForExistence(timeout: 5))

        let completeButton = app.buttons["taskRow.complete.\(taskTitle)"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()

        let completedValue = NSPredicate(format: "value CONTAINS %@", "Completed")
        let completed = expectation(for: completedValue, evaluatedWith: completeButton)
        await fulfillment(of: [completed], timeout: 5)
    }

    func testTaskAddCatsButtonAnnouncesSingleHintWhenNoCatsExist() {
        let app = makeApp(additionalArguments: ["-complete-onboarding"])
        app.launch()

        let customTaskQuickAction = app.buttons["Custom Task"]
        XCTAssertTrue(customTaskQuickAction.waitForExistence(timeout: 5))
        customTaskQuickAction.tap()

        let catsButton = app.buttons["taskAdd.catsButton"]
        XCTAssertTrue(catsButton.waitForExistence(timeout: 5))
        XCTAssertEqual(catsButton.value as? String, "Add a cat first to assign this task")
    }

    func testTemplateScrollDoesNotSelectCardAndVaccinationCanBeSelectedDeliberately() {
        let app = makeApp(additionalArguments: ["-complete-onboarding", "-seed-single-cat"])
        app.launch()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5))
        tasksTab.tap()

        let addMenuButton = app.buttons["taskManagement.addMenuButton"]
        XCTAssertTrue(addMenuButton.waitForExistence(timeout: 5))
        addMenuButton.tap()

        let templateTaskButton = app.buttons["taskManagement.templateTaskButton"]
        XCTAssertTrue(templateTaskButton.waitForExistence(timeout: 5))
        templateTaskButton.tap()

        let feedingTemplate = app.buttons["taskTemplate.morningFeeding"].firstMatch
        XCTAssertTrue(feedingTemplate.waitForExistence(timeout: 5))
        feedingTemplate.swipeUp()

        XCTAssertTrue(feedingTemplate.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["taskAdd.titleField"].exists)

        let veterinaryCategory = app.buttons["taskTemplate.category.vet"]
        XCTAssertTrue(veterinaryCategory.waitForExistence(timeout: 5))
        veterinaryCategory.tap()

        let vaccinationTemplate = app.buttons["taskTemplate.vaccination"].firstMatch
        XCTAssertTrue(vaccinationTemplate.waitForExistence(timeout: 5))
        vaccinationTemplate.tap()
        XCTAssertTrue(app.textFields["taskAdd.titleField"].waitForExistence(timeout: 5))
    }

    func testTaskListTabBarAndAssistantPlacement() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "tasks",
                "-seed-scenario", "long_task_list"
            ]
        )
        app.launch()

        let taskList = app.descendants(matching: .any)["taskManagement.list"]
        let tabBar = app.tabBars.firstMatch
        let viewModeButton = app.buttons["taskManagement.viewModeButton"]
        let addButton = app.buttons["taskManagement.addMenuButton"]
        let assistantTab = app.tabBars.buttons["Whiskers"]
        let firstTask = app.buttons["taskRow.UI Test Long Task 01"]

        XCTAssertTrue(taskList.waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertTrue(viewModeButton.waitForExistence(timeout: 5))
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertTrue(assistantTab.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["taskManagement.assistantButton"].exists)
        XCTAssertTrue(firstTask.waitForExistence(timeout: 5))

        if #available(iOS 26.0, *) {
            XCTAssertGreaterThanOrEqual(taskList.frame.maxY, tabBar.frame.minY)
            XCTAssertEqual(viewModeButton.frame.midY, addButton.frame.midY, accuracy: 2)
            XCTAssertLessThan(viewModeButton.frame.midX, addButton.frame.midX)
            XCTAssertLessThanOrEqual(firstTask.frame.minY - taskList.frame.minY, 64)

            attachScreenshot(named: "Tasks-iOS26-expanded")

            let lastTask = app.buttons["taskRow.UI Test Long Task 18"]
            let firstObstructionY = tabBar.frame.minY
            for _ in 0..<12
            where !lastTask.exists || lastTask.frame.maxY > firstObstructionY + 2 {
                taskList.swipeUp()
            }

            XCTAssertTrue(lastTask.waitForExistence(timeout: 5))
            XCTAssertTrue(lastTask.isHittable)
            XCTAssertLessThan(viewModeButton.frame.midX, addButton.frame.midX)

            // Scrolling down minimizes the floating tab bar (ContentView applies
            // `.tabBarMinimizeBehavior(.onScrollDown)`). While minimized the bar collapses to
            // just the selected tab, so every other tab button — including "Whiskers" — drops
            // out of the accessibility hierarchy. The bar CONTAINER stays in place: its frame is
            // unchanged (minY still equals the pre-scroll `firstObstructionY`), so it remains a
            // valid obstruction baseline even though its individual tabs are no longer exposed.
            XCTAssertTrue(tabBar.exists)
            XCTAssertFalse(assistantTab.exists)
            XCTAssertLessThanOrEqual(lastTask.frame.maxY, firstObstructionY + 2)
            attachScreenshot(named: "Tasks-iOS26-minimized")

            // Scrolling back up expands the bar again and restores the assistant tab, confirming
            // the assistant stays reachable from the tab bar after the user scrolls.
            for _ in 0..<12 where !assistantTab.exists {
                taskList.swipeDown()
            }
            XCTAssertTrue(assistantTab.waitForExistence(timeout: 5))

            viewModeButton.tap()

            let calendar = app.descendants(matching: .any)["taskManagement.calendar"]
            XCTAssertTrue(calendar.waitForExistence(timeout: 5))

            // Calendar mode scrolls through the month header/grid before reaching the task
            // list, and calendar task rows are taller than list-mode rows, so it needs more
            // swipes than list mode to reach the last row.
            for _ in 0..<24
            where !lastTask.exists || lastTask.frame.maxY > tabBar.frame.minY + 2 {
                calendar.swipeUp()
            }

            XCTAssertTrue(lastTask.waitForExistence(timeout: 5))
            XCTAssertTrue(lastTask.isHittable)
            XCTAssertLessThanOrEqual(lastTask.frame.maxY, tabBar.frame.minY + 2)
            attachScreenshot(named: "Tasks-iOS26-calendar-clearance")

            // Calendar scrolling minimized the bar again; scroll back up to restore the
            // assistant tab so the shared assistantTab.tap() below can reach it.
            for _ in 0..<24 where !assistantTab.exists {
                calendar.swipeDown()
            }
            XCTAssertTrue(assistantTab.waitForExistence(timeout: 5))
        } else {
            XCTAssertEqual(viewModeButton.frame.midY, addButton.frame.midY, accuracy: 2)
            XCTAssertLessThan(viewModeButton.frame.midX, addButton.frame.midX)
        }

        assistantTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["taskAssistant.startChatButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["taskAssistant.input"].exists)

        let selectedTasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(selectedTasksTab.waitForExistence(timeout: 5))
        selectedTasksTab.tap()

        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
        homeTab.tap()
        XCTAssertFalse(app.buttons["taskManagement.assistantButton"].waitForExistence(timeout: 1))

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5))
        tasksTab.tap()
        XCTAssertFalse(app.buttons["taskManagement.assistantButton"].exists)
    }

    /// Regression: `-launch-route addTask` must present `TaskAddView` on a cold launch.
    /// `shouldTriggerAddTask` is already `true` before `TaskManagementView` mounts, so an
    /// `.onChange`-only handler never fires; the fix adds an `.onAppear` fallback.
    func testLaunchRouteAddTaskPresentsTaskAddViewOnColdLaunch() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "add_task"
            ]
        )
        app.launch()

        XCTAssertTrue(app.textFields["taskAdd.titleField"].waitForExistence(timeout: 5))
    }

    func testTaskAssistantTabIsAvailableWithoutCats() {
        let app = makeApp(additionalArguments: ["-complete-onboarding", "-launch-route", "tasks"])
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["taskManagement.view"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["taskManagement.assistantButton"].exists)

        let assistantTab = app.tabBars.buttons["Whiskers"]
        XCTAssertTrue(assistantTab.waitForExistence(timeout: 5))
        assistantTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["taskAssistant.startChatButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["taskAssistant.input"].exists)
    }

    func testTaskAssistantEndChatResetsConversation() {
        let app = makeApp(additionalArguments: ["-complete-onboarding", "-launch-route", "home"])
        app.launch()

        let assistantTab = app.tabBars.buttons["Whiskers"]
        XCTAssertTrue(assistantTab.waitForExistence(timeout: 5))
        assistantTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["taskAssistant.startChatButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["taskAssistant.input"].exists)

        app.buttons["taskAssistant.startChatButton"].tap()
        dismissAssistantCloudConsentIfNeeded(in: app)

        let input = app.textFields["taskAssistant.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        input.tap()
        input.typeText("unfinished task request")

        let endChatButton = app.buttons["taskAssistant.endChatButton"]
        XCTAssertTrue(endChatButton.waitForExistence(timeout: 5))
        endChatButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["taskAssistant.startChatButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["taskAssistant.continueChatButton"].exists)

        app.buttons["taskAssistant.startChatButton"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertNotEqual(input.value as? String, "unfinished task request")
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    func testTaskAssistantSuggestionOpensChatWithConfirmation() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "home",
                "-seed-scenario", "pending_task"
            ]
        )
        app.launch()

        let assistantTab = app.tabBars.buttons["Whiskers"]
        XCTAssertTrue(assistantTab.waitForExistence(timeout: 5))
        assistantTab.tap()

        let suggestion = app.buttons["taskAssistant.quickAction.UI Test Task"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        suggestion.tap()
        dismissAssistantCloudConsentIfNeeded(in: app)

        XCTAssertTrue(app.textFields["taskAssistant.input"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["taskAssistant.confirmButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    func testTaskAssistantOpenActionSwitchesToTasksAndOpensTask() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "home",
                "-seed-scenario", "pending_task"
            ]
        )
        app.launch()

        let assistantTab = app.tabBars.buttons["Whiskers"]
        XCTAssertTrue(assistantTab.waitForExistence(timeout: 5))
        assistantTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: 5))
        app.buttons["taskAssistant.startChatButton"].tap()

        dismissAssistantCloudConsentIfNeeded(in: app)

        let input = app.textFields["taskAssistant.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        app.typeText("open UI Test Task")

        let sendButton = app.buttons["Send task message"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5))
        sendButton.tap()

        let confirmButton = app.buttons["Confirm"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5))
        XCTAssertTrue(tasksTab.isSelected)
        XCTAssertTrue(app.textFields["taskEdit.titleField"].waitForExistence(timeout: 10))
    }

    func testAssistantClarificationCardScrollsIntoViewWhenAmbiguous() {
        // `long_task_list` seeds one cat + 18 identically-titled ".general" tasks, so the
        // ambiguous "complete long task" ties every candidate and forces a clarification card
        // (header + suggestion rows + Cancel) taller than the viewport with the keyboard up —
        // the exact shipped repro where the chat failed to scroll the new card into view.
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "tasks",
                "-seed-scenario", "long_task_list"
            ]
        )
        app.launch()

        let assistantTab = app.tabBars.buttons["Whiskers"]
        XCTAssertTrue(assistantTab.waitForExistence(timeout: 5))
        assistantTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: 5))
        app.buttons["taskAssistant.startChatButton"].tap()

        // First launch presents the cloud-consent sheet over the assistant. The heuristic
        // clarification path never uses the cloud, so decline it if it appears. Match the
        // button by label — the sheet container's accessibility id isn't a queryable element.
        dismissAssistantCloudConsentIfNeeded(in: app)

        // Tap the focused chat's identified composer, type, and keep the keyboard up.
        let input = app.textFields["taskAssistant.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        app.typeText("complete long task")

        let sendButton = app.buttons["Send task message"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5))
        sendButton.tap()

        // The clarification card's trailing "Cancel" button is its last element and exists in
        // the hierarchy even when off-screen. With the shipped bug the chat did not auto-scroll
        // to reveal the card (keyboard up), so it was not hittable. The fix must scroll it in.
        let cancelClarification = app.buttons["Cancel"]
        XCTAssertTrue(cancelClarification.waitForExistence(timeout: 5))
        XCTAssertTrue(
            cancelClarification.isHittable,
            "Clarification card's trailing Cancel button must be on-screen — the chat should auto-scroll the card into view after send."
        )
    }

    func testTaskEditAndDeleteFlow() {
        let originalTitle = "UI Test Task"
        let updatedTitle = "UI Test Task Updated"
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "tasks",
                "-seed-scenario", "pending_task"
            ]
        )
        app.launch()

        let originalRow = app.buttons["taskRow.\(originalTitle)"]
        XCTAssertTrue(originalRow.waitForExistence(timeout: 5))
        originalRow.tap()

        let titleField = app.textFields["taskEdit.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        replaceText(in: titleField, with: updatedTitle)

        let saveButton = app.buttons["taskEdit.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        let updatedRow = app.buttons["taskRow.\(updatedTitle)"]
        XCTAssertTrue(updatedRow.waitForExistence(timeout: 5))

        updatedRow.swipeLeft()

        let deleteButton = app.buttons["taskRow.delete.\(updatedTitle)"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        XCTAssertFalse(updatedRow.waitForExistence(timeout: 2))
    }

    func testReminderToggleRoundTripInEditFormKeepsMenuReachable() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "tasks",
                "-seed-scenario", "pending_task"
            ]
        )
        app.launch()

        let taskRow = app.buttons["taskRow.UI Test Task"]
        XCTAssertTrue(taskRow.waitForExistence(timeout: 5))
        taskRow.tap()

        XCTAssertTrue(app.textFields["taskEdit.titleField"].waitForExistence(timeout: 5))

        assertReminderToggleRoundTripKeepsMenuReachable(in: app)
    }

    func testReminderToggleRoundTripInAddFormKeepsMenuReachable() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-seed-scenario", "single_cat"
            ]
        )
        app.launch()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5))
        tasksTab.tap()

        let addMenuButton = app.buttons["taskManagement.addMenuButton"]
        XCTAssertTrue(addMenuButton.waitForExistence(timeout: 5))
        addMenuButton.tap()

        let customTaskButton = app.buttons["taskManagement.customTaskButton"]
        XCTAssertTrue(customTaskButton.waitForExistence(timeout: 5))
        customTaskButton.tap()

        XCTAssertTrue(app.textFields["taskAdd.titleField"].waitForExistence(timeout: 5))

        assertReminderToggleRoundTripKeepsMenuReachable(in: app)
    }

    func testTaskEditReassignsCaregiverAndPersists() {
        let taskTitle = "UI Test Task"
        let newCaregiver = "UI Test Caregiver"
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "tasks",
                "-seed-scenario", "pending_task",
                "-seed-second-caregiver"
            ]
        )
        app.launch()

        let row = app.buttons["taskRow.\(taskTitle)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let caregiverButton = app.buttons["taskEdit.caregiverButton"]
        XCTAssertTrue(caregiverButton.waitForExistence(timeout: 5))
        // The seeded task is assigned to the default ("Myself") caregiver.
        XCTAssertFalse(caregiverButton.label.contains(newCaregiver))
        caregiverButton.tap()

        let option = app.buttons[newCaregiver]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()

        XCTAssertTrue(caregiverButton.label.contains(newCaregiver))

        let saveButton = app.buttons["taskEdit.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // Reopen the same task to confirm the reassignment persisted.
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let reopenedCaregiverButton = app.buttons["taskEdit.caregiverButton"]
        XCTAssertTrue(reopenedCaregiverButton.waitForExistence(timeout: 5))
        XCTAssertTrue(reopenedCaregiverButton.label.contains(newCaregiver))
    }

    func testCatAddAndEditFlow() {
        let newCatName = "Nimbus"
        let updatedCatName = "Nimbus Prime"
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "cats",
                "-seed-scenario", "single_cat"
            ]
        )
        app.launch()

        let addButton = app.buttons["cats.addButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let nameField = app.textFields["catForm.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(newCatName)

        let saveButton = app.buttons["catForm.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        let newCatCard = app.buttons["cats.card.\(newCatName)"]
        XCTAssertTrue(newCatCard.waitForExistence(timeout: 5))
        newCatCard.tap()

        let editButton = app.buttons["catDetail.editButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        let editNameField = app.textFields["catForm.nameField"]
        XCTAssertTrue(editNameField.waitForExistence(timeout: 5))
        replaceText(in: editNameField, with: updatedCatName)
        app.buttons["catForm.saveButton"].tap()

        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        let persistedNameField = app.textFields["catForm.nameField"]
        XCTAssertTrue(persistedNameField.waitForExistence(timeout: 5))
        XCTAssertEqual(persistedNameField.value as? String, updatedCatName)
        app.buttons["catForm.cancelButton"].tap()
    }

    func testMostlyEmptyCatUsesOnlyPawEmptyStateAction() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "cats",
                "-seed-scenario", "single_cat"
            ]
        )
        app.launch()

        let catCard = app.buttons["cats.card.UI Test Cat"]
        XCTAssertTrue(catCard.waitForExistence(timeout: 5))
        catCard.tap()

        XCTAssertTrue(app.descendants(matching: .any)["catDetail.emptyState"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "catDetail.emptyStateAction").count, 1)
        XCTAssertFalse(app.buttons["catDetail.completeProfileButton"].exists)
    }

    func testBasicDetailsCatHidesEmptyAdditionalInformationSection() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "cats",
                "-seed-scenario", "basic_details"
            ]
        )
        app.launch()

        let catCard = app.buttons["cats.card.UI Basic Details Cat"]
        XCTAssertTrue(catCard.waitForExistence(timeout: 5))
        catCard.tap()

        XCTAssertTrue(app.descendants(matching: .any)["catDetail.basicInformationSection"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["catDetail.additionalInformationSection"].exists)
    }

    func testNameOnlyCatEmptyStateHasReducedTopSpacing() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "cats",
                "-seed-scenario", "single_cat"
            ]
        )
        app.launch()

        app.buttons["cats.card.UI Test Cat"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["catDetail.emptyState"].waitForExistence(timeout: 5))
        attachScreenshot(named: "CatDetail-name-only-empty-state")
    }

    func testDeletingCatPreservesSharedTaskButRemovesSoloTask() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "cats",
                "-seed-scenario", "shared_task_cat_deletion"
            ]
        )
        app.launch()

        let primaryCatCard = app.buttons["cats.card.UI Test Cat"]
        XCTAssertTrue(primaryCatCard.waitForExistence(timeout: 5))
        primaryCatCard.tap()

        let editButton = app.buttons["catDetail.editButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        let deleteButton = app.buttons["catForm.deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Danger Zone"].exists)
        deleteButton.tap()

        let confirmDeleteButton = app.alerts.buttons["Delete"].firstMatch
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 5))
        confirmDeleteButton.tap()

        if app.descendants(matching: .any)["cats.view"].waitForExistence(timeout: 2) == false {
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.waitForExistence(timeout: 2) {
                backButton.tap()
            }
        }

        XCTAssertTrue(app.descendants(matching: .any)["cats.view"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cats.card.UI Second Test Cat"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cats.card.UI Test Cat"].waitForExistence(timeout: 2))

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5))
        tasksTab.tap()

        XCTAssertTrue(app.buttons["taskRow.UI Shared Task"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["taskRow.UI Solo Task"].waitForExistence(timeout: 2))
    }

    /// Regression: deleting a cat cascades its exclusive tasks away while their
    /// TaskRows are already in the view hierarchy; re-rendering a row for a
    /// deleted model used to trap in SwiftData (SIGTRAP in CareTask.category).
    func testDeletingCatWhileTaskRowsAreOnScreenDoesNotCrash() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "tasks",
                "-seed-scenario", "shared_task_cat_deletion"
            ]
        )
        app.launch()

        // Render the task rows first so they are live when the cascade delete runs.
        XCTAssertTrue(app.buttons["taskRow.UI Solo Task"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["taskRow.UI Shared Task"].waitForExistence(timeout: 5))

        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 5))
        moreTab.tap()

        let catsShortcut = app.buttons["settings.shortcut.cats"]
        XCTAssertTrue(catsShortcut.waitForExistence(timeout: 5))
        catsShortcut.tap()

        let primaryCatCard = app.buttons["cats.card.UI Test Cat"]
        XCTAssertTrue(primaryCatCard.waitForExistence(timeout: 5))
        primaryCatCard.tap()

        let editButton = app.buttons["catDetail.editButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        let deleteButton = app.buttons["catForm.deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        let confirmDeleteButton = app.alerts.buttons["Delete"].firstMatch
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 5))
        confirmDeleteButton.tap()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5))
        tasksTab.tap()

        XCTAssertTrue(app.buttons["taskRow.UI Shared Task"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["taskRow.UI Solo Task"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testCatCardContextMenuAddTaskOpensFormWithCatPreselected() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "cats",
                "-seed-single-cat"
            ]
        )
        app.launch()

        let catCard = app.buttons["cats.card.UI Test Cat"]
        XCTAssertTrue(catCard.waitForExistence(timeout: 5))
        catCard.press(forDuration: 1.2)

        let addTaskMenuItem = app.buttons["Add Task"]
        XCTAssertTrue(addTaskMenuItem.waitForExistence(timeout: 5))
        addTaskMenuItem.tap()

        XCTAssertTrue(app.textFields["taskAdd.titleField"].waitForExistence(timeout: 5))

        let catsButton = app.buttons["taskAdd.catsButton"]
        XCTAssertTrue(catsButton.waitForExistence(timeout: 5))
        XCTAssertTrue(catsButton.label.localizedStandardContains("UI Test Cat"))
    }

    func testHistoryShowsNoTasksStateWhenSeededWithNoTasks() {
        let app = makeApp(additionalArguments: ["-complete-onboarding", "-launch-route", "history"])
        app.launch()

        XCTAssertTrue(app.buttons["Create Your First Task"].waitForExistence(timeout: 5))
    }

    func testHistoryShowsCompletionsWhenSeeded() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "history",
                "-seed-scenario", "history_completion"
            ]
        )
        app.launch()

        XCTAssertTrue(app.staticTexts["UI Test Completed Task"].waitForExistence(timeout: 5))
    }

    func testHistoryShowsNoCompletionsStateWhenTasksExistWithoutCompletions() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "history",
                "-seed-scenario", "pending_task"
            ]
        )
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["history.view"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No statistics yet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["History and statistics will appear here as you complete tasks."].exists)
        XCTAssertFalse(app.descendants(matching: .any)["history.state.noTasks"].exists)
    }

    func testHomeDashboardShowsSeededTodayAndOverdueTasks() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "home",
                "-seed-scenario", "pending_task",
                "-seed-scenario", "overdue_task"
            ]
        )
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["home.view"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.currentTasks.section"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.currentTask.UI Test Overdue Task"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.currentTask.UI Test Task"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.descendants(matching: .any)["home.routineStatus.section"].waitForExistence(timeout: 5))
        // Routine status only lists tasks with at least one completion; the seeded
        // never-completed tasks must stay out of it and leave the empty state visible.
        XCTAssertFalse(app.descendants(matching: .any)["home.routineStatus.row.UI Test Overdue Task"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.routineStatus.row.UI Test Task"].exists)
        XCTAssertTrue(
            app.staticTexts["Routine history will appear here once you complete scheduled tasks."].exists
        )
    }

    func testSimulatedNotificationCompleteMarksTaskCompleted() async {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "tasks",
                "-simulate-notification-action", "complete",
                "-simulate-notification-scenario", "pending_task"
            ]
        )
        app.launch()

        let completeButton = app.buttons["taskRow.complete.UI Test Task"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))

        let completedValue = NSPredicate(format: "value CONTAINS %@", "Completed")
        let completed = expectation(for: completedValue, evaluatedWith: completeButton)
        await fulfillment(of: [completed], timeout: 5)
    }

    func testSimulatedNotificationSnoozeKeepsTaskPendingAndShowsPendingNotification() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "tasks",
                "-simulate-notification-action", "snooze_10",
                "-simulate-notification-scenario", "pending_task"
            ]
        )
        app.launch()

        let taskRow = app.buttons["taskRow.UI Test Task"]
        XCTAssertTrue(taskRow.waitForExistence(timeout: 5))

        let completeButton = app.buttons["taskRow.complete.UI Test Task"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))

        let settingsTab = app.tabBars.buttons["More"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let settingsView = app.descendants(matching: .any)["settings.view"].firstMatch
        XCTAssertTrue(settingsView.waitForExistence(timeout: 5))

        let developerToolsButton = app.buttons["settings.developerTools"]
        for _ in 0..<6 where !developerToolsButton.exists || !developerToolsButton.isHittable {
            settingsView.swipeUp()
        }
        XCTAssertTrue(developerToolsButton.waitForExistence(timeout: 5))
        developerToolsButton.tap()

        let notificationHistoryButton = app.buttons["developerTools.notificationHistory"]
        XCTAssertTrue(notificationHistoryButton.waitForExistence(timeout: 5))
        notificationHistoryButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["notificationHistory.view"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["UI Test Task"].waitForExistence(timeout: 5))
    }

    func testSettingsShortcutsNavigateToCatsAndHistory() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "settings",
                "-seed-scenario", "single_cat",
                "-seed-scenario", "history_completion"
            ]
        )
        app.launch()

        let catsShortcut = app.buttons["settings.shortcut.cats"]
        XCTAssertTrue(catsShortcut.waitForExistence(timeout: 5))
        waitUntilHittable(catsShortcut)
        catsShortcut.tap()

        XCTAssertTrue(app.buttons["cats.card.UI Test Cat"].waitForExistence(timeout: 5))

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        waitUntilHittable(backButton)
        backButton.tap()

        let historyShortcut = app.buttons["settings.shortcut.history"]
        XCTAssertTrue(historyShortcut.waitForExistence(timeout: 5))
        waitUntilHittable(historyShortcut)
        historyShortcut.tap()

        XCTAssertTrue(app.staticTexts["UI Test Completed Task"].waitForExistence(timeout: 5))
    }

    func testSettingsLaunchRouteShowsSettingsRootAndShortcuts() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "settings",
                "-seed-scenario", "single_cat",
                "-seed-scenario", "history_completion"
            ]
        )
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["settings.view"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.appSettings.row"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.shortcut.cats"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.shortcut.history"].waitForExistence(timeout: 5))
    }

    func testNotificationSettingsAdvancedChangesPersistWithinDraftFlow() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "settings"
            ]
        )
        app.launch()

        let appSettingsRow = app.buttons["settings.appSettings.row"]
        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: 5))
        appSettingsRow.tap()

        let notificationsRow = app.buttons["settings.notifications.row"]
        XCTAssertTrue(notificationsRow.waitForExistence(timeout: 5))
        notificationsRow.tap()

        XCTAssertTrue(app.navigationBars["Notification Settings"].waitForExistence(timeout: 5))

        let advancedRow = app.buttons["notificationSettings.advanced"]
        XCTAssertTrue(advancedRow.waitForExistence(timeout: 5))
        advancedRow.tap()

        XCTAssertTrue(app.navigationBars["Advanced Notification Settings"].waitForExistence(timeout: 5))

        let soundToggle = app.switches["advancedNotificationSettings.soundToggle"]
        XCTAssertTrue(soundToggle.waitForExistence(timeout: 5))
        let originalState = toggleState(for: soundToggle)
        let expectedState = originalState == "on" ? "off" : "on"
        tapSwitchControl(soundToggle)
        waitForToggleState(expectedState, in: soundToggle)

        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.navigationBars["Notification Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(advancedRow.waitForExistence(timeout: 5))
        advancedRow.tap()

        let updatedSoundToggle = app.switches["advancedNotificationSettings.soundToggle"]
        XCTAssertTrue(updatedSoundToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggleState(for: updatedSoundToggle), expectedState)
    }

    func testAboutAndSupportScreensExposeExpectedRows() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "settings"
            ]
        )
        app.launch()

        let supportRow = app.buttons["settings.support.row"]
        XCTAssertTrue(supportRow.waitForExistence(timeout: 5))
        supportRow.tap()

        XCTAssertTrue(app.staticTexts["CatCareCalendar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Version'")).firstMatch.waitForExistence(timeout: 5))
        // settings.rateApp is only rendered when APP_STORE_ID is configured, which this build doesn't set.
        XCTAssertTrue(app.descendants(matching: .any)["settings.giveFeedback"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["settings.privacyPolicy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["settings.termsOfService"].waitForExistence(timeout: 5))
    }

    func testCriticalAccessibilityIdentifiersArePresentAcrossMainFlows() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "home",
                "-seed-scenario", "single_cat",
                "-seed-scenario", "pending_task",
                "-seed-scenario", "history_completion"
            ]
        )
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["home.view"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.currentTasks.section"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.quickActions.section"].waitForExistence(timeout: 5))

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5))
        tasksTab.tap()

        // Destination-view waits after a tab/navigation transition get a longer timeout than
        // simple element checks: under CI/full-suite load, tab-switch animation + view load can
        // occasionally exceed 5s even though it's never actually stuck (confirmed by re-running
        // this test alone, where it passes reliably in ~5-10s well under the old 5s ceiling).
        XCTAssertTrue(app.descendants(matching: .any)["taskManagement.view"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["taskManagement.addMenuButton"].waitForExistence(timeout: 5))

        let assistantTab = app.tabBars.buttons["Whiskers"]
        XCTAssertTrue(assistantTab.waitForExistence(timeout: 5))
        assistantTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["taskAssistant.startChatButton"].waitForExistence(timeout: 5))

        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 5))
        moreTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["settings.view"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["settings.appSettings.row"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.shortcut.cats"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.shortcut.history"].waitForExistence(timeout: 5))

        app.buttons["settings.shortcut.cats"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["cats.view"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["settings.shortcut.history"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["history.view"].waitForExistence(timeout: 10))
    }

    /// Guards the `isSaving` re-entry guard in `TaskEditView.saveChanges`.
    ///
    /// `TaskFormPersistence.updateTask` is idempotent, so a second tap cannot duplicate the task.
    /// The regression this guards is a second update pass writing over the first one, which would
    /// leave the old row behind or resurrect the pre-edit title.
    func testTaskEditDoubleSaveTapUpdatesTaskOnce() {
        let originalTitle = "UI Test Task"
        let updatedTitle = "UI Test Task Updated"
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "tasks",
                "-seed-scenario", "pending_task"
            ]
        )
        app.launch()

        let originalRow = app.buttons["taskRow.\(originalTitle)"]
        XCTAssertTrue(originalRow.waitForExistence(timeout: 5))
        originalRow.tap()

        let titleField = app.textFields["taskEdit.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        replaceText(in: titleField, with: updatedTitle)

        let saveButton = app.buttons["taskEdit.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))

        // No wait between the taps. The stubbed notification layer resolves almost immediately, so
        // the sheet is usually gone before the second tap lands; `tapAgainIfStillPresent` keeps the
        // test deterministic. That makes this a regression guard on the update path, not a proof
        // that the `isSaving` guard holds under a real race. A real proof needs an injected delay.
        saveButton.tap()
        tapAgainIfStillPresent(saveButton)

        let updatedRow = app.buttons["taskRow.\(updatedTitle)"]
        XCTAssertTrue(updatedRow.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "taskRow.\(updatedTitle)").count, 1)
        XCTAssertFalse(app.buttons["taskRow.\(originalTitle)"].exists)
    }

    /// Guards the `isSaving` re-entry guard in `TaskAddView.createTask`.
    ///
    /// `TaskFormPersistence.createTask` is *not* idempotent, so a second tap that gets past the
    /// guard creates a second task. The row count is the assertion that matters here.
    func testTaskAddDoubleSaveTapCreatesTaskOnce() {
        let taskTitle = "UI Test Double Tap"
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-seed-scenario", "single_cat"
            ]
        )
        app.launch()

        openCustomTaskForm(in: app)
        fillCustomTaskForm(in: app, title: taskTitle)

        let saveButton = app.buttons["taskAdd.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))

        // Same timing caveat as the edit-sheet double-tap test above.
        saveButton.tap()
        tapAgainIfStillPresent(saveButton)

        XCTAssertTrue(app.buttons["taskRow.\(taskTitle)"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "taskRow.\(taskTitle)").count, 1)
    }

    /// Guards finding S1 on the edit sheet: a failed reminder schedule used to be `print()`-only.
    ///
    /// The sheet now raises an alert, stays open, and clears `isSaving` so the user can retry.
    func testTaskEditScheduleFailureKeepsSheetOpenAndAllowsRetry() {
        let updatedTitle = "UI Test Task Failed Schedule"
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "tasks",
                "-seed-scenario", "pending_task",
                "-fail-notification-schedule"
            ]
        )
        app.launch()

        let taskRow = app.buttons["taskRow.UI Test Task"]
        XCTAssertTrue(taskRow.waitForExistence(timeout: 5))
        taskRow.tap()

        let titleField = app.textFields["taskEdit.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))

        // `enableReminder` starts on, so the save takes the schedule path. Read it, do not tap it.
        let reminderToggle = app.switches["reminderRow.notificationsToggle"]
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggleState(for: reminderToggle), "on")

        replaceText(in: titleField, with: updatedTitle)

        let saveButton = app.buttons["taskEdit.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        let scheduleAlert = app.alerts[scheduleFailureAlertTitle]
        XCTAssertTrue(scheduleAlert.waitForExistence(timeout: 5))

        // Spec section 8, assertion 4 asks that the updated row not exist. A run proved that wrong:
        // finding P3 commits the update before the notification hop, so the list behind the sheet
        // already carries the new title, and XCUITest resolves elements behind a sheet. Assert both
        // real facts instead. `exists` fails if the update was rolled back; `isHittable` fails if
        // the sheet closed and let the row through, which is what assertion 4 was really after.
        let updatedRowBehindSheet = app.buttons["taskRow.\(updatedTitle)"]
        XCTAssertTrue(updatedRowBehindSheet.exists)
        XCTAssertFalse(updatedRowBehindSheet.isHittable)

        // The edit sheet's alert has an empty action block, so only the system dismiss button is up.
        let dismissAlertButton = scheduleAlert.buttons.firstMatch
        XCTAssertTrue(dismissAlertButton.waitForExistence(timeout: 5))
        dismissAlertButton.tap()
        XCTAssertTrue(scheduleAlert.waitForNonExistence(timeout: 5))

        XCTAssertTrue(app.textFields["taskEdit.titleField"].exists)

        // The difference from the add sheet: `updateTask` is idempotent, so a retry is safe and the
        // button has to come back enabled.
        XCTAssertTrue(app.buttons["taskEdit.saveButton"].isEnabled)
    }

    /// Guards #14: a one-tap completion whose reminders cannot be updated used to be `print()`-only.
    ///
    /// The completion stands, so the row reads as completed and the alert offers no retry.
    func testOneTapCompletionWithStaleRemindersWarnsAndCountsAsDone() {
        let app = launchStaleReminderCompletionScenario()

        let completeButton = app.buttons["taskRow.complete.UI Solo Task"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()

        acknowledgeReminderWarning(in: app)
        let completedValue = NSPredicate(format: "value CONTAINS %@", "Completed")
        let completed = expectation(for: completedValue, evaluatedWith: completeButton)
        wait(for: [completed], timeout: 5)
    }

    /// Guards #14 on the calendar, which completes through the same view model as the list.
    func testCalendarOneTapCompletionWithStaleRemindersWarns() {
        let app = launchStaleReminderCompletionScenario()

        let viewModeButton = app.buttons["taskManagement.viewModeButton"]
        XCTAssertTrue(viewModeButton.waitForExistence(timeout: 5))
        viewModeButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)["taskManagement.calendar"].waitForExistence(timeout: 5))

        let completeButton = app.buttons["taskRow.complete.UI Solo Task"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()

        acknowledgeReminderWarning(in: app)
    }

    /// Guards #14 on the completion sheet: the sheet closes, because the completion committed, and
    /// the warning appears once it has closed.
    func testSheetCompletionWithStaleRemindersClosesTheSheetThenWarns() {
        let app = launchStaleReminderCompletionScenario()

        let completeButton = app.buttons["taskRow.complete.UI Shared Task"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: 5))
        completeButton.tap()

        let selectAllButton = app.buttons["taskCompletionSelectAllButton"]
        XCTAssertTrue(selectAllButton.waitForExistence(timeout: 5))
        selectAllButton.tap()

        let confirmButton = app.buttons["taskCompletion.confirmButton"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        acknowledgeReminderWarning(in: app)
        XCTAssertFalse(confirmButton.exists)
    }

    private func launchStaleReminderCompletionScenario() -> XCUIApplication {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "tasks",
                "-seed-scenario", "shared_task_cat_deletion",
                "-fail-notification-schedule"
            ]
        )
        app.launch()
        return app
    }

    /// The warning's only button is OK; no retry is offered, because a retry would record twice.
    private func acknowledgeReminderWarning(in app: XCUIApplication) {
        let warning = app.alerts[scheduleFailureAlertTitle]
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertEqual(warning.buttons.count, 1)
        warning.buttons.firstMatch.tap()
        XCTAssertTrue(warning.waitForNonExistence(timeout: 5))
    }

    /// Guards finding P3: `saveChanges` re-baselines `initialSnapshot` right after `updateTask`
    /// succeeds, so the sheet must not warn about discarding edits that are already on disk.
    ///
    /// This is a separate test from the S1 one because `continueAfterFailure` is false.
    func testTaskEditScheduleFailureDismissesWithoutDiscardWarning() {
        let updatedTitle = "UI Test Task Failed Schedule"
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "tasks",
                "-seed-scenario", "pending_task",
                "-fail-notification-schedule"
            ]
        )
        app.launch()

        let taskRow = app.buttons["taskRow.UI Test Task"]
        XCTAssertTrue(taskRow.waitForExistence(timeout: 5))
        taskRow.tap()

        let titleField = app.textFields["taskEdit.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))

        // `enableReminder` starts on, so the save takes the schedule path. Read it, do not tap it.
        let reminderToggle = app.switches["reminderRow.notificationsToggle"]
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggleState(for: reminderToggle), "on")

        replaceText(in: titleField, with: updatedTitle)

        let saveButton = app.buttons["taskEdit.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        let scheduleAlert = app.alerts[scheduleFailureAlertTitle]
        XCTAssertTrue(scheduleAlert.waitForExistence(timeout: 5))
        scheduleAlert.buttons.firstMatch.tap()
        XCTAssertTrue(scheduleAlert.waitForNonExistence(timeout: 5))

        let cancelButton = app.buttons["taskEdit.cancelButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        // `SheetDismissButton` raises a confirmation dialog, not an alert. Match its destructive
        // button by label, which covers both the sheet and the alert presentation.
        XCTAssertFalse(app.buttons[discardChangesButtonTitle].waitForExistence(timeout: 2))

        XCTAssertTrue(app.textFields["taskEdit.titleField"].waitForNonExistence(timeout: 5))

        // The heart of P3: the edits were committed before the notification hop, so they survive.
        XCTAssertTrue(app.buttons["taskRow.\(updatedTitle)"].waitForExistence(timeout: 5))
    }

    /// Locks in the deliberate asymmetry of the add sheet.
    ///
    /// `TaskFormPersistence.createTask` is not idempotent, so a failed schedule leaves `isSaving`
    /// true and exits through the alert's own OK button instead of offering a retry.
    func testTaskAddScheduleFailureBlocksRetryAndDismissesThroughAlert() {
        let taskTitle = "UI Test Add Failed Schedule"
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-seed-scenario", "single_cat",
                "-fail-notification-schedule"
            ]
        )
        app.launch()

        openCustomTaskForm(in: app)
        fillCustomTaskForm(in: app, title: taskTitle)

        // `enableReminder` starts on, so the save takes the schedule path. Read it, do not tap it.
        let reminderToggle = app.switches["reminderRow.notificationsToggle"]
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggleState(for: reminderToggle), "on")

        let saveButton = app.buttons["taskAdd.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        let scheduleAlert = app.alerts[scheduleFailureAlertTitle]
        XCTAssertTrue(scheduleAlert.waitForExistence(timeout: 5))

        // The edit sheet's alerts carry no such button, and that difference is the point.
        let okButton = scheduleAlert.buttons["OK"]
        XCTAssertTrue(okButton.waitForExistence(timeout: 5))

        // Spec section 10 assertion 3 is deliberately absent. `isEnabled` reports `false` for an
        // element that does not resolve, and XCUITest may scope queries to the modal alert, so the
        // assertion could not fail for the reason the test cares about. Section 10's own UNVERIFIED
        // note permits dropping it and relying on the row count below, which is not vacuous.
        okButton.tap()

        XCTAssertTrue(app.textFields["taskAdd.titleField"].waitForNonExistence(timeout: 5))

        // The task was created once, and the failed reminder did not roll it back.
        XCTAssertTrue(app.buttons["taskRow.\(taskTitle)"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "taskRow.\(taskTitle)").count, 1)
    }

    private func makeApp(additionalArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US"
        ] + additionalArguments
        return app
    }

    /// Taps an element a second time, but only while it is still on screen.
    ///
    /// A save button whose sheet has already closed is not a test failure: the sheet closing is the
    /// wanted outcome. The assertion that matters is the row count after the taps.
    private func tapAgainIfStillPresent(_ element: XCUIElement) {
        guard element.exists, element.isHittable else { return }

        element.tap()
    }

    /// Waits for an element to report `isHittable == true`.
    ///
    /// Toolbar/chrome morph animations (e.g. Liquid Glass) can leave an element in the
    /// accessibility tree, and passing `waitForExistence`, before it is actually tappable.
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: element)
        wait(for: [hittable], timeout: timeout)
    }

    /// Navigates from a fresh launch to an open custom-task add sheet.
    private func openCustomTaskForm(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5), file: file, line: line)
        tasksTab.tap()

        let addMenuButton = app.buttons["taskManagement.addMenuButton"]
        XCTAssertTrue(addMenuButton.waitForExistence(timeout: 5), file: file, line: line)
        addMenuButton.tap()

        let customTaskButton = app.buttons["taskManagement.customTaskButton"]
        XCTAssertTrue(customTaskButton.waitForExistence(timeout: 5), file: file, line: line)
        customTaskButton.tap()
    }

    /// Fills the open add sheet with a title and the seeded cat, so Save can succeed.
    private func fillCustomTaskForm(
        in app: XCUIApplication,
        title: String,
        catName: String = "UI Test Cat",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let titleField = app.textFields["taskAdd.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), file: file, line: line)
        titleField.tap()
        titleField.typeText(title)

        // Dismiss the keyboard before tapping rows near its edge; on iOS 26 the
        // keyboard-avoidance layout shift can otherwise swallow the tap.
        let keyboardDoneButton = app.toolbars.buttons["Done"]
        if keyboardDoneButton.waitForExistence(timeout: 2) {
            keyboardDoneButton.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), file: file, line: line)
        }

        let catsButton = app.buttons["taskAdd.catsButton"]
        XCTAssertTrue(catsButton.waitForExistence(timeout: 5), file: file, line: line)
        catsButton.tap()

        let catOption = app.buttons["taskCatsSelection.cat.\(catName)"]
        XCTAssertTrue(catOption.waitForExistence(timeout: 5), file: file, line: line)
        catOption.tap()

        let doneButton = app.buttons["taskCatsSelection.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), file: file, line: line)
        doneButton.tap()
    }

    private func dismissAssistantCloudConsentIfNeeded(in app: XCUIApplication) {
        let declineConsent = app.buttons["Don't Allow"]
        if declineConsent.waitForExistence(timeout: 3) {
            declineConsent.tap()
            XCTAssertTrue(declineConsent.waitForNonExistence(timeout: 5))
        }
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func replaceText(in element: XCUIElement, with text: String) {
        element.tap()

        if let currentValue = element.value as? String, currentValue.isEmpty == false, currentValue != element.placeholderValue {
            element.press(forDuration: 1.0)

            let selectAllMenuItem = XCUIApplication().menuItems["Select All"]
            if selectAllMenuItem.waitForExistence(timeout: 1) {
                selectAllMenuItem.tap()
                element.typeText(XCUIKeyboardKey.delete.rawValue)
            } else {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
                element.typeText(deleteString)
            }
        }

        element.typeText(text)
    }

    private func toggleState(
        for element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String {
        let candidates = [
            element.value as? String,
            String(describing: element.value),
            element.label
        ]

        for candidate in candidates {
            let normalized = normalizedToggleState(from: candidate)
            if normalized.isEmpty == false {
                return normalized
            }
        }

        XCTFail("Expected a stable toggle accessibility state.", file: file, line: line)
        return ""
    }

    private func waitForToggleState(
        _ state: String,
        in element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(5)

        repeat {
            if toggleState(for: element, file: file, line: line) == state {
                return
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        XCTFail("Expected toggle state to become \(state).", file: file, line: line)
    }

    private func normalizedToggleState(from rawValue: String?) -> String {
        guard let rawValue else { return "" }

        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalized == "1" || normalized == "on" {
            return "on"
        }

        if normalized == "0" || normalized == "off" {
            return "off"
        }

        return ""
    }

    private func tapSwitchControl(_ element: XCUIElement) {
        let switchCoordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        switchCoordinate.tap()
    }

    /// Guards the fix in `ReminderMenuRow`: the notifications `Menu` used to sit inside a
    /// `.disabled(!enableReminder)` subtree that also contained the `Toggle`, so turning the
    /// reminder off disabled the very control that could turn it back on. The round trip in
    /// steps 3-6 is the assertion that matters — a test that only turns the toggle off would
    /// still pass against the broken code.
    private func assertReminderToggleRoundTripKeepsMenuReachable(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let reminderToggle = app.switches["reminderRow.notificationsToggle"]
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: 5), file: file, line: line)

        let notificationsMenu = app.buttons["reminderRow.notificationsMenu"]
        XCTAssertTrue(notificationsMenu.waitForExistence(timeout: 5), file: file, line: line)

        XCTAssertEqual(toggleState(for: reminderToggle, file: file, line: line), "on", file: file, line: line)
        XCTAssertTrue(notificationsMenu.isEnabled, file: file, line: line)

        tapSwitchControl(reminderToggle)
        waitForToggleState("off", in: reminderToggle, file: file, line: line)
        XCTAssertFalse(
            notificationsMenu.isEnabled,
            "The menu row must disable while the reminder is off.",
            file: file,
            line: line
        )

        tapSwitchControl(reminderToggle)
        waitForToggleState("on", in: reminderToggle, file: file, line: line)
        XCTAssertTrue(
            notificationsMenu.isEnabled,
            "The menu row must become reachable again once the reminder is back on — this is the regression.",
            file: file,
            line: line
        )
    }

}

private extension XCUIElement {
    var placeholderValue: String? {
        value as? String == label ? label : nil
    }
}
