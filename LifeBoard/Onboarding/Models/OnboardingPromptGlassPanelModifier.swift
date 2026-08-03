import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingPromptGlassPanelModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(
                reduceTransparency ? OnboardingPromptTheme.surfaceSolid : OnboardingPromptTheme.surfaceStrongGlass,
                in: shape
            )
            .overlay(
                shape
                    .stroke(OnboardingPromptTheme.border(reduceTransparency: reduceTransparency), lineWidth: 1)
            )
            // Elevation comes from the clay depth scale, not a bespoke shadow.
            .lifeBoardClaySurface(.floating, cornerRadius: 28)
    }
}
