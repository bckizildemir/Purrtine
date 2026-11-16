import XCTest

@MainActor
final class CriticalFlowsUITests: XCTestCase {
    /// `error.reminder_schedule`. The tests force `en_US`, so the literal is stable.
    private let scheduleFailureAlertTitle = "Could not set up reminders"

    /// `sheet.discard.confirm`, the destructive button of `SheetDismissButton`'s dialog.
    private let discardChangesButtonTitle = "Discard Changes"

    /// Ceiling for a wait on an element that must appear (#152). `waitForExistence` returns as soon
    /// as the element is there, so a passing test pays nothing extra. On a slow CI runner a single
    /// accessibility query took 8-13 s (build-14 run 43761755575), longer than the old 5 s ceiling.
    private let uiTimeout: TimeInterval = 15

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Synchronous on purpose (#152). With `continueAfterFailure = false`, an `async` tearDown made
    /// the test runner exit after every failed test; xcodebuild then restarted it on the remaining
    /// tests, and `-retry-tests-on-failure` never ran the failed test again.
    override func tearDownWithError() throws {
        guard let testRun, testRun.failureCount > 0 else { return }
        attachScreenshot(named: "\(name)-failure-screenshot")
    }

    func testOnboardingHappyPathCreatesStarterTask() {
        let app = makeApp(additionalArguments: ["-reset-onboarding"])
        app.launch()

        XCTAssertTrue(app.buttons["onboarding.welcome.continueButton"].waitForExistence(timeout: uiTimeout))
        app.buttons["onboarding.welcome.continueButton"].tap()

        XCTAssertTrue(app.buttons["onboarding.notification.skipButton"].waitForExistence(timeout: uiTimeout))
        app.buttons["onboarding.notification.skipButton"].tap()

        let nameField = app.textFields["catForm.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: uiTimeout))
        typeText("Mochi", into: nameField)

        app.buttons["onboarding.firstCat.continueButton"].tap()

        let feedingDemo = app.buttons["onboarding.taskDemo.feeding"]
        XCTAssertTrue(feedingDemo.waitForExistence(timeout: uiTimeout))
        feedingDemo.tap()

        app.buttons["onboarding.taskSetup.continueButton"].tap()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: uiTimeout))
        tasksTab.tap()

        XCTAssertTrue(app.buttons["taskRow.Daily Feeding"].waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.buttons["taskRow.Refresh Water"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["taskRow.Litter Box Cleaning"].waitForExistence(timeout: 1))
    }

    func testOnboardingWithoutStarterTasksShowsTasksEmptyState() {
        let app = makeApp(additionalArguments: ["-reset-onboarding"])
        app.launch()

        XCTAssertTrue(app.buttons["onboarding.welcome.continueButton"].waitForExistence(timeout: uiTimeout))
        app.buttons["onboarding.welcome.continueButton"].tap()
        XCTAssertTrue(app.buttons["onboarding.notification.skipButton"].waitForExistence(timeout: uiTimeout))
        app.buttons["onboarding.notification.skipButton"].tap()

        let nameField = app.textFields["catForm.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: uiTimeout))
        typeText("Mochi", into: nameField)
        app.buttons["onboarding.firstCat.continueButton"].tap()

        let startButton = app.buttons["onboarding.taskSetup.continueButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: uiTimeout))
        startButton.tap()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: uiTimeout))
        tasksTab.tap()

        XCTAssertTrue(app.staticTexts["No Tasks Found"].waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow.'")).firstMatch.exists)
    }

    func testOnboardingActionFootersStayAligned() {
        let app = makeApp(additionalArguments: ["-reset-onboarding"])
        app.launch()

        let welcomeContinue = app.buttons["onboarding.welcome.continueButton"]
        XCTAssertTrue(welcomeContinue.waitForExistence(timeout: uiTimeout))
        let primaryActionY = welcomeContinue.frame.minY
        welcomeContinue.tap()

        let notificationContinue = app.buttons["onboarding.notification.enableButton"]
        let notificationSkip = app.buttons["onboarding.notification.skipButton"]
        XCTAssertTrue(notificationContinue.waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(notificationSkip.exists)
        XCTAssertEqual(notificationContinue.frame.minY, primaryActionY, accuracy: 1)
        let secondaryActionY = notificationSkip.frame.minY
        notificationSkip.tap()

        let firstCatContinue = app.buttons["onboarding.firstCat.continueButton"]
        let firstCatSkip = app.buttons["onboarding.firstCat.skipButton"]
        XCTAssertTrue(firstCatContinue.waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(firstCatSkip.exists)
        XCTAssertEqual(firstCatContinue.frame.minY, primaryActionY, accuracy: 1)
        XCTAssertEqual(firstCatSkip.frame.minY, secondaryActionY, accuracy: 1)

        firstCatSkip.tap()

        let taskContinue = app.buttons["onboarding.taskSetup.continueButton"]
        XCTAssertTrue(taskContinue.waitForExistence(timeout: uiTimeout))
        XCTAssertEqual(taskContinue.frame.minY, primaryActionY, accuracy: 1)
    }

    func testTaskCreateAndCompleteFlow() async {
        let taskTitle = "UI Test One-Time Task"
        let app = makeApp(additionalArguments: ["-complete-onboarding", "-seed-single-cat"])
        app.launch()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: uiTimeout))
        tasksTab.tap()

        let addMenuButton = app.buttons["taskManagement.addMenuButton"]
        XCTAssertTrue(addMenuButton.waitForExistence(timeout: uiTimeout))
        addMenuButton.tap()

        let customTaskButton = app.buttons["taskManagement.customTaskButton"]
        XCTAssertTrue(customTaskButton.waitForExistence(timeout: uiTimeout))
        customTaskButton.tap()

        let titleField = app.textFields["taskAdd.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: uiTimeout))
        typeText(taskTitle, into: titleField)

        // Dismiss the keyboard before tapping rows near its edge; on iOS 26 the
        // keyboard-avoidance layout shift can otherwise swallow the tap.
        dismissKeyboardIfPresent(in: app)

        let catsButton = app.buttons["taskAdd.catsButton"]
        XCTAssertTrue(catsButton.waitForExistence(timeout: uiTimeout))
        catsButton.tap()

        let catOption = app.buttons["taskCatsSelection.cat.UI Test Cat"]
        XCTAssertTrue(catOption.waitForExistence(timeout: uiTimeout))
        catOption.tap()

        let doneButton = app.buttons["taskCatsSelection.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: uiTimeout))
        doneButton.tap()

        let saveButton = app.buttons["taskAdd.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiTimeout))
        saveButton.tap()

        XCTAssertTrue(app.buttons["taskRow.\(taskTitle)"].waitForExistence(timeout: uiTimeout))

        let completeButton = app.buttons["taskRow.complete.\(taskTitle)"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: uiTimeout))
        completeButton.tap()

        let completedValue = NSPredicate(format: "value CONTAINS %@", "Completed")
        let completed = expectation(for: completedValue, evaluatedWith: completeButton)
        await fulfillment(of: [completed], timeout: 5)
    }

    func testTaskAddCatsButtonAnnouncesSingleHintWhenNoCatsExist() {
        let app = makeApp(additionalArguments: ["-complete-onboarding"])
        app.launch()

        let customTaskQuickAction = app.buttons["Custom Task"]
        XCTAssertTrue(customTaskQuickAction.waitForExistence(timeout: uiTimeout))
        customTaskQuickAction.tap()

        let catsButton = app.buttons["taskAdd.catsButton"]
        XCTAssertTrue(catsButton.waitForExistence(timeout: uiTimeout))
        XCTAssertEqual(catsButton.value as? String, "Add a cat first to assign this task")
    }

    func testTemplateScrollDoesNotSelectCardAndVaccinationCanBeSelectedDeliberately() {
        let app = makeApp(additionalArguments: ["-complete-onboarding", "-seed-single-cat"])
        app.launch()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: uiTimeout))
        tasksTab.tap()

        let addMenuButton = app.buttons["taskManagement.addMenuButton"]
        XCTAssertTrue(addMenuButton.waitForExistence(timeout: uiTimeout))
        addMenuButton.tap()

        let templateTaskButton = app.buttons["taskManagement.templateTaskButton"]
        XCTAssertTrue(templateTaskButton.waitForExistence(timeout: uiTimeout))
        templateTaskButton.tap()

        let feedingTemplate = app.buttons["taskTemplate.morningFeeding"].firstMatch
        XCTAssertTrue(feedingTemplate.waitForExistence(timeout: uiTimeout))
        feedingTemplate.swipeUp()

        XCTAssertTrue(feedingTemplate.waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.textFields["taskAdd.titleField"].exists)

        let veterinaryCategory = app.buttons["taskTemplate.category.vet"]
        XCTAssertTrue(veterinaryCategory.waitForExistence(timeout: uiTimeout))
        veterinaryCategory.tap()

        let vaccinationTemplate = app.buttons["taskTemplate.vaccination"].firstMatch
        XCTAssertTrue(vaccinationTemplate.waitForExistence(timeout: uiTimeout))
        vaccinationTemplate.tap()
        XCTAssertTrue(app.textFields["taskAdd.titleField"].waitForExistence(timeout: uiTimeout))
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

        XCTAssertTrue(taskList.waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(tabBar.waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(viewModeButton.waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(addButton.waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(assistantTab.waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.buttons["taskManagement.assistantButton"].exists)
        XCTAssertTrue(firstTask.waitForExistence(timeout: uiTimeout))

        if #available(iOS 26.0, *) {
            XCTAssertGreaterThanOrEqual(taskList.frame.maxY, tabBar.frame.minY)
            XCTAssertEqual(viewModeButton.frame.midY, addButton.frame.midY, accuracy: 2)
            XCTAssertLessThan(viewModeButton.frame.midX, addButton.frame.midX)

            // #67 moved the filter row into a top safe-area inset on the list, so the filter row
            // and the section header now travel inside the list and the list itself starts at
            // the top of the content area. The first row therefore sits below that chrome
            // instead of 64 pt under the list top; what stays true on any device is that the
            // chrome is above the first row and the row is clear of the floating tab bar.
            let taskSearchField = app.searchFields.firstMatch
            XCTAssertTrue(taskSearchField.waitForExistence(timeout: uiTimeout))
            XCTAssertGreaterThan(firstTask.frame.minY, taskSearchField.frame.maxY)
            XCTAssertLessThan(firstTask.frame.maxY, tabBar.frame.minY)

            attachScreenshot(named: "Tasks-iOS26-expanded")

            let lastTask = app.buttons["taskRow.UI Test Long Task 18"]
            let firstObstructionY = tabBar.frame.minY
            for _ in 0..<12
            where !lastTask.exists || lastTask.frame.maxY > firstObstructionY + 2 {
                taskList.swipeUp()
            }

            XCTAssertTrue(lastTask.waitForExistence(timeout: uiTimeout))
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
            XCTAssertTrue(assistantTab.waitForExistence(timeout: uiTimeout))

            viewModeButton.tap()

            let calendar = app.descendants(matching: .any)["taskManagement.calendar"]
            XCTAssertTrue(calendar.waitForExistence(timeout: uiTimeout))

            // Calendar mode scrolls through the month header/grid before reaching the task
            // list, and calendar task rows are taller than list-mode rows, so it needs more
            // swipes than list mode to reach the last row.
            for _ in 0..<24
            where !lastTask.exists || lastTask.frame.maxY > tabBar.frame.minY + 2 {
                calendar.swipeUp()
            }

            XCTAssertTrue(lastTask.waitForExistence(timeout: uiTimeout))
            XCTAssertTrue(lastTask.isHittable)
            XCTAssertLessThanOrEqual(lastTask.frame.maxY, tabBar.frame.minY + 2)
            attachScreenshot(named: "Tasks-iOS26-calendar-clearance")

            // Calendar scrolling minimized the bar again; scroll back up to restore the
            // assistant tab so the shared assistantTab.tap() below can reach it.
            for _ in 0..<24 where !assistantTab.exists {
                calendar.swipeDown()
            }
            XCTAssertTrue(assistantTab.waitForExistence(timeout: uiTimeout))
        } else {
            XCTAssertEqual(viewModeButton.frame.midY, addButton.frame.midY, accuracy: 2)
            XCTAssertLessThan(viewModeButton.frame.midX, addButton.frame.midX)
        }

        assistantTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["taskAssistant.startChatButton"].waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.textFields["taskAssistant.input"].exists)

        let selectedTasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(selectedTasksTab.waitForExistence(timeout: uiTimeout))
        selectedTasksTab.tap()

        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: uiTimeout))
        homeTab.tap()
        XCTAssertFalse(app.buttons["taskManagement.assistantButton"].waitForExistence(timeout: 1))

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: uiTimeout))
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

        XCTAssertTrue(app.textFields["taskAdd.titleField"].waitForExistence(timeout: uiTimeout))
    }

    func testTaskAssistantTabIsAvailableWithoutCats() {
        let app = makeApp(additionalArguments: ["-complete-onboarding", "-launch-route", "tasks"])
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["taskManagement.view"].waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.buttons["taskManagement.assistantButton"].exists)

        let assistantTab = app.tabBars.buttons["Whiskers"]
        XCTAssertTrue(assistantTab.waitForExistence(timeout: uiTimeout))
        assistantTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["taskAssistant.startChatButton"].waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.textFields["taskAssistant.input"].exists)
    }

    func testTaskAssistantEndChatResetsConversation() {
        let app = makeApp(additionalArguments: ["-complete-onboarding", "-launch-route", "home"])
        app.launch()

        let assistantTab = app.tabBars.buttons["Whiskers"]
        XCTAssertTrue(assistantTab.waitForExistence(timeout: uiTimeout))
        assistantTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["taskAssistant.startChatButton"].waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.textFields["taskAssistant.input"].exists)

        app.buttons["taskAssistant.startChatButton"].tap()
        dismissAssistantCloudConsentIfNeeded(in: app)

        let input = app.textFields["taskAssistant.input"]
        XCTAssertTrue(input.waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        typeText("unfinished task request", into: input)

        let endChatButton = app.buttons["taskAssistant.endChatButton"]
        XCTAssertTrue(endChatButton.waitForExistence(timeout: uiTimeout))
        endChatButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["taskAssistant.startChatButton"].waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.buttons["taskAssistant.continueChatButton"].exists)

        app.buttons["taskAssistant.startChatButton"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(assistantTab.waitForExistence(timeout: uiTimeout))
        assistantTab.tap()

        let suggestion = app.buttons["taskAssistant.quickAction.UI Test Task"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: uiTimeout))
        suggestion.tap()
        dismissAssistantCloudConsentIfNeeded(in: app)

        XCTAssertTrue(app.textFields["taskAssistant.input"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["taskAssistant.confirmButton"].waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(assistantTab.waitForExistence(timeout: uiTimeout))
        assistantTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: uiTimeout))
        app.buttons["taskAssistant.startChatButton"].tap()

        dismissAssistantCloudConsentIfNeeded(in: app)

        let input = app.textFields["taskAssistant.input"]
        XCTAssertTrue(input.waitForExistence(timeout: uiTimeout))
        typeText("open UI Test Task", into: input)

        let sendButton = app.buttons["Send task message"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: uiTimeout))
        sendButton.tap()

        let confirmButton = app.buttons["Confirm"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: uiTimeout))
        confirmButton.tap()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(tasksTab.isSelected)
        XCTAssertTrue(app.textFields["taskEdit.titleField"].waitForExistence(timeout: 10))
    }

    func testAssistantDisambiguationCardScrollsIntoViewWhenAmbiguous() {
        // `long_task_list` seeds one cat + 18 identically-titled ".general" tasks, so the
        // ambiguous "complete long task" ties every candidate and forces a disambiguation card
        // (header + three task rows + Cancel) taller than the viewport with the keyboard up —
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
        XCTAssertTrue(assistantTab.waitForExistence(timeout: uiTimeout))
        assistantTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: uiTimeout))
        app.buttons["taskAssistant.startChatButton"].tap()

        // First launch presents the cloud-consent sheet over the assistant. The heuristic
        // disambiguation path never uses the cloud, so decline it if it appears. Match the
        // button by label — the sheet container's accessibility id isn't a queryable element.
        dismissAssistantCloudConsentIfNeeded(in: app)

        // Tap the focused chat's identified composer, type, and keep the keyboard up.
        let input = app.textFields["taskAssistant.input"]
        XCTAssertTrue(input.waitForExistence(timeout: uiTimeout))
        typeText("complete long task", into: input)

        let sendButton = app.buttons["Send task message"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: uiTimeout))
        sendButton.tap()

        // The card's trailing Cancel button is its last element and exists in the hierarchy even
        // when off-screen. With the shipped bug the chat did not auto-scroll to reveal the card
        // (keyboard up), so it was not hittable. The fix must scroll it in.
        let cancelDisambiguation = app.buttons["taskAssistant.cancelTaskDisambiguationButton"]
        XCTAssertTrue(cancelDisambiguation.waitForExistence(timeout: uiTimeout))
        // The button exists as soon as the card is inserted; the auto-scroll lands a moment later
        // (after the card's transition and the keyboard settle), so poll for it instead of
        // reading `isHittable` once. No manual swipe: only the app's own scroll can pass.
        let becameHittable = expectation(
            for: NSPredicate(format: "isHittable == true"),
            evaluatedWith: cancelDisambiguation
        )
        let waitResult = XCTWaiter().wait(for: [becameHittable], timeout: 5)
        XCTAssertTrue(
            waitResult == .completed,
            "Disambiguation card's trailing Cancel button must be on-screen — the chat should auto-scroll the card into view after send."
        )
        // The bug needs the keyboard up. The composer is disabled while the assistant works, which
        // can drop it, so prove the precondition still held when the card was on-screen.
        XCTAssertTrue(app.keyboards.firstMatch.exists, "The keyboard must still be up for this test to prove the bug.")
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
        XCTAssertTrue(originalRow.waitForExistence(timeout: uiTimeout))
        originalRow.tap()

        let titleField = app.textFields["taskEdit.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: uiTimeout))
        replaceText(in: titleField, with: updatedTitle)

        let saveButton = app.buttons["taskEdit.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiTimeout))
        saveButton.tap()

        let updatedRow = app.buttons["taskRow.\(updatedTitle)"]
        XCTAssertTrue(updatedRow.waitForExistence(timeout: uiTimeout))

        let deleteButton = app.buttons["taskRow.delete.\(updatedTitle)"].firstMatch
        performGesture(on: updatedRow, revealing: deleteButton) {
            updatedRow.swipeLeft()
        }
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
        XCTAssertTrue(taskRow.waitForExistence(timeout: uiTimeout))
        taskRow.tap()

        XCTAssertTrue(app.textFields["taskEdit.titleField"].waitForExistence(timeout: uiTimeout))

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
        XCTAssertTrue(tasksTab.waitForExistence(timeout: uiTimeout))
        tasksTab.tap()

        let addMenuButton = app.buttons["taskManagement.addMenuButton"]
        XCTAssertTrue(addMenuButton.waitForExistence(timeout: uiTimeout))
        addMenuButton.tap()

        let customTaskButton = app.buttons["taskManagement.customTaskButton"]
        XCTAssertTrue(customTaskButton.waitForExistence(timeout: uiTimeout))
        customTaskButton.tap()

        XCTAssertTrue(app.textFields["taskAdd.titleField"].waitForExistence(timeout: uiTimeout))

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
        XCTAssertTrue(row.waitForExistence(timeout: uiTimeout))
        row.tap()

        let caregiverButton = app.buttons["taskEdit.caregiverButton"]
        XCTAssertTrue(caregiverButton.waitForExistence(timeout: uiTimeout))
        // The seeded task is assigned to the default ("Myself") caregiver.
        XCTAssertFalse(caregiverButton.label.contains(newCaregiver))
        caregiverButton.tap()

        let option = app.buttons[newCaregiver]
        XCTAssertTrue(option.waitForExistence(timeout: uiTimeout))
        option.tap()

        XCTAssertTrue(caregiverButton.label.contains(newCaregiver))

        let saveButton = app.buttons["taskEdit.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiTimeout))
        saveButton.tap()

        // Reopen the same task to confirm the reassignment persisted.
        XCTAssertTrue(row.waitForExistence(timeout: uiTimeout))
        row.tap()

        let reopenedCaregiverButton = app.buttons["taskEdit.caregiverButton"]
        XCTAssertTrue(reopenedCaregiverButton.waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(addButton.waitForExistence(timeout: uiTimeout))
        addButton.tap()

        let nameField = app.textFields["catForm.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: uiTimeout))
        typeText(newCatName, into: nameField)

        let saveButton = app.buttons["catForm.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiTimeout))
        saveButton.tap()

        let newCatCard = app.buttons["cats.card.\(newCatName)"]
        XCTAssertTrue(newCatCard.waitForExistence(timeout: uiTimeout))
        newCatCard.tap()

        let editButton = app.buttons["catDetail.editButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: uiTimeout))
        editButton.tap()

        let editNameField = app.textFields["catForm.nameField"]
        XCTAssertTrue(editNameField.waitForExistence(timeout: uiTimeout))
        replaceText(in: editNameField, with: updatedCatName)
        app.buttons["catForm.saveButton"].tap()

        XCTAssertTrue(editButton.waitForExistence(timeout: uiTimeout))
        editButton.tap()

        let persistedNameField = app.textFields["catForm.nameField"]
        XCTAssertTrue(persistedNameField.waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(catCard.waitForExistence(timeout: uiTimeout))
        catCard.tap()

        XCTAssertTrue(app.descendants(matching: .any)["catDetail.emptyState"].waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(catCard.waitForExistence(timeout: uiTimeout))
        catCard.tap()

        let basicInformationSection = app.descendants(matching: .any)["catDetail.basicInformationSection"]
        XCTAssertTrue(basicInformationSection.waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(app.descendants(matching: .any)["catDetail.emptyState"].waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(primaryCatCard.waitForExistence(timeout: uiTimeout))
        primaryCatCard.tap()

        let editButton = app.buttons["catDetail.editButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: uiTimeout))
        editButton.tap()

        let deleteButton = app.buttons["catForm.deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.staticTexts["Danger Zone"].exists)
        deleteButton.tap()

        let confirmDeleteButton = app.alerts.buttons["Delete"].firstMatch
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: uiTimeout))
        confirmDeleteButton.tap()

        if app.descendants(matching: .any)["cats.view"].waitForExistence(timeout: 2) == false {
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.waitForExistence(timeout: 2) {
                backButton.tap()
            }
        }

        XCTAssertTrue(app.descendants(matching: .any)["cats.view"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["cats.card.UI Second Test Cat"].waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.buttons["cats.card.UI Test Cat"].waitForExistence(timeout: 2))

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: uiTimeout))
        tasksTab.tap()

        XCTAssertTrue(app.buttons["taskRow.UI Shared Task"].waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.buttons["taskRow.UI Solo Task"].waitForExistence(timeout: 2))
    }

    /// #19: a failed commit keeps the cat gone, and the cats screen says the delete is not saved yet.
    func testCatDeleteCommitFailureShowsPendingSaveNote() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "cats",
                "-seed-scenario", "shared_task_cat_deletion",
                "-fail-cat-delete-commit"
            ]
        )
        app.launch()

        deletePrimaryCatFromEditCat(in: app)

        assertCatDeletionAlert(in: app, title: "Delete Not Saved Yet")
    }

    /// #19: a reminder failure after the commit keeps the cat gone and shows the reminder warning.
    func testCatDeleteReminderFailureShowsReminderWarning() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "cats",
                "-seed-scenario", "shared_task_cat_deletion",
                "-fail-notification-schedule"
            ]
        )
        app.launch()

        deletePrimaryCatFromEditCat(in: app)

        assertCatDeletionAlert(in: app, title: scheduleFailureAlertTitle)
    }

    /// #31: the card menu's Delete reports a failed commit once its confirmation has closed.
    func testCatCardMenuDeleteCommitFailureShowsPendingSaveNote() {
        let app = launchCatDeletionFailureScenario(failureFlag: "-fail-cat-delete-commit", keepsAnimations: true)

        deletePrimaryCatFromCardMenu(in: app)

        assertCatDeletionAlert(in: app, title: "Delete Not Saved Yet")
    }

    /// #31: the card menu's Delete reports a reminder failure after the commit.
    func testCatCardMenuDeleteReminderFailureShowsReminderWarning() {
        let app = launchCatDeletionFailureScenario(failureFlag: "-fail-notification-schedule", keepsAnimations: true)

        deletePrimaryCatFromCardMenu(in: app)

        assertCatDeletionAlert(in: app, title: scheduleFailureAlertTitle)
    }

    /// #31: Edit Cat opened from the card leaves with the card, so its note must not depend on the
    /// order of the sheet closing and the delete finishing.
    func testCatCardEditDeleteCommitFailureShowsPendingSaveNote() {
        let app = launchCatDeletionFailureScenario(failureFlag: "-fail-cat-delete-commit", keepsAnimations: true)

        deletePrimaryCatFromCardEditCat(in: app)

        assertCatDeletionAlert(in: app, title: "Delete Not Saved Yet")
    }

    /// #31: here the sheet closes before the reminder refresh fails, which used to lose the note.
    func testCatCardEditDeleteReminderFailureShowsReminderWarning() {
        let app = launchCatDeletionFailureScenario(failureFlag: "-fail-notification-schedule", keepsAnimations: true)

        deletePrimaryCatFromCardEditCat(in: app)

        assertCatDeletionAlert(in: app, title: scheduleFailureAlertTitle)
    }

    /// - Parameter keepsAnimations: Keeps the confirmation's and the sheet's dismissal animations on,
    ///   so the note races them the way it does on a device (#31).
    private func launchCatDeletionFailureScenario(failureFlag: String, keepsAnimations: Bool) -> XCUIApplication {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "cats",
                "-seed-scenario", "shared_task_cat_deletion",
                failureFlag
            ] + (keepsAnimations ? ["-keep-animations"] : [])
        )
        app.launch()
        return app
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
        XCTAssertTrue(app.buttons["taskRow.UI Solo Task"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["taskRow.UI Shared Task"].waitForExistence(timeout: uiTimeout))

        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: uiTimeout))
        moreTab.tap()

        let catsShortcut = app.buttons["settings.shortcut.cats"]
        XCTAssertTrue(catsShortcut.waitForExistence(timeout: uiTimeout))
        catsShortcut.tap()

        let primaryCatCard = app.buttons["cats.card.UI Test Cat"]
        XCTAssertTrue(primaryCatCard.waitForExistence(timeout: uiTimeout))
        primaryCatCard.tap()

        let editButton = app.buttons["catDetail.editButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: uiTimeout))
        editButton.tap()

        let deleteButton = app.buttons["catForm.deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: uiTimeout))
        deleteButton.tap()

        let confirmDeleteButton = app.alerts.buttons["Delete"].firstMatch
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: uiTimeout))
        confirmDeleteButton.tap()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: uiTimeout))
        tasksTab.tap()

        XCTAssertTrue(app.buttons["taskRow.UI Shared Task"].waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(catCard.waitForExistence(timeout: uiTimeout))
        scrollUntilHittable(catCard, in: app)
        let addTaskMenuItem = app.buttons["Add Task"]
        // #152: on a slow runner the long press can reach the card as a plain tap, which pushes
        // the cat's detail screen instead of opening the menu (CI runs 43761755575, 43323567565:
        // the retry then found the detail screen, not the card). Hold well past the context-menu
        // threshold, and before the retry go back to the list if the press opened the detail.
        performGesture(
            on: catCard,
            revealing: addTaskMenuItem,
            recover: { self.returnToCatsListIfDetailOpened(in: app, card: catCard) },
            gesture: { catCard.press(forDuration: 2.0) }
        )
        addTaskMenuItem.tap()

        XCTAssertTrue(app.textFields["taskAdd.titleField"].waitForExistence(timeout: uiTimeout))

        let catsButton = app.buttons["taskAdd.catsButton"]
        XCTAssertTrue(catsButton.waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(catsButton.label.localizedStandardContains("UI Test Cat"))
    }

    func testHistoryShowsNoTasksStateWhenSeededWithNoTasks() {
        let app = makeApp(additionalArguments: ["-complete-onboarding", "-launch-route", "history"])
        app.launch()

        XCTAssertTrue(app.buttons["Create Your First Task"].waitForExistence(timeout: uiTimeout))
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

        XCTAssertTrue(app.staticTexts["UI Test Completed Task"].waitForExistence(timeout: uiTimeout))
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

        XCTAssertTrue(app.descendants(matching: .any)["history.view"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.staticTexts["No statistics yet"].waitForExistence(timeout: uiTimeout))
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

        XCTAssertTrue(app.descendants(matching: .any)["home.view"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.descendants(matching: .any)["home.currentTasks.section"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["home.currentTask.UI Test Overdue Task"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["home.currentTask.UI Test Task"].waitForExistence(timeout: uiTimeout))

        let routineStatusSection = app.descendants(matching: .any)["home.routineStatus.section"]
        XCTAssertTrue(routineStatusSection.waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(completeButton.waitForExistence(timeout: uiTimeout))

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
        XCTAssertTrue(taskRow.waitForExistence(timeout: uiTimeout))

        let completeButton = app.buttons["taskRow.complete.UI Test Task"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: uiTimeout))

        let settingsTab = app.tabBars.buttons["More"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: uiTimeout))
        settingsTab.tap()

        let settingsView = app.descendants(matching: .any)["settings.view"].firstMatch
        XCTAssertTrue(settingsView.waitForExistence(timeout: uiTimeout))

        let developerToolsButton = app.buttons["settings.developerTools"]
        XCTAssertTrue(developerToolsButton.waitForExistence(timeout: uiTimeout))
        scrollUntilHittable(developerToolsButton, in: app)

        let notificationHistoryButton = app.buttons["developerTools.notificationHistory"]
        tap(developerToolsButton, opening: notificationHistoryButton)

        let notificationHistoryView = app.descendants(matching: .any)["notificationHistory.view"]
        tap(notificationHistoryButton, opening: notificationHistoryView)
        XCTAssertTrue(app.staticTexts["UI Test Task"].waitForExistence(timeout: uiTimeout))
    }

    /// #39: a caregiver whose photo did not save still saves, the sheet closes, and the caregiver
    /// list shows the note once the sheet has left. Animations stay on, so the note has to wait for
    /// the closing sheet.
    func testAddCaregiverAvatarFailureShowsNoteOnTheListAfterTheSheetCloses() {
        let app = makeApp(
            additionalArguments: [
                "-complete-onboarding",
                "-launch-route", "settings",
                "-fail-caregiver-avatar-save",
                "-keep-animations"
            ]
        )
        app.launch()

        let settingsView = app.descendants(matching: .any)["settings.view"].firstMatch
        XCTAssertTrue(settingsView.waitForExistence(timeout: uiTimeout))

        // `-launch-route settings` opens the More hub. The caregiver row lives in the Settings
        // screen that the hub's "Settings" row pushes, not on the hub itself.
        let appSettingsRow = app.buttons["settings.appSettings.row"]
        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: uiTimeout))
        // The notifications row tops the pushed Settings screen; the caregivers row may sit below
        // the fold, so it is scrolled to after the push.
        tap(appSettingsRow, opening: app.buttons["settings.notifications.row"])

        let caregiversRow = app.buttons["settings.caregivers.row"]
        scrollUntilHittable(caregiversRow, in: app)
        caregiversRow.tap()

        let addButton = app.buttons["caregiverList.addButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: uiTimeout))
        addButton.tap()

        let nameField = app.textFields["Caregiver name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: uiTimeout))
        typeText("UI Avatar Caregiver", into: nameField)
        dismissKeyboardIfPresent(in: app)
        let saveButton = app.buttons["addCaregiver.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiTimeout))
        scrollUntilHittable(saveButton, in: app)
        saveButton.tap()

        let note = app.alerts["Caregiver saved, but the photo did not save."]
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        XCTAssertFalse(nameField.exists)
        note.buttons.firstMatch.tap()
        XCTAssertTrue(note.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["UI Avatar Caregiver"].waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(catsShortcut.waitForExistence(timeout: uiTimeout))
        waitUntilHittable(catsShortcut)
        catsShortcut.tap()

        XCTAssertTrue(app.buttons["cats.card.UI Test Cat"].waitForExistence(timeout: uiTimeout))

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: uiTimeout))
        waitUntilHittable(backButton)
        backButton.tap()

        let historyShortcut = app.buttons["settings.shortcut.history"]
        XCTAssertTrue(historyShortcut.waitForExistence(timeout: uiTimeout))
        waitUntilHittable(historyShortcut)
        historyShortcut.tap()

        XCTAssertTrue(app.staticTexts["UI Test Completed Task"].waitForExistence(timeout: uiTimeout))
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

        XCTAssertTrue(app.descendants(matching: .any)["settings.view"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["settings.appSettings.row"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["settings.shortcut.cats"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["settings.shortcut.history"].waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(appSettingsRow.waitForExistence(timeout: uiTimeout))
        let notificationsRow = app.buttons["settings.notifications.row"]
        tap(appSettingsRow, opening: notificationsRow)

        tap(notificationsRow, opening: app.navigationBars["Notification Settings"])

        let advancedRow = app.buttons["notificationSettings.advanced"]
        XCTAssertTrue(advancedRow.waitForExistence(timeout: uiTimeout))
        tap(advancedRow, opening: app.navigationBars["Advanced Notification Settings"])

        let soundToggle = app.switches["advancedNotificationSettings.soundToggle"]
        XCTAssertTrue(soundToggle.waitForExistence(timeout: uiTimeout))
        let originalState = toggleState(for: soundToggle)
        let expectedState = originalState == "on" ? "off" : "on"
        setToggle(soundToggle, to: expectedState)

        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.navigationBars["Notification Settings"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(advancedRow.waitForExistence(timeout: uiTimeout))
        tap(advancedRow, opening: app.navigationBars["Advanced Notification Settings"])

        let updatedSoundToggle = app.switches["advancedNotificationSettings.soundToggle"]
        XCTAssertTrue(updatedSoundToggle.waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(supportRow.waitForExistence(timeout: uiTimeout))
        supportRow.tap()

        XCTAssertTrue(app.staticTexts["Purrtine"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Version'")).firstMatch.waitForExistence(timeout: uiTimeout))
        // settings.rateApp is only rendered when APP_STORE_ID is configured, which this build doesn't set.
        XCTAssertTrue(app.descendants(matching: .any)["settings.giveFeedback"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.descendants(matching: .any)["settings.privacyPolicy"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.descendants(matching: .any)["settings.termsOfService"].waitForExistence(timeout: uiTimeout))
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

        XCTAssertTrue(app.descendants(matching: .any)["home.view"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.descendants(matching: .any)["home.currentTasks.section"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.descendants(matching: .any)["home.quickActions.section"].waitForExistence(timeout: uiTimeout))

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: uiTimeout))
        tasksTab.tap()

        // Destination-view waits after a tab/navigation transition get a longer timeout than
        // simple element checks: under CI/full-suite load, tab-switch animation + view load can
        // occasionally exceed 5s even though it's never actually stuck (confirmed by re-running
        // this test alone, where it passes reliably in ~5-10s well under the old 5s ceiling).
        XCTAssertTrue(app.descendants(matching: .any)["taskManagement.view"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["taskManagement.addMenuButton"].waitForExistence(timeout: uiTimeout))

        let assistantTab = app.tabBars.buttons["Whiskers"]
        XCTAssertTrue(assistantTab.waitForExistence(timeout: uiTimeout))
        assistantTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["taskAssistant.welcome"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["taskAssistant.startChatButton"].waitForExistence(timeout: uiTimeout))

        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: uiTimeout))
        moreTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["settings.view"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["settings.appSettings.row"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["settings.shortcut.cats"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["settings.shortcut.history"].waitForExistence(timeout: uiTimeout))

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
        XCTAssertTrue(originalRow.waitForExistence(timeout: uiTimeout))
        originalRow.tap()

        let titleField = app.textFields["taskEdit.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: uiTimeout))
        replaceText(in: titleField, with: updatedTitle)

        let saveButton = app.buttons["taskEdit.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiTimeout))

        // No wait between the taps. The stubbed notification layer resolves almost immediately, so
        // the sheet is usually gone before the second tap lands; `tapAgainIfStillPresent` keeps the
        // test deterministic. That makes this a regression guard on the update path, not a proof
        // that the `isSaving` guard holds under a real race. A real proof needs an injected delay.
        saveButton.tap()
        tapAgainIfStillPresent(saveButton)

        let updatedRow = app.buttons["taskRow.\(updatedTitle)"]
        XCTAssertTrue(updatedRow.waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiTimeout))

        // Same timing caveat as the edit-sheet double-tap test above.
        saveButton.tap()
        tapAgainIfStillPresent(saveButton)

        XCTAssertTrue(app.buttons["taskRow.\(taskTitle)"].waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(taskRow.waitForExistence(timeout: uiTimeout))
        taskRow.tap()

        let titleField = app.textFields["taskEdit.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: uiTimeout))

        // `enableReminder` starts on, so the save takes the schedule path. Read it, do not tap it.
        let reminderToggle = app.switches["reminderRow.notificationsToggle"]
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: uiTimeout))
        XCTAssertEqual(toggleState(for: reminderToggle), "on")

        replaceText(in: titleField, with: updatedTitle)

        let saveButton = app.buttons["taskEdit.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiTimeout))
        saveButton.tap()

        let scheduleAlert = app.alerts[scheduleFailureAlertTitle]
        XCTAssertTrue(scheduleAlert.waitForExistence(timeout: uiTimeout))

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
        XCTAssertTrue(dismissAlertButton.waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(completeButton.waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(viewModeButton.waitForExistence(timeout: uiTimeout))
        viewModeButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)["taskManagement.calendar"].waitForExistence(timeout: uiTimeout))

        let completeButton = app.buttons["taskRow.complete.UI Solo Task"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: uiTimeout))
        completeButton.tap()

        acknowledgeReminderWarning(in: app)
    }

    /// Guards #14 on the completion sheet: the sheet closes, because the completion committed, and
    /// the warning appears once it has closed.
    func testSheetCompletionWithStaleRemindersClosesTheSheetThenWarns() {
        let app = launchStaleReminderCompletionScenario()

        let completeButton = app.buttons["taskRow.complete.UI Shared Task"]
        XCTAssertTrue(completeButton.waitForExistence(timeout: uiTimeout))
        completeButton.tap()

        let selectAllButton = app.buttons["taskCompletionSelectAllButton"]
        XCTAssertTrue(selectAllButton.waitForExistence(timeout: uiTimeout))
        selectAllButton.tap()

        let confirmButton = app.buttons["taskCompletion.confirmButton"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(warning.waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(taskRow.waitForExistence(timeout: uiTimeout))
        taskRow.tap()

        let titleField = app.textFields["taskEdit.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: uiTimeout))

        // `enableReminder` starts on, so the save takes the schedule path. Read it, do not tap it.
        let reminderToggle = app.switches["reminderRow.notificationsToggle"]
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: uiTimeout))
        XCTAssertEqual(toggleState(for: reminderToggle), "on")

        replaceText(in: titleField, with: updatedTitle)

        let saveButton = app.buttons["taskEdit.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiTimeout))
        saveButton.tap()

        let scheduleAlert = app.alerts[scheduleFailureAlertTitle]
        XCTAssertTrue(scheduleAlert.waitForExistence(timeout: uiTimeout))
        scheduleAlert.buttons.firstMatch.tap()
        XCTAssertTrue(scheduleAlert.waitForNonExistence(timeout: 5))

        let cancelButton = app.buttons["taskEdit.cancelButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: uiTimeout))
        cancelButton.tap()

        // `SheetDismissButton` raises a confirmation dialog, not an alert. Match its destructive
        // button by label, which covers both the sheet and the alert presentation.
        XCTAssertFalse(app.buttons[discardChangesButtonTitle].waitForExistence(timeout: 2))

        XCTAssertTrue(app.textFields["taskEdit.titleField"].waitForNonExistence(timeout: 5))

        // The heart of P3: the edits were committed before the notification hop, so they survive.
        XCTAssertTrue(app.buttons["taskRow.\(updatedTitle)"].waitForExistence(timeout: uiTimeout))
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
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: uiTimeout))
        XCTAssertEqual(toggleState(for: reminderToggle), "on")

        let saveButton = app.buttons["taskAdd.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiTimeout))
        saveButton.tap()

        let scheduleAlert = app.alerts[scheduleFailureAlertTitle]
        XCTAssertTrue(scheduleAlert.waitForExistence(timeout: uiTimeout))

        // The edit sheet's alerts carry no such button, and that difference is the point.
        let okButton = scheduleAlert.buttons["OK"]
        XCTAssertTrue(okButton.waitForExistence(timeout: uiTimeout))

        // Spec section 10 assertion 3 is deliberately absent. `isEnabled` reports `false` for an
        // element that does not resolve, and XCUITest may scope queries to the modal alert, so the
        // assertion could not fail for the reason the test cares about. Section 10's own UNVERIFIED
        // note permits dropping it and relying on the row count below, which is not vacuous.
        okButton.tap()

        XCTAssertTrue(app.textFields["taskAdd.titleField"].waitForNonExistence(timeout: 5))

        // The task was created once, and the failed reminder did not roll it back.
        XCTAssertTrue(app.buttons["taskRow.\(taskTitle)"].waitForExistence(timeout: uiTimeout))
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

    /// Cats screen → "UI Test Cat" detail → Edit Cat → Delete → confirm.
    private func deletePrimaryCatFromEditCat(in app: XCUIApplication) {
        let primaryCatCard = app.buttons["cats.card.UI Test Cat"]
        XCTAssertTrue(primaryCatCard.waitForExistence(timeout: uiTimeout))
        primaryCatCard.tap()

        let editButton = app.buttons["catDetail.editButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: uiTimeout))
        editButton.tap()

        deleteCatFromOpenEditCat(in: app)
    }

    /// Cats screen → "UI Test Cat" card menu → Delete → confirm.
    private func deletePrimaryCatFromCardMenu(in app: XCUIApplication) {
        openPrimaryCatCardMenu(in: app)

        let menuDeleteButton = app.buttons["Delete"].firstMatch
        XCTAssertTrue(menuDeleteButton.waitForExistence(timeout: uiTimeout))
        menuDeleteButton.tap()

        confirmCatDelete(in: app)
    }

    /// Cats screen → "UI Test Cat" card menu → Edit → Edit Cat → Delete → confirm.
    private func deletePrimaryCatFromCardEditCat(in app: XCUIApplication) {
        openPrimaryCatCardMenu(in: app)

        let menuEditButton = app.buttons["Edit"].firstMatch
        XCTAssertTrue(menuEditButton.waitForExistence(timeout: uiTimeout))
        menuEditButton.tap()

        deleteCatFromOpenEditCat(in: app)
    }

    private func openPrimaryCatCardMenu(in app: XCUIApplication) {
        let primaryCatCard = app.buttons["cats.card.UI Test Cat"]
        XCTAssertTrue(primaryCatCard.waitForExistence(timeout: uiTimeout))
        primaryCatCard.press(forDuration: 1.2)
    }

    private func deleteCatFromOpenEditCat(in app: XCUIApplication) {
        let deleteButton = app.buttons["catForm.deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: uiTimeout))
        deleteButton.tap()

        confirmCatDelete(in: app)
    }

    private func confirmCatDelete(in app: XCUIApplication) {
        let confirmDeleteButton = app.alerts.buttons["Delete"].firstMatch
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: uiTimeout))
        confirmDeleteButton.tap()
    }

    /// The note shows on the cats screen, names the cat, shows only once, and the cat stays gone
    /// after it closes.
    private func assertCatDeletionAlert(in app: XCUIApplication, title: String) {
        let alert = app.alerts[title]
        XCTAssertTrue(alert.waitForExistence(timeout: uiTimeout))
        XCTAssertEqual(app.alerts.count, 1)
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "UI Test Cat")).firstMatch.exists)

        let dismissAlertButton = alert.buttons.firstMatch
        XCTAssertTrue(dismissAlertButton.waitForExistence(timeout: uiTimeout))
        dismissAlertButton.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5))

        // No second note follows the first (#31).
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2))

        XCTAssertTrue(app.descendants(matching: .any)["cats.view"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["cats.card.UI Second Test Cat"].waitForExistence(timeout: uiTimeout))
        XCTAssertFalse(app.buttons["cats.card.UI Test Cat"].exists)
    }

    /// Taps an element a second time, but only while it is still on screen.
    ///
    /// A save button whose sheet has already closed is not a test failure: the sheet closing is the
    /// wanted outcome. The assertion that matters is the row count after the taps.
    private func tapAgainIfStillPresent(_ element: XCUIElement) {
        guard isTappableNow(element) else { return }

        element.tap()
    }

    /// Whether `element` can take a tap right now, read without raising (#152).
    ///
    /// Asking `isHittable` of an element whose centre is off the window, such as a save button on a
    /// sheet that is sliding away, fails the test with "Activation point invalid" (main run
    /// 43770586120). So `exists` and `frame` are read first, and `isHittable` only after them.
    private func isTappableNow(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }

        let frame = element.frame
        let window = XCUIApplication().windows.firstMatch
        guard !frame.isEmpty, window.exists,
              window.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) else { return false }

        return element.isHittable
    }

    /// Taps a row that pushes a screen and waits for `destination` on that screen (#152).
    ///
    /// On CI a tap on a Developer Tools row was synthesized and still left the screen in place (PR
    /// #155 run 43761752248, attempt 2: the failure screenshot shows Developer Tools). The helper
    /// waits until `element` can take the tap, taps, and taps once more only when `destination`
    /// did not appear and `element` is still on screen, so a slow push is never tapped twice.
    private func tap(
        _ element: XCUIElement,
        opening destination: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        waitUntilHittable(element, file: file, line: line)
        element.tap()
        if destination.waitForExistence(timeout: uiTimeout) { return }

        if isTappableNow(element) {
            XCTContext.runActivity(named: "Retrying tap (#152): \(element) did not open \(destination)") { _ in
                element.tap()
            }
        }
        XCTAssertTrue(
            destination.waitForExistence(timeout: uiTimeout),
            "Tap on \(element) did not open \(destination)",
            file: file,
            line: line
        )
    }

    /// Recovery for a cat-card long press that landed as a tap (#152): leaves the pushed cat detail
    /// screen through the back button, so the retry presses the card again.
    private func returnToCatsListIfDetailOpened(in app: XCUIApplication, card: XCUIElement) {
        guard app.buttons["catDetail.editButton"].exists, !card.exists else { return }

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        waitUntilHittable(backButton)
        backButton.tap()
        XCTAssertTrue(card.waitForExistence(timeout: uiTimeout), "The cats list did not come back.")
    }

    /// Waits for an element to report `isHittable == true`.
    ///
    /// Toolbar/chrome morph animations (e.g. Liquid Glass) can leave an element in the
    /// accessibility tree, and passing `waitForExistence`, before it is actually tappable.
    ///
    /// Condition-based: returns as soon as the element is hittable (#152). Asking an element for
    /// `isHittable` before it has a real frame on screen raises "Activation point invalid", so the
    /// poll reads `exists` and `frame` first. A slow CI runner gets the full 15 s; a failure names
    /// the element.
    @discardableResult
    private func waitUntilHittable(
        _ element: XCUIElement,
        timeout: TimeInterval = 15,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let isHittable = waitUntil(timeout: timeout) { isTappableNow(element) }
        XCTAssertTrue(
            isHittable,
            "Element never became hittable within \(timeout) s: \(element)",
            file: file,
            line: line
        )
        return isHittable
    }

    /// Polls `condition` every 0.1 s and returns `true` as soon as it holds, `false` at the deadline.
    /// Never sleeps for a fixed time: the run loop keeps turning while it waits.
    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            if condition() { return true }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return condition()
    }

    /// Whether `field` itself has keyboard focus. The keyboard being up is not enough: it can still
    /// belong to the previous field.
    private func hasTypingFocus(_ field: XCUIElement) -> Bool {
        NSPredicate(format: "hasKeyboardFocus == true").evaluate(with: field)
    }

    /// Taps `field` and types `text` once the field can really receive it (#152).
    ///
    /// A `tap(); typeText()` pair right after `waitForExistence` fails with "Neither element nor any
    /// descendant has keyboard focus" when a sheet or push is still animating in. The helper waits
    /// for the field to be hittable, taps, waits for keyboard focus, taps once more if focus did
    /// not arrive, and only then types.
    private func typeText(
        _ text: String,
        into field: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        focus(field, file: file, line: line)
        field.typeText(text)
    }

    /// Gives `field` keyboard focus: tap, wait for focus, tap again if it did not arrive.
    private func focus(
        _ field: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        _ = field.waitForExistence(timeout: 15)
        waitUntilHittable(field, file: file, line: line)
        field.tap()
        if waitUntil(timeout: 5, condition: { hasTypingFocus(field) }) { return }

        field.tap()
        let gotFocus = waitUntil(timeout: 10) { hasTypingFocus(field) }
        XCTAssertTrue(gotFocus, "Field never got keyboard focus: \(field)", file: file, line: line)
    }

    /// Swipes the app's main scroll view up until `element` has its centre inside the window, then
    /// waits for it to be hittable. Bounded, so a missing element still fails in the caller's assertion.
    ///
    /// Reads `frame` instead of `isHittable` while scrolling: asking an off-screen or mid-scroll
    /// element for hittability is what raises "Activation point invalid" on CI.
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) {
        // A short settle only: a row below the fold of a lazy list may not exist until scrolled to.
        _ = element.waitForExistence(timeout: 5)
        let window = app.windows.firstMatch
        for _ in 0..<maxSwipes {
            let frame = element.frame
            let isCentreOnScreen = !frame.isEmpty && window.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
            // Keep clear of the tab bar, which covers the bottom of the window.
            let isAboveTabBar = !app.tabBars.firstMatch.exists || frame.midY < app.tabBars.firstMatch.frame.minY
            if isCentreOnScreen, isAboveTabBar { break }
            app.swipeUp()
        }
        waitUntilHittable(element)
    }

    /// Dismisses the keyboard and returns only when it is really gone (#152).
    ///
    /// Waits up to 10 s for the toolbar Done button; falls back to the keyboard's Return key when the
    /// form has no Done button. Fails when the keyboard is still up after the last wait, because a
    /// keyboard left over a button is what swallowed the save tap on slow runners.
    private func dismissKeyboardIfPresent(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }

        let done = app.toolbars.buttons["Done"]
        if done.waitForExistence(timeout: 6) {
            done.tap()
        } else {
            // The keyboard window cannot be scrolled to, so a plain `tap()` on its key fails with
            // "Failed to scroll to visible"; tap the key's coordinate instead.
            let returnKey = keyboard.buttons["Return"]
            if returnKey.exists {
                returnKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        }

        XCTAssertTrue(
            keyboard.waitForNonExistence(timeout: 10),
            "Keyboard did not go away after dismissal.",
            file: file,
            line: line
        )
    }

    /// Performs a gesture on `target` and waits for the element it reveals, with one retry (#71).
    ///
    /// On CI a swipe on a freshly reloaded list, or a long press right after a card appears, can be
    /// a no-op. The helper waits until `target` is hittable, runs `gesture`, waits up to `timeout`
    /// for `revealed`, and runs `gesture` exactly once more if `revealed` is still absent.
    /// Asserts that `revealed` exists after the retry.
    ///
    /// `recover` runs before the retry. It puts the screen back when the first attempt did
    /// something other than a no-op, such as a long press that landed as a tap and pushed a screen.
    private func performGesture(
        on target: XCUIElement,
        revealing revealed: XCUIElement,
        timeout: TimeInterval = 15,
        file: StaticString = #filePath,
        line: UInt = #line,
        recover: () -> Void = {},
        gesture: () -> Void
    ) {
        waitUntilHittable(target, file: file, line: line)

        gesture()
        if revealed.waitForExistence(timeout: timeout) { return }

        XCTContext.runActivity(named: "Retrying gesture (#71): first attempt did not reveal \(revealed)") { _ in
            recover()
            waitUntilHittable(target, file: file, line: line)
            gesture()
        }
        _ = revealed.waitForExistence(timeout: timeout)
        XCTAssertTrue(
            revealed.exists,
            "Gesture on \(target) did not reveal \(revealed) after one retry",
            file: file,
            line: line
        )
    }

    /// Navigates from a fresh launch to an open custom-task add sheet.
    private func openCustomTaskForm(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: uiTimeout), file: file, line: line)
        tasksTab.tap()

        let addMenuButton = app.buttons["taskManagement.addMenuButton"]
        XCTAssertTrue(addMenuButton.waitForExistence(timeout: uiTimeout), file: file, line: line)
        addMenuButton.tap()

        let customTaskButton = app.buttons["taskManagement.customTaskButton"]
        XCTAssertTrue(customTaskButton.waitForExistence(timeout: uiTimeout), file: file, line: line)
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
        XCTAssertTrue(titleField.waitForExistence(timeout: uiTimeout), file: file, line: line)
        typeText(title, into: titleField, file: file, line: line)

        // Dismiss the keyboard before tapping rows near its edge; on iOS 26 the
        // keyboard-avoidance layout shift can otherwise swallow the tap.
        dismissKeyboardIfPresent(in: app, file: file, line: line)

        let catsButton = app.buttons["taskAdd.catsButton"]
        XCTAssertTrue(catsButton.waitForExistence(timeout: uiTimeout), file: file, line: line)
        catsButton.tap()

        let catOption = app.buttons["taskCatsSelection.cat.\(catName)"]
        XCTAssertTrue(catOption.waitForExistence(timeout: uiTimeout), file: file, line: line)
        catOption.tap()

        let doneButton = app.buttons["taskCatsSelection.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: uiTimeout), file: file, line: line)
        doneButton.tap()
    }

    private func dismissAssistantCloudConsentIfNeeded(in app: XCUIApplication) {
        let declineConsent = app.buttons["Don't Allow"]
        if declineConsent.waitForExistence(timeout: 3) {
            declineConsent.tap()
            XCTAssertTrue(declineConsent.waitForNonExistence(timeout: 5))
        }
    }

    /// `nonisolated`: the synchronous `tearDownWithError` that calls it is not main-actor isolated.
    private nonisolated func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func replaceText(in element: XCUIElement, with text: String) {
        focus(element)

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
        let reached = waitUntil(timeout: 10) {
            toggleState(for: element, file: file, line: line) == state
        }
        if !reached {
            XCTFail("Expected toggle state to become \(state): \(element)", file: file, line: line)
        }
    }

    /// Flips a switch to `state` and waits for it (#152).
    ///
    /// Waits for the switch to be hittable, taps, then waits for the new state. Taps again only when
    /// the state is still the old one after that wait, i.e. the first tap provably did not land, so a
    /// slow update is never toggled twice.
    private func setToggle(
        _ element: XCUIElement,
        to state: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        waitUntilHittable(element, file: file, line: line)
        tapSwitchControl(element)
        if waitUntil(timeout: 8, condition: { toggleState(for: element, file: file, line: line) == state }) {
            return
        }

        tapSwitchControl(element)
        waitForToggleState(state, in: element, file: file, line: line)
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
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: uiTimeout), file: file, line: line)

        let notificationsMenu = app.buttons["reminderRow.notificationsMenu"]
        XCTAssertTrue(notificationsMenu.waitForExistence(timeout: uiTimeout), file: file, line: line)

        XCTAssertEqual(toggleState(for: reminderToggle, file: file, line: line), "on", file: file, line: line)
        XCTAssertTrue(notificationsMenu.isEnabled, file: file, line: line)

        setToggle(reminderToggle, to: "off", file: file, line: line)
        XCTAssertFalse(
            notificationsMenu.isEnabled,
            "The menu row must disable while the reminder is off.",
            file: file,
            line: line
        )

        setToggle(reminderToggle, to: "on", file: file, line: line)
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
