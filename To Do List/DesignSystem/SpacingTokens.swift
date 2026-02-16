import UIKit

public struct TaskerSpacingTokens: TaskerTokenGroup {
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

    public func value(for token: TaskerSpacingToken) -> CGFloat {
        token.rawValue
    }

    public static let `default` = TaskerSpacingTokens(
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
}
