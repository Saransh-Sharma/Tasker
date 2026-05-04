import UIKit

public struct LifeBoardSpacingTokens: LifeBoardTokenGroup, Sendable {
    public let s2: CGFloat
    public let s4: CGFloat
    public let s8: CGFloat
    public let s12: CGFloat
    public let s16: CGFloat
    public let s20: CGFloat
    public let s24: CGFloat
    public let s32: CGFloat
    public let s40: CGFloat

    // Layout recipes
    public let screenHorizontal: CGFloat
    public let cardPadding: CGFloat
    public let cardStackVertical: CGFloat
    public let sectionGap: CGFloat
    public let listRowVerticalPadding: CGFloat
    public let titleSubtitleGap: CGFloat
    public let chipSpacing: CGFloat
    public let buttonHeight: CGFloat

    /// Executes value.
    public func value(for token: LifeBoardSpacingToken) -> CGFloat {
        token.rawValue
    }

    public static let `default` = LifeBoardSpacingTokens(
        s2: 2,
        s4: 4,
        s8: 8,
        s12: 12,
        s16: 16,
        s20: 20,
        s24: 24,
        s32: 32,
        s40: 40,
        screenHorizontal: 20,
        cardPadding: 20,
        cardStackVertical: 12,
        sectionGap: 28,
        listRowVerticalPadding: 12,
        titleSubtitleGap: 4,
        chipSpacing: 8,
        buttonHeight: 48
    )

    public static let padCompact = LifeBoardSpacingTokens(
        s2: 2,
        s4: 4,
        s8: 8,
        s12: 12,
        s16: 16,
        s20: 20,
        s24: 24,
        s32: 32,
        s40: 40,
        screenHorizontal: 24,
        cardPadding: 22,
        cardStackVertical: 14,
        sectionGap: 30,
        listRowVerticalPadding: 13,
        titleSubtitleGap: 4,
        chipSpacing: 8,
        buttonHeight: 48
    )

    public static let padRegular = LifeBoardSpacingTokens(
        s2: 2,
        s4: 4,
        s8: 8,
        s12: 12,
        s16: 16,
        s20: 20,
        s24: 24,
        s32: 32,
        s40: 40,
        screenHorizontal: 28,
        cardPadding: 24,
        cardStackVertical: 14,
        sectionGap: 32,
        listRowVerticalPadding: 14,
        titleSubtitleGap: 6,
        chipSpacing: 10,
        buttonHeight: 50
    )

    public static let padExpanded = LifeBoardSpacingTokens(
        s2: 2,
        s4: 4,
        s8: 8,
        s12: 12,
        s16: 16,
        s20: 20,
        s24: 24,
        s32: 32,
        s40: 40,
        screenHorizontal: 32,
        cardPadding: 26,
        cardStackVertical: 16,
        sectionGap: 36,
        listRowVerticalPadding: 14,
        titleSubtitleGap: 6,
        chipSpacing: 10,
        buttonHeight: 52
    )

    /// Executes forLayout.
    public static func forLayout(_ layoutClass: LifeBoardLayoutClass) -> LifeBoardSpacingTokens {
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
