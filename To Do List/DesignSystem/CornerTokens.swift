import UIKit

public struct TaskerCornerTokens: TaskerTokenGroup {
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

    public func value(for token: TaskerCornerToken, height: CGFloat? = nil) -> CGFloat {
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

    public static let `default` = TaskerCornerTokens(
        r0: 0,
        r1: 8,
        r2: 12,
        r3: 20,
        r4: 28,
        pill: 999,
        card: 20,
        input: 12,
        chip: 999,
        bottomBar: 28,
        modal: 28
    )
}
