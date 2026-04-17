import XCTest

final class QuietTrackingUITests: BaseUITest {
    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedQuietTrackingWorkspace.rawValue
        ]
    }

    func testPassiveTrackingRailTapOpensHabitDetailForTappedCard() {
        let homePage = HomePage(app: app)

        XCTAssertTrue(homePage.passiveTrackingRail.waitForExistence(timeout: 8), "Passive tracking rail should appear in the seeded workspace")

        let passiveTrackingCards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityIdentifiers.Home.passiveTrackingCard(""))
        )
        XCTAssertGreaterThanOrEqual(passiveTrackingCards.count, 2, "Seeded quiet tracking workspace should expose at least two passive tracking cards")
        XCTAssertFalse(homePage.quietTrackingSheet.exists, "Quiet tracking sheet should not be visible before tapping passive tracking cards")

        let expectedTitles = ["No phone in bed", "No doomscrolling after dinner"]
        var openedTitles: [String] = []

        for index in 0..<2 {
            let card = passiveTrackingCards.element(boundBy: index)
            let expectedTitle = expectedTitles.first(where: { card.label.contains($0) }) ?? expectedTitles[index]
            XCTAssertTrue(card.waitForExistence(timeout: 3))
            XCTAssertTrue(waitForElementToBeHittable(card, timeout: 3))
            card.tap()

            let navigationTitle = app.navigationBars[expectedTitle]
            let staticTitle = app.staticTexts[expectedTitle]
            XCTAssertTrue(
                navigationTitle.waitForExistence(timeout: 5) || staticTitle.waitForExistence(timeout: 5),
                "Habit detail should open for the tapped passive tracking card"
            )
            XCTAssertFalse(homePage.quietTrackingSheet.exists, "Passive tracking tap should not present the quiet tracking sheet")

            openedTitles.append(expectedTitle)

            let closeButton = app.buttons["Close"]
            XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Habit detail should expose a Close button")
            XCTAssertTrue(waitForElementToBeHittable(closeButton, timeout: 3))
            closeButton.tap()
            XCTAssertTrue(
                waitForElementToDisappear(navigationTitle, timeout: 5)
                    || waitForElementToDisappear(staticTitle, timeout: 5),
                "Closing habit detail should return to Home"
            )
        }

        XCTAssertEqual(Set(openedTitles).count, 2, "Tapping different passive tracking cards should open different habit detail screens")
    }
}
