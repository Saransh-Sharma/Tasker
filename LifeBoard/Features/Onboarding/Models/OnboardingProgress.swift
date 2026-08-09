import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingProgress: Equatable {
    let current: Int
    let total: Int

    init?(step: OnboardingStep) {
        guard let index = OnboardingStep.orderedFlow.firstIndex(of: step) else {
            return nil
        }
        current = index + 1
        total = OnboardingStep.orderedFlow.count
    }

    var label: String {
        "Step \(current) of \(total)"
    }

    var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(current) / CGFloat(total)
    }
}
