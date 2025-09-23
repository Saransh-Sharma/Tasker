// LGPerformanceTests.swift
// Performance benchmark tests for Liquid Glass UI components
// Tests animation performance, memory usage, and rendering efficiency

import XCTest
import UIKit
@testable import Tasker

class LGPerformanceTests: XCTestCase {
    
    var window: UIWindow!
    var containerView: UIView!
    
    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        containerView = UIView(frame: window.bounds)
        window.addSubview(containerView)
        window.makeKeyAndVisible()
    }
    
    override func tearDown() {
        containerView.subviews.forEach { $0.removeFromSuperview() }
        containerView = nil
        window = nil
        super.tearDown()
    }
    
    // MARK: - Animation Performance Tests
    
    func testLGBaseViewMorphingPerformance() {
        let views = createMultipleLGBaseViews(count: 20)
        
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "All morphing animations complete")
            expectation.expectedFulfillmentCount = views.count
            
            for view in views {
                view.morphGlass(to: .liquidWave, config: .default) {
                    view.morphGlass(to: .shimmerPulse, config: .subtle) {
                        view.morphGlass(to: .idle, config: .subtle) {
                            expectation.fulfill()
                        }
                    }
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testLGButtonMorphingPerformance() {
        let buttons = createMultipleLGButtons(count: 15)
        
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let expectation = XCTestExpectation(description: "All button morphing complete")
            expectation.expectedFulfillmentCount = buttons.count
            
            for button in buttons {
                button.morphButton(to: .pressed) {
                    button.morphButton(to: .expanding) {
                        button.morphButton(to: .idle) {
                            expectation.fulfill()
                        }
                    }
                }
            }
            
            wait(for: [expectation], timeout: 4.0)
        }
    }
    
    func testLGProgressBarAnimationPerformance() {
        let progressBars = createMultipleLGProgressBars(count: 10)
        
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let expectation = XCTestExpectation(description: "All progress animations complete")
            expectation.expectedFulfillmentCount = progressBars.count
            
            for (index, progressBar) in progressBars.enumerated() {
                let targetProgress = Float(index + 1) / Float(progressBars.count)
                progressBar.setProgressWithMorphing(targetProgress, morphState: .liquidWave, animated: true)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 3.0)
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageWithMultipleComponents() {
        measure(metrics: [XCTMemoryMetric()]) {
            let components = createMixedComponents(count: 50)
            
            // Perform operations on all components
            for component in components {
                if let baseView = component as? LGBaseView {
                    baseView.morphGlass(to: .pressed, config: .subtle)
                }
                if let button = component as? LGButton {
                    button.morphButton(to: .hovering, animated: false)
                }
                if let progressBar = component as? LGProgressBar {
                    progressBar.setProgress(0.5, animated: false)
                }
            }
            
            // Clean up
            components.forEach { component in
                component.removeFromSuperview()
            }
        }
    }
    
    func testMemoryLeaksInMorphingAnimations() {
        weak var weakViews: [LGBaseView?] = []
        
        autoreleasepool {
            let views = createMultipleLGBaseViews(count: 10)
            weakViews = views.map { $0 }
            
            // Perform morphing animations
            for view in views {
                view.morphGlass(to: .liquidWave, config: .dramatic)
                view.morphGlass(to: .shimmerPulse, config: .default)
                view.morphGlass(to: .idle, config: .subtle)
            }
            
            // Remove from superview
            views.forEach { $0.removeFromSuperview() }
        }
        
        // Wait for animations to complete
        let expectation = XCTestExpectation(description: "Memory cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 4.0)
        
        // Check for memory leaks
        for weakView in weakViews {
            XCTAssertNil(weakView, "LGBaseView should be deallocated after animations")
        }
    }
    
    // MARK: - Rendering Performance Tests
    
    func testRenderingPerformanceWithGlassEffects() {
        let views = createMultipleLGBaseViews(count: 25)
        
        // Enable all glass effects
        views.forEach { view in
            view.glassIntensity = 1.0
            view.enableGlassBorder = true
        }
        
        measure(metrics: [XCTClockMetric()]) {
            // Force layout and rendering
            containerView.setNeedsLayout()
            containerView.layoutIfNeeded()
            
            // Simulate scrolling/redrawing
            for _ in 0..<10 {
                containerView.setNeedsDisplay()
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            }
        }
    }
    
    func testScrollingPerformanceWithMorphingComponents() {
        let scrollView = UIScrollView(frame: containerView.bounds)
        containerView.addSubview(scrollView)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.frame = CGRect(x: 0, y: 0, width: scrollView.bounds.width, height: 2000)
        scrollView.addSubview(stackView)
        scrollView.contentSize = stackView.frame.size
        
        // Add multiple components to stack view
        let components = createMixedComponents(count: 30)
        components.forEach { stackView.addArrangedSubview($0) }
        
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            // Simulate scrolling
            for offset in stride(from: 0, to: 1500, by: 50) {
                scrollView.contentOffset = CGPoint(x: 0, y: CGFloat(offset))
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.016)) // ~60 FPS
            }
        }
    }
    
    // MARK: - Concurrent Animation Performance Tests
    
    func testConcurrentMorphingPerformance() {
        let views = createMultipleLGBaseViews(count: 20)
        
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let expectation = XCTestExpectation(description: "Concurrent animations complete")
            expectation.expectedFulfillmentCount = views.count
            
            // Start all animations simultaneously
            for (index, view) in views.enumerated() {
                let delay = TimeInterval(index) * 0.1
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    view.morphGlass(to: .liquidWave, config: .default) {
                        expectation.fulfill()
                    }
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testRapidStateChangesPerformance() {
        let button = LGButton(title: "Performance Test", style: .primary, size: .medium)
        containerView.addSubview(button)
        
        measure(metrics: [XCTClockMetric()]) {
            // Rapid state changes
            for _ in 0..<100 {
                button.morphButton(to: .pressed, animated: false)
                button.morphButton(to: .hovering, animated: false)
                button.morphButton(to: .idle, animated: false)
            }
        }
    }
    
    // MARK: - Theme Switching Performance Tests
    
    func testThemeSwitchingPerformance() {
        let components = createMixedComponents(count: 20)
        let themes: [LGTheme] = [.light, .dark, .aurora, .ocean, .sunset]
        
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            for theme in themes {
                LGThemeManager.shared.currentTheme = theme
                
                // Allow theme to propagate
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                
                // Force layout update
                components.forEach { component in
                    component.setNeedsLayout()
                    component.layoutIfNeeded()
                }
            }
        }
        
        // Restore default theme
        LGThemeManager.shared.currentTheme = .auto
    }
    
    // MARK: - Complex Animation Sequences Performance
    
    func testComplexAnimationSequencePerformance() {
        let button = LGButton(title: "Complex Test", style: .primary, size: .large)
        let progressBar = LGProgressBar()
        let baseView = LGBaseView()
        
        [button, progressBar, baseView].forEach { containerView.addSubview($0) }
        
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Complex sequence complete")
            
            // Complex animation sequence
            button.morphButton(to: .expanding) {
                progressBar.morphProgress(to: .liquidWave) {
                    baseView.morphGlass(to: .shimmerPulse) {
                        button.morphButton(to: .pressed) {
                            progressBar.setProgressWithMorphing(1.0, morphState: .glassRipple) {
                                baseView.createLiquidTransition(from: .shimmerPulse, to: .idle) {
                                    expectation.fulfill()
                                }
                            }
                        }
                    }
                }
            }
            
            wait(for: [expectation], timeout: 8.0)
        }
    }
    
    // MARK: - Device-Specific Performance Tests
    
    func testIPadSpecificPerformance() {
        // Simulate iPad environment
        let iPadFrame = CGRect(x: 0, y: 0, width: 1024, height: 768)
        let iPadContainer = UIView(frame: iPadFrame)
        window.addSubview(iPadContainer)
        
        let components = createMixedComponents(count: 40, container: iPadContainer)
        
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            // Simulate iPad-specific interactions
            for component in components {
                if let button = component as? LGButton {
                    // Simulate hover effects (iPad)
                    button.morphButton(to: .hovering, animated: false)
                    button.morphButton(to: .idle, animated: false)
                }
            }
            
            // Force layout for larger screen
            iPadContainer.setNeedsLayout()
            iPadContainer.layoutIfNeeded()
        }
        
        iPadContainer.removeFromSuperview()
    }
    
    // MARK: - Stress Tests
    
    func testExtremeMorphingStress() {
        let views = createMultipleLGBaseViews(count: 50)
        
        measure(metrics: [XCTMemoryMetric(), XCTCPUMetric()]) {
            // Extreme stress test
            for _ in 0..<5 {
                for view in views {
                    view.morphGlass(to: .liquidWave, config: .dramatic, animated: false)
                    view.morphGlass(to: .shimmerPulse, config: .default, animated: false)
                    view.morphGlass(to: .glassRipple, config: .subtle, animated: false)
                    view.morphGlass(to: .idle, config: .subtle, animated: false)
                }
            }
        }
    }
    
    func testMemoryPressureRecovery() {
        var components: [UIView] = []
        
        measure(metrics: [XCTMemoryMetric()]) {
            // Create memory pressure
            for _ in 0..<100 {
                let newComponents = createMixedComponents(count: 10)
                components.append(contentsOf: newComponents)
                
                // Perform operations
                newComponents.forEach { component in
                    if let baseView = component as? LGBaseView {
                        baseView.morphGlass(to: .pressed, config: .subtle, animated: false)
                    }
                }
            }
            
            // Cleanup in batches to test memory recovery
            for i in stride(from: 0, to: components.count, by: 50) {
                let endIndex = min(i + 50, components.count)
                let batch = Array(components[i..<endIndex])
                
                batch.forEach { $0.removeFromSuperview() }
                
                // Allow memory cleanup
                autoreleasepool {
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMultipleLGBaseViews(count: Int) -> [LGBaseView] {
        var views: [LGBaseView] = []
        
        for i in 0..<count {
            let view = LGBaseView(frame: CGRect(x: CGFloat(i % 5) * 70, y: CGFloat(i / 5) * 70, width: 60, height: 60))
            view.glassIntensity = 0.8
            view.cornerRadius = 10
            containerView.addSubview(view)
            views.append(view)
        }
        
        return views
    }
    
    private func createMultipleLGButtons(count: Int) -> [LGButton] {
        var buttons: [LGButton] = []
        
        for i in 0..<count {
            let button = LGButton(title: "Button \(i)", style: .primary, size: .medium)
            button.frame = CGRect(x: CGFloat(i % 3) * 120, y: CGFloat(i / 3) * 60, width: 100, height: 44)
            containerView.addSubview(button)
            buttons.append(button)
        }
        
        return buttons
    }
    
    private func createMultipleLGProgressBars(count: Int) -> [LGProgressBar] {
        var progressBars: [LGProgressBar] = []
        
        for i in 0..<count {
            let progressBar = LGProgressBar()
            progressBar.frame = CGRect(x: 20, y: CGFloat(i) * 40 + 50, width: 200, height: 8)
            progressBar.shimmerEnabled = true
            containerView.addSubview(progressBar)
            progressBars.append(progressBar)
        }
        
        return progressBars
    }
    
    private func createMixedComponents(count: Int, container: UIView? = nil) -> [UIView] {
        let targetContainer = container ?? containerView!
        var components: [UIView] = []
        
        for i in 0..<count {
            let component: UIView
            
            switch i % 4 {
            case 0:
                component = LGBaseView(frame: CGRect(x: CGFloat(i % 5) * 70, y: CGFloat(i / 5) * 70, width: 60, height: 60))
            case 1:
                component = LGButton(title: "Btn\(i)", style: .secondary, size: .small)
                component.frame = CGRect(x: CGFloat(i % 4) * 90, y: CGFloat(i / 4) * 50 + 300, width: 80, height: 32)
            case 2:
                let progressBar = LGProgressBar()
                progressBar.frame = CGRect(x: 20, y: CGFloat(i / 4) * 30 + 500, width: 150, height: 6)
                progressBar.setProgress(Float.random(in: 0...1), animated: false)
                component = progressBar
            default:
                let textField = LGTextField(placeholder: "Field \(i)", style: .standard)
                textField.frame = CGRect(x: 20, y: CGFloat(i / 4) * 40 + 600, width: 200, height: 36)
                component = textField
            }
            
            targetContainer.addSubview(component)
            components.append(component)
        }
        
        return components
    }
    
    // MARK: - Benchmark Validation
    
    func testPerformanceBenchmarkValidation() {
        // Validate that our performance is within acceptable limits
        let baseView = LGBaseView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        containerView.addSubview(baseView)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform standard morphing operation
        let expectation = XCTestExpectation(description: "Benchmark validation")
        baseView.morphGlass(to: .liquidWave, config: .default) {
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            // Assert performance is under 1 second for single operation
            XCTAssertLessThan(duration, 1.0, "Single morphing operation should complete within 1 second")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
}
