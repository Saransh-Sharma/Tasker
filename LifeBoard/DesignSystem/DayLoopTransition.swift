import SwiftUI

// Split out of `LiquidLevel` so the level itself could move into
// `LifeBoardUI`. This resolver takes an `AppRoute`, which is the app router's
// vocabulary — features never import it, so neither may the UI package.
/// Shared identifiers for the zoom transition into the day-loop rituals.
///
/// Named in one place because the source lives on Home and the destination
/// lives in the shell's route switch — two files that otherwise share nothing.
/// A typo in either would silently fall back to a plain push, which looks like
/// "the animation didn't work" rather than "the ids don't match".
public enum DayLoopTransition {
    public static let close = "route.dayClose"
    public static let open = "route.dayOpen"

    /// Resolves the id for a ritual route. Any other route gets the close id
    /// rather than crashing — a wrong-but-harmless transition beats a trap.
    public static func id(for route: AppRoute) -> String {
        switch route {
        case .dayOpen: open
        default: close
        }
    }
}
