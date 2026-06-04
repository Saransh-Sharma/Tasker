import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

@MainActor
final class OnboardingFeedbackController {
    let selectionGenerator = UISelectionFeedbackGenerator()
    let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    let successGenerator = UINotificationFeedbackGenerator()
    var hapticEngine: CHHapticEngine?

    func prepare() {
        guard isFeedbackAvailable else { return }
        selectionGenerator.prepare()
        lightGenerator.prepare()
        mediumGenerator.prepare()
        successGenerator.prepare()
        prepareEngineIfNeeded()
    }

    func selection() {
        guard isFeedbackAvailable else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    func light() {
        guard isFeedbackAvailable else { return }
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }

    func medium() {
        guard isFeedbackAvailable else { return }
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }

    func successSignature() {
        guard isFeedbackAvailable else { return }
        guard playSuccessPattern() == false else { return }
        successGenerator.notificationOccurred(.success)
        successGenerator.prepare()
    }

    func prepareEngineIfNeeded() {
        guard isFeedbackAvailable else { return }
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if hapticEngine == nil {
            hapticEngine = try? CHHapticEngine()
            try? hapticEngine?.start()
        }
    }

    func playSuccessPattern() -> Bool {
        guard isFeedbackAvailable else { return false }
        prepareEngineIfNeeded()
        guard let hapticEngine else { return false }
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.75),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0.12
            )
        ]
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            return true
        } catch {
            return false
        }
    }

    private var isFeedbackAvailable: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return true
        #endif
    }
}
