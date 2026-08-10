import SwiftUI

/// The window's shared transition namespace.
///
/// This key and the source modifier below live in `LifeBoardUI` rather than in
/// the app's `ScreenScaffold` for one reason: shared primitives need to declare
/// themselves as a zoom source. `OpenRow` takes a `transitionSourceID`, so every
/// row that opens a detail gets spatial continuity by construction instead of by
/// each screen remembering to attach it — and a package type cannot read an
/// environment key defined in the app target.
///
/// The destination half (`lifeBoardZoomDestination`) stays in the app: it is
/// applied once per route by the shell, not by content.
public struct LifeBoardTransitionNamespaceKey: EnvironmentKey {
    public static let defaultValue: Namespace.ID? = nil
}

public extension EnvironmentValues {
    var lifeBoardTransitionNamespace: Namespace.ID? {
        get { self[LifeBoardTransitionNamespaceKey.self] }
        set { self[LifeBoardTransitionNamespaceKey.self] = newValue }
    }
}

private struct TransitionSourceModifier: ViewModifier {
    let id: String
    @Environment(\.lifeBoardTransitionNamespace) private var namespace

    @ViewBuilder
    func body(content: Content) -> some View {
        // No namespace installed means no `TransitionHost` above this view —
        // a preview, or a detached presentation. Skipping is correct; claiming
        // a source with no destination would be a silent no-op anyway.
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

public extension View {
    /// Marks this view as the origin of a zoom navigation transition. Pair with
    /// `lifeBoardZoomDestination(sourceID:)` on the pushed route.
    func lifeBoardTransitionSource(_ id: String) -> some View {
        modifier(TransitionSourceModifier(id: id))
    }
}
