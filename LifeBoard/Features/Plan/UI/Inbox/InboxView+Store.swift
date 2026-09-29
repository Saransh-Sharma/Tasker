import Foundation
import Observation

/// The Inbox: untriaged captures and tasks, and the decisions that clear them.
///
/// Reads through `InboxReader` and writes through `InboxTriageMutation`
/// translated into the canonical `PlanMutation` ledger, so every decision here
/// produces the same receipt and one-step Undo as any other planning change.
@MainActor
@Observable
final class InboxStore {
    private(set) var items: [InboxItem] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false
    /// Set after a triage applies; drives the Undo affordance.
    private(set) var lastReceipt: PlanMutationReceipt?
    private(set) var lastSummary: String?

    func clearLastSummary() { lastSummary = nil }
    private(set) var isMutating = false
    private(set) var mutationError: String?

    private struct CommitUndoState {
        let mutation: InboxTriageMutation
        let capture: PendingCapture
    }

    private var commitUndoState: CommitUndoState?
    private var mergeUndoState: InboxMergeReceipt?

    var scope: InboxQuery.Scope = .untriaged {
        didSet { guard oldValue != scope else { return }; Task { await load() } }
    }

    private let reader: InboxReader
    private let planningRepository: any PlanningRepository
    private let mutationRepository: any PlanningMutationRepository
    private let commitCoordinator: InboxCommitCoordinator?
    private let captureQueue: InboxCaptureQueueAccess

    init(
        reader: InboxReader,
        planningRepository: any PlanningRepository,
        mutationRepository: any PlanningMutationRepository,
        commitCoordinator: InboxCommitCoordinator? = nil,
        captureQueue: InboxCaptureQueueAccess = InboxCaptureQueueAccess()
    ) {
        self.reader = reader
        self.planningRepository = planningRepository
        self.mutationRepository = mutationRepository
        self.commitCoordinator = commitCoordinator
        self.captureQueue = captureQueue
    }

    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            items = try await reader.items(for: InboxQuery(scope: scope))
        } catch {
            // Distinct from "no items": an empty Inbox is an achievement, a
            // failed load is a problem, and the view must not congratulate the
            // user for a fetch that never completed.
            loadFailed = true
            items = []
        }
    }

    /// Applies a triage decision and keeps its receipt for Undo.
    func apply(_ mutation: InboxTriageMutation) async {
        isMutating = true
        mutationError = nil
        defer { isMutating = false }
        let metadata = (try? await planningRepository.fetchTaskMetadata(taskIDs: nil)) ?? []
        let byID = Dictionary(uniqueKeysWithValues: metadata.map { ($0.taskID, $0) })

        switch mutation.planMutation(resolve: { byID[$0] }) {
        case .success(let planMutation):
            do {
                let receipt = try await mutationRepository.prepare(
                    planMutation,
                    source: "inbox.triage",
                    summary: mutation.summary
                )
                try await mutationRepository.apply(receiptID: receipt.id)
                lastReceipt = receipt
                lastSummary = mutation.summary
                await load()
            } catch {
                loadFailed = true
                mutationError = String(localized: "Couldn’t save change.")
            }
        case .failure:
            // `moveToProject` and `commitCapture` need the task repository
            // rather than the planning ledger; neither is offered by this view
            // yet, so reaching here means a decision could not be honored and
            // must not look like it was.
            loadFailed = true
            mutationError = String(localized: "Couldn’t do that here.")
        }
    }

    func undoLast() async {
        if let mergeUndoState, let commitCoordinator {
            isMutating = true
            mutationError = nil
            defer { isMutating = false }
            do {
                try await commitCoordinator.undoMerge(mergeUndoState)
                self.mergeUndoState = nil
                lastSummary = nil
                await load()
            } catch {
                mutationError = String(localized: "Couldn’t undo merge. Try again.")
            }
            return
        }
        if let commitUndoState, let commitCoordinator {
            isMutating = true
            mutationError = nil
            defer { isMutating = false }
            do {
                try await commitCoordinator.undoCommit(
                    commitUndoState.mutation,
                    restoring: commitUndoState.capture
                )
                self.commitUndoState = nil
                lastSummary = nil
                await load()
            } catch {
                mutationError = String(localized: "Couldn’t undo. Task is still filed.")
            }
            return
        }
        guard let receipt = lastReceipt else { return }
        isMutating = true
        mutationError = nil
        defer { isMutating = false }
        do {
            try await mutationRepository.undo(receiptID: receipt.id)
            lastReceipt = nil
            lastSummary = nil
            await load()
        } catch {
            mutationError = String(localized: "Couldn’t undo. Try again.")
        }
    }

    /// Commits exactly the parser proposal and title shown in the review sheet.
    /// The capture stays queued on every failure.
    @discardableResult
    func fileCapture(_ item: InboxItem, draft: InboxCaptureReviewDraft) async -> Bool {
        guard let commitCoordinator,
              case let .pendingCapture(captureID) = item.origin,
              draft.captureID == captureID,
              let capture = captureQueue.read().first(where: { $0.id == captureID })
        else {
            mutationError = String(localized: "Couldn’t file it here.")
            return false
        }

        isMutating = true
        mutationError = nil
        defer { isMutating = false }

        let editedRequest = draft.commitRequest

        guard editedRequest.title.isEmpty == false else {
            mutationError = String(localized: "Add a title first.")
            return false
        }

        do {
            let mutation = try await commitCoordinator.commit(editedRequest)
            commitUndoState = CommitUndoState(mutation: mutation, capture: capture)
            lastReceipt = nil
            lastSummary = mutation.summary
            await load()
            return true
        } catch {
            mutationError = String(localized: "Couldn’t file task. It’s still in Inbox.")
            return false
        }
    }

    @discardableResult
    func mergeCapture(
        _ item: InboxItem,
        request: InboxCaptureCommitRequest,
        with duplicate: InboxItem
    ) async -> Bool {
        guard let commitCoordinator,
              case let .pendingCapture(captureID) = item.origin,
              request.captureID == captureID,
              captureQueue.read().contains(where: { $0.id == captureID })
        else {
            mutationError = String(localized: "Couldn’t merge here.")
            return false
        }
        guard request.title.isEmpty == false else {
            mutationError = String(localized: "Add a title first.")
            return false
        }

        isMutating = true
        mutationError = nil
        defer { isMutating = false }
        do {
            mergeUndoState = try await commitCoordinator.merge(request, with: duplicate.origin)
            commitUndoState = nil
            lastReceipt = nil
            lastSummary = String(localized: "Merged")
            await load()
            return true
        } catch {
            mutationError = String(localized: "Couldn’t merge tasks.")
            return false
        }
    }

    func reviewDraft(for item: InboxItem) -> InboxCaptureReviewDraft? {
        guard case let .pendingCapture(captureID) = item.origin else { return nil }
        return InboxCaptureReviewDraft(
            captureID: captureID,
            parsed: TaskCaptureParser.parse(item.title, now: item.capturedAt),
            fallbackTitle: item.title
        )
    }

    func mergeDestination(for item: InboxItem) async -> InboxMergeDestinationSnapshot? {
        guard let commitCoordinator else { return nil }
        do {
            return try await commitCoordinator.mergeDestination(for: item.origin)
        } catch {
            mutationError = String(localized: "Couldn’t load the other task.")
            return nil
        }
    }

    /// What the parser *would* extract from an unreviewed capture.
    ///
    /// Computed for display only. The roadmap's rule is that nothing uncertain
    /// commits silently, so this exists to show the user a proposal they can
    /// disagree with — never to apply one on their behalf. Parsing is done here
    /// rather than in `InboxReader` so capture itself stays inside its latency
    /// budget and pays nothing for a review the user may never open.
    func proposal(for item: InboxItem) -> ParsedCapture? {
        guard item.requiresCommitBeforeScheduling else { return nil }
        let parsed = TaskCaptureParser.parse(item.title, now: item.capturedAt)
        // Resolved against the capture's own timestamp, not "now": a capture
        // made yesterday saying "3pm" meant yesterday's 3pm.
        //
        // Gated on `hasProposals` rather than on `dueDate` alone: a capture like
        // "buy milk #groceries" carries a tag and a rewritten title but no date,
        // and returning nil here would rewrite the title in the editor with no
        // chip ever explaining why.
        return parsed.hasProposals ? parsed : nil
    }

    /// Seeds items directly. Test-only: the reader is exercised separately, and
    /// `alreadyFiled` is a pure function over whatever is on screen.
    func setItemsForTesting(_ value: [InboxItem]) { items = value }

    /// Captures that already have a canonical twin.
    ///
    /// The capture router cannot report whether an editor was saved or
    /// abandoned — `completeActiveRequest` and `cancelActiveRequest` do the same
    /// thing — so filing a capture cannot remove it from the queue directly.
    /// Rather than drop it optimistically (which loses the capture if the user
    /// cancelled) or leave it forever (which shows a duplicate), this detects
    /// that a matching task now exists and offers to clear it.
    ///
    /// Surfaced, never automatic: the roadmap's rule is Keep Both / Merge /
    /// Cancel, so a match is a prompt, not a decision.
    func alreadyFiled(_ item: InboxItem) -> Bool {
        guard item.requiresCommitBeforeScheduling else { return false }
        let canonical = items.filter { $0.requiresCommitBeforeScheduling == false }
        guard canonical.isEmpty == false else { return false }
        // Compared against the parsed title, because the editor strips the date
        // phrase — "call mom tomorrow" becomes a task called "call mom".
        let parsedTitle = TaskCaptureParser.parse(item.title).cleanTitle
        let candidateTitle = parsedTitle.isEmpty ? item.title : parsedTitle
        return InboxDuplicatePolicy
            .candidates(for: candidateTitle, among: canonical)
            .isEmpty == false
    }

    func duplicateCandidates(for item: InboxItem) -> [InboxDuplicateCandidate] {
        guard item.requiresCommitBeforeScheduling else { return [] }
        let parsed = TaskCaptureParser.parse(item.title, now: item.capturedAt)
        let candidateTitle = parsed.cleanTitle.isEmpty ? item.title : parsed.cleanTitle
        return InboxDuplicatePolicy.candidates(
            for: candidateTitle,
            among: items.filter { $0.id != item.id }
        )
    }

    /// Removes an unreviewed capture from the App Group queue.
    ///
    /// Returns the capture it removed so the caller can offer Undo. Nothing
    /// canonical exists yet, but the captured text is the person's own words and
    /// discarding it is the one irreversible thing in this screen —
    /// `DESIGN.md` asks for a receipt with Undo wherever reversal is supported,
    /// and here it is.
    @discardableResult
    func discardCapture(_ item: InboxItem) async -> PendingCapture? {
        guard case let .pendingCapture(captureID) = item.origin else { return nil }
        let removed = PendingCaptureInbox.read().first { $0.id == captureID }
        PendingCaptureInbox.remove(ids: [captureID])
        await load()
        return removed
    }

    /// Puts a discarded capture back in the queue.
    func restoreCapture(_ capture: PendingCapture) async {
        guard PendingCaptureInbox.upsert(capture) else { return }
        await load()
    }
}
