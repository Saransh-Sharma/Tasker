import CoreGraphics
import Foundation

/// The glyph-displacement maths behind `KineticTextRenderer`.
///
/// Split from the renderer because the renderer cannot be `public` without
/// dragging its `TextRenderer` and `Animatable` conformances public with it,
/// and the screenshot-stability contract the tests pin is this maths, not the
/// drawing.
public enum KineticTextMetrics {
    /// The furthest a glyph may travel. Small on purpose: this is a greeting,
    /// not a toy, and it has to stay legible mid-gesture.
    public static let maximumRise: CGFloat = 6
    /// How far the influence spreads either side of the finger, in points.
    public static let falloff: CGFloat = 46

    /// Vertical offset for a glyph centred at `glyphMidX`.
    ///
    /// A gaussian keeps the crest smooth: a linear falloff produces a visible
    /// kink at the edge of the influence radius.
    public static func rise(glyphMidX: CGFloat, touchX: CGFloat?, intensity: Double) -> CGFloat {
        guard let touchX, intensity > 0 else { return 0 }
        let distance = (glyphMidX - touchX) / falloff
        let bell = exp(-distance * distance)
        return -maximumRise * bell * CGFloat(min(max(intensity, 0), 1))
    }
}
