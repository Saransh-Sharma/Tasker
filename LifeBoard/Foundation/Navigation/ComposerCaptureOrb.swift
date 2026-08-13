import SwiftUI

/// The composer's compressed shape: a 48-point capture orb.
///
/// `DESIGN.md:387` sizes this exactly — the capsule is 52 points, the orb is 48 —
/// and the four-point difference matters more than it sounds. The shell measures
/// its own chrome height with `onGeometryChange` and reserves it as a bottom
/// safe-area inset on every root, so shrinking the composer automatically gives
/// content four more points before the dock, with no constant to keep in sync.
///
/// A separate type rather than a branch inside `LifeThreadComposerHost.host`:
/// that body already assembles nine conditional sections, and this repo crashes
/// at launch under `-Onone` when a body walks too deep. One more inline branch
/// there is the shape that tips it.
struct ComposerCaptureOrb: View {
    let morphNamespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: onTap) {
                Image(systemName: "plus")
                    .font(Typography.body().weight(.semibold))
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .lifeBoardGlassSurface(cornerRadius: 24, interactive: true)
            .overlay {
                Circle()
                    .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
            }
            // No ad-hoc shadow here, deliberately. The token law reserves
            // shadows for DesignSystem components, and this needs none: the orb
            // is drawn inside the shell's `GlassEffectContainer` alongside the
            // dock, so Liquid Glass already separates it from the content it
            // floats over. Copying the capsule's hand-rolled shadow would have
            // added a second, differently-tuned elevation to the same plane.
            // The same identity the capsule carries, so this is one surface
            // changing shape rather than two views trading places.
            .matchedGeometryEffect(id: "foundation.composer.capsule", in: morphNamespace)
            .lifeBoardGlassIdentity(.capture)
            .lifeBoardPressResponse(.control, haptic: nil)
            // The label names the destination, not the shape. "Collapsed
            // composer" would describe our layout problem rather than what
            // happens when the control is activated.
            .accessibilityLabel("Ask Eva or capture")
            .accessibilityIdentifier("lifeThread.composer.orb")
        }
        // Trailing, because the send control the capsule ends with is trailing.
        // Restoring to the capsule then keeps the primary action under the same
        // thumb rather than sweeping it across the screen.
        .padding(.trailing, 4)
    }
}
