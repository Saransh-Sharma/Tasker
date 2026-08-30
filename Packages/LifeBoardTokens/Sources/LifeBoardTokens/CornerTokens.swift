import UIKit

/// The shape vocabulary, which does not vary by device.
///
/// There used to be four layout-class variants with different radii, so a card
/// was 18 points on a phone, 20 on a compact iPad and 22 on an expanded one —
/// a third radius scale on top of `Radius` and `ClayDepth`. `DESIGN.md` is
/// explicit that an iPad composition "grows through spacing and composition,
/// not oversized type or empty card area": geometry is the constant a person
/// recognises an object by across devices, so all four now resolve to the one
/// contract vocabulary and `forLayout` is retained only as a stable call site.
public struct CornerTokens: TokenGroup, Sendable {
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
    public func value(for token: CornerToken, height: CGFloat? = nil) -> CGFloat {
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

    public static let `default` = CornerTokens(
        r0: 0,
        r1: 14,
        r2: 16,
        r3: 20,
        r4: 24,
        pill: 999,
        card: 20,
        input: 14,
        chip: 999,
        bottomBar: 30,
        modal: 28
    )

    public static let padCompact = CornerTokens(
        r0: 0,
        r1: 14,
        r2: 16,
        r3: 20,
        r4: 24,
        pill: 999,
        card: 20,
        input: 14,
        chip: 999,
        bottomBar: 30,
        modal: 28
    )

    public static let padRegular = CornerTokens(
        r0: 0,
        r1: 14,
        r2: 16,
        r3: 20,
        r4: 24,
        pill: 999,
        card: 20,
        input: 14,
        chip: 999,
        bottomBar: 30,
        modal: 28
    )

    public static let padExpanded = CornerTokens(
        r0: 0,
        r1: 14,
        r2: 16,
        r3: 20,
        r4: 24,
        pill: 999,
        card: 20,
        input: 14,
        chip: 999,
        bottomBar: 30,
        modal: 28
    )

    /// Executes forLayout.
    public static func forLayout(_ layoutClass: LayoutClass) -> CornerTokens {
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
