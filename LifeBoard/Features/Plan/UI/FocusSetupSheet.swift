import SwiftUI
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
                    VStack(alignment: .leading, spacing: 5) {
                        Text(context.title)
                            .font(.title2.weight(.semibold))
                        Text("Choose the rhythm that fits this moment.")
                            .font(.subheadline)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }

                    Picker("Focus mode", selection: $mode) {
                        ForEach(FocusSetupMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("plan.focus.setup.mode")

                    modeControls

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Intention")
                            .font(.subheadline.weight(.semibold))
                        TextField("What would make this session enough?", text: $intention, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("plan.focus.setup.intention")
                    }

                    Button {
                        onStart(resolvedMode, intention)
                    } label: {
                        Label(startTitle, systemImage: "play.fill")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
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
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var modeControls: some View {
        switch mode {
        case .countdown:
            Stepper(value: $countdownMinutes, in: 5...240, step: 5) {
                settingLabel("Duration", value: "\(countdownMinutes) min")
            }
            .frame(minHeight: 44)
        case .stopwatch:
            settingExplanation(
                title: "Count upward",
                detail: "Elapsed time stays primary. Stop whenever the work reaches a natural edge.",
                symbol: "stopwatch"
            )
        case .pomodoro:
            VStack(spacing: 12) {
                Stepper(value: $pomodoroFocusMinutes, in: 5...90, step: 5) {
                    settingLabel("Focus", value: "\(pomodoroFocusMinutes) min")
                }
                Stepper(value: $pomodoroBreakMinutes, in: 1...30) {
                    settingLabel("Rest", value: "\(pomodoroBreakMinutes) min")
                }
                Stepper(value: $pomodoroRounds, in: 1...8) {
                    settingLabel("Rounds", value: "\(pomodoroRounds)")
                }
            }
            .frame(minHeight: 44)
        case .openEnded:
            settingExplanation(
                title: "No clock pressure",
                detail: "The timer recedes. This session ends only when you choose Finish, Continue Later, or Abandon.",
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
        case .countdown: "Start \(countdownMinutes)-minute focus"
        case .stopwatch: "Start stopwatch"
        case .pomodoro: "Start Pomodoro"
        case .openEnded: "Begin open-ended focus"
        }
    }

    private func settingLabel(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                .monospacedDigit()
        }
    }

    private func settingExplanation(title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 32, height: 32)
                .background(
                    Color(LifeBoardColorTokens.foundationSageAccent).opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
        }
        .frame(minHeight: 52)
    }
}
