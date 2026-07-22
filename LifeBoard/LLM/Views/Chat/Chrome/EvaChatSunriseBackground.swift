import SwiftUI

struct EvaChatSunriseBackground: View {
    var isStreaming: Bool = false

    @Environment(\.lifeBoardAtmosphereIsHosted) private var isAtmosphereHosted

    var body: some View {
        Group {
            if isAtmosphereHosted {
                Color.clear
            } else {
                LifeBoardAdaptiveAtmosphere(
                    snapshot: .resolve(at: Date()),
                    placement: .eva,
                    requestedTier: isStreaming ? .static : .ambient2D,
                    comfortProfile: .balanced
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
