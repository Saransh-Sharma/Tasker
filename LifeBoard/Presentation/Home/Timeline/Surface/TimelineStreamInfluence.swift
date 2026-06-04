import SwiftUI

struct TimelineStreamInfluence: Equatable, Identifiable {
    let id: String
    let kind: TimelineStreamInfluenceKind
    let centerY: CGFloat
    let height: CGFloat
    let tintHex: String?
    let stackCount: Int

    init(
        id: String,
        kind: TimelineStreamInfluenceKind,
        centerY: CGFloat,
        height: CGFloat,
        tintHex: String? = nil,
        stackCount: Int = 1
    ) {
        self.id = id
        self.kind = kind
        self.centerY = centerY
        self.height = height
        self.tintHex = tintHex
        self.stackCount = stackCount
    }
}
