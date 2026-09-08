import SwiftUI

enum ComposerScrollPositionBand: Equatable, Sendable {
    case top
    case middle
    case compressionRange
}

/// The small, decision-level portion of scroll state that SwiftUI may observe.
///
/// Exact offsets deliberately do not live here. The composer only needs to know
/// when the top restore boundary is crossed and when one purposeful downward
/// gesture reaches the compression boundary. Publishing every point between
/// those boundaries invalidated the complete composer and atmosphere trees at
/// the display refresh rate.
struct ComposerScrollSample: Equatable, Sendable {
    var positionBand: ComposerScrollPositionBand = .top
    var normalizedOffset: CGFloat = 0
    var isTrackingDownward = false
    var interactionGeneration = 0
    var resetGeneration = 0
}

/// Scroll state for the composer's compression decision, owned by the shell.
///
/// The composer is drawn once, at shell level, as an overlay above five separate
/// root scroll views it has no reference to. This is the narrow channel between
/// them: a root opts in with `lifeBoardReportsComposerScroll()`, the shell reads
/// the result. Nothing else about a root leaks upward.
@MainActor
@Observable
final class ComposerScrollObserver {
    private(set) var sample = ComposerScrollSample()
    private(set) var decisionPublicationCount = 0

    @ObservationIgnored private var exactContentOffset: CGFloat = 0
    @ObservationIgnored private var interactionIsActive = false
    @ObservationIgnored private var emittedCompressionIntent = false
    @ObservationIgnored private var scrollSessionInterval: PerformanceInterval?

    /// Compatibility accessors keep `ComposerCompressionPolicy` pure while the
    /// observed input is now normalized to its two decision boundaries.
    var contentOffset: CGFloat { sample.normalizedOffset }
    var isTrackingDownward: Bool { sample.isTrackingDownward }

    /// Read only by the atmosphere's clock-driven motion leaf. Because the
    /// backing value is observation-ignored, per-pixel writes do not schedule a
    /// SwiftUI update; the existing ambient timeline samples the latest value.
    var sampledParallaxContentOffset: CGFloat { exactContentOffset }

    func report(offset: CGFloat) {
        // Negative offsets are rubber-band overscroll at the top; treating them
        // as travel would let a bounce read as purposeful downward scrolling.
        let clamped = max(0, offset)
        let isMovingDownward = clamped > exactContentOffset
        exactContentOffset = clamped

        let band: ComposerScrollPositionBand
        let normalizedOffset: CGFloat
        if clamped <= ComposerCompressionPolicy.restoreThreshold {
            band = .top
            normalizedOffset = ComposerCompressionPolicy.restoreThreshold
        } else if clamped >= ComposerCompressionPolicy.compressThreshold {
            band = .compressionRange
            normalizedOffset = ComposerCompressionPolicy.compressThreshold
        } else {
            band = .middle
            normalizedOffset = (ComposerCompressionPolicy.restoreThreshold
                + ComposerCompressionPolicy.compressThreshold) / 2
        }

        var next = sample
        if next.positionBand != band {
            next.positionBand = band
            next.normalizedOffset = normalizedOffset
            if band == .top { next.isTrackingDownward = false }
        }

        if interactionIsActive,
           isMovingDownward,
           band == .compressionRange,
           emittedCompressionIntent == false {
            emittedCompressionIntent = true
            next.isTrackingDownward = true
            next.interactionGeneration &+= 1
        }

        publish(next)
    }

    func beginTracking() {
        interactionIsActive = true
        emittedCompressionIntent = false
        if scrollSessionInterval == nil {
            scrollSessionInterval = PerformanceTrace.begin("FoundationScrollSession")
        }
    }

    /// The finger left the glass. Whatever the content does now is momentum, and
    /// `ComposerCompressionPolicy` requires intent, so tracking ends here.
    func endTracking() {
        interactionIsActive = false
        emittedCompressionIntent = false
        if let scrollSessionInterval {
            PerformanceTrace.end(scrollSessionInterval)
            self.scrollSessionInterval = nil
        }
        guard sample.isTrackingDownward else { return }
        var next = sample
        next.isTrackingDownward = false
        publish(next)
    }

    /// A root switch must not carry the previous root's scroll position into the
    /// next one — the composer would arrive already compressed over a screen
    /// sitting at its top.
    func reset() {
        if let scrollSessionInterval {
            PerformanceTrace.end(scrollSessionInterval)
            self.scrollSessionInterval = nil
        }
        exactContentOffset = 0
        interactionIsActive = false
        emittedCompressionIntent = false
        var next = ComposerScrollSample()
        next.resetGeneration = sample.resetGeneration &+ 1
        publish(next)
    }

    private func publish(_ next: ComposerScrollSample) {
        guard sample != next else { return }
        sample = next
        decisionPublicationCount &+= 1
        PerformanceTrace.event("ComposerScrollDecisionPublished")
    }
}

private struct ComposerScrollObserverKey: EnvironmentKey {
    static let defaultValue: ComposerScrollObserver? = nil
}

extension EnvironmentValues {
    /// Published by the shell, read by whichever root scroll view opts in.
    ///
    /// The environment rather than an initializer parameter: the three roots
    /// that need this are `AdaptiveHome`, `PlanRootView` and
    /// `TrackFoundationRootView`, whose initializers already take between six
    /// and sixteen dependencies each. Threading one more presentation detail
    /// through all of them — and through the route factory that builds them —
    /// would couple three feature modules to a shell-owned animation concern.
    var lifeBoardComposerScrollObserver: ComposerScrollObserver? {
        get { self[ComposerScrollObserverKey.self] }
        set { self[ComposerScrollObserverKey.self] = newValue }
    }
}

private struct ComposerScrollReporter: ViewModifier {
    @Environment(\.lifeBoardComposerScrollObserver) private var observer

    @ViewBuilder
    func body(content: Content) -> some View {
        if let observer {
            reporting(content, observer: observer)
        } else {
            content
        }
    }

    private func reporting(_ content: Content, observer: ComposerScrollObserver) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                observer.report(offset: offset)
            }
            .onScrollPhaseChange { _, phase in
                // `.interacting` is the only phase with a finger in it.
                // Deceleration, animation and idle all end tracking.
                if phase == .interacting {
                    observer.beginTracking()
                } else {
                    observer.endTracking()
                }
            }
    }
}

extension View {
    /// Opts a root's scroll view into driving composer compression.
    ///
    /// Attach to the `ScrollView` itself, not to its content: the geometry this
    /// reads is the scroll view's, and a content-level attachment reports the
    /// position of whatever subview happened to receive the modifier.
    ///
    /// A no-op wherever the shell has not published an observer — regular width,
    /// presented sheets, previews — so it is safe to attach unconditionally.
    func lifeBoardReportsComposerScroll() -> some View {
        modifier(ComposerScrollReporter())
    }
}
