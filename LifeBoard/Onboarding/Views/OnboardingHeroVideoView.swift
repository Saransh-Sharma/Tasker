import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingHeroVideoView: UIViewRepresentable {
    let videoName: String
    let accessibilityIdentifier: String

    func makeUIView(context: Context) -> OnboardingLoopingPlayerView {
        OnboardingLoopingPlayerView(
            videoName: videoName,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    func updateUIView(_ uiView: OnboardingLoopingPlayerView, context: Context) {
        uiView.accessibilityIdentifier = accessibilityIdentifier
        uiView.update(videoName: videoName)
    }
}
