import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum WelcomeIntroPhase: Int, Equatable {
    case introVideoOnly
    case introTitleReveal
    case introSubtitleReveal
    case introCardHold
    case introCTAReady

    var showsIntroOverlay: Bool {
        true
    }

    var showsIntroCard: Bool {
        rawValue >= Self.introTitleReveal.rawValue
    }

    var showsTitle: Bool {
        rawValue >= Self.introTitleReveal.rawValue
    }

    var showsSubtitle: Bool {
        rawValue >= Self.introSubtitleReveal.rawValue
    }

    var showsIntroCTA: Bool {
        self == .introCTAReady
    }

    var showsWelcomeChrome: Bool {
        false
    }

    var backdropBlurOpacity: Double {
        0
    }

    var backdropDimOpacity: Double {
        0
    }

    var videoGrainAmount: Int {
        switch self {
        case .introVideoOnly,
             .introTitleReveal,
             .introSubtitleReveal,
             .introCardHold,
             .introCTAReady:
            return 25
        }
    }

    var introCardOpacity: Double {
        switch self {
        case .introTitleReveal, .introSubtitleReveal, .introCardHold, .introCTAReady:
            return 1
        default:
            return 0
        }
    }
}
