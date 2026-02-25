import SwiftUI

struct QuietHoursTimeBar: View {
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int

    private let barHeight: CGFloat = 8

    private var startFraction: CGFloat {
        (CGFloat(startHour) + CGFloat(startMinute) / 60.0) / 24.0
    }

    private var endFraction: CGFloat {
        (CGFloat(endHour) + CGFloat(endMinute) / 60.0) / 24.0
    }

    private var wrapsAround: Bool {
        startFraction >= endFraction
    }

    var body: some View {
        VStack(spacing: TaskerSwiftUITokens.spacing.s4) {
            // Time labels
            HStack {
                Text(timeString(hour: startHour, minute: startMinute))
                    .font(.tasker(.caption2))
                    .foregroundColor(.tasker(.textSecondary))
                Spacer()
                Text(timeString(hour: endHour, minute: endMinute))
                    .font(.tasker(.caption2))
                    .foregroundColor(.tasker(.textSecondary))
            }

            // Visual bar
            GeometryReader { geometry in
                let width = geometry.size.width

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.tasker.surfaceTertiary)
                        .frame(height: barHeight)

                    // Active range
                    if wrapsAround {
                        // Two segments for midnight wrap
                        // Segment 1: start → end of day
                        Capsule()
                            .fill(Color.tasker.accentMuted)
                            .frame(width: max(0, width * (1.0 - startFraction)), height: barHeight)
                            .offset(x: width * startFraction)

                        // Segment 2: start of day → end
                        Capsule()
                            .fill(Color.tasker.accentMuted)
                            .frame(width: max(0, width * endFraction), height: barHeight)
                    } else {
                        // Single continuous segment
                        Capsule()
                            .fill(Color.tasker.accentMuted)
                            .frame(width: max(0, width * (endFraction - startFraction)), height: barHeight)
                            .offset(x: width * startFraction)
                    }
                }
            }
            .frame(height: barHeight)

            // Hour markers
            HStack {
                Text("12 AM")
                    .font(.system(size: 9))
                    .foregroundColor(.tasker(.textQuaternary))
                Spacer()
                Text("12 PM")
                    .font(.system(size: 9))
                    .foregroundColor(.tasker(.textQuaternary))
                Spacer()
                Text("12 AM")
                    .font(.system(size: 9))
                    .foregroundColor(.tasker(.textQuaternary))
            }
        }
    }

    private func timeString(hour: Int, minute: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
