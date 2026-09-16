import SwiftUI

/// Presentation only: persisted placement and domain projection contracts stay unchanged.
public struct HomeCardPresentationStyle: Equatable, Sendable {
    public let kind: DashboardWidgetKind
    public let preset: WidgetSizePreset

    public init(kind: DashboardWidgetKind, preset: WidgetSizePreset) {
        self.kind = kind
        self.preset = preset
    }

    var assetName: String { "HomeCardScene_\(kind.rawValue)" }

    /// Short surface labels preserve recognition in the single-line Glance header.
    /// The registry and pinning catalog retain the complete product names.
    static func glanceTitle(for kind: DashboardWidgetKind, fallback: String) -> String {
        switch kind {
        case .progressReflection: "Progress"
        case .nutritionSummary: "Nutrition"
        case .workout: "Workout"
        default: fallback
        }
    }

    static func cardWidth(contentWidth: CGFloat, preset: WidgetSizePreset, regular: Bool) -> CGFloat {
        let columns = regular ? (contentWidth >= 1100 ? 12 : 8) : 4
        let span = DashboardResponsiveSpanResolver.columns(for: preset, columnCount: columns)
        return (contentWidth - CGFloat(columns - 1) * 12) / CGFloat(columns) * CGFloat(span) + CGFloat(span - 1) * 12
    }

    func rowLimit(lowEnergy: Bool = false) -> Int {
        if kind == .tasks { return lowEnergy ? 2 : (preset == .expanded ? 6 : 4) }
        if kind == .care || kind == .routines {
            if lowEnergy { return 1 }
            switch preset {
            case .compact: return 1
            case .standard, .wide: return 3
            case .tall: return 4
            case .expanded: return 5
            }
        }
        switch preset {
        case .compact: return 1
        case .standard: return 2
        case .wide: return 3
        case .tall: return 4
        case .expanded: return 6
        }
    }

    static func showsScene(availability: HomeCardSnapshotAvailability?, hasUserMedia: Bool) -> Bool {
        !hasUserMedia && (availability == .ready || availability == .empty)
    }

    var minimumHeight: CGFloat {
        switch preset {
        case .compact: 104
        case .standard, .wide: 178
        case .tall: 260
        case .expanded: 340
        }
    }
}
