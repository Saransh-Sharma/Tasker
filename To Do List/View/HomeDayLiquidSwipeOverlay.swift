import SwiftUI
import UIKit

struct HomeDayLiquidSwipeOverlay: View {
    let isEnabled: Bool
    let reduceMotion: Bool
    let onInteractionStarted: () -> Void
    let onInteractionCancelled: () -> Void
    let onCommit: (HomeDayNavigationDirection) -> Void
    let onHandleDragChanged: (HomeDayLiquidSwipeSide, CGSize, CGPoint, CGSize) -> Void
    let onHandleDragEnded: (HomeDayLiquidSwipeSide, CGSize, CGSize, CGPoint, CGSize) -> Void

    @Binding var leadingData: HomeDayLiquidSwipeData
    @Binding var trailingData: HomeDayLiquidSwipeData
    @Binding var topSide: HomeDayLiquidSwipeSide
    @State private var lastDraggedHandleSide: HomeDayLiquidSwipeSide?
    @State private var lastHandleDragEndedAt: Date?

    private let handleTapSuppressionInterval: TimeInterval = 0.25

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                sideLayer(.leading, size: size)
                sideLayer(.trailing, size: size)
            }
        }
        .accessibilityHidden(!isEnabled)
    }

    private func sideLayer(_ side: HomeDayLiquidSwipeSide, size: CGSize) -> some View {
        let data = swipeData(for: side, size: size)
        return ZStack(alignment: .topLeading) {
            HomeDayLiquidSwipeWaveShape(data: data)
                .fill(Color.tasker.accentPrimary.opacity(reduceMotion ? 0.18 : 0.74))
                .opacity(isEnabled ? 1 : 0)
                .allowsHitTesting(false)

            Button {
                guard shouldCommitTap(for: side) else { return }
                commit(side, size: size)
            } label: {
                Label(side.accessibilityLabel, systemImage: side.systemImage)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.tasker.accentOnPrimary)
                    .frame(
                        width: HomeDayLiquidSwipeData.buttonRadius * 2,
                        height: HomeDayLiquidSwipeData.buttonRadius * 2
                    )
                    .background {
                        Circle()
                            .stroke(Color.tasker.accentOnPrimary.opacity(0.28), lineWidth: 1)
                            .background(Color.tasker.accentPrimary.opacity(0.38), in: Circle())
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(side.accessibilityLabel))
            .opacity(data.buttonOpacity)
            .position(data.buttonCenter)
            .disabled(!isEnabled)
            .allowsHitTesting(isEnabled)
            .simultaneousGesture(handleDragGesture(for: side, size: size))
        }
        .zIndex(topSide == side ? 1 : 0)
    }

    private func handleDragGesture(for side: HomeDayLiquidSwipeSide, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                guard isEnabled else { return }
                topSide = side
                onInteractionStarted()
                onHandleDragChanged(
                    side,
                    value.translation,
                    handleDragLocation(for: side, translation: value.translation, size: size),
                    size
                )
            }
            .onEnded { value in
                guard isEnabled else { return }
                lastDraggedHandleSide = side
                lastHandleDragEndedAt = Date()
                onHandleDragEnded(
                    side,
                    value.translation,
                    value.predictedEndTranslation,
                    handleDragLocation(for: side, translation: value.translation, size: size),
                    size
                )
            }
    }

    private func handleDragLocation(
        for side: HomeDayLiquidSwipeSide,
        translation: CGSize,
        size: CGSize
    ) -> CGPoint {
        let center = HomeDayLiquidSwipeData(side: side, containerSize: size).buttonCenter
        return CGPoint(
            x: center.x + translation.width,
            y: center.y + translation.height
        )
    }

    private func commit(_ side: HomeDayLiquidSwipeSide, size: CGSize) {
        guard isEnabled else { return }
        topSide = side
        onInteractionStarted()
        if reduceMotion {
            onCommit(side.direction)
            reset(side, size: size)
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            setSwipeData(swipeData(for: side, size: size).final())
        } completion: {
            onCommit(side.direction)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                reset(side, size: size)
            }
        }
    }

    private func shouldCommitTap(for side: HomeDayLiquidSwipeSide) -> Bool {
        guard lastDraggedHandleSide == side, let lastHandleDragEndedAt else {
            return true
        }
        return Date().timeIntervalSince(lastHandleDragEndedAt) > handleTapSuppressionInterval
    }

    private func reset(_ side: HomeDayLiquidSwipeSide, size: CGSize) {
        let data = swipeData(for: side, size: size).initial()
        if reduceMotion {
            setSwipeData(data)
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                setSwipeData(data)
            }
        }
    }

    private func swipeData(for side: HomeDayLiquidSwipeSide, size: CGSize) -> HomeDayLiquidSwipeData {
        let data = side == .leading ? leadingData : trailingData
        return data.sized(to: size == .zero ? data.containerSize : size)
    }

    private func setSwipeData(_ data: HomeDayLiquidSwipeData) {
        switch data.side {
        case .leading:
            leadingData = data
        case .trailing:
            trailingData = data
        }
    }
}

struct HomeDayLiquidSwipeGestureSurface: UIViewRepresentable {
    let isEnabled: Bool
    let containerSize: CGSize
    let resolver: HomeDaySwipeResolver
    let onInteractionStarted: () -> Void
    let onChanged: (HomeDayLiquidSwipeSide, CGSize, CGPoint) -> Void
    let onEnded: (HomeDayLiquidSwipeSide, CGSize, CGSize, CGPoint) -> Void
    let onCancelled: (HomeDayLiquidSwipeSide) -> Void

    func makeUIView(context: Context) -> GestureHostView {
        let view = GestureHostView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: GestureHostView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.installIfNeeded(from: uiView)
    }

    static func dismantleUIView(_ uiView: GestureHostView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class GestureHostView: UIView {
        override var intrinsicContentSize: CGSize {
            CGSize(width: 1, height: 1)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: HomeDayLiquidSwipeGestureSurface

        private weak var scrollView: UIScrollView?
        private weak var installedView: UIView?
        private weak var panRecognizer: UIPanGestureRecognizer?
        private var activeSide: HomeDayLiquidSwipeSide?
        private var hasStartedInteraction = false

        init(parent: HomeDayLiquidSwipeGestureSurface) {
            self.parent = parent
        }

        func installIfNeeded(from hostView: UIView) {
            if let scrollView = hostView.nearestSuperview(of: UIScrollView.self),
               let installView = scrollView.window ?? scrollView.superview {
                install(on: installView, observing: scrollView)
                return
            }

            DispatchQueue.main.async { [weak self, weak hostView] in
                guard let self, let hostView else { return }
                guard let scrollView = hostView.nearestSuperview(of: UIScrollView.self) else { return }
                guard let installView = scrollView.window ?? scrollView.superview else { return }
                self.install(on: installView, observing: scrollView)
            }
        }

        func uninstall() {
            if let panRecognizer, let installedView {
                installedView.removeGestureRecognizer(panRecognizer)
            }
            panRecognizer = nil
            installedView = nil
            scrollView = nil
            activeSide = nil
            hasStartedInteraction = false
        }

        private func install(on installView: UIView, observing scrollView: UIScrollView) {
            self.scrollView = scrollView

            if installedView === installView, panRecognizer?.view === installView {
                return
            }

            if let panRecognizer, let installedView {
                installedView.removeGestureRecognizer(panRecognizer)
            }

            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false

            installView.addGestureRecognizer(recognizer)
            installedView = installView
            panRecognizer = recognizer
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard parent.isEnabled, let scrollView else {
                cancelActiveGesture()
                return
            }

            let location = visibleLocation(for: recognizer, in: scrollView)
            let translation = CGSize(recognizer.translation(in: scrollView))
            let velocity = recognizer.velocity(in: scrollView)

            switch recognizer.state {
            case .began:
                guard let side = activeSide else { return }
                hasStartedInteraction = true
                parent.onInteractionStarted()
                parent.onChanged(side, translation, location)
            case .changed:
                guard let side = activeSide else { return }
                if hasStartedInteraction == false {
                    hasStartedInteraction = true
                    parent.onInteractionStarted()
                }
                parent.onChanged(side, translation, location)
            case .ended:
                guard let side = activeSide else {
                    resetGestureState()
                    return
                }
                let predicted = parent.resolver.predictedEndTranslation(
                    translation: translation,
                    velocity: velocity
                )
                resetGestureState()
                parent.onEnded(side, translation, predicted, location)
            case .cancelled, .failed:
                cancelActiveGesture()
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard parent.isEnabled else { return false }
            guard let recognizer = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            guard let scrollView else { return false }

            let location = visibleLocation(for: recognizer, in: scrollView)
            let visibleBounds = CGRect(origin: .zero, size: scrollView.bounds.size)
            guard visibleBounds.contains(location) else { return false }
            guard isHandleLocation(location, in: effectiveContainerSize(for: scrollView)) == false else {
                activeSide = nil
                return false
            }

            let side = parent.resolver.liquidActivationSide(
                startLocation: location,
                translation: CGSize(recognizer.translation(in: scrollView)),
                velocity: recognizer.velocity(in: scrollView),
                containerSize: effectiveContainerSize(for: scrollView)
            )
            activeSide = side
            return side != nil
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard gestureRecognizer === panRecognizer else { return false }
            guard let scrollView else { return false }
            return otherGestureRecognizer === scrollView.panGestureRecognizer
        }

        private func cancelActiveGesture() {
            if let side = activeSide, hasStartedInteraction {
                parent.onCancelled(side)
            }
            resetGestureState()
        }

        private func resetGestureState() {
            activeSide = nil
            hasStartedInteraction = false
        }

        private func effectiveContainerSize(for scrollView: UIScrollView) -> CGSize {
            CGSize(
                width: max(parent.containerSize.width, scrollView.bounds.width, 1),
                height: max(parent.containerSize.height, scrollView.bounds.height, 1)
            )
        }

        private func visibleLocation(
            for recognizer: UIPanGestureRecognizer,
            in scrollView: UIScrollView
        ) -> CGPoint {
            let location = recognizer.location(in: scrollView)
            return CGPoint(
                x: location.x - scrollView.bounds.minX,
                y: location.y - scrollView.bounds.minY
            )
        }

        private func isHandleLocation(_ location: CGPoint, in size: CGSize) -> Bool {
            let hitRadius = HomeDayLiquidSwipeData.buttonRadius + 12
            return HomeDayLiquidSwipeSide.allCases.contains { side in
                let center = HomeDayLiquidSwipeData(side: side, containerSize: size).buttonCenter
                return hypot(location.x - center.x, location.y - center.y) <= hitRadius
            }
        }
    }
}

private extension CGSize {
    init(_ point: CGPoint) {
        self.init(width: point.x, height: point.y)
    }
}

private extension UIView {
    func nearestSuperview<T: UIView>(of type: T.Type) -> T? {
        var view = superview
        while let current = view {
            if let match = current as? T {
                return match
            }
            view = current.superview
        }
        return nil
    }
}
