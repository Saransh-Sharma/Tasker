import SwiftUI

/// A raised clay card.
///
/// This was called `GlassCard`, and it was not glass. It filled
/// `Color.lifeboard(.surfacePrimary)`, stroked a border and dropped a shadow —
/// a flat rectangle, drawn by hand, bypassing `ClaySurfaceModifier` entirely.
/// Fifteen files reached for it believing they were getting the app's glass
/// material, which is how a design system ends up with nine ways to draw a
/// card: the names stop describing what the code does, so people pick by name.
///
/// It draws clay now, through the one primitive, so it inherits the specular
/// rim, the contact shade, the pressed state and the Reduce Transparency
/// fallback along with everything else.
///
/// `usesMaterialBackground` and `borderColor` are retained for source
/// compatibility and no longer do anything: clay owns its own boundary, and a
/// caller-supplied stroke would put a second edge on it.
struct ClaySurfaceCard<Content: View>: View {
    var cornerRadius: CGFloat = RadiusTokens.card
    var borderColor: Color = ClayColorTokens.glassBorder
    var fill: Color = ClayColorTokens.glass
    var shadow: ShadowToken? = ShadowTokens.card
    var usesMaterialBackground = true
    @ViewBuilder let content: Content

    var body: some View {
        content
            .lifeBoardClaySurface(
                .raised,
                cornerRadius: cornerRadius,
                fill: usesMaterialBackground ? nil : fill
            )
    }
}

/// The old name. `ClaySurfaceCard` is the same view under a name that says what
/// it draws.
@available(*, deprecated, renamed: "ClaySurfaceCard")
typealias GlassCard = ClaySurfaceCard
