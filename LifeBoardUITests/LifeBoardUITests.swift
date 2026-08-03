//
//  LifeBoardUITests.swift
//  LifeBoardUITests
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import XCTest

@MainActor
class LifeBoardUITests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testLaunchPerformance() {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    func testFoundationRootsAndCaptureRemainReachableAtLargestAccessibilitySize() {
        let app = launchFoundationApp(accessibilityCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        defer { app.terminate() }

        let chrome = app.descendants(matching: .any)["LifeBoardCompactChrome"]
        XCTAssertTrue(chrome.waitForExistence(timeout: 15), "The measured foundation chrome should mount.")

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        assertFoundationDestination("track", rootIdentifier: "track.header", in: app)
        assertFoundationDestination("insights", rootIdentifier: "foundation.insights", in: app)
        assertFoundationDestination("eva", rootIdentifier: "foundation.eva", in: app)
        assertFoundationDestination("home", rootIdentifier: "home.signalRow", in: app)
        XCTAssertFalse(app.textFields["home.lifeThread.composer"].exists)

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        let capture = app.buttons["foundation.capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        XCTAssertTrue(capture.isHittable, "Header capture must remain reachable.")
        capture.tap()
        XCTAssertTrue(app.buttons["Capture Task"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Capture Journal"].exists)
        XCTAssertTrue(app.buttons["Capture Note"].exists)
        XCTAssertTrue(app.buttons["Capture Tracker"].exists)
        XCTAssertTrue(app.buttons["Capture Care"].exists)
        XCTAssertTrue(capture.isHittable, "The header control must remain anchored while its tray is open.")
        capture.tap()
        XCTAssertFalse(app.buttons["Capture Task"].waitForExistence(timeout: 2))
    }

    func testInsightsEmptyStatesOfferCanonicalNextActions() {
        let app = launchFoundationApp(accessibilityCategory: "UICTContentSizeCategoryL")
        defer { app.terminate() }

        assertFoundationDestination("insights", rootIdentifier: "foundation.insights", in: app)
        let openTrack = app.buttons["insights.empty.openTrack"]
        XCTAssertTrue(openTrack.waitForExistence(timeout: 10))
        XCTAssertTrue(openTrack.isHittable)
        openTrack.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["track.header"].waitForExistence(timeout: 10),
            "The successful-empty state should lead directly to the place that records evidence."
        )

        assertFoundationDestination("insights", rootIdentifier: "foundation.insights", in: app)
        let experience = app.buttons["insights.lens.experience"]
        XCTAssertTrue(experience.waitForExistence(timeout: 8))
        experience.tap()
        let openReview = app.buttons["insights.experience.empty.openReview"]
        XCTAssertTrue(openReview.waitForExistence(timeout: 10))
        XCTAssertTrue(openReview.isHittable)
        openReview.tap()
        let review = app.buttons["insights.lens.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 10))
        XCTAssertTrue(review.isSelected, "The optional Experience lens should select canonical Review without a dead end.")
    }

    func testPhase5IPhoneRootVisualCheckpoint() throws {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true,
            evaActivationCompleted: true
        )
        defer { app.terminate() }

        guard app.windows.firstMatch.frame.width < 700 else {
            throw XCTSkip("Phase 5 approves the iPhone composition before wider adaptations.")
        }

        assertFoundationDestination("home", rootIdentifier: "home.signalRow", in: app)
        try saveVisualEvidenceScreenshot(named: "phase5-home-populated", platform: "iphone-phase5")

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        try saveVisualEvidenceScreenshot(named: "phase5-plan-day", platform: "iphone-phase5")

        assertFoundationDestination("track", rootIdentifier: "track.header", in: app)
        try saveVisualEvidenceScreenshot(named: "phase5-track-today", platform: "iphone-phase5")

        assertFoundationDestination("insights", rootIdentifier: "foundation.insights", in: app)
        try saveVisualEvidenceScreenshot(named: "phase5-insights-overview", platform: "iphone-phase5")
        let experience = app.buttons["insights.lens.experience"]
        XCTAssertTrue(experience.waitForExistence(timeout: 8))
        experience.tap()
        XCTAssertTrue(app.descendants(matching: .any)["foundation.insights"].waitForExistence(timeout: 8))
        try saveVisualEvidenceScreenshot(named: "phase5-insights-experience", platform: "iphone-phase5")

        assertFoundationDestination("eva", rootIdentifier: "foundation.eva", in: app)
        try saveVisualEvidenceScreenshot(named: "phase5-eva", platform: "iphone-phase5")
    }

    func testInAppCaptureDraftRecoversAfterProcessInterruption() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.tasks.add", in: app)
        let title = app.textFields["addTask.titleField"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("Recovered interruption draft")
        XCTAssertEqual(title.value as? String, "Recovered interruption draft")

        app.terminate()
        app.launchArguments.removeAll {
            $0 == "-RESET_APP_STATE" || $0 == "-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE"
        }
        app.launch()

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.tasks.add", in: app)
        let recovered = app.textFields["addTask.titleField"].firstMatch
        XCTAssertTrue(recovered.waitForExistence(timeout: 10))
        XCTAssertEqual(
            recovered.value as? String,
            "Recovered interruption draft",
            "A process interruption must recover the latest provisional capture instead of losing it."
        )
    }

    func testInboxCaptureSurvivesInterruptionThenFilesAndUndoes() {
        let captureID = "A1B2C3D4-0001-4000-8000-00000000FEED"
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true,
            seedInboxCaptures: true
        )
        defer { app.terminate() }

        openSeededInbox(in: app)
        let capture = app.descendants(matching: .any)["plan.inbox.row.\(captureID)"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        let file = app.buttons["File it"].firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 8))
        file.tap()
        XCTAssertTrue(app.navigationBars["Review capture"].waitForExistence(timeout: 8))

        // Terminate before File It. The pending capture is the only durable copy
        // and must remain reviewable after a fresh app process.
        app.terminate()
        app.launchArguments.removeAll {
            $0 == "-RESET_APP_STATE"
                || $0 == "-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE"
                || $0 == "-LIFEBOARD_TEST_SEED_INBOX_CAPTURES"
        }
        app.launch()

        openSeededInbox(in: app)
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        let restoredFile = app.buttons["File it"].firstMatch
        XCTAssertTrue(restoredFile.waitForExistence(timeout: 8))
        restoredFile.tap()
        let commit = app.buttons["File It"].firstMatch
        XCTAssertTrue(commit.waitForExistence(timeout: 8))
        commit.tap()
        XCTAssertTrue(waitForElementToDisappear(app.navigationBars["Review capture"], timeout: 12))
        XCTAssertTrue(waitForElementToDisappear(capture, timeout: 12))

        let undo = app.buttons["Undo"].firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 8))
        undo.tap()
        XCTAssertTrue(
            capture.waitForExistence(timeout: 12),
            "Undo must restore the same capture identity after the canonical task is removed."
        )
    }

    func testFoundationCompactChromeRemainsReadableAcrossScrollAndCapture() throws {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let chrome = app.descendants(matching: .any)["LifeBoardCompactChrome"]
        XCTAssertTrue(chrome.waitForExistence(timeout: 10))
        let restingFrame = chrome.frame

        let homeScroll = app.scrollViews.firstMatch
        XCTAssertTrue(homeScroll.waitForExistence(timeout: 5))
        homeScroll.swipeUp()
        XCTAssertTrue(chrome.waitForExistence(timeout: 5))
        XCTAssertEqual(chrome.frame.height, restingFrame.height, accuracy: 2)
        XCTAssertEqual(chrome.frame.maxY, restingFrame.maxY, accuracy: 2)

        let capture = app.buttons["lifeThread.composer.toolsToggle"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        capture.tap()
        let taskCapture = app.buttons["lifeThread.composer.tool.task"]
        XCTAssertTrue(taskCapture.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(taskCapture.frame.minY, chrome.frame.minY)
        XCTAssertLessThanOrEqual(taskCapture.frame.maxY, chrome.frame.maxY)
        XCTAssertTrue(taskCapture.isHittable)
        try saveVisualEvidenceScreenshot(named: "home-compact-chrome-capture", platform: "iphone")
    }

    func testAdaptiveHomeCustomizationCancelAndComposerHandoff() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true,
            seedHomeUserSpace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let customize = app.buttons["home.customize"]
        XCTAssertTrue(customize.waitForExistence(timeout: 8))
        customize.tap()

        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
        let seededCardMenu = app.buttons[
            "home.widget.edit.D6ED45B2-1267-4C2C-9A91-A3F5503D51AF"
        ]
        scrollUntilHittable(seededCardMenu, in: app, maximumSwipes: 8)
        XCTAssertTrue(seededCardMenu.isHittable)
        seededCardMenu.tap()
        XCTAssertTrue(app.buttons["Glance"].waitForExistence(timeout: 5))
        app.buttons["Glance"].tap()
        app.buttons["home.customization.cancel"].tap()
        XCTAssertTrue(customize.waitForExistence(timeout: 5), "Cancel should restore the pre-edit Home transaction.")

        let capture = app.buttons["lifeThread.composer.toolsToggle"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        capture.tap()
        app.buttons["lifeThread.composer.tool.task"].tap()
        XCTAssertTrue(app.buttons["foundation.capture.dismiss"].waitForExistence(timeout: 8))
    }

    func testVisualEvidenceWideIPadAtomicHomeEdit() throws {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        guard app.windows.firstMatch.frame.width >= 1_024 else {
            throw XCTSkip("Wide Home edit evidence requires the expanded iPad destination.")
        }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let customize = app.buttons["home.customize"]
        XCTAssertTrue(customize.waitForExistence(timeout: 10))
        customize.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Done"].exists)
        try saveVisualEvidenceScreenshot(named: "home-atomic-edit-wide")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(customize.waitForExistence(timeout: 8), "Cancel must restore the atomic Home draft.")
    }

    func testAddToHomeUsesSizePreviewAndProducesUndoReceipt() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        let more = app.buttons["foundation.more.plan"]
        XCTAssertTrue(more.waitForExistence(timeout: 8))
        more.tap()
        let addMenu = app.buttons["home.addToHome.plan"]
        XCTAssertTrue(addMenu.waitForExistence(timeout: 8))
        addMenu.tap()

        let tasks = app.buttons["Today’s Tasks"]
        XCTAssertTrue(tasks.waitForExistence(timeout: 5))
        tasks.tap()

        XCTAssertTrue(app.staticTexts["Add Today’s Tasks to Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["My Home preview"].exists)
        let wide = app.buttons["Wide"]
        XCTAssertTrue(wide.exists)
        wide.tap()

        let add = app.buttons["home.placement.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let receipt = app.descendants(matching: .any)["home.addCard.receipt"]
        XCTAssertTrue(receipt.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Undo"].exists)
        XCTAssertTrue(app.buttons["View"].exists)
    }

    func testFoundationHabitResilienceThirtyDayEditorAtLargestAccessibilitySize() throws {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            seedHabits: true
        )
        defer { app.terminate() }

        assertFoundationDestination("track", rootIdentifier: "track.header", in: app)
        let areas = app.buttons["track.lens.areas"]
        XCTAssertTrue(areas.waitForExistence(timeout: 8))
        areas.tap()
        let resilience = app.buttons["track.habits.resilience"]
        scrollUntilHittable(resilience, in: app, maximumSwipes: 12)
        XCTAssertTrue(resilience.isHittable, "Resilience settings must remain operable at accessibility XXXL.")
        resilience.tap()

        XCTAssertTrue(app.navigationBars["Habit resilience"].waitForExistence(timeout: 12))
        let policy = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "track.habit.resilience.")
        ).firstMatch
        XCTAssertTrue(policy.waitForExistence(timeout: 12), "The canonical seeded habit should expose a resilience policy.")
        scrollUntilHittable(policy, in: app)
        policy.tap()

        let recoveryToggle = app.switches["Allow recovery completions"]
        XCTAssertTrue(
            recoveryToggle.waitForExistence(timeout: 8),
            "The recovery policy must remain operable at accessibility XXXL."
        )
        XCTAssertTrue(app.buttons["track.resilience.commit"].exists)

        let historyHeader = app.staticTexts["30-day history"]
        scrollUntilHittable(historyHeader, in: app, maximumSwipes: 10)
        XCTAssertTrue(historyHeader.exists, "The full history section must remain reachable at accessibility XXXL.")

        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.intersects(historyHeader.frame))
        XCTAssertLessThanOrEqual(historyHeader.frame.maxX, window.maxX + 1)
        XCTAssertGreaterThanOrEqual(historyHeader.frame.minX, window.minX - 1)
    }

    func testFoundationBacklogDeletionConfirmsUndoesAndPersistsAcrossRelaunch() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        openBacklog(in: app)

        let taskButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "plan.task.")
        )
        let task = taskButtons.firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 12), "The canonical seed should expose a backlog task.")
        let taskIdentifier = task.identifier
        let initialTaskCount = taskButtons.count

        requestBacklogDeletion(for: task, in: app)
        XCTAssertTrue(app.buttons["Delete from LifeBoard"].waitForExistence(timeout: 5))
        app.buttons["Delete from LifeBoard"].tap()

        let undoBanner = app.descendants(matching: .any)["plan.backlog.deletionUndo"]
        XCTAssertTrue(undoBanner.waitForExistence(timeout: 8))
        XCTAssertTrue(
            waitForQuery(taskButtons, toHaveCount: initialTaskCount - 1, timeout: 8),
            "A confirmed tombstone should leave the active backlog."
        )
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()
        XCTAssertTrue(
            waitForQuery(taskButtons, toHaveCount: initialTaskCount, timeout: 10),
            "Undo should restore the prior backlog cardinality."
        )
        let restoredTask = app.buttons[taskIdentifier]
        XCTAssertTrue(restoredTask.waitForExistence(timeout: 5), "Undo should restore the same stable task identity.")

        requestBacklogDeletion(for: restoredTask, in: app)
        XCTAssertTrue(app.buttons["Delete from LifeBoard"].waitForExistence(timeout: 5))
        app.buttons["Delete from LifeBoard"].tap()
        XCTAssertTrue(waitForQuery(taskButtons, toHaveCount: initialTaskCount - 1, timeout: 8))

        app.terminate()
        app.launchArguments.removeAll {
            $0 == "-RESET_APP_STATE" || $0 == "-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE"
        }
        app.launch()
        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        openBacklog(in: app)
        XCTAssertFalse(
            app.buttons[taskIdentifier].waitForExistence(timeout: 5),
            "The synced tombstone must remain hidden after a fresh app process."
        )
    }

    func testFoundationHomeExposesCompletePhaseIIHierarchy() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let hero = app.descendants(matching: .any)["home.hero"]
        let loopSpine = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home.loopSpine.")
        ).firstMatch
        XCTAssertTrue(
            hero.exists || loopSpine.exists,
            "Home must lead with either its contextual decision or the canonical Daily Loop spine."
        )
        XCTAssertTrue(app.descendants(matching: .any)["home.signalRow"].exists)

        let orderedSections = [
            "home.widget.tasks",
            "home.widget.care",
            "home.widget.routines",
            "home.widget.journal",
            "home.widget.progressReflection"
        ]
        for identifier in orderedSections {
            let section = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            scrollUntilVisible(section, in: app, maximumSwipes: 12)
            XCTAssertTrue(section.exists, "The locked Home hierarchy is missing \(identifier).")
            XCTAssertTrue(
                app.windows.firstMatch.frame.intersects(section.frame),
                "The Home section \(identifier) must be reachable by scrolling."
            )
        }

    }

    func testFoundationHomeTaskUsesTypedDetailRoute() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let task = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home.task.")
        ).firstMatch
        for _ in 0..<8 { app.swipeDown() }
        scrollUntilHittableWithSmallSteps(task, in: app, maximumSteps: 24)
        XCTAssertTrue(task.waitForExistence(timeout: 8))
        XCTAssertTrue(task.isHittable)
        task.tap()

        let homeRoot = app.buttons["foundation.destination.home"]
        let routeMutation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Detail depth 1"),
            object: homeRoot
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [routeMutation], timeout: 8),
            .completed,
            "The Home action must append one typed task route."
        )
        XCTAssertTrue(app.navigationBars["Task"].waitForExistence(timeout: 8))
    }

    func testFoundationHomeTaskCardExpandsHiddenDueTasksInline() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let taskRows = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home.task.")
        )
        let addTask = app.buttons["home.tasks.add"]
        let showMore = app.buttons[AccessibilityIdentifiers.Home.taskCardShowMore]
        scrollUntilHittableWithSmallSteps(showMore, in: app, maximumSteps: 24)

        XCTAssertTrue(showMore.waitForExistence(timeout: 8))
        XCTAssertTrue(showMore.isHittable)
        XCTAssertTrue(addTask.exists)
        XCTAssertLessThan(
            addTask.frame.midX,
            showMore.frame.midX,
            "Add a task and Show more should anchor opposite sides of the same footer row."
        )
        XCTAssertEqual(addTask.frame.midY, showMore.frame.midY, accuracy: 2)
        XCTAssertEqual(showMore.label, "Show more")
        XCTAssertTrue(
            waitForQuery(taskRows, toHaveCount: 4, timeout: 8),
            "The collapsed Home task card should render only its four-row preview."
        )

        showMore.tap()

        let showLess = app.buttons[AccessibilityIdentifiers.Home.taskCardShowLess]
        XCTAssertTrue(showLess.waitForExistence(timeout: 8))
        XCTAssertEqual(showLess.label, "Show less")
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Home.taskCardDatePicker]
                .waitForExistence(timeout: 8),
            "The expanded card should expose its compact inline date picker."
        )
        XCTAssertTrue(
            waitForQuery(taskRows, toHaveCount: 6, timeout: 8),
            "Show more should expand the same card to every open task due today."
        )

        scrollUntilHittableWithSmallSteps(showLess, in: app, maximumSteps: 24)
        XCTAssertTrue(showLess.isHittable)
        showLess.tap()

        XCTAssertTrue(showMore.waitForExistence(timeout: 8))
        XCTAssertTrue(
            waitForQuery(taskRows, toHaveCount: 4, timeout: 8),
            "Show less should restore the four-row Home preview."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Home.taskCardDatePicker].exists,
            "The compact date picker belongs only to the expanded card."
        )
    }

    func testFoundationHomeLongTaskCardRemainsReachableAcrossItsFullScrollRange() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true,
            seedLongHomeTaskAgenda: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let taskRows = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home.task.")
        )
        let showMore = app.buttons[AccessibilityIdentifiers.Home.taskCardShowMore]
        scrollUntilHittableWithSmallSteps(showMore, in: app, maximumSteps: 32)
        XCTAssertTrue(showMore.waitForExistence(timeout: 8))
        XCTAssertTrue(showMore.isHittable)
        showMore.tap()

        XCTAssertTrue(
            waitForQuery(taskRows, toHaveCount: 24, timeout: 12),
            "The dedicated long agenda should expose all 24 task rows in the expanded card."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Home.taskCardDatePicker]
                .waitForExistence(timeout: 8)
        )
        attachScreenshot(named: "home-expanded-tasks-top")

        app.swipeUp()
        let middleTask = taskRows.element(boundBy: 12)
        scrollUntilHittableWithSmallSteps(middleTask, in: app, maximumSteps: 40)
        XCTAssertTrue(middleTask.exists)
        XCTAssertTrue(middleTask.isHittable, "A middle task must remain reachable in the outer Home scroll view.")
        attachScreenshot(named: "home-expanded-tasks-middle")

        let finalTask = taskRows.element(boundBy: 23)
        scrollUntilHittableWithSmallSteps(finalTask, in: app, maximumSteps: 40)
        XCTAssertTrue(finalTask.exists)
        XCTAssertTrue(finalTask.isHittable, "The final task must remain reachable without a nested task-card scroller.")
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Home.taskCardShowLess].exists)
        attachScreenshot(named: "home-expanded-tasks-bottom")
    }

    func testFoundationTaskEditPersistsAcrossRelaunchThenCompletesAndReopens() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let task = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home.task.")
        ).firstMatch
        scrollUntilHittableWithSmallSteps(task, in: app, maximumSteps: 24)
        XCTAssertTrue(task.waitForExistence(timeout: 8))
        let taskIdentifier = task.identifier
        task.tap()

        XCTAssertTrue(app.navigationBars["Task"].waitForExistence(timeout: 8))
        let editedTitle = "Persisted native task edit"
        let title = app.textFields["task.editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        title.tap()
        app.typeKey("a", modifierFlags: .command)
        title.typeText(editedTitle)

        app.navigationBars["Task"].tap()
        let save = app.buttons["task.editor.save.toolbar"]
        XCTAssertTrue(save.waitForExistence(timeout: 8))
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.staticTexts["Task updated"].waitForExistence(timeout: 10))

        app.terminate()
        app.launchArguments.removeAll {
            $0 == "-RESET_APP_STATE" || $0 == "-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE"
        }
        app.launch()

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let restoredTask = app.buttons[taskIdentifier]
        scrollUntilHittableWithSmallSteps(restoredTask, in: app, maximumSteps: 24)
        XCTAssertTrue(restoredTask.waitForExistence(timeout: 8))
        restoredTask.tap()
        XCTAssertTrue(app.navigationBars["Task"].waitForExistence(timeout: 8))
        let restoredTitle = app.textFields["task.editor.title"]
        XCTAssertTrue(restoredTitle.waitForExistence(timeout: 8))
        XCTAssertTrue(
            (restoredTitle.value as? String)?.hasPrefix(editedTitle) == true,
            "The canonical task title edit must survive a fresh app process."
        )

        let restoredCompletion = app.switches["task.editor.completion"]
        scrollUntilHittable(restoredCompletion, in: app, maximumSwipes: 16)
        XCTAssertTrue(restoredCompletion.waitForExistence(timeout: 8))
        if (restoredCompletion.value as? String) != "0" { restoredCompletion.tap() }
        restoredCompletion.tap()
        XCTAssertEqual(
            restoredCompletion.value as? String,
            "1",
            "The canonical editor must complete the restored task."
        )
        restoredCompletion.tap()
        XCTAssertEqual(restoredCompletion.value as? String, "0", "The same editor must reopen it.")
    }

    func testFoundationHomePrimaryActionsUseTypedNativeDestinations() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)

        tapHomeAction("home.care.open", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.track"]),
            "Care must open as a typed Track leaf."
        )
        XCTAssertTrue(app.buttons["Overview"].waitForExistence(timeout: 8))

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.capacity.openDay", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.plan"]),
            "Capacity must open the typed Day route."
        )
        XCTAssertTrue(app.descendants(matching: .any)["plan.header"].waitForExistence(timeout: 8))

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.progress.openInsights", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["foundation.insights"].waitForExistence(timeout: 8))

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.journal.search", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.home"]),
            "Journal search must remain a typed Home leaf."
        )
        XCTAssertTrue(app.buttons["Library"].waitForExistence(timeout: 8))

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.journal.weeklyReflection", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.home"]),
            "Weekly reflection must remain a typed protected Home leaf."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["journal.weeklyReflection.header"].waitForExistence(timeout: 8),
            "Weekly reflection must mount its native Monday–Sunday report surface."
        )
    }

    func testFoundationHomeCaptureActionsMountNativeSheets() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.tasks.add", in: app)
        let taskCapture = app.descendants(matching: .any)["addTask.view"]
        XCTAssertTrue(taskCapture.waitForExistence(timeout: 10))
        let closeCapture = app.buttons["foundation.capture.dismiss"]
        XCTAssertTrue(closeCapture.waitForExistence(timeout: 5))
        closeCapture.tap()
        XCTAssertTrue(waitForElementToDisappear(taskCapture, timeout: 8))

        tapHomeAction("home.journal.capture", in: app)
        let journalCaptureClose = app.buttons["foundation.capture.dismiss"]
        XCTAssertTrue(
            journalCaptureClose.waitForExistence(timeout: 10)
                && waitForAccessibilityValue("Journal", on: journalCaptureClose),
            "Journal capture must mount the native private Journal surface."
        )
    }

    func testFoundationHomeWeeklyReflectionUsesTypedProtectedRoute() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.journal.weeklyReflection", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.home"]),
            "Weekly reflection must append one typed protected Home leaf."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["journal.weeklyReflection.header"].waitForExistence(timeout: 8)
                || app.descendants(matching: .any)["journal.privacy.lock"].exists,
            "Weekly reflection must mount its native report or privacy gate."
        )
    }

    func testFoundationHomeRoutineFallbackUsesTypedHabitBoardRoute() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedHabits: true,
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.routines.openHabitBoard", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.track"]),
            "A habit-backed routine suggestion must open the typed native Habit Board leaf."
        )
        XCTAssertTrue(app.navigationBars["Habit Board"].waitForExistence(timeout: 10))
    }

    func testFoundationHomeHierarchyAndDaypartRemainUsableInDarkAppearance() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true,
            appearance: "Dark"
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["home.hero"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["home.signalRow"].exists)

        let daypartMenu = app.buttons["home.daypart.menu"]
        XCTAssertTrue(daypartMenu.waitForExistence(timeout: 8))
        daypartMenu.tap()
        let night = app.buttons["Night"]
        XCTAssertTrue(night.waitForExistence(timeout: 5))
        night.tap()
        XCTAssertTrue(waitForAccessibilityLabel("Daypart, night", on: daypartMenu))

        tapHomeAction("home.journal.weeklyReflection", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.home"])
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["journal.weeklyReflection.header"].waitForExistence(timeout: 8)
        )
    }

    func testFoundationHomeHierarchyAcrossEveryContentSizeCategory() {
        let categories = [
            "UICTContentSizeCategoryXS",
            "UICTContentSizeCategoryS",
            "UICTContentSizeCategoryM",
            "UICTContentSizeCategoryL",
            "UICTContentSizeCategoryXL",
            "UICTContentSizeCategoryXXL",
            "UICTContentSizeCategoryXXXL",
            "UICTContentSizeCategoryAccessibilityM",
            "UICTContentSizeCategoryAccessibilityL",
            "UICTContentSizeCategoryAccessibilityXL",
            "UICTContentSizeCategoryAccessibilityXXL",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]

        for category in categories {
            XCTContext.runActivity(named: category) { _ in
                let app = launchFoundationApp(
                    accessibilityCategory: category,
                    seedEstablishedWorkspace: true
                )
                defer { app.terminate() }

                assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
                XCTAssertTrue(app.descendants(matching: .any)["home.hero"].exists)
                XCTAssertTrue(app.descendants(matching: .any)["home.signalRow"].exists)

                let deepestSection = app.descendants(matching: .any)["home.widget.progressReflection"]
                scrollUntilVisible(deepestSection, in: app, maximumSwipes: 16)
                XCTAssertTrue(deepestSection.exists, "The full Home hierarchy must remain reachable at \(category).")
                XCTAssertTrue(app.windows.firstMatch.frame.intersects(deepestSection.frame))

                let composer = app.textFields["home.lifeThread.composer"]
                XCTAssertTrue(composer.exists && composer.isHittable)
            }
        }
    }

    func testFoundationHomeManualDaypartsRemainIndependentlySelectable() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let daypartMenu = app.buttons["home.daypart.menu"]
        XCTAssertTrue(daypartMenu.waitForExistence(timeout: 8))

        for daypart in ["Morning", "Afternoon", "Evening", "Night"] {
            daypartMenu.tap()
            let choice = app.buttons[daypart]
            XCTAssertTrue(choice.waitForExistence(timeout: 5), "The \(daypart) override must remain selectable.")
            choice.tap()
            XCTAssertTrue(
                waitForAccessibilityLabel("Daypart, \(daypart.lowercased())", on: daypartMenu),
                "The Home atmosphere did not resolve the \(daypart) override."
            )
            XCTAssertTrue(app.descendants(matching: .any)["home.signalRow"].exists)
        }
    }

    func testFoundationDayCanvasAgendaCreatesAndUndoesPersistedBlock() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedFullTimeline: true
        )
        defer { app.terminate() }

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        let canvas = app.descendants(matching: .any).matching(identifier: "plan.day.canvas").firstMatch
        scrollUntilVisible(canvas, in: app, maximumSwipes: 8)
        XCTAssertTrue(canvas.waitForExistence(timeout: 10), "Day should expose the real time canvas.")

        let presentation = app.segmentedControls["plan.day.presentation"]
        scrollUntilHittable(presentation, in: app, maximumSwipes: 12)
        XCTAssertTrue(presentation.waitForExistence(timeout: 8))
        presentation.buttons["Agenda"].tap()

        let addBlock = app.buttons["plan.day.addBlock"]
        scrollUntilHittable(addBlock, in: app, maximumSwipes: 12)
        XCTAssertTrue(addBlock.waitForExistence(timeout: 8))
        addBlock.tap()

        XCTAssertTrue(app.descendants(matching: .any)["plan.block.composer"].waitForExistence(timeout: 8))
        let title = app.descendants(matching: .any)["plan.block.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        title.tap()
        title.typeText("Simulator focus block")
        let add = app.buttons["plan.block.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let savedBlock = app.staticTexts["Simulator focus block"]
        scrollUntilVisible(savedBlock, in: app, maximumSwipes: 12)
        XCTAssertTrue(savedBlock.waitForExistence(timeout: 10), "The agenda composer should expose the persisted block.")

        let undo = app.buttons["Undo last planning change"]
        for _ in 0..<14 where undo.exists == false || undo.isHittable == false { app.swipeDown() }
        XCTAssertTrue(undo.waitForExistence(timeout: 8))
        undo.tap()
        XCTAssertTrue(
            waitForElementToDisappear(undo, timeout: 10),
            "One-step undo should consume the persisted planning receipt."
        )
    }

    func testFoundationOpenDayLaunchesOverdueRescueAndKeepsTaskInPlannedWork() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedRescueWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)

        let openDay = app.buttons["plan.day.openRescue"]
        scrollUntilHittable(openDay, in: app, maximumSwipes: 12)
        XCTAssertTrue(openDay.waitForExistence(timeout: 10))
        XCTAssertTrue(openDay.isHittable)
        openDay.tap()

        XCTAssertTrue(app.descendants(matching: .any)["home.rescue.sheet"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["Rescue oldest"].waitForExistence(timeout: 8))

        let keep = app.buttons["home.rescue.action.keepToday"]
        XCTAssertTrue(keep.waitForExistence(timeout: 8))
        XCTAssertEqual(keep.label, "Keep today")
        XCTAssertTrue(keep.isHittable, "Keep must remain above the app chrome.")
        XCTAssertTrue(app.buttons["home.rescue.action.moveLater"].isHittable)
        XCTAssertTrue(app.buttons["home.rescue.action.Edit"].isHittable)
        XCTAssertTrue(app.buttons["home.rescue.action.Delete"].isHittable)
        keep.tap()
        XCTAssertTrue(
            app.staticTexts["Rescue middle"].waitForExistence(timeout: 12),
            "The deck should advance only after the task and Planned Work metadata both save."
        )

        let close = app.buttons["home.rescue.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 8))
        XCTAssertTrue(close.isHittable, "Close must sit inside the top safe area.")
        close.tap()
        XCTAssertTrue(
            waitForElementToDisappear(app.descendants(matching: .any)["home.rescue.sheet"], timeout: 8),
            "Closing rescue should return to the existing Plan context."
        )

        let plannedTask = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "Rescue oldest")
        ).firstMatch
        scrollUntilVisible(plannedTask, in: app, maximumSwipes: 12)
        XCTAssertTrue(
            plannedTask.waitForExistence(timeout: 12),
            "A task kept from Plan rescue should appear immediately under Planned Work."
        )
    }

    func testFoundationWeekUsesSevenDayBoardOnRegularWidth() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedFullTimeline: true
        )
        defer { app.terminate() }

        guard app.windows.firstMatch.frame.width >= 700 else {
            throw XCTSkip("The seven-day board requires a regular-width iPad or Catalyst window.")
        }
        let planTab = app.buttons["foundation.expanded.destination.plan"]
        XCTAssertTrue(
            planTab.waitForExistence(timeout: 8),
            "Regular width must expose the direct, accessible Plan root switcher."
        )
        XCTAssertTrue(planTab.isHittable)
        planTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan.header"].waitForExistence(timeout: 12))
        let week = app.buttons["plan.lens.Week"]
        XCTAssertTrue(week.waitForExistence(timeout: 8))
        week.tap()

        let board = app.descendants(matching: .any).matching(identifier: "plan.week.sevenDayBoard").firstMatch
        scrollUntilVisible(board, in: app, maximumSwipes: 10)
        XCTAssertTrue(board.waitForExistence(timeout: 10), "Regular width should mount the seven-day board.")
        XCTAssertFalse(app.descendants(matching: .any)["plan.week.compactList"].exists)

        let dayTargets = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier MATCHES %@", "plan\\.week\\.[0-9]+-[0-9]+-[0-9]+")
        )
        XCTAssertEqual(dayTargets.count, 7, "The adaptive board must expose all seven stable day targets.")
        XCTAssertTrue(app.descendants(matching: .any)["plan.week.operatingLayer"].exists)
    }

    private func launchFoundationApp(
        accessibilityCategory: String,
        seedHabits: Bool = false,
        seedEstablishedWorkspace: Bool = false,
        seedLongHomeTaskAgenda: Bool = false,
        seedHomeUserSpace: Bool = false,
        seedFullTimeline: Bool = false,
        seedRescueWorkspace: Bool = false,
        seedInboxCaptures: Bool = false,
        evaActivationCompleted: Bool = false,
        appearance: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-RESET_APP_STATE",
            "-UI_TESTING",
            // Deliberately NOT `-DISABLE_ANIMATIONS`. That calls
            // `UIView.setAnimationsEnabled(false)`, which also disables the UIKit
            // animation machinery XCUITest's `swipeUp()` drives — six tests here
            // fail their "reachable by scrolling" assertions with it set.
            // `LifeBoardAnimation.areProcessAnimationsDisabled` already treats
            // `-UI_TESTING` as animations-off, so token-routed motion and the
            // zoom route transition are suppressed without it.
            "-SKIP_ONBOARDING",
            "-DISABLE_CLOUD_SYNC",
            "-LIFEBOARD_ENABLE_LIFE_OS_FOUNDATION",
            "-LIFEBOARD_ENABLE_DASHBOARD_CUSTOMIZATION_V2",
            "-LIFEBOARD_ENABLE_TRACKERS_V1",
            "-LIFEBOARD_ENABLE_HEALTH_INTEGRATIONS_V1",
            "-LIFEBOARD_ENABLE_JOURNAL_V1",
            "-LIFEBOARD_ENABLE_KNOWLEDGE_NOTES_V1",
            "-LIFEBOARD_ENABLE_PLANNING_CORE_V1",
            "-LIFEBOARD_ENABLE_PLAN_DESTINATION_V1",
            "-LIFEBOARD_ENABLE_FOCUS_EXECUTION_V2",
            "-LIFEBOARD_ENABLE_TRACK_FOUNDATIONS_V2",
            "-LIFEBOARD_ENABLE_HABIT_RESILIENCE_V2",
            "-LIFEBOARD_ENABLE_GOALS_ROUTINES_V1",
            "-LIFEBOARD_ENABLE_CARE_MODULES_V2",
            "-LIFEBOARD_ENABLE_STARTER_PACKS_V1",
            "-LIFEBOARD_ENABLE_LIFE_OS_UNIFIED_PRESENTATION_V2",
            "-UIPreferredContentSizeCategoryName",
            accessibilityCategory
        ]
        if seedHabits { app.launchArguments.append("-LIFEBOARD_TEST_SEED_HABIT_BOARD_WORKSPACE") }
        if seedEstablishedWorkspace { app.launchArguments.append("-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE") }
        if seedLongHomeTaskAgenda { app.launchArguments.append("-LIFEBOARD_TEST_SEED_LONG_HOME_TASK_AGENDA") }
        if seedHomeUserSpace { app.launchArguments.append("-LIFEBOARD_TEST_SEED_HOME_USER_SPACE") }
        if seedFullTimeline { app.launchArguments.append("-LIFEBOARD_TEST_SEED_FULL_TIMELINE_WORKSPACE") }
        if seedRescueWorkspace { app.launchArguments.append("-LIFEBOARD_TEST_SEED_RESCUE_WORKSPACE") }
        if seedInboxCaptures { app.launchArguments.append("-LIFEBOARD_TEST_SEED_INBOX_CAPTURES") }
        if evaActivationCompleted { app.launchArguments.append("-LIFEBOARD_TEST_EVA_ACTIVATION_COMPLETED") }
        if let appearance {
            app.launchArguments.append(contentsOf: ["-AppleInterfaceStyle", appearance])
        }
        app.launchEnvironment["PERFORMANCE_TEST"] = "1"
        app.launch()
        return app
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func saveVisualEvidenceScreenshot(named name: String, platform: String = "ipad") throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let outputDirectory = repositoryRoot
            .appendingPathComponent("docs/evidence/lifeboard-5/root-state-fixtures/\(platform)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try screenshot.pngRepresentation.write(
            to: outputDirectory.appendingPathComponent("\(name).png"),
            options: .atomic
        )
    }

    private func openBacklog(in app: XCUIApplication) {
        let backlog = app.segmentedControls.buttons["Backlog"]
        XCTAssertTrue(backlog.waitForExistence(timeout: 8))
        backlog.tap()
        XCTAssertTrue(app.textFields["plan.backlog.search"].waitForExistence(timeout: 8))
    }

    private func openSeededInbox(in app: XCUIApplication) {
        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        let inbox = app.buttons["plan.lens.Inbox"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 8))
        inbox.tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan.inbox"].waitForExistence(timeout: 10))
    }

    /// Opens a backlog task's action menu.
    ///
    /// This used to tap the task element itself. The card body now opens the
    /// canonical task route instead — tapping it would push a detail screen rather
    /// than surface Delete — so the row's actions are reached through their own
    /// control, which is also the only affordance that was ever a 44-point target.
    private func requestBacklogDeletion(for task: XCUIElement, in app: XCUIApplication) {
        scrollUntilHittable(task, in: app, maximumSwipes: 8)
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        // `plan.taskMenu.` rather than `plan.task.menu.`: the test's own row query
        // matches on the `plan.task.` prefix, so a nested menu identifier would be
        // counted as a task and break every cardinality assertion below.
        let menuIdentifier = task.identifier.replacingOccurrences(
            of: "plan.task.",
            with: "plan.taskMenu."
        )
        let menu = app.buttons[menuIdentifier]
        scrollUntilHittable(menu, in: app, maximumSwipes: 4)
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        XCTAssertTrue(menu.isHittable)
        menu.tap()
        let deletion = app.buttons["Delete from LifeBoard"]
        XCTAssertTrue(deletion.waitForExistence(timeout: 5))
        deletion.tap()
    }

    private func waitForQuery(
        _ query: XCUIElementQuery,
        toHaveCount expectedCount: Int,
        timeout: TimeInterval
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in query.count == expectedCount },
            object: query
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForAccessibilityValue(
        _ value: String,
        on element: XCUIElement,
        timeout: TimeInterval = 8
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForAccessibilityLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval = 8
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func tapHomeAction(
        _ identifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let action = app.buttons[identifier]
        scrollUntilHittableWithSmallSteps(action, in: app, maximumSteps: 32)
        XCTAssertTrue(action.waitForExistence(timeout: 8), file: file, line: line)
        XCTAssertTrue(action.isHittable, "Home action \(identifier) must remain reachable.", file: file, line: line)
        action.tap()
    }


    private func assertFoundationDestination(
        _ destination: String,
        rootIdentifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = app.buttons["foundation.destination.\(destination)"]
        XCTAssertTrue(button.waitForExistence(timeout: 8), file: file, line: line)
        XCTAssertTrue(button.isHittable, "\(destination) must remain reachable.", file: file, line: line)
        button.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[rootIdentifier].waitForExistence(timeout: 12),
            "\(destination) did not expose its native root.",
            file: file,
            line: line
        )
    }

    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 7
    ) {
        for _ in 0..<maximumSwipes where element.exists == false || element.isHittable == false {
            app.swipeUp()
        }
    }

    private func scrollUntilHittableWithSmallSteps(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSteps: Int = 20
    ) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
        for _ in 0..<maximumSteps where element.exists == false || element.isHittable == false {
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    private func scrollUntilVisible(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 7
    ) {
        for _ in 0..<maximumSwipes {
            if element.exists, app.windows.firstMatch.frame.intersects(element.frame) { return }
            app.swipeUp()
        }
    }

}
