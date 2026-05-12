import UIKit

public struct LifeBoardLayoutContext: Sendable {
    public let metrics: LifeBoardLayoutMetrics
    public let layoutClass: LifeBoardLayoutClass

    /// Initializes a new instance.
    public init(metrics: LifeBoardLayoutMetrics) {
        self.metrics = metrics
        self.layoutClass = LifeBoardLayoutResolver.classify(metrics: metrics)
    }

    /// Executes from.
    @MainActor
    public static func from(view: UIView) -> LifeBoardLayoutContext {
        let metrics = LifeBoardLayoutResolver.metrics(for: view)
        return LifeBoardLayoutContext(metrics: metrics)
    }

    /// Executes from.
    @MainActor
    public static func from(windowScene: UIWindowScene?) -> LifeBoardLayoutContext {
        guard let windowScene else {
            return LifeBoardLayoutContext(
                metrics: LifeBoardLayoutMetrics(
                    width: 0,
                    height: 0,
                    idiom: .phone
                )
            )
        }
        let bounds = windowScene.coordinateSpace.bounds
        let metrics = LifeBoardLayoutMetrics(
            width: bounds.width,
            height: bounds.height,
            idiom: windowScene.traitCollection.userInterfaceIdiom,
            horizontalSizeClass: windowScene.traitCollection.horizontalSizeClass,
            verticalSizeClass: windowScene.traitCollection.verticalSizeClass,
            safeAreaInsets: windowScene.windows.first?.safeAreaInsets ?? .zero
        )
        return LifeBoardLayoutContext(metrics: metrics)
    }
}
