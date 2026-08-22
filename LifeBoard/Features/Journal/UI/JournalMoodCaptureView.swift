//
//  JournalMoodCaptureView.swift
//  LifeBoard
//
//  Phase V journal parity: mood capture built on the shared MoodDialKit dial
//  (the same interaction OffRecord ships), themed for Sunrise Glass with a
//  daypart-adaptive palette and LifeBoard's optional energy stage. Persists
//  through the existing TrackFoundationStore mood pipeline.
//

import SwiftUI
import LifeBoardDomain
import JournalFeature

// MARK: - Mood mapping

extension Mood {
    /// Bridges the shared dial vocabulary onto LifeBoard's persistence enum.
    var lifeBoardJournalMood: JournalMood {
        switch self {
        case .none: return .none
        case .happy: return .happy
        case .calm: return .calm
        case .grateful: return .grateful
        case .excited: return .excited
        case .tired: return .tired
        case .anxious: return .anxious
        case .sad: return .sad
        case .angry: return .angry
        }
    }

    init(lifeBoardJournalMood: JournalMood) {
        switch lifeBoardJournalMood {
        case .none: self = .none
        case .happy: self = .happy
        case .calm: self = .calm
        case .grateful: self = .grateful
        case .excited: self = .excited
        case .tired: self = .tired
        case .anxious: self = .anxious
        case .sad: self = .sad
        case .angry: self = .angry
        }
    }
}

// MARK: - Sunrise Glass dial theme

extension MoodDialTheme {
    /// Daypart-adaptive Sunrise Glass identity for the shared mood dial.
    static func sunriseGlass(palette: DaypartPalette) -> MoodDialTheme {
        MoodDialTheme(
            backgroundTop: palette.color(for: .canvas),
            backgroundBottom: palette.color(for: .canvasSecondary),
            accent: palette.color(for: .celestialCore),
            accentContrast: .white,
            surface: palette.color(for: .canvas),
            heading: palette.color(for: .foreground),
            textSecondary: palette.color(for: .foregroundSecondary),
            textTertiary: palette.color(for: .foregroundSecondary).opacity(0.78),
            titleFont: .system(size: 30, weight: .bold, design: .rounded),
            labelFont: .system(size: 17, weight: .semibold, design: .rounded),
            captionFont: .system(size: 14, weight: .regular, design: .rounded),
            segmentColor: { mood in palette.moodSegmentColor(for: mood) },
            moodAccent: { mood in palette.moodSegmentColor(for: mood) }
        )
    }
}

extension DaypartPalette {
    /// Mood segment tints tuned per daypart so the dial sits inside the
    /// atmosphere instead of importing OffRecord's pastel wheel wholesale.
    func moodSegmentColor(for mood: Mood) -> Color {
        let base: Color
        switch mood {
        case .none: base = color(for: .coolMist)
        case .happy: base = color(for: .celestialCore)
        case .calm: base = color(for: .layerOne)
        case .grateful: base = color(for: .decorativeHighlight)
        case .excited: base = color(for: .celestialPrimary)
        case .tired: base = color(for: .layerTwo)
        case .anxious: base = color(for: .coolMist)
        case .sad: base = color(for: .layerTwo)
        case .angry: base = color(for: .celestialPrimary)
        }
        return base
    }
}

// MARK: - Haptics adapter

struct JournalHaptics: JournalHapticsProviding {
    func selectionChanged() { Task { @MainActor in HapticFeedback.selection() } }
    func moodSelected() { Task { @MainActor in HapticFeedback.light() } }
    func buttonTap() { Task { @MainActor in HapticFeedback.light() } }
    func recordingStarted() { Task { @MainActor in HapticFeedback.medium() } }
    func recordingStopped() { Task { @MainActor in HapticFeedback.light() } }
    func entrySaved() { Task { @MainActor in HapticFeedback.success() } }
    func warning() { Task { @MainActor in HapticFeedback.warning() } }
    func error() { Task { @MainActor in HapticFeedback.error() } }
}

// MARK: - Capture view

/// Two-stage mood → optional energy capture presented from the capture orb.
///
/// Migrated onto the composer kit. The dial stage uses `contentFit: .filling`
/// because `MoodDialView` sizes its wheel from a `GeometryReader`, which gets an
/// undefined height inside the scaffold's `ScrollView` — so it keeps the
/// composer's chrome (editor presentation, warm canvas, cancel item, commit bar,
/// privacy redaction) without the scroll container that would collapse it. The
/// energy stage owns its own scroll view around ordinary clay sections.
struct JournalMoodCaptureView: View {
    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store: TrackFoundationStore
    @State private var draftMood: Mood = .none
    @State private var stage: Stage = .mood
    @State private var energy = 3
    @State private var includesEnergy = false
    @State private var commitPhase: LifeBoardComposerPhase = .idle
    @State private var successTrigger = 0

    private typealias Stage = JournalMoodCaptureStageKind

    init(
        repository: CoreDataTrackFoundationRepository,
        phaseIIRepository: any PhaseIIRepository
    ) {
        _store = State(initialValue: TrackFoundationStore(
            repository: repository,
            phaseIIRepository: phaseIIRepository
        ))
    }

    var body: some View {
        let palette = DaypartTokens.appearancePalette(for: preferences.resolvedDaypart(), colorScheme: colorScheme)

        ComposerScaffold(
            title: stage == .mood ? "How are you?" : "Energy",
            titleDisplayMode: .inline,
            identifier: "journalParity.moodCapture",
            contentFit: .filling,
            cancelIdentifier: "journalParity.moodCapture.cancel"
        ) {
            JournalMoodCaptureStage(
                stage: stage,
                draftMood: $draftMood,
                includesEnergy: $includesEnergy,
                energy: $energy,
                palette: palette
            )
        } commit: {
            JournalMoodCaptureCommitBar(
                stage: stage,
                commitPhase: commitPhase,
                onNext: advance,
                onSave: save
            )
        }
        .lifeboardCompletionBurst(trigger: successTrigger)
        .interactiveDismissDisabled()
        .onAppear { MoodAssetPreheater.preheatMoodAssets() }
    }

    private func advance() {
        withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
            stage = .energy
        }
    }

    private func save() {
        guard case .running = commitPhase else {
            commitPhase = .running(progress: nil)
            let value = MoodEnergyCheckInValue(
                mood: draftMood.lifeBoardJournalMood,
                energy: includesEnergy ? energy : nil
            )
            Task {
                if await store.saveMood(value) {
                    commitPhase = .success(receipt: ComposerReceipt())
                    successTrigger &+= 1
                    HapticFeedback.success()
                    dismiss()
                } else {
                    commitPhase = .recoverableFailure(.init(
                        message: "The check-in could not be saved.",
                        recovery: .retry
                    ))
                }
            }
            return
        }
    }
}

// MARK: - Stages

private struct JournalMoodCaptureStage: View {
    let stage: JournalMoodCaptureStageKind
    @Binding var draftMood: Mood
    @Binding var includesEnergy: Bool
    @Binding var energy: Int
    let palette: DaypartPalette

    var body: some View {
        switch stage {
        case .mood:
            MoodDialView(selectedMood: $draftMood)
                .environment(\.moodDialTheme, MoodDialTheme.sunriseGlass(palette: palette))
                .environment(\.journalHaptics, JournalHaptics())
                // The dial paints its own full-bleed scene. Without this the
                // commit bar's `safeAreaInset` stops that scene short of the
                // bottom edge and the composer's warm canvas shows through the
                // glass as a light band under a dark screen.
                .ignoresSafeArea()
                .transition(.opacity)
        case .energy:
            JournalMoodEnergyStage(
                draftMood: draftMood,
                includesEnergy: $includesEnergy,
                energy: $energy,
                palette: palette
            )
            .transition(.opacity)
        }
    }
}

/// Mirrors `JournalMoodCaptureView.Stage`; a nested private enum cannot be a
/// parameter of a sibling struct.
enum JournalMoodCaptureStageKind { case mood, energy }

private struct JournalMoodEnergyStage: View {
    let draftMood: Mood
    @Binding var includesEnergy: Bool
    @Binding var energy: Int
    let palette: DaypartPalette

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                draftMood.largeImage
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .accessibilityHidden(true)

                JournalMoodEnergySection(includesEnergy: $includesEnergy, energy: $energy)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }
}

private struct JournalMoodEnergySection: View {
    @Binding var includesEnergy: Bool
    @Binding var energy: Int

    var body: some View {
        ComposerSection(
            "Energy",
            footer: "This records your signal. LifeBoard does not assign a clinical interpretation."
        ) {
            Toggle("Add an energy signal", isOn: $includesEnergy)
                .toggleStyle(.lifeBoardClay)
                .accessibilityIdentifier("journalParity.moodCapture.includesEnergy")
            if includesEnergy {
                // A slider was trying to be this: an ordered 1-5 magnitude with
                // a caption, which is exactly what a bead run is for. The
                // vocabulary matches `MoodEnergySection` in Track so the two
                // mood composers stop describing one scale two different ways.
                BeadStepper(
                    "Energy",
                    value: $energy,
                    in: 1...5,
                    beadSymbol: "bolt.fill",
                    caption: Self.caption,
                    identifier: "journalParity.moodCapture.energy"
                )
            }
        }
    }

    private static func caption(_ level: Int) -> String {
        switch level {
        case 1: "Running on empty"
        case 2: "Low"
        case 3: "Steady"
        case 4: "Good"
        default: "Full tank"
        }
    }
}

// MARK: - Commit

private struct JournalMoodCaptureCommitBar: View {
    let stage: JournalMoodCaptureStageKind
    let commitPhase: LifeBoardComposerPhase
    let onNext: () -> Void
    let onSave: () -> Void

    var body: some View {
        switch stage {
        case .mood:
            VStack(spacing: 8) {
                Button("Next", action: onNext)
                    .buttonStyle(.lifeBoardPrimary)
                    .accessibilityIdentifier("journalParity.moodCapture.confirm")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                Color.clear
                    .lifeBoardSystemGlass(.regular, in: Rectangle())
                    .ignoresSafeArea(edges: .bottom)
            }
        case .energy:
            // A real commit control: idle → running → success, driven by whether
            // the check-in actually persisted. The previous "Saving…" was a
            // title swap that reported nothing.
            ComposerCommitBar(
                title: "Save check-in",
                phase: commitPhase,
                identifier: "journalParity.moodCapture.confirm",
                action: onSave
            )
        }
    }
}
