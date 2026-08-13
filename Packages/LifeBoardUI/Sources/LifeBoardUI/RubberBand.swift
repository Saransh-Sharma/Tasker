import CoreGraphics
import Foundation

/// Resistance curves for direct manipulation.
///
/// `DESIGN.md`: "Objects follow the finger… Drag follows the finger, reveals
/// direction meaning before threshold, and settles or returns predictably."
/// A drag that tracks the finger 1:1 forever has no felt ceiling, and one that
/// hard-stops at a limit reads as a bug. Both are solved by compressing travel
/// past a boundary rather than clamping it.
///
/// Pure and synchronous so it can be unit-tested and reused from a gesture
/// callback without touching the main actor. Three call sites share it: the
/// magnetic toggle below, the Focus dial's scrub-past-maximum, and the
/// composer's over-scroll.
public enum RubberBand {
    /// Linear inside `limit`, logarithmically compressed beyond it.
    ///
    /// The curve is chosen so the first few points past the limit still move
    /// visibly — a drag that stops dead at the boundary reads as a broken
    /// gesture rather than as a ceiling.
    ///
    /// - Parameters:
    ///   - raw: Raw translation from the gesture, in points.
    ///   - limit: Where resistance begins, in points. Must be > 0.
    ///   - resistance: 0 gives a hard stop at `limit`; 1 gives gentle
    ///     compression. Values outside 0...1 are clamped.
    /// - Returns: The offset to actually apply, always with `raw`'s sign.
    public static func offset(
        _ raw: CGFloat,
        limit: CGFloat,
        resistance: CGFloat = 0.55
    ) -> CGFloat {
        guard limit > 0 else { return 0 }
        let magnitude = abs(raw)
        guard magnitude > limit else { return raw }

        let clampedResistance = max(0, min(1, resistance))
        let excess = magnitude - limit
        // log10 keeps the tail flat enough that the surface cannot be dragged
        // off screen no matter how far the finger travels.
        let compressed = log10(1 + excess / 10) * (limit * 0.5 * clampedResistance)
        return (limit + compressed) * (raw < 0 ? -1 : 1)
    }

    /// Fraction of the way to a threshold, clamped to 0...1.
    ///
    /// Direction meaning has to be legible *before* the threshold, so callers
    /// need progress rather than a crossed/not-crossed boolean.
    public static func progress(_ raw: CGFloat, threshold: CGFloat) -> CGFloat {
        guard threshold > 0 else { return 0 }
        return max(0, min(1, abs(raw) / threshold))
    }
}
