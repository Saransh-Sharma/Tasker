import SwiftUI

/// Which ritual a chat turn asks for, from a slash command or a plain
/// phrase. Runs before generation, so "make today fit" opens Make It Fit
/// instead of being answered as prose. Anything else is not a ritual and the
/// turn goes on to the normal router untouched.
enum EvaRitualKind: String, Codable, Equatable, Identifiable, Sendable {
    case makeItFit
    case frictionDetective
    case weeklyReset

    var id: String { rawValue }

    var slashCommand: String {
        switch self {
        case .makeItFit: "/fit"
        case .frictionDetective: "/friction"
        case .weeklyReset: "/reset"
        }
    }

    var title: String {
        switch self {
        case .makeItFit: String(localized: "Make it fit")
        case .frictionDetective: String(localized: "Friction detective")
        case .weeklyReset: String(localized: "Weekly reset")
        }
    }

    var systemImage: String {
        switch self {
        case .makeItFit: "arrow.down.right.and.arrow.up.left"
        case .frictionDetective: "magnifyingglass"
        case .weeklyReset: "arrow.counterclockwise"
        }
    }
}

struct EvaRitualRequest: Equatable, Identifiable, Sendable {
    let kind: EvaRitualKind
    /// `/friction <task>`: the task the person named, if any.
    let argument: String?
    var id: String { kind.rawValue + "|" + (argument ?? "") }
}

enum EvaRitualPhraseRouter {
    /// Natural phrases, lowercased; matched as substrings of the whole turn.
    static let phrases: [(EvaRitualKind, [String])] = [
        (.makeItFit, ["make today fit", "make it fit", "today doesn't fit", "today does not fit", "too much for today", "fit today"]),
        (.frictionDetective, ["what keeps getting in the way", "keeps getting in the way", "why do i keep putting off", "keep putting off", "friction detective"]),
        (.weeklyReset, ["weekly reset", "reset my week", "reset the week", "start the week over"]),
    ]

    static func match(_ turn: String) -> EvaRitualRequest? {
        let trimmed = turn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        let lowered = trimmed.lowercased()
        for kind in [EvaRitualKind.makeItFit, .frictionDetective, .weeklyReset] {
            let command = kind.slashCommand
            if lowered == command || lowered.hasPrefix(command + " ") {
                let argument = String(trimmed.dropFirst(command.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                return EvaRitualRequest(kind: kind, argument: argument.isEmpty ? nil : argument)
            }
        }
        // Plain phrases only when the turn is short enough to be the ask
        // itself, not a paragraph that happens to contain the words.
        guard lowered.count <= 80 else { return nil }
        for (kind, needles) in phrases where needles.contains(where: { lowered.contains($0) }) {
            return EvaRitualRequest(kind: kind, argument: nil)
        }
        return nil
    }
}

/// What the shell hands the chat so a ritual can open over it. `makeView`
/// returns nil when the ritual's double gate (staged flag and signed config)
/// is off, and `isAvailable` says so up front so the turn can fall through
/// to prose instead of opening an empty cover.
struct EvaRitualPresenter {
    let isAvailable: @MainActor (EvaRitualKind) -> Bool
    let makeView: @MainActor (EvaRitualRequest, _ onClose: @escaping () -> Void) -> AnyView?
}

extension EnvironmentValues {
    @Entry var evaRitualPresenter: EvaRitualPresenter? = nil
}
