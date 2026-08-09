import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

func logOnboardingError(event: String, message: String? = nil, fields: [String: String] = [:]) {
    logError(onboardingLogLine(event: event, message: message, fields: fields))
}
