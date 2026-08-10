import SwiftUI

/// Scroll state for the composer's compression decision, owned by the shell.
///
/// The composer is drawn once, at shell level, as an overlay above five separate
/// root scroll views it has no reference to. This is the narrow channel between
/// them: a root opts in with `lifeBoardReportsComposerScroll()`, the shell reads
/// the result. Nothing else about a root leaks upward.
@MainActor
@Observable
final class ComposerScrollObserver {
    private(set) var contentOffset: CGFloat = 0
    private(set) var isTrackingDownward = false

    func report(offset: CGFloat) {
        // Negative offsets are rubber-band overscroll at the top; treating them
        // as travel would let a bounce read as purposeful downward scrolling.
        let clamped = max(0, offset)
        isTrackingDownward = clamped > contentOffset
        contentOffset = clamped
    }

    /// The finger left the glass. Whatever the content does now is momentum, and
    /// `ComposerCompressionPolicy` requires intent, so tracking ends here.
    func endTracking() {
        isTrackingDownward = false
    }

    /// A root switch must not carry the previous root's scroll position into the
    /// next one — the composer would arrive already compressed over a screen
    /// sitting at its top.
    func reset() {
        contentOffset = 0
        isTrackingDownward = false
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

    func body(content: Content) -> some View {
        guard let observer else { return AnyView(content) }
        return AnyView(reporting(content, observer: observer))
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
                if phase != .interacting {
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
