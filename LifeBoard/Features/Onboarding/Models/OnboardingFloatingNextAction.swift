import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingFloatingNextAction {
    let title: String
    let systemImage: String
    let accessibilityIdentifier: String?
    let disabled: Bool
    let showsProgress: Bool
    let action: () -> Void
}
