import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingWelcomeIntroLine: View {
    let text: String
    let style: LifeBoardTextStyle
    let isVisible: Bool
    let secondary: Bool

    var body: some View {
        Text(text)
            .lifeboardFont(style)
            .foregroundStyle(secondary ? OnboardingTheme.onMediaTextSecondary : OnboardingTheme.onMediaTextPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .blur(radius: isVisible ? 0 : 18)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 14)
            .animation(.timingCurve(0.16, 0.92, 0.24, 1, duration: 1.15), value: isVisible)
    }
}
