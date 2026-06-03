import SwiftUI

struct TimelinePlacementDock: View {
    let candidate: TimelinePlacementCandidate
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.lifeboardScrollOptimizedRendering) var scrollOptimizedRendering
    @State var isDragging = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .accessibilityHidden(true)
            Text(candidate.title)
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("Drag to place")
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isDragging ? Color.lifeboard.accentWash.opacity(0.9) : Color.lifeboard.surfaceSecondary, in: Capsule())
        .overlay(
            Capsule()
                .stroke(isDragging ? Color.lifeboard.accentPrimary.opacity(0.42) : Color.lifeboard.strokeHairline.opacity(0.7), lineWidth: 1)
        )
        .scaleEffect(isDragging && reduceMotion == false ? 1.018 : 1)
        .shadow(
            color: Color.lifeboard.accentPrimary.opacity(isDragging && scrollOptimizedRendering == false ? 0.16 : 0),
            radius: isDragging && scrollOptimizedRendering == false ? 14 : 0,
            x: 0,
            y: 8
        )
        .draggable(candidate.taskID.uuidString)
        .simultaneousGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { _ in
                    guard isDragging == false else { return }
                    withAnimation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.feedbackFast) {
                        isDragging = true
                    }
                    LifeBoardFeedback.light()
                }
                .onEnded { _ in
                    withAnimation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.feedbackFast) {
                        isDragging = false
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(candidate.title), drag to place")
        .accessibilityIdentifier("home.needsReplan.placementDock")
    }
}
