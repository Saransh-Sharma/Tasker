import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingPermissionHeroIcon: View {
    let systemName: String
    let primaryColor: Color
    let secondaryColor: Color
    let accessibilityLabel: String
    let accessibilityIdentifier: String

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(primaryColor.opacity(0.13))
                .frame(width: 150, height: 150)
            Circle()
                .stroke(primaryColor.opacity(0.22), lineWidth: 1)
                .frame(width: 150, height: 150)

            Image(systemName: systemName)
                .font(.system(size: 76, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(primaryColor, secondaryColor)
                .symbolEffect(.pulse.byLayer, options: .repeat(.periodic(delay: 1.5)), isActive: isAnimating && reduceMotion == false)
                .accessibilityLabel(accessibilityLabel)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(accessibilityIdentifier)
        .onAppear {
            isAnimating = true
        }
    }
}
