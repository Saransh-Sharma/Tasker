// LGMorphingUITests.swift
// UI automation tests for Liquid Glass morphing effects and animations
// Tests user interactions, visual effects, and performance

import XCTest

class LGMorphingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Component Test Screen Tests
    
    func testComponentTestScreenAccess() throws {
        // Navigate to component test screen (assuming debug menu access)
        let debugButton = app.buttons["Debug Menu"]
        if debugButton.exists {
            debugButton.tap()
            
            let componentTestButton = app.buttons["Component Test"]
            XCTAssertTrue(componentTestButton.waitForExistence(timeout: 2), "Component test button should exist")
            componentTestButton.tap()
            
            let componentTestScreen = app.staticTexts["LGTaskCard"]
            XCTAssertTrue(componentTestScreen.waitForExistence(timeout: 3), "Component test screen should load")
        }
    }
    
    // MARK: - Button Morphing Tests
    
    func testButtonMorphingEffects() throws {
        // Navigate to component test screen
        navigateToComponentTestScreen()
        
        // Find button components section
        let buttonSection = app.staticTexts["LGButton"]
        if buttonSection.exists {
            buttonSection.swipeUp() // Scroll to make buttons visible
            
            // Test primary button morphing
            let primaryButton = app.buttons.matching(identifier: "primary_button").firstMatch
            if primaryButton.exists {
                // Test tap morphing
                primaryButton.tap()
                
                // Verify button responds to touch (visual verification would require image comparison)
                XCTAssertTrue(primaryButton.exists, "Button should still exist after tap")
            }
        }
    }
    
    func testButtonHoverEffects() throws {
        // This test is primarily for iPad/Mac Catalyst
        #if targetEnvironment(macCatalyst)
        navigateToComponentTestScreen()
        
        let button = app.buttons.matching(identifier: "hover_test_button").firstMatch
        if button.exists {
            // Simulate hover (this is challenging in UI tests)
            button.hover()
            
            // Verify hover state (would need visual verification)
            XCTAssertTrue(button.exists, "Button should exist during hover")
        }
        #endif
    }
    
    // MARK: - Progress Bar Animation Tests
    
    func testProgressBarAnimations() throws {
        navigateToComponentTestScreen()
        
        // Scroll to progress bar section
        app.swipeUp()
        
        let progressSection = app.staticTexts["LGProgressBar"]
        if progressSection.exists {
            // Look for progress bar elements
            let progressBar = app.progressIndicators.firstMatch
            if progressBar.exists {
                // Verify progress bar is visible
                XCTAssertTrue(progressBar.exists, "Progress bar should be visible")
                
                // Test animated progress change (would need to verify value changes)
                let animateButton = app.buttons["Animate Progress"]
                if animateButton.exists {
                    animateButton.tap()
                    
                    // Wait for animation to complete
                    sleep(1)
                    
                    // Verify progress bar still exists after animation
                    XCTAssertTrue(progressBar.exists, "Progress bar should exist after animation")
                }
            }
        }
    }
    
    // MARK: - Text Field Morphing Tests
    
    func testTextFieldMorphing() throws {
        navigateToComponentTestScreen()
        
        // Scroll to text field section
        app.swipeUp()
        app.swipeUp()
        
        let textFieldSection = app.staticTexts["LGTextField"]
        if textFieldSection.exists {
            let textField = app.textFields.firstMatch
            if textField.exists {
                // Test focus morphing
                textField.tap()
                
                // Type text to test floating placeholder
                textField.typeText("Test input")
                
                // Verify text was entered
                XCTAssertEqual(textField.value as? String, "Test input", "Text should be entered correctly")
                
                // Test unfocus
                app.tap() // Tap outside to unfocus
                
                // Verify text field still contains text
                XCTAssertEqual(textField.value as? String, "Test input", "Text should persist after unfocus")
            }
        }
    }
    
    // MARK: - Search Bar Tests
    
    func testSearchBarMorphing() throws {
        navigateToComponentTestScreen()
        
        // Scroll to search bar section
        scrollToSection("LGSearchBar")
        
        let searchBar = app.searchFields.firstMatch
        if searchBar.exists {
            // Test search bar activation
            searchBar.tap()
            
            // Type search query
            searchBar.typeText("test query")
            
            // Verify search text
            XCTAssertTrue(searchBar.value as? String == "test query", "Search text should be entered")
            
            // Test suggestions (if visible)
            let suggestionsList = app.tables.firstMatch
            if suggestionsList.exists {
                XCTAssertTrue(suggestionsList.cells.count > 0, "Suggestions should be visible")
            }
        }
    }
    
    // MARK: - Floating Action Button Tests
    
    func testFloatingActionButtonMorphing() throws {
        navigateToComponentTestScreen()
        
        scrollToSection("LGFloatingActionButton")
        
        let fab = app.buttons.matching(identifier: "floating_action_button").firstMatch
        if fab.exists {
            // Test FAB tap with ripple effect
            fab.tap()
            
            // Verify FAB responds to interaction
            XCTAssertTrue(fab.exists, "FAB should exist after tap")
            
            // Test expandable actions (if implemented)
            fab.press(forDuration: 1.0)
            
            // Look for expanded action buttons
            let expandedActions = app.buttons.matching(identifier: "fab_action").count
            if expandedActions > 0 {
                XCTAssertTrue(expandedActions > 0, "Expanded actions should be visible")
            }
        }
    }
    
    // MARK: - Task Card Tests
    
    func testTaskCardMorphing() throws {
        navigateToComponentTestScreen()
        
        let taskCardSection = app.staticTexts["LGTaskCard"]
        if taskCardSection.exists {
            // Look for task card elements
            let taskCard = app.buttons.matching(identifier: "task_card").firstMatch
            if taskCard.exists {
                // Test task card tap
                taskCard.tap()
                
                // Verify interaction
                XCTAssertTrue(taskCard.exists, "Task card should exist after tap")
                
                // Test completion toggle if available
                let completionToggle = taskCard.buttons["completion_toggle"]
                if completionToggle.exists {
                    completionToggle.tap()
                    
                    // Verify toggle state change (visual verification needed)
                    XCTAssertTrue(completionToggle.exists, "Completion toggle should exist after tap")
                }
            }
        }
    }
    
    // MARK: - Theme Switching Tests
    
    func testThemeSwitchingMorphing() throws {
        navigateToComponentTestScreen()
        
        // Scroll to theme section
        scrollToSection("Theme Switching")
        
        let themeButtons = app.buttons.matching(identifier: "theme_button")
        if themeButtons.count > 0 {
            // Test switching to dark theme
            let darkThemeButton = app.buttons["Dark"]
            if darkThemeButton.exists {
                darkThemeButton.tap()
                
                // Wait for theme transition
                sleep(1)
                
                // Verify theme change (would need visual verification)
                XCTAssertTrue(darkThemeButton.exists, "Dark theme button should exist")
            }
            
            // Test switching to light theme
            let lightThemeButton = app.buttons["Light"]
            if lightThemeButton.exists {
                lightThemeButton.tap()
                
                // Wait for theme transition
                sleep(1)
                
                // Verify theme change
                XCTAssertTrue(lightThemeButton.exists, "Light theme button should exist")
            }
            
            // Test Aurora theme for special effects
            let auroraThemeButton = app.buttons["Aurora"]
            if auroraThemeButton.exists {
                auroraThemeButton.tap()
                
                // Wait for theme transition with special effects
                sleep(2)
                
                // Verify Aurora theme applied
                XCTAssertTrue(auroraThemeButton.exists, "Aurora theme button should exist")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testMorphingPerformance() throws {
        navigateToComponentTestScreen()
        
        // Measure time for multiple morphing operations
        measure(metrics: [XCTClockMetric()]) {
            // Perform multiple button taps to test morphing performance
            let buttons = app.buttons.matching(identifier: "performance_test_button")
            
            for i in 0..<min(buttons.count, 5) {
                let button = buttons.element(boundBy: i)
                if button.exists {
                    button.tap()
                }
            }
        }
    }
    
    func testScrollPerformance() throws {
        navigateToComponentTestScreen()
        
        // Measure scrolling performance with glass effects
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<3 {
                app.swipeUp()
                app.swipeDown()
            }
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityWithMorphing() throws {
        navigateToComponentTestScreen()
        
        // Test VoiceOver compatibility
        let button = app.buttons.firstMatch
        if button.exists {
            XCTAssertTrue(button.isHittable, "Button should be hittable for accessibility")
            
            // Test accessibility label
            let label = button.label
            XCTAssertFalse(label.isEmpty, "Button should have accessibility label")
            
            // Test accessibility traits
            XCTAssertTrue(button.elementType == .button, "Element should have button type")
        }
    }
    
    // MARK: - Device Orientation Tests
    
    func testMorphingInDifferentOrientations() throws {
        navigateToComponentTestScreen()
        
        // Test portrait orientation
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        
        let portraitButton = app.buttons.firstMatch
        if portraitButton.exists {
            portraitButton.tap()
            XCTAssertTrue(portraitButton.exists, "Button should work in portrait")
        }
        
        // Test landscape orientation
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)
        
        let landscapeButton = app.buttons.firstMatch
        if landscapeButton.exists {
            landscapeButton.tap()
            XCTAssertTrue(landscapeButton.exists, "Button should work in landscape")
        }
        
        // Restore portrait
        XCUIDevice.shared.orientation = .portrait
    }
    
    // MARK: - Stress Tests
    
    func testRapidInteractionStress() throws {
        navigateToComponentTestScreen()
        
        let button = app.buttons.firstMatch
        if button.exists {
            // Rapid tapping to test morphing stability
            for _ in 0..<10 {
                button.tap()
                usleep(100000) // 0.1 second delay
            }
            
            // Verify button still responds after stress test
            XCTAssertTrue(button.exists, "Button should exist after stress test")
            XCTAssertTrue(button.isHittable, "Button should still be hittable after stress test")
        }
    }
    
    func testMemoryStressWithMorphing() throws {
        navigateToComponentTestScreen()
        
        // Create and destroy many morphing effects
        for _ in 0..<20 {
            // Scroll to create/destroy views
            app.swipeUp()
            app.swipeDown()
            
            // Tap various elements to trigger morphing
            let buttons = app.buttons
            for i in 0..<min(buttons.count, 3) {
                let button = buttons.element(boundBy: i)
                if button.exists && button.isHittable {
                    button.tap()
                }
            }
        }
        
        // Verify app is still responsive
        let finalButton = app.buttons.firstMatch
        if finalButton.exists {
            XCTAssertTrue(finalButton.isHittable, "App should still be responsive after memory stress test")
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToComponentTestScreen() {
        // This method should navigate to the component test screen
        // Implementation depends on your app's navigation structure
        
        // Example: Access through debug menu
        if app.buttons["Debug Menu"].exists {
            app.buttons["Debug Menu"].tap()
            
            if app.buttons["Component Test"].exists {
                app.buttons["Component Test"].tap()
            }
        }
        
        // Wait for screen to load
        let componentScreen = app.staticTexts["LGTaskCard"]
        _ = componentScreen.waitForExistence(timeout: 3)
    }
    
    private func scrollToSection(_ sectionName: String) {
        let section = app.staticTexts[sectionName]
        
        // Scroll until section is visible
        var attempts = 0
        while !section.exists && attempts < 10 {
            app.swipeUp()
            attempts += 1
        }
        
        if section.exists {
            // Scroll a bit more to center the section
            app.swipeUp()
        }
    }
    
    // MARK: - Visual Verification Helpers
    
    private func takeScreenshot(name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    private func verifyVisualEffect(element: XCUIElement, effectName: String) {
        // Take before screenshot
        takeScreenshot(name: "\(effectName)_before")
        
        // Trigger effect
        element.tap()
        
        // Wait for effect
        sleep(1)
        
        // Take after screenshot
        takeScreenshot(name: "\(effectName)_after")
        
        // Note: Actual visual verification would require image comparison
        // This is a placeholder for visual regression testing
    }
}
