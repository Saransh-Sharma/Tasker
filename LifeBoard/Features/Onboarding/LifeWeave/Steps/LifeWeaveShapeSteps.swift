import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// A rough boundary, not a settings form.
///
/// v5 opened this step on two time steppers. That asks for precision most people
/// do not have, and it quietly tells anyone on shifts, caregiving, or an
/// irregular week that they are holding the app wrong. Presets first; the
/// steppers are still there, one tap away, for whoever wants them.
struct LifeWeaveDayShapeStep: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    @State private var showsEditor = false

    var body: some View {
        LifeMapQuestionScaffold(
            title: "When does your day usually have room?",
            support: "This gives LifeBoard a realistic planning boundary. It won't stop you from planning outside it."
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(LifeWeaveDayShapePreset.allCases.filter { $0 != .custom }, id: \.rawValue) { preset in
                    LifeMapChoiceRow(
                        title: preset.title,
                        subtitle: Self.subtitle(for: preset),
                        symbol: Self.symbol(for: preset),
                        isSelected: model.draft.dayShapePreset == preset
                    ) {
                        model.selectDayShapePreset(preset)
                    }
                    .accessibilityIdentifier(LifeWeaveAccessibilityID.dayShapePreset(preset.rawValue))
                }

                Button {
                    showsEditor.toggle()
                } label: {
                    Label(showsEditor ? "Hide hours" : "Edit hours", systemImage: "slider.horizontal.3")
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier(LifeWeaveAccessibilityID.dayShapeEdit)

                if showsEditor {
                    editor.transition(.opacity.combined(with: .move(edge: .top)))
                }

                weekStartRow
            }
            .lifeBoardMotion(.contentInsertion, value: showsEditor)
        }
    }

    /// Disclosed, never the default path. The weekend question lives here too:
    /// asking about it up front is a question about a life most people have not
    /// been asked to describe before they have seen the product.
    private var editor: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            LifeMapTimeStepper(
                label: "Weekdays start",
                value: model.draft.dayShape.weekdayStartMinute
            ) { minute in
                model.updateDayShape { $0.weekdayStartMinute = minute }
            }
            LifeMapTimeStepper(
                label: "Weekdays end",
                value: model.draft.dayShape.weekdayEndMinute
            ) { minute in
                model.updateDayShape { $0.weekdayEndMinute = minute }
            }
            Toggle("I work weekends too", isOn: Binding(
                get: { model.draft.dayShape.worksWeekends },
                set: { value in model.updateDayShape { $0.worksWeekends = value } }
            ))
            .lifeboardFont(.body)
            .foregroundStyle(Color.lifeboard(.textPrimary))
        }
        .padding(Theme.Spacing.md)
        .lifeBoardClaySurface(.well, cornerRadius: 18)
    }

    /// Derived from the locale, shown as a fact with a way to change it.
    ///
    /// Not a question. Making somebody confirm something the system already
    /// knows correctly is a step that exists only to look thorough.
    private var weekStartRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("Week starts \(model.draft.dayShape.weekStartsOn.displayTitle)")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
            Button("Change") {
                model.updateDayShape { shape in
                    shape.weekStartsOn = shape.weekStartsOn == .monday ? .sunday : .monday
                }
            }
            .lifeboardFont(.caption1)
            .foregroundStyle(Color.lifeboard(.accentPrimary))
            .frame(minHeight: 44)
            .accessibilityIdentifier(LifeWeaveAccessibilityID.weekStartChange)
            Spacer(minLength: 0)
        }
    }

    private static func subtitle(for preset: LifeWeaveDayShapePreset) -> String? {
        guard let window = preset.weekdayWindow else { return nil }
        if preset == .flexible { return "I'll keep a wide window." }
        return "\(OnboardingDayShapeDraft.label(forMinute: window.start)) – "
            + OnboardingDayShapeDraft.label(forMinute: window.end)
    }

    private static func symbol(for preset: LifeWeaveDayShapePreset) -> String {
        switch preset {
        case .typical: "sun.max"
        case .early: "sunrise"
        case .later: "sunset"
        case .flexible: "shuffle"
        case .custom: "slider.horizontal.3"
        }
    }
}

/// The magic moment, and the tutorial.
///
/// One real sentence, interpreted in front of the user, corrected by them if
/// wrong, and then actually persisted. That teaches the whole Universal Input
/// contract — natural language becomes structure, nothing saves silently, you
/// can correct it — without a single screen explaining any of it.
struct LifeWeaveCaptureStep: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    @FocusState private var isFocused: Bool

    private var hasProposal: Bool { model.draft.stagedCapture != nil }

    var body: some View {
        LifeMapQuestionScaffold(
            title: "Give LifeBoard one real thing.",
            support: "Something you need to do, remember, or think through."
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                TextField(placeholder, text: $model.captureText, axis: .vertical)
                    .lifeboardFont(.body)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.sentences)
                    .focused($isFocused)
                    .frame(minHeight: 28)
                    .padding(Theme.Spacing.md)
                    // The padded well is what the user aims at, but padding is
                    // not interactive — without this the only tappable region is
                    // the text line itself, which is both unhittable in practice
                    // and under the 44-point target floor. Focus is driven
                    // explicitly so the whole well behaves like one control.
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onTapGesture { isFocused = true }
                    .lifeBoardClaySurface(.well, cornerRadius: 18)
                    .accessibilityIdentifier(LifeWeaveAccessibilityID.captureField)
                    .disabled(model.isResolvingCapture)

                if hasProposal {
                    LifeWeaveCaptureReviewCard(model: model)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .lifeBoardMotion(.contentInsertion, value: model.draft.stagedCapture)
        }
    }

    /// Personalised by the area the user put first, so the example reads like
    /// their life rather than a demo.
    private var placeholder: String {
        switch model.draft.primaryLifeAreaTemplateID {
        case "health-self": "Walk before my first coffee"
        case "relationships": "Call Mum on Sunday"
        case "learning-growth": "Read chapter 4 this weekend"
        case "creativity-fun": "Sketch something on Saturday"
        case "money": "Check the insurance renewal"
        case "life-admin": "Renew passport photos"
        default: "Send the launch handoff Friday"
        }
    }
}

/// "Here's what I understood" — in human words.
///
/// Never "Approve this route" or "Route approved". The user did not come to
/// route an entity; they came to get something out of their head. And no
/// confidence percentage appears anywhere: a number is not an explanation, and
/// showing 0.62 invites a person to argue with a scale nobody defined.
struct LifeWeaveCaptureReviewCard: View {
    @ObservedObject var model: LifeWeaveOnboardingModel

    private var capture: LifeMapStagedCapture? { model.draft.stagedCapture }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let capture {
                Text(headline)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textTertiary))

                Text(capture.text)
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)

                Text(destinationLine(for: capture))
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))

                if model.captureNeedsDisambiguation || capture.isReviewed == false {
                    kindPicker(selected: capture.kind)
                }

                if capture.isReviewed {
                    Button("Change") { model.reopenCapture() }
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.accentPrimary))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier(LifeWeaveAccessibilityID.captureChange)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
    }

    private var headline: String {
        guard let capture else { return "" }
        if model.captureNeedsDisambiguation { return "Where should this live?" }
        return capture.kind == .task ? "Looks like a task" : "This sounds like a reflection"
    }

    private func destinationLine(for capture: LifeMapStagedCapture) -> String {
        let areaName = capture.lifeAreaTemplateID.flatMap { id in
            StarterWorkspaceCatalog.allLifeAreas.first { $0.id == id }?.name
        }
        let destination = capture.kind == .task ? "Task" : "Journal"
        return [destination, areaName].compactMap { $0 }.joined(separator: " · ")
    }

    private func kindPicker(selected: LifeMapCaptureKind) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(LifeWeaveOnboardingModel.offeredCaptureKinds, id: \.id) { kind in
                LifeWeaveChip(
                    title: kind == .task ? "Task" : "Journal",
                    isSelected: selected == kind
                ) {
                    model.keepCapture(kind: kind, areaTemplateID: model.draft.stagedCapture?.lifeAreaTemplateID)
                }
                .accessibilityIdentifier(LifeWeaveAccessibilityID.captureKind(kind.id))
            }
        }
    }
}
