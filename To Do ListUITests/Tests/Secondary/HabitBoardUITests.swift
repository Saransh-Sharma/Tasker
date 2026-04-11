import XCTest

final class HabitBoardUITests: BaseUITest {
    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedHabitBoardWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testPresentHabitBoard.rawValue
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

    func testHabitBoardShowsSevenDayMatrixAndPages() {
        openHabitBoard()

        let board = app.otherElements[AccessibilityIdentifiers.HabitBoard.view]
        XCTAssertTrue(board.waitForExistence(timeout: 8), "Habit Board should be presented from Home")
        let pinnedHeader = app.otherElements[AccessibilityIdentifiers.HabitBoard.pinnedHeader]
        XCTAssertTrue(pinnedHeader.waitForExistence(timeout: 3), "Pinned HABITS header should exist")

        let rangeTitle = app.staticTexts[AccessibilityIdentifiers.HabitBoard.rangeTitle]
        XCTAssertTrue(rangeTitle.waitForExistence(timeout: 3), "Range title should render on the board")

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

        let dayHeaders = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "habitBoard.dayHeader."))
        XCTAssertEqual(dayHeaders.count, 7, "Compact portrait should expose exactly seven visible day headers")

        let pinnedTitles = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "habitBoard.pinnedTitle."))
        let firstPinnedTitle = pinnedTitles.firstMatch
        XCTAssertTrue(firstPinnedTitle.waitForExistence(timeout: 3), "Pinned habit labels should stay visible in the left rail")
        let initialPinnedTitle = firstPinnedTitle.label
        XCTAssertLessThan(abs(firstPinnedTitle.frame.minX - pinnedHeader.frame.minX), 40, "Pinned title should align under the pinned HABITS rail")

        let visibleRange = rangeTitle.label
        nextButton.tap()
        XCTAssertNotEqual(rangeTitle.label, visibleRange, "Paging forward should update the visible date range")

        previousButton.tap()
        XCTAssertEqual(rangeTitle.label, visibleRange, "Paging backward should restore the prior date range")
        XCTAssertEqual(firstPinnedTitle.label, initialPinnedTitle, "Paging the matrix should not replace the pinned habit label rail")

        let headerIdentifiers = dayHeaders.allElementsBoundByIndex.map(\.identifier)
        XCTAssertEqual(headerIdentifiers.count, 7)

        guard let firstHeaderID = headerIdentifiers.first,
              let lastDateStamp = firstHeaderID.split(separator: ".").last else {
            XCTFail("Expected a visible day header identifier")
            return
        }

        let rowCells = app.otherElements.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                "habitBoard.cell.",
                String(lastDateStamp)
            )
        )
        XCTAssertGreaterThan(rowCells.count, 0, "At least one board cell should share the visible day header date")
    }

    func testHabitBoardRowTapOpensHabitDetail() {
        openHabitBoard()

        let firstRow = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "habitBoard.row.")).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "A board row should be available to open detail")
        XCTAssertTrue(waitForElementToBeHittable(firstRow, timeout: 3))

        firstRow.tap()

        XCTAssertTrue(app.staticTexts["Drink water after breakfast"].waitForExistence(timeout: 5), "Habit detail should show the tapped habit title")
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 3), "Habit detail should expose the edit action")
    }

    func testHomeHabitLastCellCyclesThroughThreeStates() {
        let row = firstHomeHabitRow()

        XCTAssertTrue(row.waitForExistence(timeout: 5), "A home habit row should exist in the seeded workspace")

        let rowID = row.identifier.replacingOccurrences(of: "home.habitRow.", with: "")
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

    func testHomeHabitRowTapOutsideLastCellStillOpensDetail() {
        let row = firstHomeHabitRow()

        XCTAssertTrue(row.waitForExistence(timeout: 5), "A home habit row should exist in the seeded workspace")

        let coordinate = row.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        coordinate.tap()

        XCTAssertTrue(app.staticTexts["Drink water after breakfast"].waitForExistence(timeout: 5), "Tapping outside the last cell should still open habit detail")
    }

    private func openHabitBoard(file: StaticString = #file, line: UInt = #line) {
        let board = app.otherElements[AccessibilityIdentifiers.HabitBoard.view]
        if board.waitForExistence(timeout: 6) {
            return
        }

        let openBoardButton = app.buttons[AccessibilityIdentifiers.Home.habitsOpenBoard]
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

        XCTAssertTrue(foundBoardButton && openBoardButton.isHittable, "Home habits section should expose the Habit Board entry point", file: file, line: line)
        XCTAssertTrue(waitForElementToBeHittable(openBoardButton, timeout: 3, file: file, line: line))
        openBoardButton.tap()
        XCTAssertTrue(board.waitForExistence(timeout: 5), "Habit Board should appear after tapping the Home entry point", file: file, line: line)
    }

    private func firstHomeHabitRow(file: StaticString = #file, line: UInt = #line) -> XCUIElement {
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

    @discardableResult
    private func waitForLastCellValue(_ element: XCUIElement, expected: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
