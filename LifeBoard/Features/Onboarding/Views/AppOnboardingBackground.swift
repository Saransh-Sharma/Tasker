import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct AppOnboardingBackground: View {
    var body: some View {
        AdaptiveAtmosphere(
            snapshot: AtmosphereSnapshot.resolve(at: Date()).replacingPhase(.dawn),
            placement: .onboarding,
            requestedTier: .static,
            comfortProfile: .calm
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
