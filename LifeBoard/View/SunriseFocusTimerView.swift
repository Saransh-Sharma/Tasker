import SwiftUI
import UIKit

/// Full-screen focus session timer using Sunrise focus role styling.
public struct SunriseFocusTimerView: View {

    let taskTitle: String?
    let taskPriority: String?
    let targetDurationSeconds: Int
    let onComplete: (Int) -> Void
    let onCancel: () -> Void

    @State private var elapsedSeconds: Int = 0
    @State private var isRunning: Bool = true
    @State private var timer: Timer?
    @State private var completionSent: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let focusStyle = LBColorTokens.role(.focus)
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    private var remainingSeconds: Int {
        max(0, targetDurationSeconds - elapsedSeconds)
    }

    private var progress: CGFloat {
        guard targetDurationSeconds > 0 else { return 0 }
        return min(1.0, CGFloat(elapsedSeconds) / CGFloat(targetDurationSeconds))
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
                Button("Close", systemImage: "xmark", action: onCancel)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .frame(width: 44, height: 44)
                    .background(LBColorTokens.glassStrong, in: Circle())
                    .overlay(Circle().stroke(LBColorTokens.glassBorder, lineWidth: 1))
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, spacing.screenHorizontal)

            Spacer()

            ZStack {
                Circle()
                    .stroke(focusStyle.border.opacity(0.56), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        focusStyle.base,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)

                VStack(spacing: 8) {
                    Text(timeString)
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                        .foregroundStyle(LBColorTokens.navy)
                        .monospacedDigit()
                    Text(isRunning ? "Protected focus" : "Paused")
                        .font(.lifeboard(.callout))
                        .fontDesign(.rounded)
                        .foregroundStyle(LBColorTokens.navyMuted)
                }
            }
            .frame(width: 248, height: 248)
            .padding(20)
            .background(focusStyle.softSurface.opacity(0.72), in: Circle())
            .overlay(Circle().stroke(focusStyle.border, lineWidth: 1))

            if let title = taskTitle {
                VStack(spacing: spacing.s4) {
                    Text(title)
                        .font(.lifeboard(.headline))
                        .fontDesign(.rounded)
                        .foregroundStyle(LBColorTokens.navy)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)

                    if let priority = taskPriority {
                        Text(priority)
                            .font(.lifeboard(.caption1))
                            .fontDesign(.rounded)
                            .foregroundStyle(LBColorTokens.navyMuted)
                    }
                }
                .padding(.horizontal, spacing.screenHorizontal)
            }

            Spacer()

            VStack(spacing: spacing.s12) {
                Button(isRunning ? "Pause focus" : "Resume focus", systemImage: isRunning ? "pause.fill" : "play.fill") {
                    isRunning ? pauseTimer() : resumeTimer()
                }
                .font(.lifeboard(.bodyEmphasis))
                .fontDesign(.rounded)
                .foregroundStyle(focusStyle.deep)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(LBColorTokens.glassStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(focusStyle.border, lineWidth: 1))

                Button("Finish focus", systemImage: "checkmark") {
                    completeIfNeeded()
                }
                .font(.lifeboard(.bodyEmphasis))
                .fontDesign(.rounded)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    LinearGradient(colors: LBColorTokens.actionGradient(for: .focus), startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .padding(.horizontal, spacing.screenHorizontal)
            .padding(.bottom, spacing.s16)
        }
        .background(
            LinearGradient(
                colors: [LBColorTokens.coolCanvas, focusStyle.softSurface.opacity(0.64), LBColorTokens.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus timer. \(remainingSeconds / 60) minutes remaining.")
    }

    // MARK: - Timer Control

    private func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                elapsedSeconds += 1
                if elapsedSeconds >= targetDurationSeconds {
                    LifeBoardFeedback.success()
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
