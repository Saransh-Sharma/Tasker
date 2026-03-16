import UIKit

public enum TaskerLayoutClass: String, CaseIterable {
    case phone
    case padCompact
    case padRegular
    case padExpanded

    public var isPad: Bool {
        self != .phone
    }
}

public struct TaskerLayoutMetrics {
    public let width: CGFloat
    public let height: CGFloat
    public let idiom: UIUserInterfaceIdiom
    public let horizontalSizeClass: UIUserInterfaceSizeClass?
    public let verticalSizeClass: UIUserInterfaceSizeClass?
    public let safeAreaInsets: UIEdgeInsets

    /// Initializes a new instance.
    public init(
        width: CGFloat,
        height: CGFloat,
        idiom: UIUserInterfaceIdiom,
        horizontalSizeClass: UIUserInterfaceSizeClass? = nil,
        verticalSizeClass: UIUserInterfaceSizeClass? = nil,
        safeAreaInsets: UIEdgeInsets = .zero
    ) {
        self.width = width
        self.height = height
        self.idiom = idiom
        self.horizontalSizeClass = horizontalSizeClass
        self.verticalSizeClass = verticalSizeClass
        self.safeAreaInsets = safeAreaInsets
    }
}

public enum TaskerLayoutResolver {
    public static let padCompactUpperBound: CGFloat = 700
    public static let padRegularUpperBound: CGFloat = 1024

    /// Executes classify.
    public static func classify(metrics: TaskerLayoutMetrics) -> TaskerLayoutClass {
        guard metrics.idiom == .pad else { return .phone }
        if metrics.width < padCompactUpperBound {
            return .padCompact
        }
        if metrics.width < padRegularUpperBound {
            return .padRegular
        }
        return .padExpanded
    }

    /// Executes classify.
    public static func classify(windowScene: UIWindowScene?) -> TaskerLayoutClass {
        guard let windowScene else { return .phone }
        let size = windowScene.coordinateSpace.bounds.size
        let horizontalSizeClass = windowScene.traitCollection.horizontalSizeClass
        let verticalSizeClass = windowScene.traitCollection.verticalSizeClass
        let safeAreaInsets = windowScene.windows.first?.safeAreaInsets ?? .zero
        let metrics = TaskerLayoutMetrics(
            width: size.width,
            height: size.height,
            idiom: windowScene.traitCollection.userInterfaceIdiom,
            horizontalSizeClass: horizontalSizeClass,
            verticalSizeClass: verticalSizeClass,
            safeAreaInsets: safeAreaInsets
        )
        return classify(metrics: metrics)
    }

    /// Executes classify.
    public static func classify(view: UIView) -> TaskerLayoutClass {
        classify(metrics: metrics(for: view))
    }

    static func metrics(for view: UIView) -> TaskerLayoutMetrics {
        let bounds = view.bounds
        let fallbackBounds = view.window?.windowScene?.coordinateSpace.bounds ?? view.window?.bounds
        let resolvedWidth: CGFloat
        let resolvedHeight: CGFloat

        if bounds.width <= 1, let fallbackBounds, fallbackBounds.width > 1 {
            resolvedWidth = fallbackBounds.width
            resolvedHeight = fallbackBounds.height
        } else {
            resolvedWidth = bounds.width
            resolvedHeight = bounds.height
        }

        return TaskerLayoutMetrics(
            width: resolvedWidth,
            height: resolvedHeight,
            idiom: view.traitCollection.userInterfaceIdiom,
            horizontalSizeClass: view.traitCollection.horizontalSizeClass,
            verticalSizeClass: view.traitCollection.verticalSizeClass,
            safeAreaInsets: view.safeAreaInsets
        )
    }
}

public protocol TaskerTokenGroup {}

public protocol TaskerTokenContainer {
    var color: TaskerColorTokens { get }
    var typography: TaskerTypographyTokens { get }
    var spacing: TaskerSpacingTokens { get }
    var elevation: TaskerElevationTokens { get }
    var corner: TaskerCornerTokens { get }
}

public enum TaskerTextStyle: String, CaseIterable {
    case heroDisplay
    case screenTitle
    case sectionTitle
    case eyebrow
    case display
    case title1
    case title2
    case title3
    case headline
    case body
    case bodyStrong
    case bodyEmphasis
    case support
    case meta
    case callout
    case metric
    case monoMeta
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
    case brandPrimary
    case brandSecondary
    case brandHighlight
    case actionPrimary
    case actionPrimaryPressed
    case actionFocus
    case borderSubtle
    case borderDefault
    case borderStrong
    case divider
    case strokeHairline
    case strokeStrong
    case textPrimary
    case textSecondary
    case textTertiary
    case textQuaternary
    case textInverse
    case textDisabled
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
    case stateInfo
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

    /// Executes value.
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

    /// Initializes a new instance.
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
