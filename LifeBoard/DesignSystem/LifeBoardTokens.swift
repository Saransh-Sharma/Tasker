import UIKit

public enum LifeBoardLayoutClass: String, CaseIterable, Hashable, Sendable {
    case phone
    case padCompact
    case padRegular
    case padExpanded

    public var isPad: Bool {
        self != .phone
    }
}

public enum LifeBoardInterfacePlatform: String, Sendable {
    case phone
    case pad
    case macCatalyst

    public var usesExpandedLayout: Bool {
        switch self {
        case .phone:
            return false
        case .pad, .macCatalyst:
            return true
        }
    }

    public static func resolve(idiom: UIUserInterfaceIdiom) -> LifeBoardInterfacePlatform {
        #if targetEnvironment(macCatalyst)
        if idiom != .phone {
            return .macCatalyst
        }
        #endif

        switch idiom {
        case .pad:
            return .pad
        case .mac:
            return .macCatalyst
        default:
            return .phone
        }
    }
}

public struct LifeBoardLayoutMetrics: Sendable {
    public let width: CGFloat
    public let height: CGFloat
    public let idiom: UIUserInterfaceIdiom
    public let platform: LifeBoardInterfacePlatform
    public let horizontalSizeClass: UIUserInterfaceSizeClass?
    public let verticalSizeClass: UIUserInterfaceSizeClass?
    public let safeAreaInsets: UIEdgeInsets

    /// Initializes a new instance.
    public init(
        width: CGFloat,
        height: CGFloat,
        idiom: UIUserInterfaceIdiom,
        platform: LifeBoardInterfacePlatform? = nil,
        horizontalSizeClass: UIUserInterfaceSizeClass? = nil,
        verticalSizeClass: UIUserInterfaceSizeClass? = nil,
        safeAreaInsets: UIEdgeInsets = .zero
    ) {
        self.width = width
        self.height = height
        self.idiom = idiom
        self.platform = platform ?? LifeBoardInterfacePlatform.resolve(idiom: idiom)
        self.horizontalSizeClass = horizontalSizeClass
        self.verticalSizeClass = verticalSizeClass
        self.safeAreaInsets = safeAreaInsets
    }
}

public enum LifeBoardLayoutResolver {
    public static let padCompactUpperBound: CGFloat = 700
    public static let padRegularUpperBound: CGFloat = 1024

    /// Executes classify.
    public static func classify(metrics: LifeBoardLayoutMetrics) -> LifeBoardLayoutClass {
        guard metrics.platform.usesExpandedLayout else { return .phone }
        if metrics.width < padCompactUpperBound {
            return .padCompact
        }
        if metrics.width < padRegularUpperBound {
            return .padRegular
        }
        return .padExpanded
    }

    /// Executes classify.
    @MainActor
    public static func classify(windowScene: UIWindowScene?) -> LifeBoardLayoutClass {
        guard let windowScene else { return .phone }
        let size = windowScene.effectiveGeometry.coordinateSpace.bounds.size
        let horizontalSizeClass = windowScene.traitCollection.horizontalSizeClass
        let verticalSizeClass = windowScene.traitCollection.verticalSizeClass
        let safeAreaInsets = windowScene.windows.first?.safeAreaInsets ?? .zero
        let metrics = LifeBoardLayoutMetrics(
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
    @MainActor
    public static func classify(view: UIView) -> LifeBoardLayoutClass {
        classify(metrics: metrics(for: view))
    }

    @MainActor
    static func metrics(for view: UIView) -> LifeBoardLayoutMetrics {
        let bounds = view.bounds
        let fallbackBounds = view.window?.windowScene?.effectiveGeometry.coordinateSpace.bounds ?? view.window?.bounds
        let resolvedWidth: CGFloat
        let resolvedHeight: CGFloat

        if bounds.width <= 1, let fallbackBounds, fallbackBounds.width > 1 {
            resolvedWidth = fallbackBounds.width
            resolvedHeight = fallbackBounds.height
        } else {
            resolvedWidth = bounds.width
            resolvedHeight = bounds.height
        }

        return LifeBoardLayoutMetrics(
            width: resolvedWidth,
            height: resolvedHeight,
            idiom: view.traitCollection.userInterfaceIdiom,
            horizontalSizeClass: view.traitCollection.horizontalSizeClass,
            verticalSizeClass: view.traitCollection.verticalSizeClass,
            safeAreaInsets: view.safeAreaInsets
        )
    }
}

public protocol LifeBoardTokenGroup {}

public protocol LifeBoardTokenContainer {
    var color: LifeBoardColorTokens { get }
    var typography: LifeBoardTypographyTokens { get }
    var spacing: LifeBoardSpacingTokens { get }
    var elevation: LifeBoardElevationTokens { get }
    var corner: LifeBoardCornerTokens { get }
}

public enum LifeBoardTextStyle: String, CaseIterable {
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

public enum LifeBoardColorRole: String, CaseIterable, Sendable {
    case bgCanvas
    case bgCanvasSecondary
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

/// The semantic surface beneath content. Feature views describe their
/// surface instead of guessing a foreground color from appearance alone.
public enum LifeBoardSurfaceContext: String, CaseIterable, Sendable {
    case canvas
    case paper
    case elevatedPaper
    case card
    case glass
    case strongGlass
    case dockChrome
    case sidebar
    case toolbar
    case inspector
    case sheet
    case overlay
    case accent
    case image
    case modalScrim

    /// Opaque surface used for deterministic contrast validation and as the
    /// Reduce Transparency fallback for translucent chrome.
    public var fallbackBackgroundRole: LifeBoardColorRole? {
        switch self {
        case .canvas:
            return .bgCanvas
        case .paper, .card, .sidebar, .sheet:
            return .surfacePrimary
        case .elevatedPaper, .glass, .dockChrome, .toolbar, .inspector:
            return .bgElevated
        case .strongGlass, .overlay:
            return .surfaceSecondary
        case .accent:
            return .actionPrimary
        case .modalScrim:
            return .overlayScrim
        case .image:
            return nil
        }
    }
}

public enum LifeBoardLegibilityRole: String, CaseIterable, Sendable {
    case primary
    case secondary
    case tertiary
    case disabled
    case link
    case success
    case warning
    case destructive
    case onAccent
    case onImage
    case focusRing
}

public enum LifeBoardImageForegroundStyle: String, Sendable {
    case darkContent
    case lightContent
}

/// Shared policy for copy placed over photography or decorative artwork.
/// The sampled region, not the image as a whole, determines the foreground.
public enum LifeBoardImageReadabilityPolicy {
    public static let darkContentThreshold: CGFloat = 0.56
    public static let strongScrimLowerBound: CGFloat = 0.30
    public static let strongScrimUpperBound: CGFloat = 0.72

    public static func foregroundStyle(forLuminance luminance: CGFloat) -> LifeBoardImageForegroundStyle {
        luminance >= darkContentThreshold ? .darkContent : .lightContent
    }

    /// Returns a bounded scrim opacity for locally ambiguous image regions.
    /// Very light and very dark regions need less intervention; mid-tones get
    /// the strongest treatment because either foreground can become fragile.
    public static func scrimOpacity(forLuminance luminance: CGFloat) -> CGFloat {
        let value = min(1, max(0, luminance))
        guard value > strongScrimLowerBound, value < strongScrimUpperBound else { return 0.08 }
        let distanceFromMiddle = abs(value - 0.5) / 0.22
        return 0.26 - min(1, distanceFromMiddle) * 0.10
    }
}

public struct LifeBoardLegibilityPair: Hashable, Sendable {
    public let foreground: LifeBoardColorRole
    public let background: LifeBoardColorRole
    public let minimumContrast: CGFloat

    public init(foreground: LifeBoardColorRole, background: LifeBoardColorRole, minimumContrast: CGFloat) {
        self.foreground = foreground
        self.background = background
        self.minimumContrast = minimumContrast
    }

    /// Release-gated combinations used by reading, action, status, and glass
    /// surfaces. Decorative separators intentionally do not appear here.
    public static let releaseGate: [LifeBoardLegibilityPair] = [
        .init(foreground: .textPrimary, background: .bgCanvas, minimumContrast: 4.5),
        .init(foreground: .textPrimary, background: .surfacePrimary, minimumContrast: 4.5),
        .init(foreground: .textPrimary, background: .surfaceSecondary, minimumContrast: 4.5),
        .init(foreground: .textPrimary, background: .surfaceTertiary, minimumContrast: 4.5),
        .init(foreground: .textPrimary, background: .bgElevated, minimumContrast: 4.5),
        .init(foreground: .textSecondary, background: .bgCanvas, minimumContrast: 4.5),
        .init(foreground: .textSecondary, background: .surfacePrimary, minimumContrast: 4.5),
        .init(foreground: .textSecondary, background: .surfaceSecondary, minimumContrast: 4.5),
        .init(foreground: .textSecondary, background: .surfaceTertiary, minimumContrast: 4.5),
        .init(foreground: .textSecondary, background: .bgElevated, minimumContrast: 4.5),
        .init(foreground: .accentOnPrimary, background: .actionPrimary, minimumContrast: 4.5),
        .init(foreground: .statusSuccess, background: .surfacePrimary, minimumContrast: 3.0),
        .init(foreground: .statusWarning, background: .surfacePrimary, minimumContrast: 3.0),
        .init(foreground: .statusDanger, background: .surfacePrimary, minimumContrast: 3.0),
        .init(foreground: .actionFocus, background: .surfacePrimary, minimumContrast: 3.0)
    ]
}

public enum LifeBoardSpacingToken: CGFloat, CaseIterable {
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

public enum LifeBoardElevationLevel: String, CaseIterable {
    case e0
    case e1
    case e2
    case e3
}

public enum LifeBoardCornerToken: String, CaseIterable {
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

public enum LifeBoardNavButtonContext: String, CaseIterable {
    case onGradient
    case onSurface
}

public enum LifeBoardNavButtonEmphasis: String, CaseIterable {
    case normal
    case done
    case filled
}

public enum LifeBoardChipSelectionStyle: String, CaseIterable {
    case tinted
    case filled
}

public struct LifeBoardTokens: LifeBoardTokenContainer {
    public let color: LifeBoardColorTokens
    public let typography: LifeBoardTypographyTokens
    public let spacing: LifeBoardSpacingTokens
    public let elevation: LifeBoardElevationTokens
    public let corner: LifeBoardCornerTokens

    /// Initializes a new instance.
    public init(
        color: LifeBoardColorTokens,
        typography: LifeBoardTypographyTokens,
        spacing: LifeBoardSpacingTokens,
        elevation: LifeBoardElevationTokens,
        corner: LifeBoardCornerTokens
    ) {
        self.color = color
        self.typography = typography
        self.spacing = spacing
        self.elevation = elevation
        self.corner = corner
    }
}
