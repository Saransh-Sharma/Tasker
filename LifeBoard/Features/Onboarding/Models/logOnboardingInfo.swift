import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

func logOnboardingInfo(event: String, message: String? = nil, fields: [String: String] = [:]) {
    logInfo(onboardingLogLine(event: event, message: message, fields: fields))
}
