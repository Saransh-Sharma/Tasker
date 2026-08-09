import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingPresentationQueue: Equatable {
    private(set) var pending: PendingOnboardingPresentation?

    mutating func enqueue(_ presentation: PendingOnboardingPresentation) {
        guard let pending else {
            self.pending = presentation
            return
        }
        if presentation.priority >= pending.priority {
            self.pending = presentation
        }
    }

    mutating func markPresented(_ presentation: PendingOnboardingPresentation) {
        guard pending == presentation else { return }
        pending = nil
    }
}
