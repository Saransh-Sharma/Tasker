import UIKit

public protocol TaskerTokenGroup {}

public protocol TaskerTokenContainer {
    var color: TaskerColorTokens { get }
    var typography: TaskerTypographyTokens { get }
    var spacing: TaskerSpacingTokens { get }
    var elevation: TaskerElevationTokens { get }
    var corner: TaskerCornerTokens { get }
}

public enum TaskerTextStyle: String, CaseIterable {
    case display
    case title1
    case title2
    case title3
    case headline
    case body
    case bodyEmphasis
    case callout
    case caption1
    case caption2
    case button
    case buttonSmall
}

public enum TaskerColorRole: String, CaseIterable {
    case bgCanvas
    case bgElevated
    case surfacePrimary
    case surfaceSecondary
    case surfaceTertiary
    case divider
    case strokeHairline
    case strokeStrong
    case textPrimary
    case textSecondary
    case textTertiary
    case textQuaternary
    case textInverse
    case accentPrimary
    case accentPrimaryPressed
    case accentMuted
    case accentWash
    case accentOnPrimary
    case accentRing
    case accentSecondary
    case accentSecondaryPressed
    case accentSecondaryMuted
    case accentSecondaryWash
    case statusSuccess
    case statusWarning
    case statusDanger
    case overlayScrim
    case overlayGlassTint
    case taskCheckboxBorder
    case taskCheckboxFill
    case taskOverdue
    case chartPrimary
    case chartSecondary
    case chipSelectedBackground
    case chipUnselectedBackground
    case priorityMax
    case priorityHigh
    case priorityLow
    case priorityNone
}

public enum TaskerSpacingToken: CGFloat, CaseIterable {
    case s2 = 2
    case s4 = 4
    case s8 = 8
    case s12 = 12
    case s16 = 16
    case s20 = 20
    case s24 = 24
    case s32 = 32
    case s40 = 40
}

public enum TaskerElevationLevel: String, CaseIterable {
    case e0
    case e1
    case e2
    case e3
}

public enum TaskerCornerToken: String, CaseIterable {
    case r0
    case r1
    case r2
    case r3
    case r4
    case pill
    case circle

    public var value: CGFloat {
        switch self {
        case .r0: return 0
        case .r1: return 8
        case .r2: return 12
        case .r3: return 16
        case .r4: return 24
        case .pill: return 999
        case .circle: return 999
        }
    }

    public func value(forHeight height: CGFloat) -> CGFloat {
        if self == .circle {
            return max(0, height / 2)
        }
        return value
    }
}

public enum TaskerNavButtonContext: String, CaseIterable {
    case onGradient
    case onSurface
}

public enum TaskerNavButtonEmphasis: String, CaseIterable {
    case normal
    case done
    case filled
}

public enum TaskerChipSelectionStyle: String, CaseIterable {
    case tinted
    case filled
}

public struct TaskerTokens: TaskerTokenContainer {
    public let color: TaskerColorTokens
    public let typography: TaskerTypographyTokens
    public let spacing: TaskerSpacingTokens
    public let elevation: TaskerElevationTokens
    public let corner: TaskerCornerTokens

    public init(
        color: TaskerColorTokens,
        typography: TaskerTypographyTokens,
        spacing: TaskerSpacingTokens,
        elevation: TaskerElevationTokens,
        corner: TaskerCornerTokens
    ) {
        self.color = color
        self.typography = typography
        self.spacing = spacing
        self.elevation = elevation
        self.corner = corner
    }
}
