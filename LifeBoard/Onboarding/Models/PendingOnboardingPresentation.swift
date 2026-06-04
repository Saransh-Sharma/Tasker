import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum PendingOnboardingPresentation: Equatable {
    case prompt(snapshot: OnboardingWorkspaceSnapshot)
    case fullFlow(source: String)

    var priority: Int {
        switch self {
        case .prompt:
            return 1
        case .fullFlow:
            return 2
        }
    }

    var analyticsLabel: String {
        switch self {
        case .prompt:
            return "prompt"
        case .fullFlow:
            return "full_flow"
        }
    }
}
