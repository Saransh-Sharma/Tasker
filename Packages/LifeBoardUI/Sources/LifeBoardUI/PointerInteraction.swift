import SwiftUI

/// Pointer and hit-target affordances for iPad trackpads and the Mac.
///
/// `DESIGN.md` iPad: "Pointer targets, hover treatment, keyboard focus, and root
/// shortcuts are part of the design." Rows and cards across Home, Plan and
/// Habits had none of the first two — plain-style buttons and tap gestures give
/// no hover feedback, and many controls drew a 22–34 point target.
public extension View {
    /// Grows the tappable area to at least `size` points in both directions
    /// without changing what is drawn.
    func minimumHitTarget(_ size: CGFloat = 44) -> some View {
        frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
    }

    /// A card or row that responds to the pointer the way system list rows do.
    func hoverableCard(cornerRadius: CGFloat = 20) -> some View {
        contentShape(.hoverEffect, RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .hoverEffect(.highlight)
    }
}
