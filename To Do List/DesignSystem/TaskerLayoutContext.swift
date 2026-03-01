import UIKit

public struct TaskerLayoutContext {
    public let metrics: TaskerLayoutMetrics
    public let layoutClass: TaskerLayoutClass

    /// Initializes a new instance.
    public init(metrics: TaskerLayoutMetrics) {
        self.metrics = metrics
        self.layoutClass = TaskerLayoutResolver.classify(metrics: metrics)
    }

    /// Executes from.
    public static func from(view: UIView) -> TaskerLayoutContext {
        let metrics = TaskerLayoutResolver.metrics(for: view)
        return TaskerLayoutContext(metrics: metrics)
    }

    /// Executes from.
    public static func from(windowScene: UIWindowScene?) -> TaskerLayoutContext {
        guard let windowScene else {
            return TaskerLayoutContext(
                metrics: TaskerLayoutMetrics(
                    width: 0,
                    height: 0,
                    idiom: .phone
                )
            )
        }
        let bounds = windowScene.coordinateSpace.bounds
        let metrics = TaskerLayoutMetrics(
            width: bounds.width,
            height: bounds.height,
            idiom: windowScene.traitCollection.userInterfaceIdiom,
            horizontalSizeClass: windowScene.traitCollection.horizontalSizeClass,
            verticalSizeClass: windowScene.traitCollection.verticalSizeClass,
            safeAreaInsets: windowScene.windows.first?.safeAreaInsets ?? .zero
        )
        return TaskerLayoutContext(metrics: metrics)
    }
}
