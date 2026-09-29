import UIKit

public enum LayoutClass: String, CaseIterable, Hashable, Sendable {
    case phone
    case padCompact
    case padRegular
    case padExpanded

    public var isPad: Bool {
        self != .phone
    }
}

public enum InterfacePlatform: String, Sendable {
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

    public static func resolve(idiom: UIUserInterfaceIdiom) -> InterfacePlatform {
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

public struct LayoutMetrics: Sendable {
    public let width: CGFloat
    public let height: CGFloat
    public let idiom: UIUserInterfaceIdiom
    public let platform: InterfacePlatform
    public let horizontalSizeClass: UIUserInterfaceSizeClass?
    public let verticalSizeClass: UIUserInterfaceSizeClass?
    public let safeAreaInsets: UIEdgeInsets

    /// Initializes a new instance.
    public init(
        width: CGFloat,
        height: CGFloat,
        idiom: UIUserInterfaceIdiom,
        platform: InterfacePlatform? = nil,
        horizontalSizeClass: UIUserInterfaceSizeClass? = nil,
        verticalSizeClass: UIUserInterfaceSizeClass? = nil,
        safeAreaInsets: UIEdgeInsets = .zero
    ) {
        self.width = width
        self.height = height
        self.idiom = idiom
        self.platform = platform ?? InterfacePlatform.resolve(idiom: idiom)
        self.horizontalSizeClass = horizontalSizeClass
        self.verticalSizeClass = verticalSizeClass
        self.safeAreaInsets = safeAreaInsets
    }
}

public enum LayoutResolver {
    /// Below this an iPad or Mac window is phone-shaped (Slide Over, a narrow
    /// Split View pane) and gets the phone composition.
    public static let phoneUpperBound: CGFloat = 600
    public static let padCompactUpperBound: CGFloat = 700
    public static let padRegularUpperBound: CGFloat = 1024

    /// Classifies a window by the width it actually has, not the device it runs on.
    ///
    /// The device alone says nothing about a ⅓ Split View pane or a narrow Mac
    /// window, and those need the phone layout. A compact size class on iPad is
    /// treated the same way. Width 0 (before the first layout pass) falls back to
    /// the platform's usual class, so the first frame does not flash the phone
    /// layout.
    public static func classify(
        width: CGFloat,
        horizontalSizeClass: UIUserInterfaceSizeClass?,
        platform: InterfacePlatform
    ) -> LayoutClass {
        guard platform.usesExpandedLayout else { return .phone }
        guard width > 0 else { return .padRegular }
        if platform == .pad, horizontalSizeClass == .compact { return .phone }
        if width < phoneUpperBound { return .phone }
        if width < padCompactUpperBound { return .padCompact }
        if width < padRegularUpperBound { return .padRegular }
        return .padExpanded
    }

    /// Executes classify.
    public static func classify(metrics: LayoutMetrics) -> LayoutClass {
        classify(
            width: metrics.width,
            horizontalSizeClass: metrics.horizontalSizeClass,
            platform: metrics.platform
        )
    }

    /// Executes classify.
    @MainActor
    public static func classify(windowScene: UIWindowScene?) -> LayoutClass {
        guard let windowScene else { return .phone }
        let size = windowScene.effectiveGeometry.coordinateSpace.bounds.size
        let horizontalSizeClass = windowScene.traitCollection.horizontalSizeClass
        let verticalSizeClass = windowScene.traitCollection.verticalSizeClass
        let safeAreaInsets = windowScene.windows.first?.safeAreaInsets ?? .zero
        let metrics = LayoutMetrics(
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
    public static func classify(view: UIView) -> LayoutClass {
        classify(metrics: metrics(for: view))
    }

    @MainActor
    // Resolves the live scene geometry for a view. Internal while this type
    // was compiled into each target; LifeBoardTests drives it directly, so it
    // has to cross the module boundary now.
    public static func metrics(for view: UIView) -> LayoutMetrics {
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

        return LayoutMetrics(
            width: resolvedWidth,
            height: resolvedHeight,
            idiom: view.traitCollection.userInterfaceIdiom,
            horizontalSizeClass: view.traitCollection.horizontalSizeClass,
            verticalSizeClass: view.traitCollection.verticalSizeClass,
            safeAreaInsets: view.safeAreaInsets
        )
    }
}
