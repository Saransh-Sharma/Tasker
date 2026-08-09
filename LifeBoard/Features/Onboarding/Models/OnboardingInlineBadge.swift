import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingInlineBadge: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .lifeboardFont(.caption2)
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(accent.opacity(0.10), in: Capsule())
    }
}
