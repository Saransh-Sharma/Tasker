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
        reduceMotion
            || reduceTransparency
            || scenePhase != .active
            || SignatureShaders.isReadyForRendering == false
    }

    func body(content: Content) -> some View {
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
