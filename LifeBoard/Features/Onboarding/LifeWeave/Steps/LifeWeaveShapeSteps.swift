import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// Usual hours, edited from the Ready screen rather than asked.
///
/// Regular weekday hours are the right answer for most people, so the flow
/// assumes them and shows them on the receipt with an Edit link. Presets come
/// first; exact times are one more tap for whoever wants them.
struct LifeWeaveDayShapeStep: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    @State private var showsEditor = false

    var body: some View {
        LifeMapQuestionScaffold(
            title: LifeWeaveCopy.Hours.title,
            support: LifeWeaveCopy.Hours.support
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(LifeWeaveDayShapePreset.allCases.filter { $0 != .custom }, id: \.rawValue) { preset in
                    LifeMapChoiceRow(
                        title: LifeWeaveCopy.Hours.presetTitle(preset),
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
                    Label(
                        showsEditor ? LifeWeaveCopy.Hours.hideHours : LifeWeaveCopy.Hours.editHours,
                        systemImage: "slider.horizontal.3"
                    )
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

    private var editor: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            LifeMapTimeStepper(
                label: LifeWeaveCopy.Hours.start,
                value: model.draft.dayShape.weekdayStartMinute
            ) { minute in
                model.updateDayShape { $0.weekdayStartMinute = minute }
            }
            LifeMapTimeStepper(
                label: LifeWeaveCopy.Hours.end,
                value: model.draft.dayShape.weekdayEndMinute
            ) { minute in
                model.updateDayShape { $0.weekdayEndMinute = minute }
            }
            Toggle(LifeWeaveCopy.Hours.weekends, isOn: Binding(
                get: { model.draft.dayShape.worksWeekends },
                set: { value in model.updateDayShape { $0.worksWeekends = value } }
            ))
            .lifeboardFont(.body)
            .foregroundStyle(Color.lifeboard(.textPrimary))
        }
        .padding(Theme.Spacing.md)
        .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
    }

    /// Derived from the locale and shown as a fact with a way to change it.
    private var weekStartRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(LifeWeaveCopy.Hours.weekStarts(model.draft.dayShape.weekStartsOn.displayTitle))
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
            Button(LifeWeaveCopy.Hours.change) {
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
        guard preset != .flexible, let window = preset.weekdayWindow else { return nil }
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

/// Steppers rather than a slider: 30-minute detents are the real granularity of
/// a working day, and buttons are reachable by Switch Control and VoiceOver
/// without a custom rotor.
///
struct LifeMapTimeStepper: View {
    let label: String
    let value: Int
    let action: (Int) -> Void

    var body: some View {
        VStack(spacing: 7) {
            Text(label)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
            HStack(spacing: Theme.Spacing.sm) {
                Button { action(max(0, value - 30)) } label: {
                    Image(systemName: "minus")
                }
                .accessibilityLabel(String(localized: "\(label) earlier"))
                Text(OnboardingDayShapeDraft.label(forMinute: value))
                    .lifeboardFont(.bodyStrong)
                    .monospacedDigit()
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .frame(minWidth: 74)
                Button { action(min(24 * 60, value + 30)) } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "\(label) later"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm + 2)
        .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
        .accessibilityElement(children: .contain)
        .accessibilityValue(OnboardingDayShapeDraft.label(forMinute: value))
    }
}

/// The hours editor, presented from the Ready screen's receipt.
struct LifeWeaveDayShapeSheet: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LifeWeaveDayShapeStep(model: model)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.lifeboard(.bgCanvas))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LifeWeaveCopy.Dock.done, action: onDone)
                        .accessibilityIdentifier("onboarding.lifeweave.dayshape.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("onboarding.lifeweave.dayshape.sheet")
    }
}

/// The magic moment, and the tutorial.
///
/// One real sentence, interpreted while the user types, correctable in place,
/// and then persisted. That teaches the whole Universal Input contract —
/// natural language becomes structure, nothing saves silently, you can correct
/// it — without a screen explaining any of it.
///
/// Interpretation used to sit behind a "Make sense of this" button, then a
/// "Keep this" button, then "Finish setup": three labels for one intention.
/// A pause in typing now asks for the interpretation, and Save is the only
/// thing to press.
struct LifeWeaveCaptureStep: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    let pillNamespace: Namespace.ID
    @FocusState private var isFocused: Bool

    var body: some View {
        LifeMapQuestionScaffold(
            title: LifeWeaveCopy.Capture.title,
            support: LifeWeaveCopy.Capture.support
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                TextField(
                    LifeWeaveCopy.Capture.placeholder(primaryAreaTemplateID: model.draft.primaryLifeAreaTemplateID),
                    text: $model.captureText,
                    axis: .vertical
                )
                .lifeboardFont(.body)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($isFocused)
                .frame(minHeight: 28)
                .padding(Theme.Spacing.md)
                // The padded well is what people aim at, but padding is not
                // interactive; without this only the text line itself takes a
                // tap, which is under the 44-point floor.
                .contentShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .onTapGesture { isFocused = true }
                .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
                .matchedGeometryEffect(id: LifeWeaveCaptureStep.pillID, in: pillNamespace, isSource: true)
                .accessibilityIdentifier(LifeWeaveAccessibilityID.captureField)
                .onChange(of: model.captureText) { _, _ in
                    model.scheduleCaptureInterpretation()
                }

                LifeWeaveCaptureProposalRow(model: model)
            }
            .lifeBoardMotion(.contentInsertion, value: model.draft.stagedCapture?.text)
            .lifeBoardMotion(.contentInsertion, value: model.isResolvingCapture)
        }
        .onAppear {
            // Straight to the keyboard: the question is "what's on your mind?",
            // and making somebody tap before they can answer is a small no.
            if model.draft.isCaptureResolved == false { isFocused = true }
        }
    }

    /// Shared with the Ready screen's first receipt row, so the sentence the
    /// user typed visibly travels to where it was kept.
    static let pillID = "onboarding.capture.pill"
}

/// "Save as Task · Health & Self", in the user's words.
///
/// No headline claiming what the sentence "looks like", and no confidence
/// number: the kind control is simply there, preset to the best guess and
/// editable until Save.
private struct LifeWeaveCaptureProposalRow: View {
    @ObservedObject var model: LifeWeaveOnboardingModel

    private var areaName: String? {
        model.draft.stagedCapture?.lifeAreaTemplateID.flatMap { id in
            StarterWorkspaceCatalog.allLifeAreas.first { $0.id == id }?.name
        }
    }

    var body: some View {
        if model.isResolvingCapture, model.draft.stagedCapture == nil {
            HStack(spacing: Theme.Spacing.xs) {
                EvaMascotView(placement: .onboardingProcessing, size: .chip)
                Text(LifeWeaveCopy.Capture.reading)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }
            .transition(.opacity)
            .accessibilityElement(children: .combine)
        } else if let capture = model.draft.stagedCapture {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(LifeWeaveCopy.Capture.saveAs)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                    if let areaName {
                        Text("· \(areaName)")
                            .lifeboardFont(.caption1)
                            .foregroundStyle(Color.lifeboard(.textTertiary))
                            .lineLimit(1)
                    }
                }
                LensPicker(
                    LifeWeaveCopy.Capture.saveAs,
                    selection: Binding(
                        get: { capture.kind == .note ? .journal : capture.kind },
                        set: { model.chooseCaptureKind($0) }
                    ),
                    values: LifeWeaveOnboardingModel.offeredCaptureKinds,
                    identifierPrefix: "onboarding.lifeweave.capture.kind",
                    title: LifeWeaveCopy.Capture.kindTitle,
                    identifier: \.id
                )
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
