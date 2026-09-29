import SwiftUI

struct EvaInstallStatusView: View {
    let isComplete: Bool
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.lifeboard(.surfaceTertiary), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.04, min(progress, 1)))
                .stroke(
                    LinearGradient(
                        colors: [Color.lifeboard(.accentPrimary), Color.lifeboard(.accentSecondary)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .lifeBoardMotion(.threadAdvance, value: progress)

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .lifeboardFont(.heroDisplay)
                    .foregroundStyle(Color.lifeboard(.statusSuccess))
            } else {
                ZStack {
                    EvaLoopingLottieContainer(size: 92)
                    Circle()
                        .fill(Color.clear)
                        .overlay(
                            Circle()
                                .stroke(Color.lifeboard(.accentMuted).opacity(0.5), lineWidth: 1)
                        )
                }
            }
        }
        .frame(width: 140, height: 140)
    }
}
