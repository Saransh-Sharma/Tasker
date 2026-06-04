import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingAccessibilityMarker: UIViewRepresentable {
    let identifier: String
    let label: String
    let value: String?

    func makeUIView(context: Context) -> OnboardingAccessibilityMarkerView {
        OnboardingAccessibilityMarkerView()
    }

    func updateUIView(_ uiView: OnboardingAccessibilityMarkerView, context: Context) {
        uiView.update(identifier: identifier, label: label, value: value)
    }
}
