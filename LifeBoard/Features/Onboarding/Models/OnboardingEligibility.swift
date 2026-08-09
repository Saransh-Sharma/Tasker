import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingEligibility: Equatable {
    case fullFlow(OnboardingWorkspaceSnapshot)
    case promptOnly(OnboardingWorkspaceSnapshot)
    case suppressed
}
