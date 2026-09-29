import Foundation
import Observation
import SwiftUI

/// What a person has done with one message's proposal and day cards: what
/// they selected, edited, set aside, applied, and can still undo.
///
/// This lived in `@State` on `MessageView`. Messages sit in a `LazyVStack`, so
/// scrolling a card far enough away tore the view down and its state with it:
/// an applied proposal came back reading "Apply", with its Undo gone. The
/// conversation owns these now, keyed by message id, and `MessageView` reads
/// and writes through the same property names it always used.
struct EvaProposalCardSession {
    var undoExpiredLogged = false
    var selectedEvaCardIDs: Set<UUID> = []
    var expandedEvaCardID: UUID?
    var evaCardOverrides: [UUID: EvaProposalCardOverride] = [:]
    var editingEvaCardID: UUID?
    var notNowEvaCardIDs: Set<UUID> = []
    var dismissedEvaRunIDs: Set<UUID> = []
    var evaApplyMessage: String?
    var isApplyingEvaProposal = false
    var appliedEvaRunIDs: Set<UUID> = []
    var appliedEvaRunIDByPayloadRunID: [UUID: UUID] = [:]
    var appliedEvaUndoExpiresAtByPayloadRunID: [UUID: Date] = [:]
    var pendingEvaApplyConfirmationIDs: Set<UUID>?
    var isUndoingEvaRun = false
    var dayTaskOverlayStates: [UUID: EvaDayTaskOverlayState] = [:]
    var dayHabitOverlayStates: [UUID: EvaDayHabitOverlayState] = [:]
    var dayOverviewNotices: [String] = []
    var createdTaskReferencesByCardID: [UUID: EvaRecordReference] = [:]
}

@MainActor
@Observable
final class EvaProposalCardSessions {
    private var sessions: [UUID: EvaProposalCardSession] = [:]

    subscript(messageID: UUID) -> EvaProposalCardSession {
        get { sessions[messageID] ?? EvaProposalCardSession() }
        set { sessions[messageID] = newValue }
    }
}

private struct EvaProposalCardSessionsKey: EnvironmentKey {
    static let defaultValue: EvaProposalCardSessions? = nil
}

extension EnvironmentValues {
    /// Installed by `ConversationView`. `nil` elsewhere (previews, a message
    /// rendered on its own), where `MessageView` keeps a private store.
    var evaProposalCardSessions: EvaProposalCardSessions? {
        get { self[EvaProposalCardSessionsKey.self] }
        set { self[EvaProposalCardSessionsKey.self] = newValue }
    }
}
