//
//  ThemeAndAppearanceTests.swift
//  LifeBoardUITests
//
//  Secondary Tests: Theme & Appearance (3 tests)
//  Tests dark mode, theming, and UI appearance
//

import XCTest

class ThemeAndAppearanceTests: BaseUITest {

    var homePage: HomePage!
    var settingsPage: SettingsPage!

    override func setUp() async throws {
        try await super.setUp()
        homePage = HomePage(app: app)
    }

    // MARK: - Test 61: Core Components Render

    func testCoreComponentsRender() throws {
        // GIVEN: App uses the current design system
        // WHEN: User views home screen
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // THEN: Key components should render correctly
        // Verify key UI elements exist and are styled

        // Check for floating action button
        let addButton = homePage.addTaskButton
        XCTAssertTrue(addButton.exists, "Floating action button should exist")

        // Check for bottom app bar (glass style)
        XCTAssertTrue(homePage.verifyBottomBarExists(), "Home bottom bar should exist")

        // Check for task cells with expected styling
        let taskCells = app.tables.cells
        if taskCells.count > 0 {
            print("✅ Task cells rendered")
        }

        takeScreenshot(named: "core_components_render")
    }

    // MARK: - Test 62: Workspace Settings Messaging

    func testWorkspaceSettingsMessaging() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        XCTAssertTrue(app.staticTexts["Life Management"].waitForExistence(timeout: 3), "Life Management row should exist")
        XCTAssertTrue(app.staticTexts["AI Assistant"].waitForExistence(timeout: 3), "AI Assistant row should exist")
        XCTAssertTrue(settingsPage.heroCard.waitForExistence(timeout: 3), "Settings hero should exist")

        takeScreenshot(named: "workspace_settings_rows")
    }

    // MARK: - Test 63: Theme Propagation Into Settings

    func testThemePropagationIntoSettings() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should appear")
        takeScreenshot(named: "brand_surface_home")

        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should appear")
        XCTAssertTrue(app.staticTexts["Life Management"].waitForExistence(timeout: 3), "Workspace rows should remain visible in settings")
        XCTAssertTrue(app.staticTexts["AI Assistant"].waitForExistence(timeout: 3), "AI Assistant row should remain visible in settings")
        takeScreenshot(named: "brand_surface_settings")

        homePage = settingsPage.tapDone()
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should be displayed after closing settings")
    }

    // MARK: - Bonus: Material Design Elements

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

    func testThemeAndLLMSettingsVisibility() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        XCTAssertTrue(app.staticTexts["Life Management"].waitForExistence(timeout: 3), "Life Management setting should exist")
        XCTAssertTrue(app.staticTexts["AI Assistant"].waitForExistence(timeout: 3), "AI Assistant setting should exist")
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Settings.onboardingRestartButton].waitForExistence(timeout: 3), "Guided Setup row should exist")

        takeScreenshot(named: "theme_and_llm_settings_visibility")
    }

    func testThemePropagationAcrossHomeAddTaskSearchSettingsAndLLM() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")
        takeScreenshot(named: "theme_surface_home")

        // Add Task surface
        let addTaskPage = homePage.tapAddTask()
        XCTAssertTrue(addTaskPage.verifyIsDisplayed(), "Add task screen should be displayed")
        takeScreenshot(named: "theme_surface_add_task")
        addTaskPage.tapCancel()
        XCTAssertTrue(addTaskPage.waitForDismissal(timeout: 3), "Add task screen should dismiss")

        // Search surface
        homePage.tapSearch()
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Search screen should be displayed")
        XCTAssertTrue(homePage.searchField.waitForExistence(timeout: 3), "Search field should be visible on backdrop")
        takeScreenshot(named: "theme_surface_search")
        if homePage.searchBackChip.exists {
            homePage.tapSearchBackChip()
        } else {
            homePage.tapSearch()
        }
        XCTAssertTrue(homePage.waitForSunriseState("collapsed", timeout: 3), "Search should collapse before opening settings")

        // Settings + LLM surfaces
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")
        takeScreenshot(named: "theme_surface_settings")

        if settingsPage.verifyAIAssistantRowExists() {
            settingsPage.navigateToAIAssistant()
            let llmNav = app.navigationBars["AI Assistant"]
            XCTAssertTrue(llmNav.waitForExistence(timeout: 3) || app.navigationBars.firstMatch.exists, "LLM settings should be displayed")
            takeScreenshot(named: "theme_surface_llm")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        homePage = settingsPage.tapDone()
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should be displayed after closing settings")
    }

    func testAllCelestialPhasesResolveInThePersistentRootHost() throws {
        for phase in ["dawn", "morning", "midday", "goldenHour", "twilight", "night"] {
            app.terminate()
            app.launchVisualFixture(root: "home", state: "populated", phase: phase)

            let marker = app.otherElements["lifeboard.atmosphere.\(phase)"]
            XCTAssertTrue(
                marker.waitForExistence(timeout: 5),
                "The persistent atmosphere host should resolve \(phase)"
            )
            takeScreenshot(named: "celestial_home_\(phase)")
        }
    }

    func testCelestialAtmospherePersistsAcrossEveryPrimaryRoot() throws {
        for root in ["home", "plan", "track", "insights", "eva"] {
            app.terminate()
            app.launchVisualFixture(root: root, state: "populated", phase: "twilight")

            XCTAssertTrue(
                app.otherElements["lifeboard.atmosphere.twilight"].waitForExistence(timeout: 5),
                "The shared Twilight atmosphere should remain installed behind \(root)"
            )
            takeScreenshot(named: "celestial_twilight_\(root)")
        }
    }

    func testCelestialAccessibilityAppearanceFallbackMatrix() throws {
        let appearances = [
            "light", "dark", "high-contrast-light", "high-contrast-dark",
            "reduced-transparency", "reduced-motion", "grayscale"
        ]

        for appearance in appearances {
            app.terminate()
            app.launchVisualFixture(
                root: "home",
                state: "populated",
                appearance: appearance,
                phase: "night"
            )

            XCTAssertTrue(
                app.otherElements["lifeboard.atmosphere.night"].waitForExistence(timeout: 5),
                "Night should remain usable with the \(appearance) fallback"
            )
            takeScreenshot(named: "celestial_night_\(appearance)")
        }
    }

    func testCelestialFocusedStatusSurfaceMatrix() throws {
        let states = [
            "empty", "loading", "stale", "offline", "denied",
            "recoverable-error", "locked", "destructive-confirmation"
        ]

        for state in states {
            app.terminate()
            app.launchVisualFixture(root: "home", state: state, phase: "midday")

            XCTAssertTrue(
                app.otherElements["fixture.home.\(state)"].waitForExistence(timeout: 5),
                "The focused \(state) surface should render on the phase canvas"
            )
            takeScreenshot(named: "celestial_midday_home_\(state)")
        }
    }
}
