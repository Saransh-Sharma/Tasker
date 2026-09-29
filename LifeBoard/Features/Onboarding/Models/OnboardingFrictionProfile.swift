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
            return String(localized: "Getting started")
        case .choosing:
            return String(localized: "Too many options")
        case .remembering:
            return String(localized: "Keeping track")
        case .finishing:
            return String(localized: "Following through")
        case .overwhelmed:
            return String(localized: "Too much at once")
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
            return String(localized: "Starts with the easiest step.")
        case .choosing:
            return String(localized: "Fewer choices, good defaults.")
        case .remembering:
            return String(localized: "Brings back the next step.")
        case .finishing:
            return String(localized: "Steps with a clear finish.")
        case .overwhelmed:
            return String(localized: "A lighter setup.")
        }
    }
}
