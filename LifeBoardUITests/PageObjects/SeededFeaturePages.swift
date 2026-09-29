import XCTest

@MainActor
final class OverdueRescuePage {
    private let app: XCUIApplication
    private let homePage: HomePage

    init(app: XCUIApplication, homePage: HomePage) {
        self.app = app
        self.homePage = homePage
    }

    var sheet: XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueSheet]
    }

    var keepTodayButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.rescueActionKeepToday]
    }

    var moveLaterButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.rescueActionMoveLater]
    }

    var editButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.rescueActionEdit]
    }

    var deleteButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.rescueActionDelete]
    }

    var snackbarUndoButton: XCUIElement {
        // The snackbar draws the shared receipt bar, whose Undo is this.
        app.buttons["lifeboard.receipt.undo"]
    }

    func card(id: String) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueCard(id)]
    }

    /// Plan's day decision line (or its empty-day card) is the live entry to
    /// the Overdue Rescue deck; Home's "Needs you" row opens Plan's overdue
    /// week instead.
    var planRescueEntry: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Plan.openRescue]
    }

    @discardableResult
    func open(cardID: String, timeout: TimeInterval = 18) -> Bool {
        if sheet.waitForExistence(timeout: 1), card(id: cardID).waitForExistence(timeout: 1) {
            return true
        }

        homePage.openRoot("plan")
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if planRescueEntry.exists, planRescueEntry.isHittable {
                tap(planRescueEntry)
            } else {
                app.swipeUp()
            }

            if sheet.waitForExistence(timeout: 2), card(id: cardID).waitForExistence(timeout: 4) {
                return true
            }
        }
        return false
    }

    func tap(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
