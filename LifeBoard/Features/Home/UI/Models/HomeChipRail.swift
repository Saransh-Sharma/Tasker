//
//  HomeChipRail.swift
//  LifeBoard
//
//  Unified Home chip rail: scope lenses, Today facets, and filter actions in one row.
//

import Foundation
import SwiftUI

enum HomeChipRailItem: Equatable, Identifiable {
    case lens(HomeLensChip)
    case separator
    case todayFacet(HomeContentScope)
    case manageLifeAreas
    case advancedFilters(hasActiveFilters: Bool)

    public var id: String {
        switch self {
        case .lens(let chip): return "lens.\(chip.id)"
        case .separator: return "separator"
        case .todayFacet(let scope): return "facet.\(scope.rawValue)"
        case .manageLifeAreas: return "manage.lifeAreas"
        case .advancedFilters: return "filters"
        }
    }
}

enum HomeChipRailBuilder {
    static func build(
        activeLens: HomeLens,
        lifeAreaChips: [HomeLensChip],
        selectedContentScope: HomeContentScope,
        hasActiveFilters: Bool
    ) -> [HomeChipRailItem] {
        var items: [HomeChipRailItem] = []

        items.append(.lens(HomeLensChip(
            lens: .today,
            title: "Today",
            systemImage: "sun.max",
            isSelected: activeLens == .today
        )))
        items.append(.lens(HomeLensChip(
            lens: .upcoming,
            title: "Upcoming",
            systemImage: "arrow.up.right",
            isSelected: activeLens == .upcoming
        )))
        for chip in lifeAreaChips {
            items.append(.lens(chip))
        }
        items.append(.manageLifeAreas)

        if activeLens == .today {
            items.append(.separator)
            for scope in HomeContentScope.allCases {
                items.append(.todayFacet(scope))
            }
        }

        items.append(.advancedFilters(hasActiveFilters: hasActiveFilters))
        return items
    }

    static func todayFacetChipModel(
        for scope: HomeContentScope,
        isSelected: Bool
    ) -> ClayFilterChip.Model {
        switch scope {
        case .all:
            return ClayFilterChip.Model(
                id: "all",
                title: "All",
                systemImage: "square.grid.2x2",
                isSelected: isSelected,
                hidesTitle: true,
                accessibilityID: "home.sunrise.filter.all"
            )
        case .meetings:
            return ClayFilterChip.Model(
                id: "meetings",
                title: "Meetings",
                systemImage: "calendar",
                isSelected: isSelected,
                hidesTitle: true,
                accessibilityID: "home.sunrise.filter.meetings"
            )
        case .tasks:
            return ClayFilterChip.Model(
                id: "tasks",
                title: "Tasks",
                systemImage: "checkmark.square",
                isSelected: isSelected,
                hidesTitle: true,
                accessibilityID: "home.sunrise.filter.tasks"
            )
        case .habits:
            return ClayFilterChip.Model(
                id: "habits",
                title: "Habits",
                systemImage: "heart",
                isSelected: isSelected,
                hidesTitle: true,
                accessibilityID: "home.sunrise.filter.habits"
            )
        }
    }

    static func advancedFiltersChipModel(hasActiveFilters: Bool) -> ClayFilterChip.Model {
        ClayFilterChip.Model(
            id: "filters",
            title: "Filters",
            systemImage: "slider.horizontal.3",
            isSelected: false,
            showsIndicator: hasActiveFilters,
            hidesTitle: true,
            accessibilityID: "home.sunrise.filter.filters"
        )
    }

    static func manageLifeAreasChipModel() -> ClayFilterChip.Model {
        ClayFilterChip.Model(
            id: "lens.manage",
            title: "Manage life areas",
            systemImage: "plus",
            isSelected: false,
            hidesTitle: true,
            accessibilityID: "home.sunrise.lens.manage"
        )
    }
}
