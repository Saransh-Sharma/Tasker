import XCTest

final class HabitBoardUITests: BaseUITest {
    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedHabitBoardWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testPresentHabitBoard.rawValue
        ]
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
}
