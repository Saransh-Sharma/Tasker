import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingPromptBackground: View {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    var body: some View {
        LinearGradient(
            colors: [
                OnboardingPromptTheme.canvasWarm,
                OnboardingPromptTheme.canvasBase,
                OnboardingPromptTheme.canvasCool
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(OnboardingPromptTheme.sunriseGold.opacity(reduceTransparency ? 0.08 : 0.18))
                .frame(width: 220, height: 220)
                .blur(radius: reduceTransparency ? 0 : 56)
                .offset(x: 72, y: -96)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(OnboardingPromptTheme.assistantSoft.opacity(reduceTransparency ? 0.12 : 0.32))
                .frame(width: 260, height: 260)
                .blur(radius: reduceTransparency ? 0 : 64)
                .offset(x: -112, y: 88)
        }
    }
}
