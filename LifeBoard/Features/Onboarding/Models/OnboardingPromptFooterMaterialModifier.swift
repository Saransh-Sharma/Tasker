import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingPromptFooterMaterialModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [
                        OnboardingPromptTheme.canvasBase.opacity(0.0),
                        OnboardingPromptTheme.canvasBase.opacity(reduceTransparency ? 1.0 : 0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}
