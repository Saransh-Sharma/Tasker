import Foundation

/// A presentation waiting for the host to be free.
///
/// This was a two-case enum with a priority ordering, because the
/// established-workspace prompt (priority 1) and the full flow (priority 2)
/// could both be queued and the higher one had to win. The prompt is gone: an
/// existing workspace now receives a dismissible invitation on Home rather than
/// a modal that has to compete for the launch window, so there is only ever one
/// kind of thing to present.
///
/// Kept as an enum rather than collapsed to a bare `String` so the queue's
/// `Equatable` de-duplication and its analytics label stay where they were, and
/// so a second presentation kind can return without reshaping the queue.
enum PendingOnboardingPresentation: Equatable {
    case fullFlow(source: String)

    var priority: Int {
        switch self {
        case .fullFlow:
            return 2
        }
    }

    var analyticsLabel: String {
        switch self {
        case .fullFlow:
            return "full_flow"
        }
    }
}
