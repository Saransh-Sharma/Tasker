import CoreGraphics

enum LBSpacingTokens {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let screenMargin: CGFloat = 16
    static let compactHeaderHeight: CGFloat = 242
    static let compactHeaderAccessibilityHeight: CGFloat = 292
    static let timelineTimeColumnWidth: CGFloat = 72
    static let timelineRailWidth: CGFloat = 16
    static let timelineCardGap: CGFloat = 8
    static let timelineRailCenterX: CGFloat = screenMargin + timelineTimeColumnWidth + timelineRailWidth / 2
    static let bottomDockHeight: CGFloat = 84
    static let bottomDockClearance: CGFloat = 150
}
