import Foundation
import Observation

/// Drives the end-of-day ritual.
///
/// Deliberately *not* `PlanStore`. That store's `load()` refetches a week of
/// blocks, the working-hours profile, the calendar and focus history on every
/// mutation; the ritual touches a single day and must not re-run any of that
/// between cards.
///
/// The defining behaviour: **swiping a card writes nothing.** Decisions
/// accumulate in memory and the whole reconciliation is committed once, as one
/// batch, when the day is actually closed. Per-card writes would produce one
/// receipt per card — so Undo would unwind the evening one task at a time — and
/// would leave a half-applied reconciliation behind if someone backed out
/// halfway. The cost is that the deck must not show success feedback per card;
/// see `record(_:for:)`.
@MainActor
@Observable
public final class DayCloseStore {
    // MARK: - Observable state

    public private(set) var loadState: DayCloseLoadState = .loading
    /// Committed work still open at the end of the day, oldest decision first.
    public private(set) var unfinished: [PlanningTaskSummary] = []
    public private(set) var ribbon: DayCloseRibbon?
    /// Keyed by task. One decision per task; a re-swipe replaces.
    public private(set) var decisions: [UUID: DayCloseDirection] = [:]
    /// Decision order, so "bring back the last card" needs no second undo stack.
    public private(set) var decisionOrder: [UUID] = []
    public private(set) var anchorTaskID: UUID?
    public private(set) var applyPhase: AsyncActionPhase<PlanMutationReceipt> = .idle
    public private(set) var appliedReceipt: PlanMutationReceipt?
    /// Non-nil when a `versionConflict` named records that moved underneath us.
    public private(set) var staleTaskIDs: Set<UUID> = []
    /// True when this day already has an applied close receipt. Flips back to
    /// false after Undo, because the receipt's state does.
    public private(set) var alreadyClosed = false
    public private(set) var closedAt: Date?
    /// The task the retrospective day's close named as its first thing, if any.
    /// Read from that day's receipt, never from `pinOrder`.
    public private(set) var carriedAnchorTaskID: UUID?
    /// True when the retrospective day was actually closed. Distinguishes "you
    /// chose nothing" from "there was no close to choose in".
    public private(set) var retrospectiveDayWasClosed = false

    // MARK: - Morning commit

    /// What the morning proposes, anchor first.
    public private(set) var openProposal: [DayOpenCandidate] = []
    /// Which of the proposal the person is agreeing to. Pre-filled with all of
    /// it — the primary action confirms, it does not compose.
    public private(set) var openSelection: Set<UUID> = []
    public private(set) var openCommitPhase: AsyncActionPhase<PlanMutationReceipt> = .idle
    public private(set) var openReceipt: PlanMutationReceipt?
    /// True when today already has an applied open receipt.
    public private(set) var alreadyCommitted = false
    /// True when the proposal has been edited away from what was offered. Used
    /// to tell "one tap" from "authored", which is the number that says whether
    /// the proposal is any good.
    public private(set) var openProposalWasEdited = false
    public private(set) var dayLoopEvidenceReport = DayLoopEvidenceReport()
    public private(set) var morningCommitPolicy: MorningCommitPolicy = .explicitConfirmation

    // MARK: - Dependencies

    private let reader: any DayCloseReading
    private let completions: (any DayCloseCompletionReading)?
    private let scenarios: any PlanningScenarioCoordinating
    private let day: PlanningDay
    /// The day being *reported on*, which is not always the day being acted on.
    ///
    /// Closing reports on the day it closes, so the two match. Opening reports on
    /// **yesterday** — the ribbon, the reflection and the anchor all describe the
    /// day that just ended — while still listing the work that carried into
    /// today. Collapsing them is what made the morning screen show today's tasks
    /// under the heading "What carried" and the subtitle "Last night's
    /// decisions": true only on a day that happened to have been closed.
    private let retrospectiveDay: PlanningDay
    private let calendar: Calendar
    /// Notification suppression only — the receipt remains the source of truth.
    private let closureLog: DayLoopClosureLog
    private let proposalSignalStore: any DayOpenProposalSignalStoring
    private let morningPolicyResolver: MorningCommitPolicyResolver
    /// Where tonight's undecided-until-close choices are kept, so a ritual cut
    /// short (the app killed, the phone locked for the night) reopens where it
    /// was left. `nil` keeps nothing — the default under XCTest, so one test's
    /// deck never leaks into the next.
    private let draftDefaults: UserDefaults?

    private var dayStart: Date? { day.startDate(calendar: calendar) }
    private var retrospectiveStart: Date? { retrospectiveDay.startDate(calendar: calendar) }

    public init(
        reader: any DayCloseReading,
        completions: (any DayCloseCompletionReading)? = nil,
        scenarios: any PlanningScenarioCoordinating,
        day: PlanningDay,
        retrospectiveDay: PlanningDay? = nil,
        calendar: Calendar = .current,
        closureLog: DayLoopClosureLog = DayLoopClosureLog(),
        proposalSignalStore: any DayOpenProposalSignalStoring = DayOpenProposalSignalStore.shared,
        morningPolicyResolver: MorningCommitPolicyResolver = MorningCommitPolicyResolver(),
        draftDefaults: UserDefaults? = DayCloseStore.defaultDraftDefaults
    ) {
        self.draftDefaults = draftDefaults
        self.reader = reader
        self.completions = completions
        self.scenarios = scenarios
        self.day = day
        self.retrospectiveDay = retrospectiveDay ?? day
        self.calendar = calendar
        self.closureLog = closureLog
        self.proposalSignalStore = proposalSignalStore
        self.morningPolicyResolver = morningPolicyResolver
    }

    public var receiptSource: String {
        DayCloseScenarioBuilder.receiptSource(for: day)
    }

    // MARK: - Loading

    public func load() async {
        loadState = .loading
        guard let reportStart = retrospectiveStart,
              let reportEnd = calendar.date(byAdding: .day, value: 1, to: reportStart) else {
            loadState = .failed(String(localized: "Couldn’t find this day on your calendar."))
            return
        }

        do {
            // Checked first: re-entering a closed day must show the receipt and
            // an Undo, never a second silent close.
            alreadyClosed = try await reader.hasAppliedReceipt(source: receiptSource)
            await loadCarry(reportStart: reportStart)

            let tasks = try await reader.fetchOpenPlanningTasks()
            let blocks = try await reader.fetchTimeBlocks(from: reportStart, to: reportEnd)
            let sessions = try await reader.sessions(since: reportStart)

            unfinished = tasks
                .filter { $0.metadata.planningDay == day }
                .filter { $0.metadata.availability == .actionable }
                .filter { $0.metadata.unscheduledDisposition != .deleted }
                .sorted { lhs, rhs in
                    if lhs.metadata.commitmentLevel != rhs.metadata.commitmentLevel {
                        return lhs.metadata.commitmentLevel == .mustDo
                    }
                    return lhs.id.uuidString < rhs.id.uuidString
                }

            // A failed completion lookup must not fail the whole ritual — the
            // ticks are the least load-bearing part of the ribbon.
            let marks = await (try? completions?.completions(
                on: DateInterval(start: reportStart, end: reportEnd)
            )) ?? []

            ribbon = DayCloseRibbonBuilder.make(
                blocks: blocks,
                commitments: [],
                sessions: sessions.compactMap(Self.receipt(from:)),
                completions: marks,
                unfinishedCount: unfinished.count,
                windowStart: reportStart,
                windowEnd: reportEnd,
                // The calendar is not read here. Saying "unavailable" is honest;
                // showing an empty external lane would claim the day had no
                // meetings, which we do not know.
                externalCalendarUnavailable: true
            )

            // Only meaningful in `.open` mode, where the retrospective day is
            // yesterday and there is a day ahead to commit to.
            if retrospectiveDay != day {
                if openReceipt != nil {
                    alreadyCommitted = true
                } else {
                    alreadyCommitted = try await reader.hasAppliedReceipt(
                        source: DayOpenScenarioBuilder.receiptSource(for: day)
                    )
                }
                openProposal = DayOpenScenarioBuilder.proposal(
                    tasks: unfinished,
                    anchorTaskID: carriedAnchorTaskID,
                    carriedTaskIDs: Set(unfinished.map(\.id)),
                    day: day
                )
                if openProposalWasEdited == false {
                    // Pre-filled so the primary action is a confirmation. A
                    // proposal that starts empty is an authoring session wearing
                    // a proposal's clothes.
                    openSelection = Set(openProposal.map(\.id))
                }
                await refreshMorningEvidence()
            }

            if alreadyClosed { clearDraft() } else { restoreDraft() }
            loadState = (unfinished.isEmpty && ribbon?.summary.hasNothingToReport == true)
                ? .empty
                : .ready
            if retrospectiveDay != day,
               alreadyCommitted == false,
               morningCommitPolicy == .zeroInteractionConfirmation {
                // After the dogfood threshold, a morning that is consistently
                // being skipped confirms itself without moving any task. The
                // empty receipt records the deliberate day; omitting the
                // proposal signal keeps this automation out of acceptance-rate
                // evidence.
                await applyOpen(selected: [], now: Date(), recordsProposalSignal: false)
            }
        } catch {
            // Distinct from `.empty` on purpose: the app must never congratulate
            // someone for a fetch that did not complete.
            loadState = .failed(error.localizedDescription)
        }
    }

    /// Resolves what the retrospective day's close decided.
    ///
    /// Never fails the ritual: a missing or unreadable receipt just means there
    /// is no carry to show, which is an ordinary state on a day nobody closed.
    private func loadCarry(reportStart: Date) async {
        guard retrospectiveDay != day else {
            // Closing reports on itself; there is no prior day to carry from.
            carriedAnchorTaskID = nil
            retrospectiveDayWasClosed = alreadyClosed
            return
        }
        let records = (try? await reader.fetchMutationReceipts(since: reportStart)) ?? []
        retrospectiveDayWasClosed = records.contains {
            $0.state == .applied
                && $0.receipt.source == DayCloseScenarioBuilder.receiptSource(for: retrospectiveDay)
        }
        carriedAnchorTaskID = DayLoopLedger.anchorTaskID(
            in: records,
            closedOn: retrospectiveDay,
            targetDay: day
        )
    }

    /// The carried anchor as a task, once `unfinished` has loaded.
    public var carriedAnchor: PlanningTaskSummary? {
        carriedAnchorTaskID.flatMap { id in unfinished.first { $0.id == id } }
    }

    // MARK: - Morning commit

    private func refreshMorningEvidence() async {
        let records = (try? await reader.fetchMutationReceipts(since: nil)) ?? []
        let signals = (try? await proposalSignalStore.signals()) ?? []
        dayLoopEvidenceReport = DayLoopLedger.evidenceReport(
            records: records,
            proposalSignals: signals,
            calendar: calendar
        )
        morningCommitPolicy = morningPolicyResolver.resolve(dayLoopEvidenceReport)
    }

    /// Toggles one proposed item. Marks the proposal edited either way — the
    /// signal is "did this need touching", not which direction.
    public func toggleOpenSelection(_ taskID: UUID) {
        guard openProposal.contains(where: { $0.id == taskID }) else { return }
        if openSelection.remove(taskID) == nil { openSelection.insert(taskID) }
        openProposalWasEdited = true
    }

    /// Commits today as one batch, one receipt, one Undo.
    ///
    /// An empty selection still writes: agreeing that today is deliberately
    /// clear is a commitment, and a ledger that only records busy days would
    /// misreport the loop.
    public func commitOpen(now: Date = Date()) async {
        guard alreadyCommitted == false else { return }
        let selected = openProposal
            .filter { openSelection.contains($0.id) }
            .map(\.task)

        await applyOpen(selected: selected, now: now, recordsProposalSignal: true)
    }

    private func applyOpen(
        selected: [PlanningTaskSummary],
        now: Date,
        recordsProposalSignal: Bool
    ) async {
        guard alreadyCommitted == false else { return }

        openCommitPhase = .running(progress: nil)
        let scenario = DayOpenScenarioBuilder.make(
            selected: selected,
            day: day,
            snapshot: previewSnapshot(now: now),
            now: now
        )
        do {
            let receipt = try await scenarios.apply(scenario)
            openReceipt = receipt
            alreadyCommitted = true
            openCommitPhase = .success(receipt: receipt)
            if recordsProposalSignal {
                let signal = DayOpenProposalSignal(
                    receiptID: receipt.id,
                    dayStamp: String(format: "%04d%02d%02d", day.year, day.month, day.day),
                    wasEdited: openProposalWasEdited,
                    committedAt: now
                )
                // Evidence is explicitly non-authoritative. A failed sidecar
                // write becomes unknown evidence and never fails or compensates
                // the already-persisted commitment.
                try? await proposalSignalStore.record(signal)
            }
            await load()
        } catch let PlanningScenarioApplyError.versionConflict(changedRecordIDs) {
            staleTaskIDs = Set(changedRecordIDs)
            openCommitPhase = .recoverableFailure(
                AsyncActionFailure(
                    message: String(localized: "Some tasks changed. Review and try again."),
                    recovery: .edit
                )
            )
        } catch {
            openCommitPhase = .recoverableFailure(
                AsyncActionFailure(message: error.localizedDescription, recovery: .retry)
            )
        }
    }

    /// Puts today back the way the morning found it.
    public func undoOpen() async {
        guard let receipt = openReceipt else { return }
        do {
            try await reader.undo(receiptID: receipt.id)
            openReceipt = nil
            alreadyCommitted = false
            openCommitPhase = .idle
            await load()
        } catch {
            openCommitPhase = .recoverableFailure(
                AsyncActionFailure(message: error.localizedDescription, recovery: .retry)
            )
        }
    }

    /// Focus sessions become receipt-shaped so the ribbon builder has one input
    /// type regardless of how a session ended.
    ///
    /// Focused time is wall-clock minus pauses, not the target. Reporting the
    /// target would credit a person for a 50-minute block they abandoned after
    /// six, which is exactly the kind of flattering lie this screen exists not to
    /// tell. Sessions still running are skipped — a session with no end has no
    /// measured duration yet.
    private static func receipt(from session: FocusSessionV2) -> FocusExecutionReceipt? {
        guard let endedAt = session.endedAt else { return nil }
        let elapsed = endedAt.timeIntervalSince(session.startedAt)
        let focused = max(0, elapsed - session.accumulatedPauseDuration)
        return FocusExecutionReceipt(
            id: session.id,
            sessionID: session.id,
            taskID: session.taskID,
            timeBlockID: session.timeBlockID,
            targetDuration: session.targetDuration,
            actualFocusedDuration: focused,
            interruptionCount: session.interruptionCount,
            outcome: session.outcome ?? .stopped,
            energyAfter: session.energyAfter,
            reflection: session.reflection,
            startedAt: session.startedAt,
            endedAt: endedAt
        )
    }

    // MARK: - Same-day draft

    public static var defaultDraftDefaults: UserDefaults? {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil ? .standard : nil
    }

    private struct Draft: Codable {
        var order: [UUID]
        var decisions: [UUID: DayCloseDirection]
        var anchor: UUID?
    }

    /// Only the evening close has a draft; the morning's one choice commits at once.
    private var draftKey: String? {
        guard retrospectiveDay == day else { return nil }
        return "lifeboard.dayClose.draft.\(day.year)-\(day.month)-\(day.day)"
    }

    private func saveDraft() {
        guard let draftDefaults, let draftKey else { return }
        guard decisionOrder.isEmpty == false || anchorTaskID != nil else {
            draftDefaults.removeObject(forKey: draftKey)
            return
        }
        let draft = Draft(order: decisionOrder, decisions: decisions, anchor: anchorTaskID)
        if let data = try? JSONEncoder().encode(draft) {
            draftDefaults.set(data, forKey: draftKey)
        }
    }

    private func clearDraft() {
        guard let draftDefaults, let draftKey else { return }
        draftDefaults.removeObject(forKey: draftKey)
    }

    /// Puts back tonight's choices for tasks that are still open. Never
    /// overwrites decisions already made in this session.
    private func restoreDraft() {
        guard alreadyClosed == false, decisionOrder.isEmpty, anchorTaskID == nil,
              let draftDefaults, let draftKey,
              let data = draftDefaults.data(forKey: draftKey),
              let draft = try? JSONDecoder().decode(Draft.self, from: data) else { return }
        let live = Set(unfinished.map(\.id))
        decisionOrder = draft.order.filter { live.contains($0) && draft.decisions[$0] != nil }
        decisions = draft.decisions.filter { decisionOrder.contains($0.key) }
        if let anchor = draft.anchor, anchorCandidates.contains(where: { $0.id == anchor }) {
            anchorTaskID = anchor
        }
    }

    // MARK: - Deciding

    /// Records one card's outcome. **Writes nothing.**
    ///
    /// Callers must pair this with a *selection* haptic, not a success one: the
    /// design contract puts a persisted-state boundary before success feedback,
    /// and nothing is persisted until `close()`.
    public func record(_ direction: DayCloseDirection, for taskID: UUID) {
        guard unfinished.contains(where: { $0.id == taskID }) else { return }
        if decisions[taskID] == nil { decisionOrder.append(taskID) }
        decisions[taskID] = direction
        // Releasing the anchor would leave tomorrow pointing at something the
        // person just let go.
        if anchorTaskID == taskID, [.someday, .doneAnyway, .release].contains(direction) {
            anchorTaskID = nil
        }
        saveDraft()
    }

    /// Reverses the most recent decision. Pure state — no I/O, nothing to unwind.
    ///
    /// This is what makes deferred commit honest: a swipe stays reversible right
    /// up until the day is closed, so the deck can be fast without being final.
    @discardableResult
    public func bringBackLastCard() -> UUID? {
        guard let taskID = decisionOrder.popLast() else { return nil }
        decisions.removeValue(forKey: taskID)
        saveDraft()
        return taskID
    }

    public func setAnchor(_ taskID: UUID?) {
        guard let taskID else {
            anchorTaskID = nil
            saveDraft()
            return
        }
        guard anchorCandidates.contains(where: { $0.id == taskID }) else { return }
        anchorTaskID = taskID
        saveDraft()
    }

    /// The uncommitted reconciliation, for preview and for `close()`.
    public func makeScenario(now: Date = Date()) -> PlanningScenario? {
        guard let start = day.startDate(calendar: calendar),
              let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let tomorrow = PlanningDay(
            date: tomorrowDate,
            timeZone: TimeZone(identifier: day.timeZoneIdentifier) ?? calendar.timeZone,
            calendar: calendar
        )
        return DayCloseScenarioBuilder.make(
            decisions: decisionOrder.compactMap { taskID in
                decisions[taskID].map { DayCloseDecision(taskID: taskID, direction: $0, decidedAt: now) }
            },
            anchorTaskID: anchorTaskID,
            tasks: unfinished,
            snapshot: previewSnapshot(now: now),
            tomorrow: tomorrow,
            now: now
        )
    }

    private func previewSnapshot(now: Date) -> PlanDaySnapshot {
        PlanDaySnapshot(
            day: day,
            capacity: CapacityBudget(
                workingDuration: 0,
                fixedCalendarDuration: 0,
                internalFixedDuration: 0,
                bufferDuration: 0,
                plannedEstimatedDuration: 0,
                missingEstimateCount: 0
            ),
            commitments: [],
            blocks: [],
            plannedTasks: unfinished,
            unscheduledTasks: [],
            generatedAt: now
        )
    }

    // MARK: - Closing

    /// Applies the whole reconciliation as one batch.
    ///
    /// A day with nothing decided still writes a receipt: the receipt *is* the
    /// record that this day was closed, so skipping it for an empty
    /// reconciliation would make the ritual re-offer itself forever.
    public func close(now: Date = Date()) async {
        guard alreadyClosed == false else { return }
        guard let scenario = makeScenario(now: now) else {
            applyPhase = .recoverableFailure(
                AsyncActionFailure(
                    message: String(localized: "Couldn’t find this day on your calendar."),
                    recovery: .retry
                )
            )
            return
        }

        applyPhase = .running(progress: nil)
        staleTaskIDs = []
        do {
            let receipt = try await scenarios.apply(scenario)
            appliedReceipt = receipt
            alreadyClosed = true
            closedAt = now
            // Suppresses tonight's configured nudge. Written only after
            // the receipt lands, so a failed close never silences the nudge.
            closureLog.markClosed(dayStart ?? now, calendar: calendar)
            clearDraft()
            applyPhase = .success(receipt: receipt)
        } catch let PlanningScenarioApplyError.versionConflict(changedRecordIDs) {
            // Name what moved rather than discarding the evening's work. The
            // decisions stay; the person re-reviews only the stale cards.
            staleTaskIDs = Set(changedRecordIDs)
            applyPhase = .recoverableFailure(
                AsyncActionFailure(
                    message: staleTaskIDs.count == 1
                        ? String(localized: "1 task changed. Review it and close again.")
                        : String(localized: "\(staleTaskIDs.count) tasks changed. Review them and close again."),
                    // `.edit` rather than `.retry`: retrying the identical
                    // scenario would conflict again. The person has to look.
                    recovery: .edit
                )
            )
        } catch {
            applyPhase = .recoverableFailure(
                AsyncActionFailure(message: error.localizedDescription, recovery: .retry)
            )
        }
    }

    /// Puts every carried task back where it was.
    ///
    /// Only the reconciliation. The one line is a separate write with its own
    /// commit control, and the UI says so — undoing the plan must not silently
    /// delete something the person wrote.
    public func undoClose() async {
        guard let receipt = appliedReceipt else { return }
        do {
            try await reader.undo(receiptID: receipt.id)
            appliedReceipt = nil
            alreadyClosed = false
            closedAt = nil
            // Undo reopens the day, so the evening nudge comes back with it.
            closureLog.clearClosed(dayStart ?? Date(), calendar: calendar)
            applyPhase = .idle
            await load()
        } catch {
            applyPhase = .recoverableFailure(AsyncActionFailure(message: error.localizedDescription, recovery: .retry))
        }
    }

    /// Re-reads the day after a version conflict, keeping every decision whose
    /// task is still present and unchanged.
    public func reviewAfterConflict() async {
        let keptDecisions = decisions
        let keptOrder = decisionOrder
        let keptAnchor = anchorTaskID
        await load()
        let live = Set(unfinished.map(\.id))
        decisionOrder = keptOrder.filter { live.contains($0) && staleTaskIDs.contains($0) == false }
        decisions = keptDecisions.filter { decisionOrder.contains($0.key) }
        anchorTaskID = keptAnchor.flatMap { live.contains($0) ? $0 : nil }
        applyPhase = .idle
    }
}
