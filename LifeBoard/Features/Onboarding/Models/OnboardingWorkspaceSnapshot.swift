import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingWorkspaceSnapshot: Equatable {
    let customLifeAreaCount: Int
    let customProjectCount: Int
    let taskCount: Int

    var isEffectivelyEmpty: Bool {
        customLifeAreaCount == 0 && customProjectCount == 0 && taskCount < 3
    }
}
