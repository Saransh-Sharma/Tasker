import SwiftUI

struct TimelineNowBeadView: View {
    let time: Date
    let railMetrics: TimelineRailMetrics
    let beadX: CGFloat
    let reduceMotion: Bool
    @State var pulseIsExpanded = false

    var body: some View {
        ZStack(alignment: .leading) {
            Text("Now · \(TimelineRailTimeFormatter.railText(for: time, kind: .current))")
                .font(TimelineRailTypography.font(for: .current, isEmphasized: true))
                .monospacedDigit()
                .foregroundStyle(Color.lifeboard.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.lifeboard.surfacePrimary.opacity(0.94), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.lifeboard.accentPrimary.opacity(0.36), lineWidth: 1)
                }
                .offset(x: max(railMetrics.labelLeadingX, beadX - 58), y: -14)

            if TimelineNowBeadPresentation.shouldPulse(reduceMotion: reduceMotion) {
                Circle()
                    .stroke(Color.lifeboard.accentPrimary.opacity(pulseIsExpanded ? 0 : 0.28), lineWidth: 1.4)
                    .frame(width: 25, height: 25)
                    .scaleEffect(pulseIsExpanded ? 1.28 : 1)
                    .offset(x: beadX - 12.5, y: -12.5)
            }

            Circle()
                .fill(Color.lifeboard.accentPrimary.opacity(reduceMotion ? 0.18 : 0.26))
                .frame(width: 24, height: 24)
                .offset(x: beadX - 12, y: -12)

            Circle()
                .fill(Color.lifeboard.accentPrimary)
                .frame(width: 11, height: 11)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.76), lineWidth: 1)
                }
                .offset(x: beadX - 5.5, y: -5.5)
        }
        .frame(height: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current time")
        .accessibilityValue(time.formatted(date: .omitted, time: .shortened))
        .onAppear {
            guard TimelineNowBeadPresentation.shouldPulse(reduceMotion: reduceMotion) else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulseIsExpanded = true
            }
        }
        .onChange(of: reduceMotion) { _, newValue in
            if newValue {
                pulseIsExpanded = false
            } else {
                withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    pulseIsExpanded = true
                }
            }
        }
    }
}
