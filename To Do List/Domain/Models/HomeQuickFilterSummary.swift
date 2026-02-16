//
//  HomeQuickFilterSummary.swift
//  Tasker
//
//  Computed summary text for the quick filter dropdown trigger button.
//

import Foundation

/// Represents a summary of the current filter state for display in the trigger button.
public struct HomeQuickFilterSummary: Equatable {
    /// The primary display text (e.g., "Today", "Feb 13", "Upcoming")
    public let primaryText: String

    /// Optional secondary text indicating additional filters (e.g., "+ 2 projects")
    public let secondaryText: String?

    /// Whether any non-default filters are active
    public let hasActiveFilters: Bool

    public init(primaryText: String, secondaryText: String? = nil, hasActiveFilters: Bool = false) {
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.hasActiveFilters = hasActiveFilters
    }

    /// Full display text combining primary and secondary
    public var displayText: String {
        if let secondary = secondaryText {
            return "\(primaryText) \(secondary)"
        }
        return primaryText
    }
}

// MARK: - Factory Methods

extension HomeQuickFilterSummary {

    /// Create a summary from the current filter state.
    /// - Parameters:
    ///   - scope: The current list scope
    ///   - filterState: The current filter state
    ///   - customDate: The selected custom date (if any)
    /// - Returns: A summary for display in the trigger button
    public static func from(
        scope: HomeListScope,
        filterState: HomeFilterState,
        customDate: Date
    ) -> HomeQuickFilterSummary {
        let primaryText = primaryTextForScope(scope, customDate: customDate)
        var secondaryParts: [String] = []
        var hasActiveFilters = false

        // Check for project filters
        let projectCount = filterState.selectedProjectIDs.count
        if projectCount > 0 {
            secondaryParts.append("+ \(projectCount) project\(projectCount > 1 ? "s" : "")")
            hasActiveFilters = true
        }

        // Check for advanced filters
        if filterState.advancedFilter != nil {
            secondaryParts.append("+ Advanced")
            hasActiveFilters = true
        }

        // Check if we're on a non-default quick view (but not custom date)
        if scope.quickView != .today && !isCustomDate(scope) {
            hasActiveFilters = true
        }

        // Check for non-default grouping
        if filterState.projectGroupingMode != .defaultMode {
            hasActiveFilters = true
        }

        let secondaryText = secondaryParts.isEmpty ? nil : secondaryParts.joined(separator: " ")

        return HomeQuickFilterSummary(
            primaryText: primaryText,
            secondaryText: secondaryText,
            hasActiveFilters: hasActiveFilters
        )
    }

    /// Get the primary display text for a given scope.
    private static func primaryTextForScope(_ scope: HomeListScope, customDate: Date) -> String {
        switch scope {
        case .today:
            return "Today"
        case .customDate(let date):
            return dateFormatter.string(from: date)
        case .upcoming:
            return "Upcoming"
        case .done:
            return "Done"
        case .morning:
            return "Morning"
        case .evening:
            return "Evening"
        }
    }

    /// Check if scope is a custom date.
    private static func isCustomDate(_ scope: HomeListScope) -> Bool {
        if case .customDate = scope { return true }
        return false
    }

    /// Date formatter for custom date display.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}
