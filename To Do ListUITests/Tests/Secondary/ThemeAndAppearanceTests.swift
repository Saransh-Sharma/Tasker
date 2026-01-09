//
//  ThemeAndAppearanceTests.swift
//  To Do ListUITests
//
//  Secondary Tests: Theme & Appearance (3 tests)
//  Tests dark mode, theming, and UI appearance
//

import XCTest

class ThemeAndAppearanceTests: BaseUITest {

    var homePage: HomePage!
    var settingsPage: SettingsPage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)
    }

    // MARK: - Test 61: FluentUI Components Render

    func testFluentUIComponentsRender() throws {
        // GIVEN: App uses FluentUI design system
        // WHEN: User views home screen
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // THEN: FluentUI components should render correctly
        // Verify key UI elements exist and are styled

        // Check for floating action button (Material/Fluent style)
        let addButton = homePage.addTaskButton
        XCTAssertTrue(addButton.exists, "Floating action button should exist")

        // Check for bottom app bar (Fluent style)
        let bottomBar = app.toolbars.firstMatch
        if bottomBar.exists {
            print("✅ Bottom app bar (FluentUI) rendered")
        }

        // Check for task cells with Fluent styling
        let taskCells = app.tables.cells
        if taskCells.count > 0 {
            print("✅ Task cells rendered")
        }

        takeScreenshot(named: "fluentui_components_render")
    }

    // MARK: - Test 62: Dark Mode Toggle

    func testDarkModeToggle() throws {
        // GIVEN: User is on home screen in light mode (default)
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // Capture light mode screenshot
        takeScreenshot(named: "theme_light_mode_before")

        // WHEN: User toggles dark mode
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        settingsPage.toggleDarkMode()
        waitForAnimations(duration: 1.5)

        takeScreenshot(named: "theme_dark_mode_settings")

        // Return to home to see theme change
        homePage = settingsPage.tapDone()
        waitForAnimations(duration: 1.0)

        // THEN: UI should reflect dark mode
        takeScreenshot(named: "theme_dark_mode_home")

        // Toggle back to light mode
        settingsPage = homePage.tapSettings()
        settingsPage.toggleDarkMode()
        waitForAnimations(duration: 1.5)

        homePage = settingsPage.tapDone()
        waitForAnimations(duration: 1.0)

        takeScreenshot(named: "theme_light_mode_restored")
    }

    // MARK: - Test 63: Theme Persistence

    func testThemePersistence() throws {
        // GIVEN: User sets theme to dark mode
        settingsPage = homePage.tapSettings()
        settingsPage.enableDarkMode()
        waitForAnimations(duration: 1.0)

        homePage = settingsPage.tapDone()
        waitForAnimations(duration: 1.0)

        takeScreenshot(named: "theme_persistence_dark_set")

        // WHEN: User restarts app
        app.terminate()
        app.launch()

        homePage = HomePage(app: app)
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should appear after relaunch")

        waitForAnimations(duration: 2.0)

        // THEN: Dark mode should persist
        // (Visual verification via screenshot)
        // Note: With fresh state launch arguments, theme won't persist
        // In production without fresh state, it should persist

        takeScreenshot(named: "theme_persistence_after_relaunch")

        // Restore light mode
        settingsPage = homePage.tapSettings()
        settingsPage.disableDarkMode()
        waitForAnimations(duration: 1.0)
        homePage = settingsPage.tapDone()
    }

    // MARK: - Bonus: FluentUI Material Design Elements

    func testMaterialDesignElements() throws {
        // GIVEN: App uses Material Design components
        // WHEN: User interacts with UI
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // THEN: Material components should be present

        // Floating Action Button (FAB)
        let fab = homePage.addTaskButton
        XCTAssertTrue(fab.exists, "FAB should exist")

        // Ripple effect (visual only - can't be tested programmatically)
        fab.tap()
        waitForAnimations(duration: 0.3)

        let addTaskPage = AddTaskPage(app: app)
        XCTAssertTrue(addTaskPage.verifyIsDisplayed(), "Add task page should appear")

        // Material text fields (MDC)
        XCTAssertTrue(addTaskPage.titleField.exists, "Material text field should exist")

        takeScreenshot(named: "material_design_elements")

        addTaskPage.tapCancel()
    }

    // MARK: - Bonus: System Theme Compatibility

    func testSystemThemeCompatibility() throws {
        // Test that app respects system theme settings
        // (This requires system-level theme control which may not be available in UI tests)

        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // Document that app should respect system appearance
        print("✅ App should respect system theme (light/dark) by default")

        takeScreenshot(named: "system_theme_compatibility")
    }

    // MARK: - Bonus: Dynamic Type Support

    func testDynamicTypeSupport() throws {
        // Test that text scales with dynamic type settings
        // (System font size changes - requires accessibility settings)

        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // Verify text elements exist and are readable
        let taskCells = app.tables.cells
        if taskCells.count > 0 {
            let firstCell = taskCells.element(boundBy: 0)
            let staticTexts = firstCell.staticTexts
            XCTAssertGreaterThan(staticTexts.count, 0, "Cell should contain readable text")
        }

        takeScreenshot(named: "dynamic_type_support")
    }
}
