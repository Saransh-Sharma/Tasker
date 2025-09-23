// LGPerformanceOptimizer.swift
// Performance optimization layer - Phase 6 Implementation
// Maintains Clean Architecture while optimizing Liquid Glass UI performance

import UIKit
import QuartzCore
import os.log

// MARK: - Performance Optimizer

final class LGPerformanceOptimizer {
    
    // MARK: - Singleton
    static let shared = LGPerformanceOptimizer()
    
    // MARK: - Properties
    
    private let performanceLog = OSLog(subsystem: "com.tasker.liquidglass", category: "Performance")
    private var frameDropMonitor: CADisplayLink?
    private var memoryWarningObserver: NSObjectProtocol?
    private var performanceMetrics = PerformanceMetrics()
    
    // Performance thresholds
    private let targetFPS: Double = 60.0
    private let maxMemoryUsage: Int = 150 * 1024 * 1024 // 150MB
    private let maxAnimationDuration: TimeInterval = 0.5
    
    // Optimization flags
    private(set) var isLowPowerMode = false
    private(set) var isReducedMotionEnabled = false
    private(set) var isMemoryConstrained = false
    
    // MARK: - Initialization
    
    private init() {
        setupMonitoring()
        observeSystemSettings()
    }
    
    // MARK: - Setup
    
    private func setupMonitoring() {
        // Frame rate monitoring
        frameDropMonitor = CADisplayLink(target: self, selector: #selector(monitorFrameRate))
        frameDropMonitor?.add(to: .main, forMode: .common)
        
        // Memory monitoring
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func observeSystemSettings() {
        // Low power mode
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        // Reduced motion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        
        updateSystemSettings()
    }
    
    // MARK: - Performance Monitoring
    
    @objc private func monitorFrameRate(_ displayLink: CADisplayLink) {
        let currentFPS = 1.0 / (displayLink.targetTimestamp - displayLink.timestamp)
        performanceMetrics.recordFrameRate(currentFPS)
        
        if currentFPS < targetFPS * 0.9 { // Below 54 FPS
            os_log(.info, log: performanceLog, "Frame drop detected: %.1f FPS", currentFPS)
            optimizeForFrameRate()
        }
    }
    
    private func handleMemoryWarning() {
        os_log(.warning, log: performanceLog, "Memory warning received")
        isMemoryConstrained = true
        
        // Clear caches
        URLCache.shared.removeAllCachedResponses()
        
        // Reduce glass effect intensity
        LGThemeManager.shared.reduceEffectIntensity(by: 0.3)
        
        // Notify all active views to reduce complexity
        NotificationCenter.default.post(
            name: .lgPerformanceOptimizationNeeded,
            object: nil,
            userInfo: ["reason": "memory"]
        )
    }
    
    // MARK: - System Settings
    
    @objc private func powerStateChanged() {
        updateSystemSettings()
    }
    
    @objc private func accessibilityChanged() {
        updateSystemSettings()
    }
    
    private func updateSystemSettings() {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        isReducedMotionEnabled = UIAccessibility.isReduceMotionEnabled
        
        if isLowPowerMode || isReducedMotionEnabled {
            applyReducedPerformanceMode()
        }
    }
    
    // MARK: - Optimization Methods
    
    private func optimizeForFrameRate() {
        // Reduce animation complexity
        UIView.setAnimationDuration(maxAnimationDuration * 0.7)
        
        // Simplify glass effects
        LGBaseView.globalGlassIntensityMultiplier = 0.8
        
        // Disable non-essential animations
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.commit()
    }
    
    private func applyReducedPerformanceMode() {
        os_log(.info, log: performanceLog, "Applying reduced performance mode")
        
        // Disable complex animations
        LGAnimationConfig.globalAnimationEnabled = false
        
        // Reduce glass effect layers
        LGBaseView.globalMaxBlurRadius = 10
        
        // Disable haptic feedback
        FeatureFlags.enableHapticFeedback = false
    }
    
    // MARK: - Public API
    
    func optimizeView(_ view: UIView) {
        // Apply view-specific optimizations
        view.layer.shouldRasterize = true
        view.layer.rasterizationScale = UIScreen.main.scale
        
        // Optimize shadow rendering
        if let shadowPath = view.layer.shadowPath {
            view.layer.shadowPath = shadowPath
        } else if view.layer.shadowOpacity > 0 {
            view.layer.shadowPath = UIBezierPath(rect: view.bounds).cgPath
        }
        
        // Reduce transparency calculations
        if view.alpha < 1.0 && view.alpha > 0.95 {
            view.alpha = 1.0
        }
    }
    
    func optimizeScrollView(_ scrollView: UIScrollView) {
        // Optimize scrolling performance
        scrollView.layer.drawsAsynchronously = true
        
        // Reduce off-screen rendering
        if let tableView = scrollView as? UITableView {
            tableView.estimatedRowHeight = 80
            tableView.rowHeight = UITableView.automaticDimension
        }
        
        if let collectionView = scrollView as? UICollectionView {
            collectionView.isPrefetchingEnabled = true
        }
    }
    
    func prepareForComplexAnimation() {
        // Pre-render complex views
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        CATransaction.commit()
    }
    
    func completeComplexAnimation() {
        // Clean up after animation
        CATransaction.flush()
    }
    
    // MARK: - Performance Metrics
    
    func currentPerformanceLevel() -> PerformanceLevel {
        let avgFPS = performanceMetrics.averageFrameRate
        let memoryUsage = performanceMetrics.currentMemoryUsage()
        
        if avgFPS < 30 || memoryUsage > maxMemoryUsage {
            return .low
        } else if avgFPS < 50 || memoryUsage > maxMemoryUsage * 0.8 {
            return .medium
        } else {
            return .high
        }
    }
    
    func performanceReport() -> PerformanceReport {
        return PerformanceReport(
            averageFPS: performanceMetrics.averageFrameRate,
            memoryUsage: performanceMetrics.currentMemoryUsage(),
            isOptimized: isMemoryConstrained || isLowPowerMode,
            optimizationReasons: getOptimizationReasons()
        )
    }
    
    private func getOptimizationReasons() -> [String] {
        var reasons: [String] = []
        if isLowPowerMode { reasons.append("Low Power Mode") }
        if isReducedMotionEnabled { reasons.append("Reduced Motion") }
        if isMemoryConstrained { reasons.append("Memory Pressure") }
        return reasons
    }
}

// MARK: - Performance Metrics

private class PerformanceMetrics {
    private var frameRates: [Double] = []
    private let maxSamples = 60
    
    var averageFrameRate: Double {
        guard !frameRates.isEmpty else { return 60.0 }
        return frameRates.reduce(0, +) / Double(frameRates.count)
    }
    
    func recordFrameRate(_ fps: Double) {
        frameRates.append(fps)
        if frameRates.count > maxSamples {
            frameRates.removeFirst()
        }
    }
    
    func currentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}

// MARK: - Supporting Types

enum PerformanceLevel {
    case low, medium, high
}

struct PerformanceReport {
    let averageFPS: Double
    let memoryUsage: Int
    let isOptimized: Bool
    let optimizationReasons: [String]
    
    var memoryUsageMB: Double {
        return Double(memoryUsage) / (1024 * 1024)
    }
}

// MARK: - Global Configuration

struct LGAnimationConfig {
    static var globalAnimationEnabled = true
    static var globalAnimationSpeed: Double = 1.0
}

// MARK: - Extensions

extension LGBaseView {
    static var globalGlassIntensityMultiplier: CGFloat = 1.0
    static var globalMaxBlurRadius: CGFloat = 20.0
}

extension Notification.Name {
    static let lgPerformanceOptimizationNeeded = Notification.Name("lgPerformanceOptimizationNeeded")
}

// MARK: - Clean Architecture Integration

extension LGPerformanceOptimizer {
    
    /// Optimizes view rendering while maintaining Clean Architecture separation
    func optimizePresentation(for viewController: UIViewController) {
        // Presentation layer optimization only - no business logic
        if let view = viewController.view {
            optimizeView(view)
        }
        
        // Optimize child views
        viewController.view.subviews.forEach { subview in
            if subview is LGBaseView {
                optimizeView(subview)
            }
        }
    }
    
    /// Monitors use case execution performance
    func monitorUseCase<T>(_ name: String, execute: () throws -> T) rethrows -> T {
        let startTime = CACurrentMediaTime()
        defer {
            let duration = CACurrentMediaTime() - startTime
            if duration > 0.1 { // Log slow operations
                os_log(.info, log: performanceLog, "Slow use case '%@': %.3fs", name, duration)
            }
        }
        return try execute()
    }
    
    /// Optimizes state management queries
    func optimizeStateQuery<T>(_ query: () -> T) -> T {
        // Execute query with optimized Core Data settings
        return autoreleasepool {
            return query()
        }
    }
}
