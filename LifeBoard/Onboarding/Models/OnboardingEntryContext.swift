import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingEntryContext: String, Codable, Equatable {
    case freshFlow
    case establishedWorkspace
}
