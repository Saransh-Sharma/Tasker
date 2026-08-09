import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

final class OnboardingAccessibilityMarkerView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        isUserInteractionEnabled = false
        backgroundColor = .clear
        alpha = 0.01
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(identifier: String, label: String, value: String?) {
        accessibilityIdentifier = identifier
        accessibilityLabel = label
        accessibilityValue = value
    }
}
