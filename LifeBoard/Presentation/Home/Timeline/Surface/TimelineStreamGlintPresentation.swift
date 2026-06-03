import SwiftUI

struct TimelineStreamGlintPresentation: Equatable {
    static let halfLength: CGFloat = 16
    static let blurRadius: CGFloat = 3
    static let opacity: Double = 0.36
    static let extraLineWidth: CGFloat = 0.75

    static func visibleAnchorIDs(
        anchors: [TimelineStreamAnchor],
        currentY: CGFloat?,
        currentDistanceThreshold: CGFloat = 64
    ) -> Set<String> {
        let candidates = anchors
            .filter { $0.kind == .task || $0.kind == .meeting || $0.kind == .flock }
            .sorted { lhs, rhs in
                if lhs.y != rhs.y { return lhs.y < rhs.y }
                return lhs.id < rhs.id
            }
        var visible = Set(candidates.filter { $0.kind == .flock }.map(\.id))

        guard let currentY else {
            return visible
        }

        if let current = candidates.min(by: { abs($0.y - currentY) < abs($1.y - currentY) }),
           abs(current.y - currentY) <= currentDistanceThreshold {
            visible.insert(current.id)
        }

        if let next = candidates.first(where: { $0.y > currentY + 8 }) {
            visible.insert(next.id)
        }

        return visible
    }
}
