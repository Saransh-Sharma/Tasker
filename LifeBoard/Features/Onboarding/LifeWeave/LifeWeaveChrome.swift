import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// Back, and how far along the user is.
///
/// Four anonymous segments, never a percentage: a life is not a completion bar.
/// VoiceOver is told the exact position the sighted UI deliberately does not
/// spell out.
struct LifeWeaveTopBar: View {
    let step: LifeWeaveStep
    let canGoBack: Bool
    let onBack: () -> Void

    private var progress: LifeWeaveProgressModel { .resolve(step) }

    private var showsBack: Bool {
        // Nothing sits behind the welcome, and the Ready screen is past a
        // successful commit — stepping back into capture from there would offer
        // to re-stage a record that is already persisted.
        guard step != .arrival, step != .reveal else { return false }
        return canGoBack
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if showsBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .lifeboardFont(.headline)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                        .frame(width: 44, height: 44)
                        .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
                }
                .accessibilityLabel(String(localized: "Back"))
                .accessibilityIdentifier(LifeWeaveAccessibilityID.backButton)
                .transition(.opacity)
            }
            Spacer(minLength: 0)
            if let index = progress.index, let total = progress.total {
                LifeWeaveProgressTrack(index: index, total: total)
                    .accessibilityIdentifier(LifeWeaveAccessibilityID.progress)
                    .accessibilityLabel(Text(progress.spokenLabel ?? ""))
            }
        }
        .frame(height: 44)
        .lifeBoardMotion(.contentInsertion, value: showsBack)
    }
}

/// Position in the four-screen flow.
///
/// Connections open as sheets over the Ready screen, so they never take a
/// position of their own: an optional choice must not read as more steps.
enum LifeWeaveProgressModel: Equatable {
    case none
    case core(index: Int, total: Int, name: String)

    static func resolve(_ step: LifeWeaveStep) -> Self {
        let normalized = LifeWeaveMigration.streamlinedStep(for: step)
        guard let index = LifeWeaveStep.streamlined.firstIndex(of: normalized) else { return .none }
        return .core(
            index: index + 1,
            total: LifeWeaveStep.streamlined.count,
            name: LifeWeaveCopy.Progress.stepName(normalized)
        )
    }

    var index: Int? {
        if case .core(let index, _, _) = self { return index }
        return nil
    }

    var total: Int? {
        if case .core(_, let total, _) = self { return total }
        return nil
    }

    var spokenLabel: String? {
        guard case .core(let index, let total, let name) = self else { return nil }
        return LifeWeaveCopy.Progress.spoken(index: index, total: total, name: name)
    }
}

/// Four segments, filled to the current step.
///
/// Hidden from accessibility: the bar's own label already states the position in
/// words, and publishing six anonymous elements would make a screen reader
/// enumerate them without ever saying where the user is.
private struct LifeWeaveProgressTrack: View {
    let index: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...max(1, total), id: \.self) { position in
                Capsule(style: .continuous)
                    .fill(
                        position <= index
                            ? Color.lifeboard(.accentPrimary)
                            : Color.lifeboard(.strokeHairline)
                    )
                    .frame(width: position == index ? 18 : 10, height: 3)
            }
        }
        .lifeBoardMotion(.contentInsertion, value: index)
        .accessibilityHidden(true)
    }
}

/// Every stable accessibility identifier published by the v6 flow.
enum LifeWeaveAccessibilityID {
    static let flow = "onboarding.lifeweave.flow"
    static let canvas = "onboarding.lifeweave.canvas"
    static let progress = "onboarding.lifeweave.progress"
    static let backButton = "onboarding.lifeweave.back"
    static let errorBanner = "onboarding.lifeweave.error"
    static let primaryAction = "onboarding.lifeweave.primary"
    static let secondaryAction = "onboarding.lifeweave.secondary"
    static let captureField = "onboarding.lifeweave.capture.field"
    static let captureSkip = "onboarding.lifeweave.capture.skip"
    static let dayShapeEdit = "onboarding.lifeweave.dayshape.edit"
    static let hoursEdit = "onboarding.lifeweave.reveal.hours.edit"
    static let weekStartChange = "onboarding.lifeweave.dayshape.weekstart"
    static let revealReceipt = "onboarding.lifeweave.reveal.receipt"

    static func step(_ step: LifeWeaveStep) -> String {
        "onboarding.lifeweave.step.\(step.identifierSuffix)"
    }

    static func intent(_ id: String) -> String { "onboarding.lifeweave.intent.\(id)" }
    static func lifeArea(_ id: String) -> String { "onboarding.lifeweave.area.\(id)" }
    static func dayShapePreset(_ id: String) -> String { "onboarding.lifeweave.preset.\(id)" }
    static func permission(_ id: String) -> String { "onboarding.lifeweave.permission.\(id)" }
    static func calendarRow(_ id: String) -> String { "onboarding.lifeweave.calendar.\(id)" }
    static func healthWriteBack(_ id: String) -> String { "onboarding.lifeweave.health.writeback.\(id)" }
}
