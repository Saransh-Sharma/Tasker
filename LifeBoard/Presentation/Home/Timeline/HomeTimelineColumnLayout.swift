//
//  HomeTimelineColumnLayout.swift
//  LifeBoard
//
//  Timeline column layout support for the Home shell.
//

import CoreGraphics

enum HomeTimelineColumnLayout {
    static func maxWidth(for layoutClass: LifeBoardLayoutClass) -> CGFloat? {
        switch layoutClass {
        case .padRegular:
            return 760
        case .padExpanded:
            return 840
        default:
            return nil
        }
    }

    static func bottomContentClearance(
        taskListBottomInset: CGFloat,
        layoutClass: LifeBoardLayoutClass,
        spacing: LifeBoardSpacingTokens
    ) -> CGFloat {
        guard layoutClass == .phone else {
            return taskListBottomInset
        }
        return max(taskListBottomInset + spacing.s40 + spacing.s8, 132)
    }
}
