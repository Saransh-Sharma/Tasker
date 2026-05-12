import SwiftUI

/// Full-screen focus session timer with XP tracking.
public struct FocusTimerView: View {

    let taskTitle: String?
    let taskPriority: String?
    let targetDurationSeconds: Int
    let onComplete: (Int) -> Void
    let onCancel: () -> Void

    @State private var elapsedSeconds: Int = 0
    @State private var isRunning: Bool = true
    @State private var timer: Timer?
    @State private var completionSent: Bool = false

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    private var remainingSeconds: Int {
        max(0, targetDurationSeconds - elapsedSeconds)
    }

    private var progress: CGFloat {
        guard targetDurationSeconds > 0 else { return 0 }
        return min(1.0, CGFloat(elapsedSeconds) / CGFloat(targetDurationSeconds))
    }

    private var currentXP: Int {
        XPCalculationEngine.focusSessionXP(durationSeconds: elapsedSeconds)
    }

    private var timeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var body: some View {
        VStack(spacing: spacing.s16) {
            HStack {
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.lifeboard.textTertiary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, spacing.screenHorizontal)

            Spacer()

            // Timer Ring
            ZStack {
                Circle()
                    .stroke(Color.lifeboard.accentSecondaryMuted, lineWidth: GamificationTokens.focusTimerRingWidth)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [Color.lifeboard.accentPrimary, Color.lifeboard.accentSecondary]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: GamificationTokens.focusTimerRingWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                Text(timeString)
                    .font(.system(size: GamificationTokens.focusTimerFontSize, weight: .light, design: .rounded))
                    .foregroundColor(Color.lifeboard.textPrimary)
                    .monospacedDigit()
            }
            .frame(width: GamificationTokens.focusTimerSize, height: GamificationTokens.focusTimerSize)

            // Task Info
            if let title = taskTitle {
                VStack(spacing: spacing.s4) {
                    Text(title)
                        .font(.lifeboard(.headline))
                        .foregroundColor(Color.lifeboard.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if let priority = taskPriority {
                        Text(priority)
                            .font(.lifeboard(.caption1))
                            .foregroundColor(Color.lifeboard.textTertiary)
                    }
                }
            }

            Spacer()

            // Controls
            VStack(spacing: spacing.s12) {
                Button(action: {
                    if isRunning {
                        pauseTimer()
                    } else {
                        resumeTimer()
                    }
                }) {
                    Text(isRunning ? "Pause" : "Resume")
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundColor(Color.lifeboard.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.lifeboard.accentPrimary, lineWidth: 1.5)
                        )
                }

                Button(action: {
                    completeIfNeeded()
                }) {
                    Text("Complete Session")
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundColor(Color.lifeboard.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lifeboard.accentPrimary)
                        )
                }

                // XP earned so far
                Text("+\(currentXP) XP earned so far")
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textTertiary)
            }
            .padding(.horizontal, spacing.screenHorizontal)
            .padding(.bottom, spacing.s16)
        }
        .background(Color.lifeboard.bgCanvas.ignoresSafeArea())
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus timer. \(remainingSeconds / 60) minutes remaining. \(currentXP) XP earned.")
    }

    // MARK: - Timer Control

    private func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                elapsedSeconds += 1
                if elapsedSeconds >= targetDurationSeconds {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    completeIfNeeded()
                }
            }
        }
    }

    private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func resumeTimer() {
        startTimer()
    }

    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func completeIfNeeded() {
        guard !completionSent else { return }
        completionSent = true
        stopTimer()
        onComplete(elapsedSeconds)
    }
}
