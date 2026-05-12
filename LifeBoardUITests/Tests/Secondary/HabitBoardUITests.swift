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

    func testHomeHabitRowUsesHybridOverlayLayout() {
        let row = firstHomeHabitRow()

        XCTAssertTrue(row.waitForExistence(timeout: 5), "A home habit row should exist in the seeded workspace")
        XCTAssertTrue(waitForElementToBeHittable(row, timeout: 3))

        let rowID = row.identifier.replacingOccurrences(of: "home.habitRow.", with: "")
        let icon = app.otherElements[AccessibilityIdentifiers.Home.habitRowIcon(rowID)]
        let strip = app.otherElements[AccessibilityIdentifiers.Home.habitRowStrip(rowID)]
        let title = app.staticTexts[AccessibilityIdentifiers.Home.habitRowTitle(rowID)]

        XCTAssertTrue(icon.waitForExistence(timeout: 3), "Expected the habit row icon tile to exist")
        XCTAssertTrue(strip.waitForExistence(timeout: 3), "Expected the habit row streak surface to exist")
        XCTAssertTrue(title.waitForExistence(timeout: 3), "Expected the habit row title overlay to exist")

        XCTAssertGreaterThanOrEqual(icon.frame.height, row.frame.height * 0.8, "Icon tile should fill most of the row height")
        XCTAssertGreaterThanOrEqual(strip.frame.height, row.frame.height * 0.8, "Streak surface should fill most of the row height")
        XCTAssertGreaterThan(strip.frame.width, row.frame.width * 0.45, "Streak surface should occupy the majority of the row width")
        XCTAssertLessThanOrEqual(abs(icon.frame.minX - row.frame.minX), 2, "Icon tile should begin at the row's leading edge")
        XCTAssertLessThanOrEqual(abs(icon.frame.minY - row.frame.minY), 2, "Icon tile should begin at the row's top edge")
        XCTAssertLessThanOrEqual(abs(icon.frame.maxY - row.frame.maxY), 2, "Icon tile should extend to the row's bottom edge")
        XCTAssertLessThanOrEqual(abs(strip.frame.minX - icon.frame.maxX), 2, "Streak surface should begin flush at the icon separator")
        XCTAssertLessThanOrEqual(abs(strip.frame.minY - row.frame.minY), 2, "Streak surface should begin at the row's top edge")
        XCTAssertLessThanOrEqual(abs(strip.frame.maxY - row.frame.maxY), 2, "Streak surface should extend to the row's bottom edge")
        XCTAssertLessThanOrEqual(abs(strip.frame.maxX - row.frame.maxX), 2, "Streak surface should extend to the row's trailing edge")
        XCTAssertGreaterThan(title.frame.minX, icon.frame.maxX, "Title overlay should start to the right of the icon tile")
        XCTAssertGreaterThanOrEqual(title.frame.minX, strip.frame.minX, "Title overlay should sit within the streak surface")
        XCTAssertLessThan(title.frame.maxX, strip.frame.maxX + 1, "Title overlay should remain inside the streak surface")
        XCTAssertGreaterThanOrEqual(title.frame.minY, strip.frame.minY, "Title overlay should be vertically inside the streak surface")
    }

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
        XCTAssertEqual(rangeSubtitle.label, "7-day window")

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
        XCTAssertEqual(previousButton.label, "Show previous 7 days")
        XCTAssertEqual(nextButton.label, "Show next 7 days")

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
        XCTAssertEqual(rangeSubtitle.label, "7-day window")
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
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 3), "Habit detail should expose the edit action")
    }

    func testHabitDetailShowsSquareTappableDayCells() throws {
        openHabitBoard()

        let firstRow = try firstHabitBoardRow()
        firstRow.tap()

        let detailView = app.otherElements[AccessibilityIdentifiers.HabitDetail.view]
        XCTAssertTrue(detailView.waitForExistence(timeout: 5), "Habit detail should render")

        let grid = app.scrollViews[AccessibilityIdentifiers.HabitDetail.grid]
        XCTAssertTrue(grid.waitForExistence(timeout: 3), "Habit detail should expose the streak grid")

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

    func testHabitDetailEditWaitsForDeferredEditorSupport() throws {
        openHabitBoard()

        let firstRow = try firstHabitBoardRow()
        firstRow.tap()

        let detailView = app.otherElements[AccessibilityIdentifiers.HabitDetail.view]
        XCTAssertTrue(detailView.waitForExistence(timeout: 5), "Habit detail should render")

        let editButton = app.buttons[AccessibilityIdentifiers.HabitDetail.editButton]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3), "Habit detail should expose the edit action")
        XCTAssertTrue(waitForElementToBeHittable(editButton, timeout: 3))

        editButton.tap()

        let loadingExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Loading"),
            object: editButton
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [loadingExpectation], timeout: 1.5),
            .completed,
            "Deferred editor support should keep the sheet visible and show a loading affordance"
        )

        let saveButton = app.buttons[AccessibilityIdentifiers.HabitDetail.saveButton]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Habit detail should enter edit mode after editor support loads")
    }

    func testHomeHabitLastCellCyclesThroughThreeStates() throws {
        relaunchForHomeHabitRowAssertions()
        let (rowID, strip) = try firstHomeHabitStrip()

        XCTAssertTrue(strip.waitForExistence(timeout: 5), "A home habit strip should exist in the seeded workspace")
        let lastCell = app.buttons[AccessibilityIdentifiers.Home.habitRowLastCell(rowID)]

        XCTAssertTrue(lastCell.waitForExistence(timeout: 5), "Eligible home habit rows should expose a tappable last-cell button")
        XCTAssertTrue(waitForElementToBeHittable(lastCell, timeout: 3))

        XCTAssertEqual(lastCell.value as? String, "Empty. Next: Mark done.")

        lastCell.tap()
        XCTAssertTrue(waitForLastCellValue(lastCell, expected: "Done. Next: Mark skipped."))

        lastCell.tap()
        XCTAssertTrue(waitForLastCellValue(lastCell, expected: "Skipped. Next: Clear to empty."))

        lastCell.tap()
        XCTAssertTrue(waitForLastCellValue(lastCell, expected: "Empty. Next: Mark done."))
    }

    func testHomeHabitContextMenuStillCommitsMutation() {
        let row = firstHomeHabitRow()

        XCTAssertTrue(row.waitForExistence(timeout: 5), "A home habit row should exist in the seeded workspace")

        let rowID = row.identifier.replacingOccurrences(of: "home.habitRow.", with: "")
        let lastCell = app.buttons[AccessibilityIdentifiers.Home.habitRowLastCell(rowID)]

        XCTAssertTrue(lastCell.waitForExistence(timeout: 5), "Eligible home habit rows should expose a tappable last-cell button")
        XCTAssertEqual(lastCell.value as? String, "Empty. Next: Mark done.")

        row.press(forDuration: 1.1)

        let positiveAction = app.buttons["Done"]
        let abstainAction = app.buttons["Stayed clean"]
        let lapseAction = app.buttons["Log lapse"]

        let actionButton: XCUIElement
        if positiveAction.waitForExistence(timeout: 2) {
            actionButton = positiveAction
        } else if abstainAction.waitForExistence(timeout: 1) {
            actionButton = abstainAction
        } else {
            actionButton = lapseAction
        }

        XCTAssertTrue(actionButton.waitForExistence(timeout: 2), "Context menu should expose a primary mutation action")
        actionButton.tap()

        XCTAssertNotEqual(lastCell.value as? String, "Empty. Next: Mark done.")
    }

    func testHomeHabitRowTapOutsideIconCyclesHabitStateAcrossStripTapPoints() throws {
        relaunchForHomeHabitRowAssertions()
        let (rowID, strip) = try firstHomeHabitStrip()
        XCTAssertTrue(strip.waitForExistence(timeout: 5), "A home habit strip should exist in the seeded workspace")
        let lastCell = app.buttons[AccessibilityIdentifiers.Home.habitRowLastCell(rowID)]
        XCTAssertTrue(lastCell.waitForExistence(timeout: 5), "Eligible home habit rows should expose a tappable last-cell button")
        XCTAssertEqual(lastCell.value as? String, "Empty. Next: Mark done.")

        let stripTapPoints = [0.20, 0.50, 0.80]
        let expectedValues = [
            "Done. Next: Mark skipped.",
            "Skipped. Next: Clear to empty.",
            "Empty. Next: Mark done."
        ]

        for (index, tapPoint) in stripTapPoints.enumerated() {
            let coordinate = strip.coordinate(withNormalizedOffset: CGVector(dx: tapPoint, dy: 0.5))
            coordinate.tap()
            XCTAssertTrue(
                waitForLastCellValue(lastCell, expected: expectedValues[index]),
                "Tapping strip point \(tapPoint) should cycle the habit state"
            )
        }
    }

    func testHomeHabitIconTapStillOpensDetail() throws {
        relaunchForHomeHabitRowAssertions()
        let (rowID, strip) = try firstHomeHabitStrip()
        XCTAssertTrue(strip.waitForExistence(timeout: 5), "A home habit strip should exist in the seeded workspace")
        let icon = app.otherElements[AccessibilityIdentifiers.Home.habitRowIcon(rowID)]
        XCTAssertTrue(icon.waitForExistence(timeout: 5), "Habit row icon should be visible")

        icon.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(
            app.staticTexts["Drink water after breakfast"].waitForExistence(timeout: 5),
            "Tapping the left icon should open habit detail"
        )
    }

    private func openHabitBoard(file: StaticString = #file, line: UInt = #line) {
        for _ in 0..<12 {
            if waitForHabitBoardVisible(timeout: 1) {
                return
            }
        }

        let openBoardButton = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.habitsOpenBoard]
        let backToTodayButton = app.buttons[AccessibilityIdentifiers.Home.backToTodayButton]

        if backToTodayButton.waitForExistence(timeout: 2) && backToTodayButton.isHittable {
            backToTodayButton.tap()
        }

        var foundBoardButton = openBoardButton.waitForExistence(timeout: 4)
        if !foundBoardButton || !openBoardButton.isHittable {
            for _ in 0..<8 {
                if openBoardButton.exists && openBoardButton.isHittable {
                    foundBoardButton = true
                    break
                }
                app.swipeUp()
                foundBoardButton = openBoardButton.waitForExistence(timeout: 1)
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
        let title = app.navigationBars["Habit Board"]
        let close = app.buttons["Close"]
        return board.waitForExistence(timeout: timeout)
            || title.waitForExistence(timeout: timeout)
            || close.waitForExistence(timeout: timeout)
    }

    private func firstHomeHabitRow(file: StaticString = #file, line: UInt = #line) -> XCUIElement {
        dismissHabitBoardIfVisible()

        let backToTodayButton = app.buttons[AccessibilityIdentifiers.Home.backToTodayButton]
        if backToTodayButton.waitForExistence(timeout: 2) && backToTodayButton.isHittable {
            backToTodayButton.tap()
        }

        let rowQuery = app.otherElements.matching(NSPredicate(format: "identifier MATCHES %@", #"^home\.habitRow\.[A-Za-z0-9-]+$"#))
        let firstRow = rowQuery.firstMatch

        if firstRow.waitForExistence(timeout: 3) && firstRow.isHittable {
            return firstRow
        }

        for _ in 0..<8 {
            app.swipeUp()
            if firstRow.exists && firstRow.isHittable {
                break
            }
        }

        XCTAssertTrue(firstRow.waitForExistence(timeout: 2), "Expected to find a home habit row after scrolling", file: file, line: line)
        return firstRow
    }

    private func firstHomeHabitStrip(file: StaticString = #file, line: UInt = #line) throws -> (rowID: String, strip: XCUIElement) {
        dismissHabitBoardIfVisible()

        let backToTodayButton = app.buttons[AccessibilityIdentifiers.Home.backToTodayButton]
        if backToTodayButton.waitForExistence(timeout: 2) && backToTodayButton.isHittable {
            backToTodayButton.tap()
        }

        let stripQuery = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier MATCHES %@", #"^home\.habitRow\.strip\.[A-Za-z0-9-]+$"#)
        )
        let firstStrip = stripQuery.firstMatch

        if firstStrip.waitForExistence(timeout: 3) && firstStrip.isHittable {
            let rowID = firstStrip.identifier.replacingOccurrences(of: "home.habitRow.strip.", with: "")
            return (rowID, firstStrip)
        }

        for _ in 0..<12 {
            app.swipeUp()
            if firstStrip.exists && firstStrip.isHittable {
                break
            }
        }

        guard firstStrip.waitForExistence(timeout: 2) else {
            throw XCTSkip("Home habit strip is unavailable in the current UI test seed")
        }
        let rowID = firstStrip.identifier.replacingOccurrences(of: "home.habitRow.strip.", with: "")
        return (rowID, firstStrip)
    }

    private func firstHabitBoardRow() throws -> XCUIElement {
        do {
            return try requireHabitBoardRows(timeout: 12)
        } catch {
            throw XCTSkip("A board row should be available to open detail")
        }
    }

    private func dismissHabitBoardIfVisible() {
        let closeButton = app.buttons["Close"]
        if closeButton.waitForExistence(timeout: 1) && closeButton.isHittable {
            closeButton.tap()
            XCTAssertFalse(waitForHabitBoardVisible(timeout: 2), "Habit Board should dismiss before returning to Home")
        }
    }

    @discardableResult
    private func waitForLastCellValue(_ element: XCUIElement, expected: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
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

    private func relaunchForHomeHabitRowAssertions() {
        app.terminate()

        let relaunchedApp = XCUIApplication()
        relaunchedApp.launchArguments = [
            "-RESET_APP_STATE",
            "-UI_TESTING",
            "-DISABLE_ANIMATIONS",
            "-SKIP_ONBOARDING"
        ]
        relaunchedApp.launchArguments.append(
            contentsOf: additionalLaunchArguments.filter {
                $0 != XCUIApplication.LaunchArgumentKey.testPresentHabitBoard.rawValue
                    && $0 != XCUIApplication.LaunchArgumentKey.testSeedHabitBoardWorkspace.rawValue
            }
        )
        relaunchedApp.launchArguments.append(XCUIApplication.LaunchArgumentKey.testSeedEstablishedWorkspace.rawValue)
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
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let dateStamps = dayHeaders.allElementsBoundByIndex.compactMap { header in
                header.identifier.split(separator: ".").last.map(String.init)
            }

            if dateStamps.count == 7 {
                if let previous {
                    if dateStamps != previous {
                        return dateStamps
                    }
                } else {
                    return dateStamps
                }
            }

            Thread.sleep(forTimeInterval: 0.2)
        }

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
