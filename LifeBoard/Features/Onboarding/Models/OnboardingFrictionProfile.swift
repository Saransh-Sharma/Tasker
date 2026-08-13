import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingFrictionProfile: String, CaseIterable, Codable, Identifiable, Sendable {
    case starting
    case choosing
    case remembering
    case finishing
    case overwhelmed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .starting:
            return "Getting started"
        case .choosing:
            return "Too many options"
        case .remembering:
            return "Keeping track"
        case .finishing:
            return "Following through"
        case .overwhelmed:
            return "Too much at once"
        }
    }

    var symbolName: String {
        switch self {
        case .starting:
            return "sparkles"
        case .choosing:
            return "slider.horizontal.3"
        case .remembering:
            return "bookmark"
        case .finishing:
            return "flag"
        case .overwhelmed:
            return "circle.grid.2x2"
        }
    }

    var helperCopy: String {
        switch self {
        case .starting:
            return "We’ll narrow things to the easiest place to begin."
        case .choosing:
            return "We’ll keep decisions light and use good defaults."
        case .remembering:
            return "We’ll bring the next step back when it matters."
        case .finishing:
            return "We’ll favor steps with a clear finish line."
        case .overwhelmed:
            return "We’ll keep the setup light and low-pressure."
        }
    }
}
