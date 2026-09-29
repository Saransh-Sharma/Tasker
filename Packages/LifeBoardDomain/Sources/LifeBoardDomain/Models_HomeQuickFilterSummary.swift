//
//  HomeQuickFilterSummary.swift
//  LifeBoard
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

    /// Initializes a new instance.
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

public extension HomeQuickFilterSummary {

    /// Create a summary from the current filter state.
    /// - Parameters:
    ///   - scope: The current list scope
    ///   - filterState: The current filter state
    ///   - customDate: The selected custom date (if any)
    /// - Returns: A summary for display in the trigger button
    static func from(
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
            secondaryParts.append(projectCount == 1 ? String(localized: "+ 1 project") : String(localized: "+ \(projectCount) projects"))
            hasActiveFilters = true
        }

        // Check for advanced filters
        if filterState.advancedFilter != nil {
            secondaryParts.append(String(localized: "+ Advanced"))
            hasActiveFilters = true
        }

        // Check if we're on a non-default quick view (but not custom date)
        if scope.quickView != .today && !isCustomDate(scope) {
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
            return String(localized: "Today")
        case .customDate(let date):
            return dateFormatter.string(from: date)
        case .upcoming:
            return String(localized: "Upcoming")
        case .overdue:
            return String(localized: "From earlier")
        case .done:
            return String(localized: "Done")
        case .morning:
            return String(localized: "Morning")
        case .evening:
            return String(localized: "Evening")
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
