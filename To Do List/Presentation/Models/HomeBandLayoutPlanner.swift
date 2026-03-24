import Foundation

enum HomeBandLayoutPlanner {
    static func visibleBands(
        hasQuickFilters: Bool,
        hasDueTodayAgenda: Bool,
        hasPressureTools: Bool,
        hasSecondaryContent: Bool
    ) -> [HomeBand] {
        var bands: [HomeBand] = []

        if hasQuickFilters {
            bands.append(.context)
        }

        if hasDueTodayAgenda {
            bands.append(.activeWork)
        }

        if hasPressureTools {
            bands.append(.pressure)
        }

        if hasSecondaryContent {
            bands.append(.secondary)
        }

        return bands
    }
}
