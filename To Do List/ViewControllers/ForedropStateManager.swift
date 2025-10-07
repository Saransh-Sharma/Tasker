//
//  ForedropStateManager.swift
//  To Do List
//
//  Created by Cascade on 30/09/25.
//  Copyright 2025 saransh1337. All rights reserved.
//
//  Deterministic state machine for foredrop positioning with consistent
//  transitions across all iPhone and iPad models, orientations, and aspect ratios.
//

import UIKit
import FSCalendar

/// Three deterministic states for the foredrop overlay
enum ForedropState {
    case `default`  // Foredrop aligned to bottom of nav bar, covering calendar + charts
    case calendar   // Foredrop reveals calendar only
    case charts     // Foredrop reveals both calendar + charts
}

/// State machine managing foredrop positioning with deterministic transitions
class ForedropStateManager {
    
    // MARK: - Properties
    
    /// Current state of the foredrop
    private(set) var currentState: ForedropState = .default
    
    /// Reference to the foredrop container
    private weak var foredropContainer: UIView?
    
    /// Reference to the calendar view
    private weak var calendar: FSCalendar?
    
    /// Reference to the charts container
    private weak var chartsContainer: UIView?
    
    /// Reference to the parent view controller's view for safe area calculations
    private weak var parentView: UIView?
    
    /// Reference to navigation controller for nav bar height
    private weak var navigationController: UINavigationController?
    
    /// Cached positions for each state (recalculated on layout changes)
    private var defaultPosition: CGFloat = 0
    private var calendarPosition: CGFloat = 0
    private var chartsPosition: CGFloat = 0
    
    /// Animation duration for state transitions
    private let animationDuration: TimeInterval = 0.3
    
    /// Spring damping for smooth animations
    private let springDamping: CGFloat = 0.85
    
    /// Initial spring velocity
    private let springVelocity: CGFloat = 0.5

    /// Callback invoked when charts become visible (for transparency application)
    var onChartsVisibilityChanged: (() -> Void)?

    // MARK: - Initialization
    
    init(foredropContainer: UIView,
         calendar: FSCalendar,
         chartsContainer: UIView,
         parentView: UIView,
         navigationController: UINavigationController?) {
        self.foredropContainer = foredropContainer
        self.calendar = calendar
        self.chartsContainer = chartsContainer
        self.parentView = parentView
        self.navigationController = navigationController
        
        // Calculate initial positions
        recalculatePositions()
    }
    
    // MARK: - Position Calculations
    
    /// Recalculates all foredrop positions based on current device layout
    /// Call this whenever device rotates or layout changes
    func recalculatePositions() {
        guard let parentView = parentView,
              let foredropContainer = foredropContainer,
              let calendar = calendar,
              let chartsContainer = chartsContainer else {
            print("⚠️ ForedropStateManager: Missing required views for position calculation")
            return
        }
        
        // Get navigation bar height
        let navBarHeight = navigationController?.navigationBar.frame.height ?? 0
        let statusBarHeight = parentView.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        let totalTopHeight = calendar.frame.minY + 8


        // Get safe area insets
        let safeAreaInsets = parentView.safeAreaInsets
        
        // MARK: Default Position
        // Foredrop top edge aligned with bottom of navigation bar
        defaultPosition = totalTopHeight
        
        // MARK: Calendar Position
        // Calculate position to reveal full calendar with padding
        let calendarPadding: CGFloat = 14
        let calendarHeight = calendar.frame.height
        
        // Use charts container's minY as the reveal point (just above the charts)
        // Convert to parent view's coordinate space for accurate positioning
        let chartsFrameForCalendar = chartsContainer.convert(chartsContainer.bounds, to: parentView)
        let calendarBottomY = chartsFrameForCalendar.minY
        
        // Foredrop should slide down so its top edge is just above the charts (revealing calendar only)
        calendarPosition = calendarBottomY - calendarPadding
        
        // MARK: Charts Position
        // Calculate position to reveal both calendar and charts with padding
        let chartsPadding: CGFloat = 20
        let chartsHeight = chartsContainer.frame.height
        
        // IMPORTANT: Use the charts parent container's maxY to ensure title, subtitle, and chart are all visible
        // Convert to parent view's coordinate space to ensure accurate positioning
        let chartsFrameInParentView = chartsContainer.convert(chartsContainer.bounds, to: parentView)
        let chartsBottomY = chartsFrameInParentView.maxY
        
        // Foredrop should slide down so its top edge is just below the charts
        chartsPosition = chartsBottomY + chartsPadding
        
        // Ensure positions are within screen bounds
        let screenHeight = parentView.bounds.height
        let maxPosition = screenHeight - (safeAreaInsets.bottom + 100) // Keep some foredrop visible
        
        calendarPosition = min(calendarPosition, maxPosition)
        chartsPosition = min(chartsPosition, maxPosition)
        
        print("""
        📐 ForedropStateManager: Positions calculated
           - Default: \(defaultPosition) (nav bar bottom)
           - Calendar: \(calendarPosition) (reveals calendar only)
           - Charts: \(chartsPosition) (reveals calendar + charts)
           - Screen height: \(screenHeight)
           - Calendar frame (local): \(calendar.frame)
           - Charts container frame (local): \(chartsContainer.frame)
           - Charts container frame (in parent): \(chartsFrameInParentView)
           - Charts bottom Y (used for position): \(chartsBottomY)
        """)
    }
    
    /// Returns the Y position for a given state
    private func position(for state: ForedropState) -> CGFloat {
        switch state {
        case .default:
            return defaultPosition
        case .calendar:
            return calendarPosition
        case .charts:
            return chartsPosition
        }
    }
    
    // MARK: - State Transitions
    
    /// Transitions to a new state with animation
    /// - Parameters:
    ///   - newState: Target state to transition to
    ///   - animated: Whether to animate the transition
    ///   - completion: Optional completion handler
    func transition(to newState: ForedropState, animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let foredropContainer = foredropContainer else {
            print("⚠️ ForedropStateManager: Foredrop container is nil")
            completion?()
            return
        }

        // If already in target state, do nothing
        if currentState == newState {
            print("ℹ️ ForedropStateManager: Already in \(newState) state")
            completion?()
            return
        }

        let oldState = currentState
        currentState = newState

        let targetY = position(for: newState)

        print("🔄 ForedropStateManager: Transitioning \(oldState) → \(newState) (Y: \(targetY))")

        // Update visibility of charts container based on state
        updateChartsVisibility(for: newState)

        if animated {
            UIView.animate(
                withDuration: animationDuration,
                delay: 0,
                usingSpringWithDamping: springDamping,
                initialSpringVelocity: springVelocity,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: {
                    var frame = foredropContainer.frame
                    frame.origin.y = targetY
                    foredropContainer.frame = frame
                },
                completion: { _ in
                    print("✅ ForedropStateManager: Transition complete → \(newState)")
                    completion?()
                }
            )
        } else {
            var frame = foredropContainer.frame
            frame.origin.y = targetY
            foredropContainer.frame = frame
            print("✅ ForedropStateManager: Instant transition → \(newState)")
            completion?()
        }
    }

    /// Updates the visibility of the charts container based on the current state
    private func updateChartsVisibility(for state: ForedropState) {
        guard let chartsContainer = chartsContainer else { return }

        switch state {
        case .charts:
            // Show charts when in charts state
            chartsContainer.isHidden = false
            print("   📊 Charts container: VISIBLE")

            // Apply transparency immediately when charts become visible
            onChartsVisibilityChanged?()

            // Additional delayed transparency passes for async-created subviews
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                print("🎯 ForedropStateManager: Delayed transparency (0.15s)")
                self?.onChartsVisibilityChanged?()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                print("🎯 ForedropStateManager: Delayed transparency (0.3s)")
                self?.onChartsVisibilityChanged?()
            }

        case .default, .calendar:
            // Hide charts in default and calendar states
            chartsContainer.isHidden = true
            print("   📊 Charts container: HIDDEN")
        }
    }
    
    // MARK: - Toggle Actions
    
    /// Handles calendar button tap with proper toggle logic
    func toggleCalendar() {
        switch currentState {
        case .default:
            // Show calendar
            transition(to: .calendar)
            
        case .calendar:
            // Hide calendar (return to default)
            transition(to: .default)
            
        case .charts:
            // Special transition: Charts → Default → Calendar
            transition(to: .default, animated: true) { [weak self] in
                // After returning to default, immediately show calendar
                self?.transition(to: .calendar)
            }
        }
    }
    
    /// Handles charts button tap with proper toggle logic
    func toggleCharts() {
        switch currentState {
        case .default:
            // Show charts (and calendar)
            transition(to: .charts)
            
        case .calendar:
            // Special transition: Calendar → Default → Charts
            transition(to: .default, animated: true) { [weak self] in
                // After returning to default, immediately show charts
                self?.transition(to: .charts)
            }
            
        case .charts:
            // Hide charts (return to default)
            transition(to: .default)
        }
    }
    
    // MARK: - Orientation Handling
    
    /// Call this when device orientation changes
    func handleOrientationChange() {
        print("🔄 ForedropStateManager: Handling orientation change")
        
        // Recalculate positions for new orientation
        recalculatePositions()
        
        // Reposition foredrop to maintain current state
        transition(to: currentState, animated: false)
    }
    
    // MARK: - Layout Updates
    
    /// Call this when layout changes (e.g., after viewDidLayoutSubviews)
    func updateLayout() {
        // Recalculate positions
        recalculatePositions()
        
        // Reposition foredrop to maintain current state without animation
        // (to avoid jitter during layout updates)
        guard let foredropContainer = foredropContainer else { return }
        
        let targetY = position(for: currentState)
        var frame = foredropContainer.frame
        frame.origin.y = targetY
        foredropContainer.frame = frame
    }
    
    // MARK: - State Queries
    
    /// Returns whether calendar is currently visible
    var isCalendarVisible: Bool {
        return currentState == .calendar || currentState == .charts
    }
    
    /// Returns whether charts are currently visible
    var isChartsVisible: Bool {
        return currentState == .charts
    }
    
    /// Returns whether foredrop is in default position
    var isInDefaultPosition: Bool {
        return currentState == .default
    }
}
