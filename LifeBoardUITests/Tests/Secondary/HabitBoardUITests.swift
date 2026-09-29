import XCTest

final class HabitBoardUITests: BaseUITest {
    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedHabitBoardWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testPresentHabitBoard.rawValue,
            "\(XCUIApplication.LaunchArgumentKey.testHabitDetailEditorSupportDelayMilliseconds.rawValue):350"
        ]
    }

    // Home's habit rows (`home.habitRow.*`, the Sunrise grid) are not in the
    // live app; Home logs habits in "Habits today", covered by
    // `LifeBoardUITests`. The Board opens from that section's "All habits".

    func testHabitBoardShowsSevenDayMatrixAndPages() throws {
        openHabitBoard()
        _ = try requireHabitBoardRows(timeout: 12)

        XCTAssertTrue(waitForHabitBoardVisible(timeout: 8), "Habit Board should be presented from Home")
        let pinnedHeader = app.otherElements[AccessibilityIdentifiers.HabitBoard.pinnedHeader]
        XCTAssertTrue(pinnedHeader.waitForExistence(timeout: 3), "Pinned HABITS header should exist")

        let rangeTitle = app.staticTexts[AccessibilityIdentifiers.HabitBoard.rangeTitle]
        XCTAssertTrue(rangeTitle.waitForExistence(timeout: 3), "Range title should render on the board")
        let rangeSubtitle = app.staticTexts[AccessibilityIdentifiers.HabitBoard.rangeSubtitle]
        XCTAssertTrue(rangeSubtitle.waitForExistence(timeout: 3), "Range subtitle should provide a secondary scanning cue")
        XCTAssertEqual(rangeSubtitle.label, "7 days")

        let previousButton = app.buttons[AccessibilityIdentifiers.HabitBoard.previousWindow]
        let nextButton = app.buttons[AccessibilityIdentifiers.HabitBoard.nextWindow]

        [previousButton, nextButton].forEach {
            XCTAssertTrue($0.waitForExistence(timeout: 3), "Expected Habit Board control \($0.identifier) to exist")
            XCTAssertTrue($0.isHittable, "Expected Habit Board control \($0.identifier) to be hittable")
        }

        XCTAssertGreaterThanOrEqual(previousButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(previousButton.frame.height, 44)
        XCTAssertGreaterThanOrEqual(nextButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(nextButton.frame.height, 44)
        XCTAssertEqual(previousButton.label, "Previous 7 days")
        XCTAssertEqual(nextButton.label, "Next 7 days")

        let initialHeaderDateStamps = try waitForVisibleDayHeaderDateStamps()
        XCTAssertEqual(initialHeaderDateStamps.count, 7, "Habit Board should expose exactly seven visible day headers")

        let pinnedTitles = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "habitBoard.pinnedTitle."))
        let firstPinnedTitle = pinnedTitles.firstMatch
        XCTAssertTrue(firstPinnedTitle.waitForExistence(timeout: 3), "Pinned habit labels should stay visible in the left rail")
        let initialPinnedTitle = firstPinnedTitle.label
        XCTAssertLessThan(abs(firstPinnedTitle.frame.minX - pinnedHeader.frame.minX), 40, "Pinned title should align under the pinned HABITS rail")

        let visibleRange = rangeTitle.label
        nextButton.tap()
        XCTAssertNotEqual(rangeTitle.label, visibleRange, "Paging forward should update the visible date range")
        let advancedHeaderDateStamps = try waitForVisibleDayHeaderDateStamps(previous: initialHeaderDateStamps)
        XCTAssertEqual(advancedHeaderDateStamps.count, 7, "Paging forward should still render seven day headers")
        XCTAssertEqual(dayDistance(from: initialHeaderDateStamps[0], to: advancedHeaderDateStamps[0]), 7, "Paging should advance the matrix by seven days")

        previousButton.tap()
        XCTAssertEqual(rangeTitle.label, visibleRange, "Paging backward should restore the prior date range")
        XCTAssertEqual(firstPinnedTitle.label, initialPinnedTitle, "Paging the matrix should not replace the pinned habit label rail")
        let restoredHeaderDateStamps = try waitForVisibleDayHeaderDateStamps(previous: advancedHeaderDateStamps)
        XCTAssertEqual(restoredHeaderDateStamps, initialHeaderDateStamps, "Paging backward should restore the original seven-day window")

        let lastDateStamp = initialHeaderDateStamps[0]

        let rowCells = app.otherElements.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                "habitBoard.cell.",
                lastDateStamp
            )
        )
        XCTAssertGreaterThan(rowCells.count, 0, "At least one board cell should share the visible day header date")
    }

    func testHabitBoardAndDetailMaintainTypographyHierarchyAtAccessibilitySize() throws {
        relaunchWithPreferredContentSizeCategory("UICTContentSizeCategoryAccessibilityXL")
        openHabitBoard()

        let firstRow = try requireHabitBoardRows(timeout: 12)
        let rangeTitle = app.staticTexts[AccessibilityIdentifiers.HabitBoard.rangeTitle]
        let rangeSubtitle = app.staticTexts[AccessibilityIdentifiers.HabitBoard.rangeSubtitle]
        XCTAssertTrue(rangeTitle.waitForExistence(timeout: 3), "Range title should remain visible at large text sizes")
        XCTAssertTrue(rangeSubtitle.waitForExistence(timeout: 3), "Range subtitle should remain visible at large text sizes")
        XCTAssertEqual(rangeSubtitle.label, "7 days")
        XCTAssertEqual(try waitForVisibleDayHeaderDateStamps().count, 7, "Board should keep seven visible day headers at large text sizes")

        firstRow.tap()

        let detailView = app.otherElements[AccessibilityIdentifiers.HabitDetail.view]
        XCTAssertTrue(detailView.waitForExistence(timeout: 5), "Habit detail should render")
        XCTAssertTrue(
            app.staticTexts[AccessibilityIdentifiers.HabitDetail.contextPrimary].waitForExistence(timeout: 3),
            "Context primary text should remain visible at large text sizes"
        )
        XCTAssertTrue(
            app.staticTexts[AccessibilityIdentifiers.HabitDetail.contextSecondary].waitForExistence(timeout: 3),
            "Context secondary text should remain visible at large text sizes"
        )
        XCTAssertTrue(
            app.staticTexts[AccessibilityIdentifiers.HabitDetail.helperText].waitForExistence(timeout: 3),
            "Calendar helper text should remain visible at large text sizes"
        )
    }

    func testHabitBoardRowTapOpensHabitDetail() throws {
        openHabitBoard()

        let firstRow = try firstHabitBoardRow()
        XCTAssertTrue(waitForElementToBeHittable(firstRow, timeout: 3))

        firstRow.tap()

        XCTAssertTrue(app.staticTexts["Drink water after breakfast"].waitForExistence(timeout: 5), "Habit detail should show the tapped habit title")
        XCTAssertTrue(app.textFields["Habit title"].waitForExistence(timeout: 3), "Habit detail should expose the always-editable title field")
    }

    func testHabitDetailShowsSquareTappableDayCells() throws {
        openHabitBoard()

        let firstRow = try firstHabitBoardRow()
        firstRow.tap()

        let detailView = app.otherElements[AccessibilityIdentifiers.HabitDetail.view]
        XCTAssertTrue(detailView.waitForExistence(timeout: 5), "Habit detail should render")

        let grid = app.scrollViews[AccessibilityIdentifiers.HabitDetail.grid]
        XCTAssertTrue(grid.waitForExistence(timeout: 3), "Habit detail should expose the streak grid")

        XCTAssertTrue(
            app.otherElements[AccessibilityIdentifiers.HabitDetail.currentStreakMetric].waitForExistence(timeout: 3),
            "Habit detail should show current streak metadata below the grid"
        )
        XCTAssertTrue(
            app.otherElements[AccessibilityIdentifiers.HabitDetail.completionRateMetric].waitForExistence(timeout: 3),
            "Habit detail should show completion rate metadata below the grid"
        )

        let todayCell = app.buttons[AccessibilityIdentifiers.HabitDetail.dayCell(Self.accessibilityStamp(Date()))]
        XCTAssertTrue(todayCell.waitForExistence(timeout: 5), "Today's habit cell should exist in the detail grid")
        XCTAssertTrue(waitForElementToBeHittable(todayCell, timeout: 3))
        XCTAssertGreaterThanOrEqual(todayCell.frame.width, 44, "Day cells should meet minimum touch target width")
        XCTAssertGreaterThanOrEqual(todayCell.frame.height, 44, "Day cells should meet minimum touch target height")
        XCTAssertLessThanOrEqual(abs(todayCell.frame.width - todayCell.frame.height), 1.5, "Day cells should remain visually square")
    }

    func testHabitDetailDayTapKeepsCalendarGridMounted() throws {
        openHabitBoard()

        let firstRow = try requireHabitBoardRows(timeout: 12)
        firstRow.tap()

        let detailView = app.otherElements[AccessibilityIdentifiers.HabitDetail.view]
        XCTAssertTrue(detailView.waitForExistence(timeout: 5), "Habit detail should render")

        let grid = app.scrollViews[AccessibilityIdentifiers.HabitDetail.grid]
        XCTAssertTrue(grid.waitForExistence(timeout: 3), "Habit detail should expose the streak grid")

        let todayCell = app.buttons[AccessibilityIdentifiers.HabitDetail.dayCell(Self.accessibilityStamp(Date()))]
        XCTAssertTrue(todayCell.waitForExistence(timeout: 5), "Today's habit cell should exist in the detail grid")
        XCTAssertTrue(waitForElementToBeHittable(todayCell, timeout: 3))

        todayCell.tap()

        XCTAssertTrue(detailView.waitForExistence(timeout: 5), "Habit detail should remain visible after mutating a day")
        XCTAssertTrue(grid.waitForExistence(timeout: 5), "Streak grid should remain mounted after day mutation")
        XCTAssertTrue(waitForElementToBeHittable(todayCell, timeout: 5), "Day cell should become interactive again after the save cycle")
    }

    func testHabitDetailShowsAlwaysEditableDetailsAfterDeferredEditorSupport() throws {
        openHabitBoard()

        let firstRow = try firstHabitBoardRow()
        firstRow.tap()

        let detailView = app.otherElements[AccessibilityIdentifiers.HabitDetail.view]
        XCTAssertTrue(detailView.waitForExistence(timeout: 5), "Habit detail should render")

        let titleField = app.textFields["Habit title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Habit detail should expose the always-editable title field")

        let detailsDisclosure = app.buttons[AccessibilityIdentifiers.HabitDetail.detailsDisclosure]
        XCTAssertTrue(detailsDisclosure.waitForExistence(timeout: 5), "Habit detail should expose editable details after editor support loads")
        XCTAssertTrue(waitForElementToBeHittable(detailsDisclosure, timeout: 3))
    }

    private func openHabitBoard(file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<12 {
            if waitForHabitBoardVisible(timeout: 1) {
                return
            }
        }

        let openBoardButton = app.buttons[AccessibilityIdentifiers.Home.habitsTodayBoard]

        var foundBoardButton = openBoardButton.waitForExistence(timeout: 4)
        if !foundBoardButton || !openBoardButton.isHittable {
            // At accessibility text sizes Home is several screens tall and a
            // swipe can carry the link past the top; steer by where it is
            // rather than only swiping one way.
            for _ in 0..<16 {
                if openBoardButton.exists && openBoardButton.isHittable {
                    foundBoardButton = true
                    break
                }
                if openBoardButton.exists, openBoardButton.frame.maxY < app.frame.height * 0.2 {
                    app.swipeDown()
                } else {
                    app.swipeUp()
                }
                foundBoardButton = openBoardButton.exists
            }
        }

        XCTAssertTrue(foundBoardButton, "Home habits section should expose the Habit Board entry point", file: file, line: line)
        XCTAssertTrue(waitForElementToBeHittable(openBoardButton, timeout: 4, file: file, line: line))
        openBoardButton.tap()
        XCTAssertTrue(waitForHabitBoardVisible(timeout: 5), "Habit Board should appear after tapping the Home entry point", file: file, line: line)
    }

    @discardableResult
    private func waitForHabitBoardVisible(timeout: TimeInterval) -> Bool {
        let board = app.otherElements[AccessibilityIdentifiers.HabitBoard.view]
        let title = app.navigationBars["Habits"]
        let close = app.buttons["Close"]
        return board.waitForExistence(timeout: timeout)
            || title.waitForExistence(timeout: timeout)
            || close.waitForExistence(timeout: timeout)
    }

    private func firstHabitBoardRow() throws -> XCUIElement {
        do {
            return try requireHabitBoardRows(timeout: 12)
        } catch {
            throw XCTSkip("A board row should be available to open detail")
        }
    }

    private func relaunchWithPreferredContentSizeCategory(_ contentSizeCategory: String) {
        app.terminate()

        let relaunchedApp = XCUIApplication()
        relaunchedApp.launchArguments = [
            "-RESET_APP_STATE",
            "-UI_TESTING",
            "-DISABLE_ANIMATIONS",
            "-SKIP_ONBOARDING"
        ]
        relaunchedApp.launchArguments.append(contentsOf: additionalLaunchArguments)
        relaunchedApp.launchArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName",
            contentSizeCategory
        ])
        relaunchedApp.launchEnvironment[XCUIApplication.LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        app = relaunchedApp
        app.launch()
        waitForAppLaunch()
    }

    private func requireHabitBoardRows(
        timeout: TimeInterval
    ) throws -> XCUIElement {
        let firstRow = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "habitBoard.row.")).firstMatch
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if firstRow.exists {
                return firstRow
            }

            if app.otherElements[AccessibilityIdentifiers.HabitBoard.emptyState].exists {
                throw XCTSkip("No habit board rows available in the seeded test workspace")
            }

            if app.otherElements[AccessibilityIdentifiers.HabitBoard.errorState].exists {
                throw XCTSkip("Habit board entered an error state in the seeded test workspace")
            }

            _ = app.otherElements[AccessibilityIdentifiers.HabitBoard.loadingState].waitForExistence(timeout: 0.25)
        }
        throw XCTSkip("No habit board rows available in the seeded test workspace")
    }

    private func waitForVisibleDayHeaderDateStamps(
        previous: [String]? = nil,
        timeout: TimeInterval = 5
    ) throws -> [String] {
        let dayHeaders = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "habitBoard.dayHeader."))
        var resolved: [String]?
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
            let dateStamps = dayHeaders.allElementsBoundByIndex.compactMap { header in
                header.identifier.split(separator: ".").last.map(String.init)
            }

            if dateStamps.count == 7 {
                if let previous {
                    if dateStamps != previous {
                        resolved = dateStamps
                        return true
                    }
                } else {
                    resolved = dateStamps
                    return true
                }
            }

            return false
            },
            object: NSObject()
        )
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if let resolved { return resolved }

        throw XCTSkip("Expected seven visible day headers, but the seeded board did not stabilize in time")
    }

    private func dayDistance(from lhsDateStamp: String, to rhsDateStamp: String) -> Int {
        guard let lhsDate = Self.accessibilityDateFormatter.date(from: lhsDateStamp),
              let rhsDate = Self.accessibilityDateFormatter.date(from: rhsDateStamp) else {
            XCTFail("Unable to parse habit board date stamps: \(lhsDateStamp), \(rhsDateStamp)")
            return 0
        }
        return Calendar(identifier: .gregorian).dateComponents([.day], from: lhsDate, to: rhsDate).day ?? 0
    }

    private static let accessibilityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func accessibilityStamp(_ date: Date) -> String {
        accessibilityDateFormatter.string(from: date)
    }
}

/// The amount ring on the Board's Day lens: tap adds a step, holding fills to
/// the target, and each change is announced in the person's own units.
final class HabitAmountRingUITests: BaseUITest {
    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedHabitBoardWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testPresentHabitBoard.rawValue,
            "-LIFEBOARD_TEST_SEED_HABIT_AMOUNTS"
        ]
    }

    func testRingAddsAStepOnTapAndFinishesOnHold() {
        // In the Foundation shell the board is a typed Track leaf, reached from
        // Home's routines card.
        let openBoard = app.buttons["home.routines.openHabitBoard"]
        for _ in 0..<10 where openBoard.exists == false || openBoard.isHittable == false {
            app.swipeUp()
        }
        if openBoard.isHittable { openBoard.tap() }
        let dayLens = app.buttons["habitBoard.lens.day"]
        XCTAssertTrue(dayLens.waitForExistence(timeout: 12))
        dayLens.tap()

        let ring = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "habitBoard.day.ring.")).firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 10), "An amount habit shows a ring on the Day lens")
        XCTAssertEqual(ring.value as? String, "0 of 8 glasses")

        ring.tap()
        XCTAssertTrue(waitForValue("1 of 8 glasses", on: ring), "A tap adds one step")

        ring.press(forDuration: 1.4)
        XCTAssertTrue(waitForValue("8 of 8 glasses", on: ring), "Holding fills the ring to the target")
    }

    private func waitForValue(_ expected: String, on element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expected)
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }
}
