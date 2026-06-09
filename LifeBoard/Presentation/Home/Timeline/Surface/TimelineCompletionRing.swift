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
        Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(color)
            .symbolRenderingMode(.hierarchical)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}
