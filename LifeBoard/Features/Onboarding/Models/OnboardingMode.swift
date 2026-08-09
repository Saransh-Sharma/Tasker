import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingMode: String, Codable, Equatable {
    case guided
    case custom
}
