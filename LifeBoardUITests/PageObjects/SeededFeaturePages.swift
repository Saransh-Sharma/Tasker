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
        app.buttons[AccessibilityIdentifiers.Snackbar.action("undo")]
    }

    func card(id: String) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueCard(id)]
    }

    @discardableResult
    func open(cardID: String, timeout: TimeInterval = 18) -> Bool {
        if sheet.waitForExistence(timeout: 1), card(id: cardID).waitForExistence(timeout: 1) {
            return true
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if homePage.rescueStartButton.exists {
                tap(homePage.rescueStartButton)
            } else if homePage.rescueOpenButton.exists {
                tap(homePage.rescueOpenButton)
            } else {
                scrollHome()
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

    private func scrollHome() {
        let taskList = app.scrollViews[AccessibilityIdentifiers.Home.taskListScrollView]
        if taskList.exists {
            taskList.swipeUp()
        } else {
            app.scrollViews.firstMatch.swipeUp()
        }
    }
}

@MainActor
final class FocusNowPage {
    private let app: XCUIApplication
    private let homePage: HomePage

    init(app: XCUIApplication, homePage: HomePage) {
        self.app = app
        self.homePage = homePage
    }

    var detailSheet: XCUIElement {
        app.descendants(matching: .other)[AccessibilityIdentifiers.FocusNow.detailSheet]
    }

    var detailReady: XCUIElement {
        app.descendants(matching: .other)[AccessibilityIdentifiers.FocusNow.detailSheet]
    }

    var deck: XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.FocusNow.deck]
    }

    var toast: XCUIElement {
        app.buttons[AccessibilityIdentifiers.FocusNow.toast]
    }

    func waitForHomeStrip(timeout: TimeInterval = 8) -> Bool {
        if homePage.focusStrip.waitForExistence(timeout: min(2, timeout)) {
            return true
        }

        let scrollView = app.scrollViews.firstMatch
        guard scrollView.exists else {
            return false
        }

        for _ in 0..<4 {
            scrollView.swipeUp()
            if homePage.focusStrip.waitForExistence(timeout: 1) {
                return true
            }
        }

        return false
    }

    func openDetail(timeout: TimeInterval = 8) -> Bool {
        if detailSheet.exists {
            return true
        }
        guard waitForHomeStrip(timeout: timeout) else { return false }
        let title = homePage.focusTitleTap
        guard title.waitForExistence(timeout: timeout) else { return false }
        tap(title)
        return detailReady.waitForExistence(timeout: timeout)
    }

    func card(index: Int) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.FocusNow.card(index)]
    }

    func candidateSwap(id: String) -> XCUIElement {
        app.buttons[AccessibilityIdentifiers.FocusNow.candidateSwap(id)]
    }

    func refineRow(id: String) -> XCUIElement {
        app.buttons[AccessibilityIdentifiers.FocusNow.refineRow(id)]
    }

    func tap(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
