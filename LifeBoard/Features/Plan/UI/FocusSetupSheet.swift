import SwiftUI
import LifeBoardDomain
import UIKit

struct FocusSetupContext: Identifiable {
    let id = UUID()
    var taskID: UUID?
    var timeBlockID: UUID?
    var title: String
    var suggestedDuration: TimeInterval
    var subtaskID: UUID?
}

enum FocusSetupMode: String, CaseIterable, Identifiable {
    case countdown = "Countdown"
    case stopwatch = "Stopwatch"
    case pomodoro = "Pomodoro"
    case openEnded = "Open-ended"

    var id: String { rawValue }
}

struct FocusSetupSheet: View {
    let context: FocusSetupContext
    let onCancel: () -> Void
    let onStart: (FocusMode, String) -> Void

    @State private var mode: FocusSetupMode = .countdown
    @State private var countdownMinutes: Int
    @State private var pomodoroFocusMinutes = 25
    @State private var pomodoroBreakMinutes = 5
    @State private var pomodoroRounds = 4
    @State private var intention = ""
    @State private var selectedPresetID: String?
    @State private var presetBloom = 0
    private let presets = WorkspacePreferencesStore.shared.load().focusPresets

    init(
        context: FocusSetupContext,
        onCancel: @escaping () -> Void,
        onStart: @escaping (FocusMode, String) -> Void
    ) {
        self.context = context
        self.onCancel = onCancel
        self.onStart = onStart
        _countdownMinutes = State(
            initialValue: max(5, Int((context.suggestedDuration / 60).rounded()))
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(context.title)
                        .lifeboardFont(.title2)

                    // Presets first: one tap fills the rhythm below. The rail and
                    // steppers stay for anyone who wants to tune this session.
                    presetRow

                    // Was `.pickerStyle(.segmented)`, the stock grey segmented
                    // control. `OptionRail` is the design system's equivalent and
                    // keeps the semantics: one selection, per-value accessibility
                    // identifiers, and reflow at accessibility text sizes.
                    OptionRail(
                        "Focus mode",
                        selection: $mode,
                        values: Array(FocusSetupMode.allCases),
                        identifierPrefix: "focusSetupSheet.focusMode",
                        title: { $0.rawValue }
                    )
                    .accessibilityIdentifier("plan.focus.setup.mode")

                    modeControls

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Goal (optional)", text: $intention, prompt: Text("Goal (optional)").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.plain)
                            // Clay well, not the system rounded border: that drew a pure white
                            // box on warm paper and a pure black one in dark appearance.
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
                            .accessibilityIdentifier("plan.focus.setup.intention")
                    }

                    Button {
                        onStart(resolvedMode, intention)
                    } label: {
                        Label(startTitle, systemImage: "play.fill")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.lifeBoardPrimaryCompact)
                    .accessibilityIdentifier("plan.focus.setup.start")
                }
                .padding(20)
            }
            .background(Color.lifeboard(.bgCanvas).ignoresSafeArea())
            .navigationTitle("Start focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .frame(minHeight: 44)
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .escapeCancels(perform: onCancel)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var presetRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(presets) { preset in
                    let isSelected = selectedPresetID == preset.id
                    Button {
                        apply(preset)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(preset.name).font(.subheadline.weight(.semibold))
                                Text(preset.summary)
                                    .font(.caption)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                        } icon: {
                            Image(systemName: preset.systemImage)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .background(
                        (isSelected ? Color(SemanticColorTokens.foundationSurfaceSelected) : Color(SemanticColorTokens.foundationSurfaceRecessed)).opacity(isSelected ? 1 : 0.6),
                        in: Capsule()
                    )
                    .overlay {
                        if isSelected {
                            Capsule().strokeBorder(Color(SemanticColorTokens.foundationApricotAccent), lineWidth: 1.5)
                        }
                    }
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    .accessibilityLabel("\(preset.name), \(preset.summary)")
                    .accessibilityIdentifier("plan.focus.setup.preset.\(preset.id)")
                }
            }
        }
        .scrollIndicators(.hidden)
        .lifeboardClayPressBloom(trigger: presetBloom)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.focus.setup.presets")
    }

    /// A preset fills the controls; it does not lock them.
    private func apply(_ preset: FocusPreset) {
        Haptic.pick.play()
        presetBloom &+= 1
        selectedPresetID = preset.id
        switch preset.kind {
        case .countdown:
            mode = .countdown
            countdownMinutes = preset.minutes
        case .stopwatch:
            mode = .stopwatch
        case .pomodoro:
            mode = .pomodoro
            pomodoroFocusMinutes = preset.minutes
            pomodoroBreakMinutes = preset.breakMinutes
            pomodoroRounds = preset.rounds
        case .openEnded:
            mode = .openEnded
        }
    }

    @ViewBuilder
    private var modeControls: some View {
        switch mode {
        case .countdown:
            Stepper(value: $countdownMinutes, in: 5...240, step: 5) {
                settingLabel("Duration", value: LifeBoardDuration.text(minutes: countdownMinutes))
            }
            .frame(minHeight: 44)
        case .stopwatch:
            settingExplanation(
                title: String(localized: "Counts up"),
                detail: String(localized: "Stop when you’re done."),
                symbol: "stopwatch"
            )
        case .pomodoro:
            VStack(spacing: 12) {
                Stepper(value: $pomodoroFocusMinutes, in: 5...90, step: 5) {
                    settingLabel("Focus", value: LifeBoardDuration.text(minutes: pomodoroFocusMinutes))
                }
                Stepper(value: $pomodoroBreakMinutes, in: 1...30) {
                    settingLabel("Rest", value: LifeBoardDuration.text(minutes: pomodoroBreakMinutes))
                }
                Stepper(value: $pomodoroRounds, in: 1...8) {
                    settingLabel("Rounds", value: "\(pomodoroRounds)")
                }
            }
            .frame(minHeight: 44)
        case .openEnded:
            settingExplanation(
                title: String(localized: "No timer"),
                detail: String(localized: "Timer hidden while you work."),
                symbol: "infinity"
            )
        }
    }

    private var resolvedMode: FocusMode {
        switch mode {
        case .countdown:
            .countdown(duration: TimeInterval(countdownMinutes * 60))
        case .stopwatch:
            .stopwatch
        case .pomodoro:
            .pomodoro(
                focus: TimeInterval(pomodoroFocusMinutes * 60),
                breakDuration: TimeInterval(pomodoroBreakMinutes * 60),
                rounds: pomodoroRounds
            )
        case .openEnded:
            .openEnded
        }
    }

    private var startTitle: String {
        switch mode {
        case .countdown: String(localized: "Start \(LifeBoardDuration.text(minutes: countdownMinutes))")
        case .stopwatch: String(localized: "Start stopwatch")
        case .pomodoro: String(localized: "Start Pomodoro")
        case .openEnded: String(localized: "Start focus")
        }
    }

    private func settingLabel(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                .monospacedDigit()
        }
    }

    private func settingExplanation(title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 32, height: 32)
                .background(
                    Color(SemanticColorTokens.foundationSageAccent).opacity(0.16),
                    in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
        }
        .frame(minHeight: 52)
    }
}
