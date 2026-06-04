import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct AppOnboardingBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                OnboardingTheme.canvas.opacity(0.98),
                OnboardingTheme.canvasSecondary.opacity(0.99),
                OnboardingTheme.canvasElevated.opacity(0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(OnboardingTheme.accent.opacity(0.035))
                .frame(width: 320, height: 220)
                .blur(radius: 56)
                .offset(x: -96, y: -84)
        }
    }
}
