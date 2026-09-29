import Foundation

/// Turns a typed launch context into the slash command whose result becomes
/// the thread's context attachment. Records, not prose: the envelope receives
/// the same records the person could have asked for by hand, through the
/// same fail-closed budget and the same journal consent gate. Kinds with no
/// slash equivalent yet (a single task, habit or journal day) attach nothing
/// and leave the composer's prefill to carry the ask.
enum EvaLaunchContextMapping {
    static func invocation(for context: EvaLaunchContext) -> SlashCommandInvocation? {
        switch context.kind {
        case .day:
            return SlashCommandInvocation(id: .today)
        case .project:
            guard let id = context.recordIDs.first else { return nil }
            return SlashCommandInvocation(id: .project, resolvedArgument: id.uuidString)
        case .insight:
            // Insights already lists its evidence; the recent window is the
            // closest record set the planner can attach.
            return SlashCommandInvocation(id: .recent)
        case .task, .habit, .journalDay:
            return nil
        }
    }
}
