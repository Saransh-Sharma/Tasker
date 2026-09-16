import SwiftUI

extension View {
    /// Reuses the same ambient scene on its owning feature surface.
    /// Apply before the surface material so paint stays behind native content.
    func homeAmbientArtwork(_ kind: DashboardWidgetKind?, enabled: Bool = true, cornerRadius: CGFloat = 24) -> some View {
        background {
            if enabled, let kind {
                HomeCardScene(style: .init(kind: kind, preset: .wide))
                    .clipShape(.rect(cornerRadius: cornerRadius))
            }
        }
    }
}

/// Dedicated panoramic compositions for feature identity; never persisted as widget kinds.
enum FeatureHeaderScene: String, CaseIterable {
    case home, track, plan, insights, eva, journal, care, routines, goals
    case fasting, body, workout, sleep, movement, nutrition, moment, capture

    var assetName: String { "AmbientSurface_\(rawValue)Header" }

    var fallbackKind: DashboardWidgetKind {
        switch self {
        case .home, .track: .lifeSnapshot
        case .plan: .tasks
        case .insights: .progressReflection
        case .eva: .evaConversation
        case .journal: .journal
        case .care: .care
        case .routines: .routines
        case .goals: .goals
        case .fasting: .fasting
        case .body: .bodyMetric
        case .workout: .workout
        case .sleep: .sleep
        case .movement: .movement
        case .nutrition: .nutritionSummary
        case .moment: .lifeMoment
        case .capture: .quickCapture
        }
    }
}

extension View {
    func featureHeaderArtwork(_ scene: FeatureHeaderScene, enabled: Bool = true, cornerRadius: CGFloat = 24) -> some View {
        background {
            if enabled {
                HomeCardScene(style: .init(kind: scene.fallbackKind, preset: .wide), assetName: scene.assetName)
                    .clipShape(.rect(cornerRadius: cornerRadius))
            }
        }
    }
}
