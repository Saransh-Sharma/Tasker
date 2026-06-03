import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingEyebrowLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .lifeboardFont(.caption2)
            .foregroundStyle(OnboardingTheme.headerAccent)
    }
}
