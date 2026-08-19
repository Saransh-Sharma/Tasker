import CoreGraphics
import Foundation

/// Where everything sits, as a pure function of the canvas.
///
/// Deterministic on purpose. A physics simulation or a collision solver would
/// place these nodes differently on every launch, which makes a screenshot test
/// meaningless, a VoiceOver description unstable, and a "settled" state
/// something the map only approximates. For two to five nodes an anchor family
/// is not a compromise — it is simply the right answer, and it costs nothing to
/// draw the same map twice.
enum LifeWeaveGeometry {

    /// The quiet origin, low in the field so the nodes rest above it.
    ///
    /// Was 0.54, which put it *inside* the node band: at a realistic map height
    /// of ~190 points the nodes at y 0.42 landed 23 points from the anchor and
    /// covered it. The map has to be readable at the height it actually gets,
    /// not at the height the anchor table imagines.
    static let nowAnchor = CGPoint(x: 0.5, y: 0.80)

    /// How much closer to Now the primary area sits, in points.
    ///
    /// Deliberately small. Emphasis here means *attention*, not value: the
    /// primary area does not double in size, gain a rank badge, or acquire a
    /// score, because none of those are things LifeBoard is willing to say about
    /// a part of somebody's life.
    static let primaryPullPoints: CGFloat = 12

    /// Normalised anchor families for each supported count.
    ///
    /// Asymmetric on purpose past three: a perfect polygon reads as a diagram of
    /// something, and the map is meant to read as a person's own arrangement.
    static func anchors(for count: Int) -> [CGPoint] {
        switch count {
        case ...0: []
        case 1: [CGPoint(x: 0.50, y: 0.30)]
        case 2: [CGPoint(x: 0.22, y: 0.34), CGPoint(x: 0.78, y: 0.30)]
        case 3: [
            CGPoint(x: 0.16, y: 0.42),
            CGPoint(x: 0.50, y: 0.16),
            CGPoint(x: 0.84, y: 0.40)
        ]
        case 4: [
            CGPoint(x: 0.15, y: 0.20),
            CGPoint(x: 0.62, y: 0.13),
            CGPoint(x: 0.20, y: 0.55),
            CGPoint(x: 0.83, y: 0.46)
        ]
        default: [
            CGPoint(x: 0.14, y: 0.18),
            CGPoint(x: 0.58, y: 0.11),
            CGPoint(x: 0.86, y: 0.34),
            CGPoint(x: 0.20, y: 0.54),
            CGPoint(x: 0.66, y: 0.56)
        ]
        }
    }

    /// Resolves an area's centre in points.
    ///
    /// `isMirrored` mirrors the field for right-to-left layout. The map has no
    /// reading order, but its relationship to the choices beside it does, and a
    /// left-anchored node next to a right-anchored list reads as unrelated.
    static func areaCenter(
        index: Int,
        count: Int,
        isPrimary: Bool,
        in size: CGSize,
        isMirrored: Bool
    ) -> CGPoint {
        let family = anchors(for: count)
        guard family.indices.contains(index) else { return point(nowAnchor, in: size, isMirrored: isMirrored) }

        var anchor = family[index]
        // A tiny stable offset so five nodes never look mechanically placed.
        // Seeded by index rather than by `hashValue`, which Swift randomises per
        // process — the same map would land differently on every launch.
        let jitter = deterministicJitter(seed: index &* 7 &+ count)
        anchor.x += jitter.dx
        anchor.y += jitter.dy
        // Clamped so the wobble can never push a node under the top edge or off
        // the side, where its label would clip.
        anchor.x = min(max(0.12, anchor.x), 0.88)
        anchor.y = min(max(0.10, anchor.y), 0.62)

        var resolved = point(anchor, in: size, isMirrored: isMirrored)
        if isPrimary {
            let now = point(nowAnchor, in: size, isMirrored: isMirrored)
            resolved = pull(resolved, towards: now, by: primaryPullPoints)
        }
        return resolved
    }

    static func now(in size: CGSize, isMirrored: Bool) -> CGPoint {
        point(nowAnchor, in: size, isMirrored: isMirrored)
    }

    /// One operating strand: a gentle curve sweeping through the Now region.
    ///
    /// Not a spoke. Spokes radiating from a centre draw a hub-and-wheel, which
    /// says the middle owns the edges; a strand passing *through* says the five
    /// ways of working cross the same life. The curves extend past the canvas so
    /// their ends are never visible, which is what stops them reading as items.
    static func strandPath(index: Int, of total: Int, in size: CGSize, isMirrored: Bool) -> CGPath {
        let now = self.now(in: size, isMirrored: isMirrored)
        let span = max(size.width, size.height) * 1.4
        let angle = (Double.pi / Double(max(1, total))) * Double(index) - Double.pi / 2.6
        let direction = CGVector(dx: cos(angle), dy: sin(angle))
        let normal = CGVector(dx: -direction.dy, dy: direction.dx)

        let start = CGPoint(x: now.x - direction.dx * span, y: now.y - direction.dy * span)
        let end = CGPoint(x: now.x + direction.dx * span, y: now.y + direction.dy * span)

        // Alternating curvature is what makes five curves read as a weave rather
        // than a fan. The amplitude stays well under the node radius so a strand
        // never crosses a label.
        // Proportional to the short side, not the height alone: on a wide short
        // band, curvature scaled by height is invisible and five curves through
        // one point read as a spoked wheel rather than a weave.
        let bow = (index.isMultiple(of: 2) ? 1.0 : -1.0) * min(size.width, size.height) * 0.34
        let control1 = CGPoint(
            x: now.x - direction.dx * span * 0.35 + normal.dx * bow,
            y: now.y - direction.dy * span * 0.35 + normal.dy * bow
        )
        let control2 = CGPoint(
            x: now.x + direction.dx * span * 0.35 - normal.dx * bow,
            y: now.y + direction.dy * span * 0.35 - normal.dy * bow
        )

        let path = CGMutablePath()
        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: control2)
        return path
    }

    /// The thread tying one area into the weave.
    ///
    /// Drawn once when the area is chosen and retracted when it is deselected;
    /// it does not animate at rest. The screen already has exactly one ambient
    /// timeline — the hero video — and `DESIGN.md` allows only that one.
    static func threadPath(from area: CGPoint, to now: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: area)
        // Perpendicular bow proportional to length, so a near node curves gently
        // and a far one curves more — the thread reads as slack, not as a wire.
        let dx = now.x - area.x
        let dy = now.y - area.y
        let length = max(1, sqrt(dx * dx + dy * dy))
        let bow = min(length * 0.18, 34)
        let midpoint = CGPoint(x: (area.x + now.x) / 2, y: (area.y + now.y) / 2)
        let control = CGPoint(
            x: midpoint.x + (-dy / length) * bow,
            y: midpoint.y + (dx / length) * bow
        )
        path.addQuadCurve(to: now, control: control)
        return path
    }

    // MARK: - Helpers

    private static func point(_ normalized: CGPoint, in size: CGSize, isMirrored: Bool) -> CGPoint {
        let x = isMirrored ? 1 - normalized.x : normalized.x
        return CGPoint(x: x * size.width, y: normalized.y * size.height)
    }

    private static func pull(_ origin: CGPoint, towards target: CGPoint, by distance: CGFloat) -> CGPoint {
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > distance else { return origin }
        return CGPoint(x: origin.x + dx / length * distance, y: origin.y + dy / length * distance)
    }

    /// A small, stable, and entirely reproducible wobble.
    private static func deterministicJitter(seed: Int) -> (dx: Double, dy: Double) {
        // A tiny integer hash rather than `Hasher`, whose seed changes per
        // process. The values are bounded to ±0.018 of the canvas — visible as
        // "not perfectly aligned", never as a different layout.
        var value = UInt64(bitPattern: Int64(seed &* 2_654_435_761))
        value ^= value >> 33
        value = value &* 0xFF51_AFD7_ED55_8CCD
        value ^= value >> 33
        let dx = Double(value % 1_000) / 1_000 - 0.5
        let dy = Double((value >> 16) % 1_000) / 1_000 - 0.5
        return (dx * 0.036, dy * 0.036)
    }
}
