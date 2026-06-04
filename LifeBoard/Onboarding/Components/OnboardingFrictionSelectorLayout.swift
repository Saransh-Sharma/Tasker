import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingFrictionSelectorLayout: Equatable {
    case stacked
    case twoColumn

    static func preferredLayout(for availableWidth: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Self {
        if dynamicTypeSize.isAccessibilitySize || availableWidth < 500 {
            return .stacked
        }

        return .twoColumn
    }
}
