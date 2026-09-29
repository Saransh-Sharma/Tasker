import Foundation
import LifeBoardTokens

/// When each beat of the end-of-session reflection appears, per comfort
/// profile. The sequence is boundary motion — it plays once after the ending
/// is persisted and settles — and it never gates input: Done and Skip are live
/// from the first frame, the delays only stage what the person sees.
///
/// `DESIGN.md`: signature moments stay under roughly 800 ms and never block the
/// next action; Calm is crossfades only; Playful may be springier but not
/// slower.
struct FocusReflectionTimeline: Equatable {
    /// The dial arc sweeps closed, then the tick draws.
    let tickDelay: TimeInterval
    /// The "25 min on <task>" line rolls in.
    let numberDelay: TimeInterval
    /// The energy choice and the one-line note appear.
    let promptDelay: TimeInterval
    /// How long the tick takes to draw.
    let tickDuration: TimeInterval

    /// The last beat's start; the whole sequence is on screen after this.
    var total: TimeInterval { promptDelay }

    static func resolve(comfort: ComfortProfile, reduceMotion: Bool) -> FocusReflectionTimeline {
        if reduceMotion || comfort == .calm {
            // Everything at once, as a crossfade. Nothing is staged for someone
            // who asked for less motion, and a paused-looking screen would read
            // as "did it save?".
            return FocusReflectionTimeline(tickDelay: 0, numberDelay: 0, promptDelay: 0, tickDuration: 0)
        }
        // Balanced and Playful share the beats; Playful's difference is spring
        // texture in the controls themselves, not longer waits.
        return FocusReflectionTimeline(tickDelay: 0.30, numberDelay: 0.48, promptDelay: 0.62, tickDuration: 0.32)
    }

    /// The whole sequence must land inside the signature-moment budget.
    static let budget: TimeInterval = 0.8
}
