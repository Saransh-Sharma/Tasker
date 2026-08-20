import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// Back, and how far along the user is.
///
/// The percentages v5 showed — 0%, 12%, 25%, 37% — were the wrong unit twice
/// over. They implied a precision six discrete questions do not have, and read
/// as a completion score for a life rather than a position in a form. This shows
/// a six-segment track instead, and gives VoiceOver the exact position that the
/// sighted UI deliberately no longer spells out.
struct LifeWeaveTopBar: View {
    let step: LifeWeaveStep
    let canGoBack: Bool
    let onBack: () -> Void

    private var showsBack: Bool {
        // Nothing sits behind Arrival, and the reveal is past a successful
        // commit — stepping back into capture from there would offer to re-stage
        // a record that is already persisted.
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
                        .lifeBoardClaySurface(.resting, cornerRadius: 22)
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier(LifeWeaveAccessibilityID.backButton)
            }
            Spacer(minLength: 0)
            if let index = step.coreIndex {
                LifeWeaveProgressTrack(index: index, total: LifeWeaveStep.coreCount)
                    .accessibilityIdentifier(LifeWeaveAccessibilityID.progress)
                    .accessibilityLabel(Text("Step \(index) of \(LifeWeaveStep.coreCount), \(Self.stepName(step))"))
            }
        }
        .frame(height: 44)
    }

    /// Human names, not case names. VoiceOver reads this aloud.
    private static func stepName(_ step: LifeWeaveStep) -> String {
        switch step {
        case .arrival: "Welcome"
        case .intent: "What would feel lighter"
        case .lifeAreas: "Life areas"
        case .dayShape: "Day shape"
        case .firstCapture: "First capture"
        case .reveal: "Ready"
        }
    }
}

/// Six segments, filled to the current step.
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

/// A compact multi-select chip, for the optional blockers row.
///
/// Chips rather than another list of full rows: the blockers are a follow-up to
/// a choice the user already made, and giving them the same visual weight as the
/// intent itself is how v5 ended up charging a whole screen for them.
struct LifeWeaveChip: View {
    let title: String
    let isSelected: Bool
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .lifeBoardClaySurface(
                    isSelected ? .raised : .resting,
                    cornerRadius: 18,
                    fill: isSelected ? Color.lifeboard(.accentWash) : nil
                )
                // Selection is shape and mark as well as fill, never fill alone —
                // it has to survive grayscale and colour-vision differences.
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.lifeboard(.accentPrimary), lineWidth: isSelected ? 2 : 0)
                )
        }
        .buttonStyle(LifeMapPressButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.48 : 1)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
    static let captureInterpret = "onboarding.lifeweave.capture.interpret"
    static let captureKeep = "onboarding.lifeweave.capture.keep"
    static let captureChange = "onboarding.lifeweave.capture.change"
    static let captureSkip = "onboarding.lifeweave.capture.skip"
    static let dayShapeEdit = "onboarding.lifeweave.dayshape.edit"
    static let weekStartChange = "onboarding.lifeweave.dayshape.weekstart"
    static let revealReceipt = "onboarding.lifeweave.reveal.receipt"

    static func step(_ step: LifeWeaveStep) -> String {
        "onboarding.lifeweave.step.\(step.identifierSuffix)"
    }

    static func intent(_ id: String) -> String { "onboarding.lifeweave.intent.\(id)" }
    static func blocker(_ id: String) -> String { "onboarding.lifeweave.blocker.\(id)" }
    static func lifeArea(_ id: String) -> String { "onboarding.lifeweave.area.\(id)" }
    static func primaryArea(_ id: String) -> String { "onboarding.lifeweave.primaryArea.\(id)" }
    static func dayShapePreset(_ id: String) -> String { "onboarding.lifeweave.preset.\(id)" }
    static func captureKind(_ id: String) -> String { "onboarding.lifeweave.capture.kind.\(id)" }
    static func permission(_ id: String) -> String { "onboarding.lifeweave.permission.\(id)" }
    static func calendarRow(_ id: String) -> String { "onboarding.lifeweave.calendar.\(id)" }
    static func healthWriteBack(_ id: String) -> String { "onboarding.lifeweave.health.writeback.\(id)" }
}
