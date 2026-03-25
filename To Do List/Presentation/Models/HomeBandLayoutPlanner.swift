import Foundation

enum HomeBandLayoutPlanner {
    static func visibleBands(
        hasPassiveTracking: Bool,
        hasFocusHero: Bool,
        hasTodayAgenda: Bool,
        hasRescue: Bool,
        hasQuietTracking: Bool
    ) -> [HomeBand] {
        var bands: [HomeBand] = []

        if hasPassiveTracking {
            bands.append(.context)
        }

        if hasFocusHero || hasTodayAgenda {
            bands.append(.activeWork)
        }

        if hasRescue {
            bands.append(.pressure)
        }

        if hasQuietTracking {
            bands.append(.secondary)
        }

        return bands
    }
}
