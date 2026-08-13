import SwiftUI
import UIKit

/// A read-only calendar commitment drawn on the day canvas.
///
/// Conflict detection and vertical sizing stay with the canvas, which is the
/// only thing that can see the whole day; this receives the answers.
struct PlanCanvasCommitmentCard: View {
    let commitment: PlanningFixedCommitment
    let width: CGFloat
    let height: CGFloat
    let conflict: Bool

    var body: some View {
        // Same reasoning as the block card: once lanes split the canvas the
        // icons eat the title, and the tint already says "conflict".
        let compact = width < 140
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                if compact == false {
                    Image(systemName: commitment.source == .externalCalendar ? "calendar" : "lock.fill")
                }
                Text(commitment.title).lineLimit(1)
                if conflict, compact == false { Image(systemName: "exclamationmark.triangle.fill") }
            }
            .font(.caption.weight(.semibold))
            Text(
                compact
                    ? PlanSectionCopy.time(commitment.startAt)
                    : "\(PlanSectionCopy.time(commitment.startAt))–\(PlanSectionCopy.time(commitment.endAt)) · read-only"
            )
            .font(.caption2).lineLimit(1)
        }
        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
        .padding(.horizontal, compact ? 5 : 9)
        .frame(
            width: max(1, width),
            height: height,
            alignment: .topLeading
        )
        .background(
            conflict
                ? Color(SemanticColorTokens.foundationApricotAccent).opacity(0.20)
                : Color(SemanticColorTokens.foundationSurfaceRecessed),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(commitment.title), \(PlanSectionCopy.time(commitment.startAt)) to \(PlanSectionCopy.time(commitment.endAt))\(conflict ? ", conflicts with another item" : "")")
    }
}
