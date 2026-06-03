import SwiftUI

struct TimelineStreamAnchor: Equatable, Identifiable {
    let id: String
    let kind: TimelineStreamInfluenceKind
    let y: CGFloat
    let strength: CGFloat
    let thickness: CGFloat
    let tintHex: String?
    let direction: TimelineStreamDirection

    var xDirection: CGFloat { direction.rawValue }
}
