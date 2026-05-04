import XCTest

class SettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        let app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testNavigateToAndDismissSettingsPage() throws {
        let app = XCUIApplication()

        // Attempt to tap the Settings button (gear icon)
        // The leadingBarButtonItems are [barButtonSearch, barButtonInbox, barButtonMenu(Settings)]
        // So, the settings button is the 3rd item (index 2) if we can access these buttons directly.
        // MDCBottomAppBarView might be identified as a generic toolbar or other element.

        // Option 1: Try by accessibility label (if system name "gearshape.fill" provides one or if "Settings" is set)
        // NSPredicate is more flexible for partial matches.
        let settingsPredicate = NSPredicate(format: "label CONTAINS[c] 'Settings' OR label CONTAINS[c] 'gear' OR identifier CONTAINS[c] 'settings'")
        let settingsButtonQuery = app.buttons.containing(settingsPredicate)
        
        var settingsButtonToTap: XCUIElement?

        // First, try to find a button that matches the predicate directly
        if settingsButtonQuery.count > 0 {
            settingsButtonToTap = settingsButtonQuery.firstMatch
        }
        
        // If not found directly, try looking within toolbars/bottomToolbars
        // MDCBottomAppBarView might be interpreted as a UIToolbar by accessibility.
        if settingsButtonToTap == nil || !settingsButtonToTap!.exists {
            // Try the last button in the first bottom toolbar, assuming it's the settings button.
            // This is based on the visual layout and common patterns.
            // The order of buttons in `leadingBarButtonItems` is Search, Inbox, Menu(Settings).
            // If these are the only items, and it's the primary toolbar, it might be index 2.
            // However, `firstMatch` for toolbars might be the top one if any.
            // Let's try to find the bottom toolbar specifically.
            if app.toolbars.firstMatch.exists { // `toolbars` finds all toolbars including bottom bars
                 let buttonsInBottomBar = app.toolbars.firstMatch.buttons
                 if buttonsInBottomBar.count > 2 { // Check if there are at least 3 buttons
                    settingsButtonToTap = buttonsInBottomBar.element(boundBy: 2) // Settings is the 3rd
                 } else if buttonsInBottomBar.count > 0 {
                    settingsButtonToTap = buttonsInBottomBar.element(boundBy: buttonsInBottomBar.count - 1) // Fallback to last
                 }
            }
        }
        
        // As a further fallback, if it's not a toolbar, it might be buttons directly under app, or within otherElements
        if settingsButtonToTap == nil || !settingsButtonToTap!.exists {
            // This is a very generic attempt if the structure is flat
            let allButtons = app.buttons
            if allButtons.matching(settingsPredicate).count > 0 {
                 settingsButtonToTap = allButtons.matching(settingsPredicate).firstMatch
            }
        }


        // Check if the button exists and tap it
        if let button = settingsButtonToTap, button.waitForExistence(timeout: 10) {
            button.tap()
        } else {
            // If specific queries fail, print debug description and try a more general approach or fail.
            print(app.debugDescription)
            // As a last resort, try to find *any* button that could be settings, based on common labels.
            // This is less precise.
            let potentialSettingsButtons = app.buttons.matching(NSPredicate(format: "label IN {'Settings', 'Menu', 'gearshape.fill'}"))
            if potentialSettingsButtons.count > 0 && potentialSettingsButtons.firstMatch.waitForExistence(timeout: 5) {
                potentialSettingsButtons.firstMatch.tap()
            } else {
                 XCTFail("Could not find or tap the Settings button. Check accessibility identifiers or hierarchy.")
            }
        }

        // Verify Settings Page is displayed by checking for the navigation bar titled "Settings"
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5), "Settings page navigation bar did not appear.")

        // Tap the "Done" button in the "Settings" navigation bar
        // Ensure the "Settings" navigation bar itself exists before trying to tap a button in it.
        let settingsNavBar = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNavBar.exists, "Settings navigation bar does not exist before tapping Done.")
        let doneButton = settingsNavBar.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button does not exist in Settings navigation bar.")
        doneButton.tap()

        // Verify Settings Page is dismissed
        // Check that the "Settings" navigation bar no longer exists.
        // Adding a small delay for the dismissal animation to complete.
        // Using waitForExistence with a short timeout and checking for false is better.
        XCTAssertFalse(app.navigationBars["Settings"].waitForExistence(timeout: 5), "Settings page was not dismissed.")
        
        // Optionally, verify that an element from the HomeViewController is visible again
        // For example, if HomeViewController has a specific, identifiable element:
        // XCTAssertTrue(app.otherElements["HomeViewIdentifier"].exists) // Replace with actual identifier
    }

    func testNavigateToProjectManagementAndBack() throws {
        let app = XCUIApplication()

        // 1. Navigate to Settings page (reuse the robust button finding logic)
        let settingsPredicate = NSPredicate(format: "label CONTAINS[c] 'Settings' OR label CONTAINS[c] 'gear' OR identifier CONTAINS[c] 'settings' OR label CONTAINS[c] 'Menu'")
        var settingsButton = app.buttons.containing(settingsPredicate).firstMatch
        
        if !settingsButton.exists {
            // Fallback if it's in a toolbar and the above predicate didn't catch it by a more generic label
            // This assumes the gear icon for settings is the third button (index 2) if others like search/calendar are present
            // Or it could be the last one if fewer buttons are there.
            // Using app.toolbars.firstMatch as a general approach for the bottom bar if it's identified as a toolbar
            let bottomToolbar = app.toolbars.firstMatch 
            if bottomToolbar.exists {
                 settingsButton = bottomToolbar.buttons.element(boundBy: 2) // Try 3rd
                 if !settingsButton.exists && bottomToolbar.buttons.count > 0 {
                     settingsButton = bottomToolbar.buttons.element(boundBy: bottomToolbar.buttons.count - 1) // Try last
                 }
            }
        }
        
        // Final attempt with a simpler predicate if still not found by more specific queries
        if !settingsButton.exists {
             let simplerPredicate = NSPredicate(format: "label IN {'Settings', 'Menu', 'gearshape.fill'}")
             settingsButton = app.buttons.containing(simplerPredicate).firstMatch
        }

        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "Settings button not found.") // Increased timeout for initial button
        settingsButton.tap()

        let settingsNavBar = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNavBar.waitForExistence(timeout: 5), "Settings page did not appear.")

        // 2. Tap the "Project Management" row
        // In a Form, rows are often identified as buttons or staticTexts.
        // If it's a NavigationLink, its label "Project Management" should be tappable.
        // We might need to tap the cell containing this text.
        // Using .cells.staticTexts is often more robust for Form/List in SwiftUI
        let projectManagementRow = app.tables.cells.staticTexts["Project Management"]
        
        XCTAssertTrue(projectManagementRow.waitForExistence(timeout: 5), "'Project Management' row not found.")
        projectManagementRow.tap()

        // 3. Verify "Projects" management page is displayed
        let projectsNavBar = app.navigationBars["Projects"]
        XCTAssertTrue(projectsNavBar.waitForExistence(timeout: 5), "Project Management page did not appear.")

        // 4. Tap the back button to return to Settings
        // The back button in a NavigationView usually takes the title of the previous screen, or a generic "Back".
        // In this case, the previous screen is "Settings".
        // The back button is typically the first button in the navigation bar.
        projectsNavBar.buttons.element(boundBy: 0).tap() 

        // 5. Verify Settings page is displayed again
        XCTAssertTrue(settingsNavBar.waitForExistence(timeout: 5), "Did not navigate back to Settings page.")

        // 6. Tap "Done" to dismiss settings
        settingsNavBar.buttons["Done"].tap()

        // 7. Verify Settings page is dismissed
        XCTAssertFalse(settingsNavBar.waitForExistence(timeout: 5), "Settings page was not dismissed after tapping Done.")
    }
}
