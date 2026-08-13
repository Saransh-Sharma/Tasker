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
struct JournalMoodCaptureView: View {
    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store: TrackFoundationStore
    @State private var draftMood: Mood = .none
    @State private var stage: Stage = .mood
    @State private var energy = 3.0
    @State private var includesEnergy = false
    @State private var isSaving = false

    private enum Stage { case mood, energy }

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
        let palette = DaypartTokens.palette(for: preferences.resolvedDaypart())
        let theme = MoodDialTheme.sunriseGlass(palette: palette)

        ZStack(alignment: .top) {
            switch stage {
            case .mood:
                MoodDialView(selectedMood: $draftMood)
                    .transition(.opacity)
            case .energy:
                energyStage(palette: palette)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            header(palette: palette)
        }
        .background(
            LinearGradient(
                colors: [theme.backgroundTop, theme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .environment(\.moodDialTheme, theme)
        .environment(\.journalHaptics, JournalHaptics())
        .interactiveDismissDisabled()
        .accessibilityIdentifier("journalParity.moodCapture")
        .onAppear { MoodAssetPreheater.preheatMoodAssets() }
    }

    private func header(palette: DaypartPalette) -> some View {
        HStack {
            Button("Cancel") { dismiss() }
                .lifeboardFont(.headline)
                .foregroundStyle(palette.color(for: .foreground))
                .frame(minWidth: 76, minHeight: 44)
                .background(.regularMaterial, in: Capsule())
                .accessibilityIdentifier("journalParity.moodCapture.cancel")

            Spacer()

            Button(stage == .mood ? "Next" : (isSaving ? "Saving…" : "Save")) {
                advance()
            }
            .lifeboardFont(.headline)
            .foregroundStyle(Color(SemanticColorTokens.foundationOnCelestialAccent))
            .frame(minWidth: 84, minHeight: 44)
            .background(palette.color(for: .celestialCore), in: Capsule())
            .disabled(isSaving)
            .accessibilityIdentifier("journalParity.moodCapture.confirm")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func advance() {
        switch stage {
        case .mood:
            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
                stage = .energy
            }
        case .energy:
            save()
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let value = MoodEnergyCheckInValue(
            mood: draftMood.lifeBoardJournalMood,
            energy: includesEnergy ? Int(energy.rounded()) : nil
        )
        Task {
            await store.saveMood(value)
            await MainActor.run {
                HapticFeedback.success()
                dismiss()
            }
        }
    }

    private func energyStage(palette: DaypartPalette) -> some View {
        VStack(spacing: 24) {
            Spacer()

            draftMood.largeImage
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 132, height: 132)
                .accessibilityHidden(true)

            Text(includesEnergy ? energyLabel : "Energy is optional")
                .lifeboardFont(.metric)
                .foregroundStyle(palette.color(for: .foreground))
                .contentTransition(.opacity)

            VStack(spacing: 18) {
                Toggle("Add an energy signal", isOn: $includesEnergy.animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)))
                    .lifeboardFont(.headline)

                if includesEnergy {
                    Slider(value: $energy, in: 1...5, step: 1) {
                        Text("Energy")
                    } minimumValueLabel: {
                        Image(systemName: "battery.25")
                    } maximumValueLabel: {
                        Image(systemName: "battery.100")
                    }
                    .tint(palette.color(for: .celestialCore))
                    .accessibilityValue(energyLabel)
                    .onChange(of: energy) {
                        HapticFeedback.selection()
                    }
                }
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 24)

            Text("This records your signal. LifeBoard does not assign a clinical interpretation.")
                .font(.footnote)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 64)
    }

    private var energyLabel: String {
        switch Int(energy.rounded()) {
        case 1: return "Very low energy"
        case 2: return "Low energy"
        case 3: return "Steady energy"
        case 4: return "High energy"
        default: return "Very high energy"
        }
    }
}
