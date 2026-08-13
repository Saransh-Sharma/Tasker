import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct ResolvedProjectSelection: Codable, Equatable {
    let draft: OnboardingProjectDraft
    let project: Project
    let reusedExisting: Bool
}
