import LifeBoardTokens
import SwiftUI

/// The arriving root settling after a dock change.
///
/// `DESIGN.md` gives motion the grammar **source → travel → settle**, and names
/// the dock's contract explicitly: "Root transitions originate from the selected
/// target and settle before secondary content animates." The shell had the
/// source (the dock slot) and the travel (a horizontal offset), but nothing that
/// made the travel say where it came from — a uniform slide is the same picture
/// whichever target you pressed.
///
/// This adds the missing half: a vertical shear across the direction of travel,
/// strongest at the edge furthest from the departing dock slot, decaying to
/// identity. It is the one new Metal function this program adds, because every
/// other transition it touches already had an effect named for it in
/// `DESIGN.md`'s vocabulary and simply lacked call sites.
///
/// Bounded to twelve points and eased so most of it is spent in the first third
/// of the travel. If it is ever legible as distortion on text, it is wrong.
private struct RootTravelModifier: ViewModifier {
    let origin: Double
    let direction: Double
    let progress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    private var usesFallback: Bool {
        MotionOverride.resolve(reduceMotion)
            || reduceTransparency
            || scenePhase != .active
            || SignatureShaders.isReadyForRendering == false
    }

    func body(content: Content) -> some View {
        // The shear is switched off. It is the only Metal effect that runs
        // during exactly the tab-switch window and at no other time, which makes
        // it the prime suspect for the full-screen flat-colour frame seen on
        // every root change, on device and in the Simulator alike.
        //
        // `distortionEffect` forces the whole screen-sized root — atmosphere
        // included — into an offscreen render target for the duration of the
        // travel. A momentarily wrong buffer there is full-screen by
        // construction, and that matches the report exactly: both roots visible
        // at partial opacity over one flat field, while the dock stays crisp
        // because it is an overlay outside the roots and so outside the
        // distorted layer.
        //
        // What it is *not*: the daypart scene. The flash was reported as bright
        // yellow while the night phase was on screen, and night's artwork and
        // `SceneHex.nightFallback` (#343545) are both dark.
        //
        // Removing it costs an accent, not the transition — the shell's own
        // offset slide and the dock's selection movement are untouched. The
        // shader, its `functionNames` entry and the call sites all remain, so
        // restoring this is deleting the early return below.
        content
    }

    /// The shear as it was, kept for restoration. See `body(content:)`.
    @ViewBuilder
    private func shearedContent(_ content: Content) -> some View {
        if usesFallback || progress >= 0.999 || direction == 0 {
            // The plain offset transition the shell already performs remains
            // fully intact underneath. Removing the shear removes an accent,
            // never the sense of travel.
            content
        } else {
            content.visualEffect { effect, proxy in
                effect.distortionEffect(
                    Shader(
                        function: ShaderFunction(
                            library: .default,
                            name: "LifeBoardRootTravelShear"
                        ),
                        arguments: [
                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                            .float(Float(origin)),
                            .float(Float(direction)),
                            .float(Float(progress))
                        ]
                    ),
                    maxSampleOffset: CGSize(width: 0, height: 12)
                )
            }
        }
    }
}

public extension View {
    /// - Parameters:
    ///   - origin: The departing dock slot's x-centre, 0...1.
    ///   - direction: -1 or +1, matching the root's travel direction.
    ///   - progress: 0 at the start of the transition, 1 when settled.
    func lifeboardRootTravel(
        origin: Double,
        direction: Double,
        progress: Double
    ) -> some View {
        modifier(RootTravelModifier(
            origin: origin,
            direction: direction,
            progress: progress
        ))
    }
}
