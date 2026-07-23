import SwiftUI

struct LBSunriseHeroArtwork: View {
    struct Model: Equatable {
        let selectedDate: Date
        let asset: TimeOfDayHeaderAsset
        let isScrollActive: Bool
    }

    let model: Model
    var height: CGFloat
    @Environment(\.lifeBoardAtmosphereIsHosted) private var isAtmosphereHosted

    var body: some View {
        Group {
            if isAtmosphereHosted {
                Color.clear
            } else {
                LifeBoardAdaptiveAtmosphere(
                    snapshot: .resolve(at: Date()),
                    placement: .home,
                    requestedTier: .ambient2D,
                    comfortProfile: .balanced
                )
            }
        }
        .frame(height: height)
        .clipped()
        .accessibilityHidden(true)
    }
}
