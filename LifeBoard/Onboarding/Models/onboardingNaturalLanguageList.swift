import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

func onboardingNaturalLanguageList(_ items: [String], fallback: String) -> String {
    let cleanedItems = items
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { $0.isEmpty == false }

    switch cleanedItems.count {
    case 0:
        return fallback
    case 1:
        return cleanedItems[0]
    case 2:
        return "\(cleanedItems[0]) and \(cleanedItems[1])"
    default:
        let head = cleanedItems.dropLast().joined(separator: ", ")
        return "\(head), and \(cleanedItems[cleanedItems.count - 1])"
    }
}
