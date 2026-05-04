import UIKit

public struct LifeBoardCornerTokens: LifeBoardTokenGroup, Sendable {
    public let r0: CGFloat
    public let r1: CGFloat
    public let r2: CGFloat
    public let r3: CGFloat
    public let r4: CGFloat
    public let pill: CGFloat

    // Component mappings
    public let card: CGFloat
    public let input: CGFloat
    public let chip: CGFloat
    public let bottomBar: CGFloat
    public let modal: CGFloat

    /// Executes value.
    public func value(for token: LifeBoardCornerToken, height: CGFloat? = nil) -> CGFloat {
        switch token {
        case .r0: return r0
        case .r1: return r1
        case .r2: return r2
        case .r3: return r3
        case .r4: return r4
        case .pill: return pill
        case .circle:
            return max(0, (height ?? 0) / 2)
        }
    }

    public static let `default` = LifeBoardCornerTokens(
        r0: 0,
        r1: 12,
        r2: 14,
        r3: 18,
        r4: 22,
        pill: 999,
        card: 18,
        input: 14,
        chip: 999,
        bottomBar: 28,
        modal: 28
    )

    public static let padCompact = LifeBoardCornerTokens(
        r0: 0,
        r1: 12,
        r2: 14,
        r3: 18,
        r4: 24,
        pill: 999,
        card: 20,
        input: 14,
        chip: 999,
        bottomBar: 30,
        modal: 30
    )

    public static let padRegular = LifeBoardCornerTokens(
        r0: 0,
        r1: 12,
        r2: 14,
        r3: 18,
        r4: 24,
        pill: 999,
        card: 20,
        input: 14,
        chip: 999,
        bottomBar: 32,
        modal: 32
    )

    public static let padExpanded = LifeBoardCornerTokens(
        r0: 0,
        r1: 12,
        r2: 16,
        r3: 20,
        r4: 26,
        pill: 999,
        card: 22,
        input: 16,
        chip: 999,
        bottomBar: 34,
        modal: 34
    )

    /// Executes forLayout.
    public static func forLayout(_ layoutClass: LifeBoardLayoutClass) -> LifeBoardCornerTokens {
        switch layoutClass {
        case .phone:
            return `default`
        case .padCompact:
            return padCompact
        case .padRegular:
            return padRegular
        case .padExpanded:
            return padExpanded
        }
    }
}
