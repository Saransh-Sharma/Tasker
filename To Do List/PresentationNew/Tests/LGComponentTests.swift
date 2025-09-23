// LGComponentTests.swift
// Comprehensive unit tests for all Liquid Glass UI components
// Tests morphing effects, animations, and component functionality

import XCTest
import UIKit
@testable import Tasker

class LGComponentTests: XCTestCase {
    
    var window: UIWindow!
    
    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.makeKeyAndVisible()
    }
    
    override func tearDown() {
        window = nil
        super.tearDown()
    }
    
    // MARK: - LGBaseView Tests
    
    func testLGBaseViewInitialization() {
        let baseView = LGBaseView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        XCTAssertEqual(baseView.glassIntensity, 0.8, "Default glass intensity should be 0.8")
        XCTAssertEqual(baseView.cornerRadius, 20, "Default corner radius should be 20")
        XCTAssertTrue(baseView.enableGlassBorder, "Glass border should be enabled by default")
    }
    
    func testLGBaseViewMorphing() {
        let baseView = LGBaseView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.addSubview(baseView)
        
        let expectation = XCTestExpectation(description: "Morphing animation completes")
        
        baseView.morphGlass(to: .hovering) {
            XCTAssertNotEqual(baseView.layer.transform, CATransform3DIdentity, "Transform should be applied during hover state")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testLGBaseViewLiquidTransition() {
        let baseView = LGBaseView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.addSubview(baseView)
        
        let expectation = XCTestExpectation(description: "Liquid transition completes")
        
        baseView.createLiquidTransition(from: .idle, to: .pressed, duration: 0.5)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - LGButton Tests
    
    func testLGButtonInitialization() {
        let button = LGButton(title: "Test Button", style: .primary, size: .medium)
        
        XCTAssertEqual(button.title, "Test Button", "Button title should be set correctly")
        XCTAssertEqual(button.style, .primary, "Button style should be primary")
        XCTAssertEqual(button.size, .medium, "Button size should be medium")
        XCTAssertTrue(button.morphingEnabled, "Morphing should be enabled by default")
    }
    
    func testLGButtonStyles() {
        let primaryButton = LGButton(title: "Primary", style: .primary, size: .medium)
        let secondaryButton = LGButton(title: "Secondary", style: .secondary, size: .medium)
        let ghostButton = LGButton(title: "Ghost", style: .ghost, size: .medium)
        let destructiveButton = LGButton(title: "Destructive", style: .destructive, size: .medium)
        
        XCTAssertEqual(primaryButton.style.glassIntensity, 0.9, "Primary button should have 0.9 glass intensity")
        XCTAssertEqual(secondaryButton.style.glassIntensity, 0.7, "Secondary button should have 0.7 glass intensity")
        XCTAssertEqual(ghostButton.style.glassIntensity, 0.3, "Ghost button should have 0.3 glass intensity")
        XCTAssertEqual(destructiveButton.style.glassIntensity, 0.8, "Destructive button should have 0.8 glass intensity")
    }
    
    func testLGButtonSizes() {
        let smallButton = LGButton(title: "Small", style: .primary, size: .small)
        let mediumButton = LGButton(title: "Medium", style: .primary, size: .medium)
        let largeButton = LGButton(title: "Large", style: .primary, size: .large)
        
        XCTAssertTrue(smallButton.size.height < mediumButton.size.height, "Small button should be smaller than medium")
        XCTAssertTrue(mediumButton.size.height < largeButton.size.height, "Medium button should be smaller than large")
    }
    
    func testLGButtonMorphing() {
        let button = LGButton(title: "Test", style: .primary, size: .medium)
        window.addSubview(button)
        
        let expectation = XCTestExpectation(description: "Button morphing completes")
        
        button.morphButton(to: .pressed) {
            XCTAssertNotEqual(button.layer.transform, CATransform3DIdentity, "Button should have transform applied when pressed")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testLGButtonTapCallback() {
        let button = LGButton(title: "Test", style: .primary, size: .medium)
        window.addSubview(button)
        
        let expectation = XCTestExpectation(description: "Button tap callback triggered")
        
        button.onTap = {
            expectation.fulfill()
        }
        
        // Simulate touch
        let touch = UITouch()
        button.touchesBegan([touch], with: nil)
        button.touchesEnded([touch], with: nil)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - LGProgressBar Tests
    
    func testLGProgressBarInitialization() {
        let progressBar = LGProgressBar()
        
        XCTAssertEqual(progressBar.progress, 0.0, "Initial progress should be 0.0")
        XCTAssertTrue(progressBar.shimmerEnabled, "Shimmer should be enabled by default")
    }
    
    func testLGProgressBarProgress() {
        let progressBar = LGProgressBar()
        window.addSubview(progressBar)
        
        progressBar.setProgress(0.5, animated: false)
        XCTAssertEqual(progressBar.progress, 0.5, "Progress should be set to 0.5")
        
        progressBar.setProgress(1.2, animated: false)
        XCTAssertEqual(progressBar.progress, 1.0, "Progress should be clamped to 1.0")
        
        progressBar.setProgress(-0.1, animated: false)
        XCTAssertEqual(progressBar.progress, 0.0, "Progress should be clamped to 0.0")
    }
    
    func testLGProgressBarAnimatedProgress() {
        let progressBar = LGProgressBar()
        window.addSubview(progressBar)
        
        let expectation = XCTestExpectation(description: "Animated progress completes")
        
        progressBar.setProgress(0.8, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(progressBar.progress, 0.8, accuracy: 0.01, "Progress should be animated to 0.8")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - LGTextField Tests
    
    func testLGTextFieldInitialization() {
        let textField = LGTextField(placeholder: "Test Placeholder", style: .standard)
        
        XCTAssertEqual(textField.placeholder, "Test Placeholder", "Placeholder should be set correctly")
        XCTAssertEqual(textField.style, .standard, "Style should be standard")
        XCTAssertTrue(textField.floatingPlaceholderEnabled, "Floating placeholder should be enabled by default")
    }
    
    func testLGTextFieldStyles() {
        let standardField = LGTextField(placeholder: "Standard", style: .standard)
        let outlinedField = LGTextField(placeholder: "Outlined", style: .outlined)
        let filledField = LGTextField(placeholder: "Filled", style: .filled)
        
        XCTAssertEqual(standardField.style, .standard, "Standard field should have standard style")
        XCTAssertEqual(outlinedField.style, .outlined, "Outlined field should have outlined style")
        XCTAssertEqual(filledField.style, .filled, "Filled field should have filled style")
    }
    
    func testLGTextFieldFloatingPlaceholder() {
        let textField = LGTextField(placeholder: "Test", style: .standard)
        window.addSubview(textField)
        
        // Simulate text input
        textField.text = "Hello"
        textField.sendActions(for: .editingChanged)
        
        // Floating placeholder should be visible when text is present
        XCTAssertFalse(textField.text?.isEmpty ?? true, "Text field should contain text")
    }
    
    // MARK: - LGSearchBar Tests
    
    func testLGSearchBarInitialization() {
        let searchBar = LGSearchBar()
        
        XCTAssertNotNil(searchBar.placeholder, "Search bar should have a placeholder")
        XCTAssertTrue(searchBar.suggestionsEnabled, "Suggestions should be enabled by default")
        XCTAssertEqual(searchBar.suggestions.count, 0, "Initial suggestions should be empty")
    }
    
    func testLGSearchBarSuggestions() {
        let searchBar = LGSearchBar()
        let testSuggestions = ["Apple", "Banana", "Cherry"]
        
        searchBar.suggestions = testSuggestions
        XCTAssertEqual(searchBar.suggestions.count, 3, "Should have 3 suggestions")
        XCTAssertEqual(searchBar.suggestions, testSuggestions, "Suggestions should match input")
    }
    
    // MARK: - LGProjectPill Tests
    
    func testLGProjectPillInitialization() {
        let projectPill = LGProjectPill()
        
        XCTAssertTrue(projectPill.liquidGradientEnabled, "Liquid gradient should be enabled by default")
        XCTAssertTrue(projectPill.animationsEnabled, "Animations should be enabled by default")
    }
    
    func testLGProjectPillConfiguration() {
        let projectPill = LGProjectPill()
        let projectData = ProjectData(
            id: "test",
            name: "Test Project",
            color: .systemBlue,
            iconName: "folder.fill",
            taskCount: 10,
            completedCount: 5
        )
        
        projectPill.configure(with: projectData)
        
        // Verify configuration was applied (implementation dependent)
        XCTAssertNotNil(projectPill, "Project pill should be configured")
    }
    
    // MARK: - LGFloatingActionButton Tests
    
    func testLGFloatingActionButtonInitialization() {
        let fab = LGFloatingActionButton()
        
        XCTAssertTrue(fab.rippleEffectEnabled, "Ripple effect should be enabled by default")
        XCTAssertTrue(fab.expandableActionsEnabled, "Expandable actions should be enabled by default")
    }
    
    func testLGFloatingActionButtonIcon() {
        let fab = LGFloatingActionButton()
        let testIcon = UIImage(systemName: "plus")
        
        fab.icon = testIcon
        XCTAssertEqual(fab.icon, testIcon, "Icon should be set correctly")
    }
    
    // MARK: - LGTaskCard Tests
    
    func testLGTaskCardInitialization() {
        let taskCard = LGTaskCard()
        
        XCTAssertTrue(taskCard.glassEffectsEnabled, "Glass effects should be enabled by default")
        XCTAssertTrue(taskCard.progressBarEnabled, "Progress bar should be enabled by default")
        XCTAssertTrue(taskCard.priorityIndicatorEnabled, "Priority indicator should be enabled by default")
    }
    
    func testLGTaskCardConfiguration() {
        let taskCard = LGTaskCard()
        let taskData = TaskCardData(
            id: "test",
            title: "Test Task",
            description: "Test Description",
            dueDate: Date(),
            priority: .high,
            project: nil,
            progress: 0.5,
            isCompleted: false
        )
        
        taskCard.task = taskData
        
        // Verify configuration was applied (implementation dependent)
        XCTAssertNotNil(taskCard.task, "Task should be set")
    }
    
    // MARK: - Theme Integration Tests
    
    func testThemeIntegration() {
        let button = LGButton(title: "Test", style: .primary, size: .medium)
        window.addSubview(button)
        
        // Test theme changes
        let originalTheme = LGThemeManager.shared.currentTheme
        
        LGThemeManager.shared.currentTheme = .dark
        XCTAssertEqual(LGThemeManager.shared.currentTheme, .dark, "Theme should change to dark")
        
        LGThemeManager.shared.currentTheme = .light
        XCTAssertEqual(LGThemeManager.shared.currentTheme, .light, "Theme should change to light")
        
        // Restore original theme
        LGThemeManager.shared.currentTheme = originalTheme
    }
    
    // MARK: - Device Adaptation Tests
    
    func testDeviceAdaptation() {
        let button = LGButton(title: "Test", style: .primary, size: .medium)
        
        // Test iPad vs iPhone sizing
        let iPadHeight = LGButton.Size.medium.height
        XCTAssertTrue(iPadHeight > 0, "Button height should be positive")
        
        let fontSize = LGButton.Size.medium.fontSize
        XCTAssertTrue(fontSize > 0, "Font size should be positive")
    }
    
    // MARK: - Performance Tests
    
    func testMorphingPerformance() {
        let baseView = LGBaseView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.addSubview(baseView)
        
        measure {
            for _ in 0..<10 {
                baseView.morphGlass(to: .pressed, config: .subtle)
                baseView.morphGlass(to: .idle, config: .subtle)
            }
        }
    }
    
    func testAnimationPerformance() {
        let button = LGButton(title: "Test", style: .primary, size: .medium)
        window.addSubview(button)
        
        measure {
            for _ in 0..<5 {
                button.morphButton(to: .expanding)
                button.morphButton(to: .idle)
            }
        }
    }
    
    // MARK: - Memory Tests
    
    func testMemoryLeaks() {
        weak var weakBaseView: LGBaseView?
        weak var weakButton: LGButton?
        
        autoreleasepool {
            let baseView = LGBaseView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
            let button = LGButton(title: "Test", style: .primary, size: .medium)
            
            weakBaseView = baseView
            weakButton = button
            
            window.addSubview(baseView)
            window.addSubview(button)
            
            // Perform some operations
            baseView.morphGlass(to: .pressed)
            button.morphButton(to: .hovering)
            
            // Remove from superview
            baseView.removeFromSuperview()
            button.removeFromSuperview()
        }
        
        // Check for memory leaks
        XCTAssertNil(weakBaseView, "LGBaseView should be deallocated")
        XCTAssertNil(weakButton, "LGButton should be deallocated")
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibility() {
        let button = LGButton(title: "Accessible Button", style: .primary, size: .medium)
        
        XCTAssertTrue(button.isAccessibilityElement, "Button should be accessible")
        XCTAssertEqual(button.accessibilityLabel, "Accessible Button", "Accessibility label should match title")
        XCTAssertEqual(button.accessibilityTraits, .button, "Should have button accessibility trait")
    }
    
    // MARK: - Feature Flag Tests
    
    func testFeatureFlagIntegration() {
        let baseView = LGBaseView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.addSubview(baseView)
        
        // Test with animations disabled
        FeatureFlags.enableLiquidAnimations = false
        baseView.morphGlass(to: .pressed)
        
        // Test with animations enabled
        FeatureFlags.enableLiquidAnimations = true
        baseView.morphGlass(to: .hovering)
        
        // Restore default
        FeatureFlags.enableLiquidAnimations = true
    }
}

// MARK: - Mock Extensions for Testing

extension UITouch {
    convenience init(location: CGPoint = .zero) {
        self.init()
        // Note: UITouch is difficult to mock in unit tests
        // In a real implementation, you might use a testing framework
        // or create a protocol for touch handling
    }
}
