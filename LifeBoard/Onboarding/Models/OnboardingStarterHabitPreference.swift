import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingStarterHabitPreference: String, CaseIterable, Codable {
    case positive
    case negativeDailyCheckIn

    var title: String {
        switch self {
        case .positive:
            return "Build a positive habit"
        case .negativeDailyCheckIn:
            return "Reduce a habit"
        }
    }

    var subtitle: String {
        switch self {
        case .positive:
            return "Create a visible streak around something you want more of."
        case .negativeDailyCheckIn:
            return "Track a clean day without making the flow punitive."
        }
    }
}
