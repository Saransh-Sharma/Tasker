import UIKit

public struct LayoutContext: Sendable {
    public let metrics: LayoutMetrics
    public let layoutClass: LayoutClass

    /// Initializes a new instance.
    public init(metrics: LayoutMetrics) {
        self.metrics = metrics
        self.layoutClass = LayoutResolver.classify(metrics: metrics)
    }

    /// Executes from.
    @MainActor
    public static func from(view: UIView) -> LayoutContext {
        let metrics = LayoutResolver.metrics(for: view)
        return LayoutContext(metrics: metrics)
    }

    /// Executes from.
    @MainActor
    public static func from(windowScene: UIWindowScene?) -> LayoutContext {
        guard let windowScene else {
            return LayoutContext(
                metrics: LayoutMetrics(
                    width: 0,
                    height: 0,
                    idiom: .phone
                )
            )
        }
        let bounds = windowScene.effectiveGeometry.coordinateSpace.bounds
        let metrics = LayoutMetrics(
            width: bounds.width,
            height: bounds.height,
            idiom: windowScene.traitCollection.userInterfaceIdiom,
            horizontalSizeClass: windowScene.traitCollection.horizontalSizeClass,
            verticalSizeClass: windowScene.traitCollection.verticalSizeClass,
            safeAreaInsets: windowScene.windows.first?.safeAreaInsets ?? .zero
        )
        return LayoutContext(metrics: metrics)
    }
}
