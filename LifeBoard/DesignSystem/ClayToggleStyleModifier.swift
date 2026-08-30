import SwiftUI

/// Applies the clay toggle to everything beneath it, behind its flag.
///
/// Split into a modifier rather than written inline at the shell root because
/// `toggleStyle` returns an opaque type: branching on the flag inside the shell
/// body would need `AnyView` and would erase the whole root's type on every
/// evaluation. A `ViewModifier` keeps the branch local to one small view.
struct ClayToggleStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if V2FeatureFlags.clayToggleStyleEnabled {
            content.toggleStyle(ClayToggleStyle())
        } else {
            content
        }
    }
}
