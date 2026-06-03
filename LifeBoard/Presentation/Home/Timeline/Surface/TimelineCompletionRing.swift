import SwiftUI

struct TimelineCompletionRing: View {
    let color: Color
    let isCompleted: Bool
    let isInteractive: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Group {
            if isInteractive {
                Button(action: action) {
                    ringBody
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityValue(isCompleted ? "Completed" : "Not completed")
            } else {
                ringBody
                    .accessibilityHidden(true)
            }
        }
    }

    var ringBody: some View {
        ZStack {
            Circle()
                .strokeBorder(color.opacity(0.82), lineWidth: 2.2)
                .background(
                    Circle()
                        .fill(isCompleted ? color.opacity(0.16) : Color.clear)
                )
                .frame(width: 28, height: 28)
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
    }
}
