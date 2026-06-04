import SwiftUI

struct TimelineStreamSegment: Equatable, Identifiable {
    let index: Int
    let start: TimelineStreamAnchor
    let end: TimelineStreamAnchor
    let control1: CGPoint
    let control2: CGPoint

    var id: Int { index }
}
