import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingNetworkClass {
    case wifi
    case cellular
    case unavailable
}
