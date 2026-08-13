import SwiftUI

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
                mutationError = "That change couldn’t be saved. Your inbox is unchanged."
            }
        case .failure:
            // `moveToProject` and `commitCapture` need the task repository
            // rather than the planning ledger; neither is offered by this view
            // yet, so reaching here means a decision could not be honored and
            // must not look like it was.
            loadFailed = true
            mutationError = "This inbox action is not available from the current route."
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
                mutationError = "The merge is still in place. Please try Undo again."
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
                mutationError = "The task is still filed. Nothing else was changed."
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
            mutationError = "The change is still in place. Please try Undo again."
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
            mutationError = "This capture can’t be filed from the current route."
            return false
        }

        isMutating = true
        mutationError = nil
        defer { isMutating = false }

        let editedRequest = draft.commitRequest

        guard editedRequest.title.isEmpty == false else {
            mutationError = "Add a title before filing this capture."
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
            mutationError = "Couldn’t file this capture. It is still safely in your inbox."
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
            mutationError = "This capture can’t be merged from the current route."
            return false
        }
        guard request.title.isEmpty == false else {
            mutationError = "Add a title before merging this capture."
            return false
        }

        isMutating = true
        mutationError = nil
        defer { isMutating = false }
        do {
            mergeUndoState = try await commitCoordinator.merge(request, with: duplicate.origin)
            commitUndoState = nil
            lastReceipt = nil
            lastSummary = "Merged without losing either capture"
            await load()
            return true
        } catch {
            mutationError = "Couldn’t merge these items. Both originals are unchanged."
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
            mutationError = "Couldn’t load the existing item for comparison."
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
    /// Safe to offer without a receipt because nothing canonical exists yet —
    /// the capture was never committed, so there is no task to restore.
    func discardCapture(_ item: InboxItem) async {
        guard case let .pendingCapture(captureID) = item.origin else { return }
        PendingCaptureInbox.remove(ids: [captureID])
        await load()
    }
}

/// Persists how many times each capture has been passed over in the Inbox deck.
///
/// Lives in the App Group domain so it clears with `resetAppState()` alongside
/// every other launch-scoped preference, and stores counts by capture id rather
/// than touching the capture queue itself — a skip must leave the captured text,
/// timestamp and identity completely untouched.
private enum InboxSkipLedger {
    private static let key = "lifeboard.inbox.skipCounts.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard
    }

    static func load() -> [UUID: Int] {
        guard let raw = defaults.dictionary(forKey: key) as? [String: Int] else { return [:] }
        return raw.reduce(into: [:]) { result, entry in
            guard let id = UUID(uuidString: entry.key) else { return }
            result[id] = entry.value
        }
    }

    static func record(count: Int, for id: UUID) {
        var raw = (defaults.dictionary(forKey: key) as? [String: Int]) ?? [:]
        raw[id.uuidString] = count
        defaults.set(raw, forKey: key)
    }

    static func forget(_ id: UUID) {
        var raw = (defaults.dictionary(forKey: key) as? [String: Int]) ?? [:]
        raw[id.uuidString] = nil
        defaults.set(raw, forKey: key)
    }

    /// Drops every entry whose capture has left the queue.
    static func retain(only ids: Set<UUID>) -> [UUID: Int] {
        let surviving = load().filter { ids.contains($0.key) }
        defaults.set(
            Dictionary(uniqueKeysWithValues: surviving.map { ($0.key.uuidString, $0.value) }),
            forKey: key
        )
        return surviving
    }
}

struct InboxView: View {
    @Bindable var store: InboxStore
    /// Opens the normal task editor seeded with the capture's raw text.
    ///
    /// Reuses the app's real capture flow rather than committing from here, so
    /// filing an unreviewed capture goes through the same editor — and the same
    /// chance to disagree with the parser — as anything typed by hand.
    var onReviewCapture: ((InboxItem) -> Void)?
    @State private var selection: Set<UUID> = []
    @State private var filingItem: InboxItem?
    /// How many times each capture has been passed over.
    ///
    /// Presentation only — skipping is explicitly not a mutation, so a capture is
    /// never altered just because it was not the one you wanted next. The count
    /// lives beside the view rather than in the capture record, whose text,
    /// timestamp and id must stay exactly as captured.
    @State private var skipCounts: [UUID: Int] = [:]
    @State private var triageSettleTrigger = 0
    @State private var triageSettleDirection = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Which way a flick can send the front capture.
    ///
    /// Only two, because only two honest decisions exist here. A capture is not a
    /// task yet, so there is no disposition to set: `InboxStore` offers
    /// `fileCapture`, `mergeCapture` and `discardCapture` and nothing else.
    /// Someday and Reference would have to commit the capture first, which is
    /// exactly the silent commit this screen exists to prevent.
    private enum CaptureFlick {
        case file
        case skip

        var label: String {
            switch self {
            case .file: "File it"
            case .skip: "Skip for now"
            }
        }

        var symbol: String {
            switch self {
            case .file: "tray.and.arrow.down"
            case .skip: "arrow.uturn.forward"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            scopePicker

            // Directly under the lens, not at the foot of the screen. Filing is
            // reversible for one step and the receipt is the only way back, so it
            // has to be in view the moment the sheet closes — at the bottom of the
            // stack it landed beneath the floating composer and had to be
            // scrolled for.
            if let summary = store.lastSummary {
                undoRow(summary)
            }

            if store.isLoading && store.items.isEmpty {
                loadingSkeleton
            } else if store.loadFailed {
                loadFailure
            } else if store.items.isEmpty {
                emptyState
            } else {
                if orderedCaptures.isEmpty == false { captureDeckSection }
                if settledItems.isEmpty == false { settledSection }
            }

            if let mutationError = store.mutationError {
                Label(mutationError, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(Color.lifeboard.statusWarning)
                    .accessibilityIdentifier("plan.inbox.mutation-error")
            }
        }
        .task {
            await store.load()
            pruneSkipLedger()
        }
        .onChange(of: store.items.map(\.id)) { _, _ in pruneSkipLedger() }
        .sheet(item: $filingItem) { item in
            InboxCaptureReviewSheet(item: item, store: store) {
                filingItem = nil
            }
        }
        .accessibilityIdentifier("plan.inbox")
    }

    /// Captures still awaiting a first decision. A skipped capture moves to the
    /// back rather than disappearing, so the deck can be cycled without ever
    /// losing something.
    private var orderedCaptures: [InboxItem] {
        let captures = store.items.filter(\.requiresCommitBeforeScheduling)
        guard skipCounts.isEmpty == false else { return captures }
        // Fewer passes first, then the reader's own newest-first order. A skipped
        // capture sinks but never leaves, so the deck can be cycled indefinitely
        // without anything falling out of it.
        return captures.enumerated().sorted { left, right in
            let leftSkips = skipCounts[left.element.id] ?? 0
            let rightSkips = skipCounts[right.element.id] ?? 0
            if leftSkips != rightSkips { return leftSkips < rightSkips }
            return left.offset < right.offset
        }
        .map(\.element)
    }

    /// A capture passed over this often gets one line acknowledging it, so nothing
    /// quietly rots at the back of the deck.
    private static let repeatedSkipThreshold = 3

    /// Rows that are already real records; they need a disposition, not a review.
    private var settledItems: [InboxItem] {
        store.items.filter { $0.requiresCommitBeforeScheduling == false }
    }

    /// Reconciles the persisted skip counts against the captures that are actually
    /// queued, so filing or discarding a capture takes its count with it.
    private func pruneSkipLedger() {
        let liveIDs = Set(store.items.filter(\.requiresCommitBeforeScheduling).map(\.id))
        skipCounts = InboxSkipLedger.retain(only: liveIDs)
    }

    private var scopePicker: some View {
        Picker("Inbox scope", selection: Binding(
            get: { store.scope },
            set: { store.scope = $0 }
        )) {
            Text("Inbox").tag(InboxQuery.Scope.untriaged)
            Text("Someday").tag(InboxQuery.Scope.someday)
            Text("Reference").tag(InboxQuery.Scope.reference)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("plan.inbox.scope")
    }

    // MARK: - Capture deck

    /// The decision surface. One capture is in the hand at a time because each
    /// one is a separate judgement, and a flat list of five equally weighted rows
    /// invites skimming past things that were captured in a hurry.
    private var captureDeckSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Needs review")
                    .font(.headline)
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                Spacer(minLength: 8)
                Text(deckPositionLabel)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .accessibilityIdentifier("plan.inbox.deck.position")
            }

            ZStack {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Color.clear)
                    .lifeboardTriageSettle(
                        trigger: triageSettleTrigger,
                        direction: triageSettleDirection
                    )
                    .allowsHitTesting(false)

                DirectionalDeck(
                    items: orderedCaptures,
                    candidates: { _ in [CaptureFlick.file, CaptureFlick.skip] },
                    actionLabel: \.label,
                    onCommit: { item, action in resolveFlick(action, for: item) },
                    card: { item, armed in captureCard(item, armed: armed) }
                )
            }
            .accessibilityIdentifier("plan.inbox.deck")

            if let front = orderedCaptures.first {
                captureActions(for: front)
            }
        }
    }

    private var deckPositionLabel: String {
        let total = orderedCaptures.count
        return total == 1 ? "1 capture" : "\(total) captures"
    }

    /// Raised clay, deliberately. These rows used to sit straight on the canvas,
    /// and on Plan's scenic backdrop the title and its actions landed on top of
    /// the bright sun with no readable field behind them.
    private func captureCard(_ item: InboxItem, armed: DeckDirection?) -> some View {
        let flick = armedFlick(for: armed)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(proposalTitle(for: item))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            if store.alreadyFiled(item) {
                Label("Possible duplicate — choose what to keep", systemImage: "square.on.square")
                    .font(.caption)
                    .foregroundStyle(Color.lifeboard.statusSuccess)
            } else if let source = item.captureSource {
                // Named so an unreviewed capture is visibly different from a
                // task the user created deliberately in the app.
                Text("Captured from \(source) · needs review")
                    .font(.caption)
                    .foregroundStyle(Color.lifeboard.textTertiary)
            }

            if let parsed = store.proposal(for: item) {
                reviewChips(for: parsed)
            }

            repeatedSkipNote(for: item)

            // The armed decision is named on the card itself. A directional
            // gesture the user cannot see resolving is a guess, and filing is a
            // real mutation.
            armedBanner(flick)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.largeCard)
        .accessibilityIdentifier("plan.inbox.row.\(item.id.uuidString)")
    }

    /// States the fact and nothing more.
    ///
    /// `DESIGN.md` rules out moralised productivity language, so this counts the
    /// passes and leaves the judgement to the reader — it does not imply the
    /// capture should have been dealt with, and Discard is already one tap away in
    /// the row's menu.
    @ViewBuilder
    private func repeatedSkipNote(for item: InboxItem) -> some View {
        let passes = skipCounts[item.id] ?? 0
        if passes >= Self.repeatedSkipThreshold {
            Label(
                "You've come back to this \(passes) times.",
                systemImage: "arrow.uturn.forward.circle"
            )
            .font(.caption)
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            .accessibilityIdentifier("plan.inbox.repeatedSkip.\(item.id.uuidString)")
        }
    }

    @ViewBuilder
    private func armedBanner(_ flick: CaptureFlick?) -> some View {
        if let flick {
            Label(flick.label, systemImage: flick.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color(SemanticColorTokens.foundationSurfaceSelected))
                )
                .transition(.opacity)
                .accessibilityHidden(true)
        }
    }

    private func armedFlick(for direction: DeckDirection?) -> CaptureFlick? {
        guard let direction else { return nil }
        return DeckPhysics.action(
            for: direction,
            candidates: [CaptureFlick.file, CaptureFlick.skip]
        )
    }

    /// One dominant action, then quieter equivalents.
    ///
    /// This replaced three same-size `.footnote` text buttons crowded against the
    /// trailing edge — none of which reached the 44-point minimum, and which gave
    /// Discard exactly as much visual weight as File It.
    private func captureActions(for item: InboxItem) -> some View {
        HStack(spacing: 10) {
            Button("File it") { beginFiling(item) }
                .buttonStyle(.lifeBoardPrimary)
                .disabled(store.isMutating)
                .accessibilityIdentifier("plan.inbox.file.\(item.id.uuidString)")

            if let onReviewCapture {
                Button {
                    onReviewCapture(item)
                } label: {
                    Image(systemName: "square.and.pencil")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.lifeBoardClay(.resting, cornerRadius: Radius.compact, fill: nil))
                .accessibilityLabel("Review \(item.title) in the editor")
                .accessibilityIdentifier("plan.inbox.review.\(item.id.uuidString)")
            }

            Button {
                skip(item)
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.lifeBoardClay(.resting, cornerRadius: Radius.compact, fill: nil))
            .accessibilityLabel("Skip \(item.title) for now")
            .accessibilityIdentifier("plan.inbox.skip.\(item.id.uuidString)")

            Menu {
                Button("Discard capture", systemImage: "trash", role: .destructive) {
                    forgetSkips(for: item)
                    Task { await store.discardCapture(item) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.lifeBoardClay(.resting, cornerRadius: Radius.compact, fill: nil))
            .accessibilityLabel("More actions for \(item.title)")
            .accessibilityIdentifier("plan.inbox.discard.\(item.id.uuidString)")
        }
    }

    private func resolveFlick(_ action: CaptureFlick, for item: InboxItem) {
        switch action {
        case .file: beginFiling(item)
        case .skip: skip(item)
        }
    }

    private func beginFiling(_ item: InboxItem) {
        HapticFeedback.light()
        triageSettleDirection = 1
        triageSettleTrigger &+= 1
        filingItem = item
    }

    /// Sinks the capture in the deck. No mutation, no receipt: the capture is
    /// untouched and will be waiting next time — including after a relaunch.
    private func skip(_ item: InboxItem) {
        HapticFeedback.selection()
        let next = (skipCounts[item.id] ?? 0) + 1
        InboxSkipLedger.record(count: next, for: item.id)
        triageSettleDirection = -1
        triageSettleTrigger &+= 1
        withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
            skipCounts[item.id] = next
        }
    }

    /// Drops a capture's skip count once it is no longer in the queue, so the
    /// ledger cannot outlive the captures it describes.
    private func forgetSkips(for item: InboxItem) {
        InboxSkipLedger.forget(item.id)
        skipCounts[item.id] = nil
    }

    // MARK: - Settled rows

    /// Records that already exist and only need a disposition. Open rows rather
    /// than cards: this is ordinary grouping, and `DESIGN.md` reserves a card for
    /// one decision or one movable module.
    private var settledSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Already in your system")
                .font(.headline)
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            if selection.isEmpty == false { batchBar }
            ForEach(settledItems) { item in
                settledRow(item)
                if item.id != settledItems.last?.id {
                    Divider().overlay(Color.lifeboard.strokeHairline)
                }
            }
        }
    }

    private func settledRow(_ item: InboxItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                if selection.contains(item.id) { selection.remove(item.id) }
                else { selection.insert(item.id) }
            } label: {
                Image(systemName: selection.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selection.contains(item.id) ? "Deselect \(item.title)" : "Select \(item.title)")

            Text(item.title)
                .font(.body)
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .frame(minHeight: 44, alignment: .leading)

            Spacer(minLength: 0)

            triageMenu(for: item)
                .frame(width: 44, height: 44)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.inbox.row.\(item.id.uuidString)")
    }

    // MARK: - Non-content states

    /// Geometry-matched rather than a spinner, so the deck does not jump into
    /// place when the real captures arrive.
    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<2, id: \.self) { index in
                RoundedRectangle(cornerRadius: Radius.largeCard, style: .continuous)
                    .fill(Color(SemanticColorTokens.foundationSurfaceRecessed))
                    .frame(height: index == 0 ? 132 : 96)
                    .opacity(index == 0 ? 1 : 0.55)
            }
        }
        .accessibilityLabel("Loading your inbox")
        .accessibilityIdentifier("plan.inbox.loading")
    }

    /// Deliberately not shaped like `emptyState`. A failed fetch that looks like
    /// an empty inbox congratulates someone for a load that never completed.
    private var loadFailure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Couldn’t load your inbox", systemImage: "exclamationmark.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            Text("Nothing has been lost. Your captures are still saved.")
                .font(.subheadline)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            Button("Try again") { Task { await store.load() } }
                .buttonStyle(.lifeBoardPrimary)
                .accessibilityIdentifier("plan.inbox.retry")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
        .accessibilityIdentifier("plan.inbox.loadFailure")
    }

    /// An empty Inbox is a success state, not a void.
    private var emptyState: some View {
        stateMessage(
            title: store.scope == .untriaged ? "Inbox clear" : "Nothing here",
            detail: store.scope == .untriaged
                ? "Everything you captured has somewhere to be."
                : "Items you set aside will appear here.",
            symbol: store.scope == .untriaged ? "checkmark.circle" : "tray"
        )
    }

    private func stateMessage(title: String, detail: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.lifeboard.textTertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .accessibilityElement(children: .combine)
    }

    /// The title as it would be filed: the parser strips the date phrase, so
    /// showing the raw text next to a date chip would misrepresent what filing
    /// this capture actually produces.
    private func proposalTitle(for item: InboxItem) -> String {
        guard let parsed = store.proposal(for: item), parsed.cleanTitle.isEmpty == false else {
            return item.title
        }
        return parsed.cleanTitle
    }

    /// Shown, never applied.
    ///
    /// The parser rewrites the title and assigns a date; before this the drain
    /// committed both silently, so a capture could acquire a due date the user
    /// never saw. These chips are the review step that makes the proposal
    /// visible and disagreeable-with.
    private func reviewChips(for parsed: ParsedCapture) -> some View {
        // Two rows rather than one: scheduling on top, classification beneath.
        // A single HStack of up to six chips truncates at accessibility text
        // sizes, and DESIGN.md's rule is to stack metadata before truncating
        // content that carries meaning.
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let due = parsed.dueDate {
                    chip(
                        parsed.isAllDay
                            ? due.formatted(date: .abbreviated, time: .omitted)
                            : due.formatted(date: .abbreviated, time: .shortened),
                        symbol: "calendar"
                    )
                }
                if let duration = parsed.duration {
                    chip(Self.durationLabel(duration), symbol: "timer")
                }
                if parsed.repeatPattern != nil {
                    chip("Repeats", symbol: "arrow.triangle.2.circlepath")
                }
                if let priority = parsed.priority {
                    chip(priority.displayName, symbol: "flag")
                }
            }
            HStack(spacing: 6) {
                if let project = parsed.projectName {
                    chip(project, symbol: "folder")
                }
                if let context = parsed.context {
                    chip(context, symbol: "mappin.and.ellipse")
                }
                ForEach(parsed.tags, id: \.self) { tag in
                    chip(tag, symbol: "number")
                }
            }
            if let matched = parsed.matchedText {
                chip("from “\(matched)”", symbol: "text.magnifyingglass")
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.proposalAccessibilityLabel(parsed))
    }

    private static func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours) hr \(remainder) min"
    }

    /// One sentence covering every proposal, ending in the fact that matters
    /// most: none of it has been applied yet.
    private static func proposalAccessibilityLabel(_ parsed: ParsedCapture) -> String {
        var parts: [String] = []
        if let due = parsed.dueDate {
            parts.append("date \(due.formatted(date: .abbreviated, time: parsed.isAllDay ? .omitted : .shortened))")
        }
        if let duration = parsed.duration { parts.append("duration \(durationLabel(duration))") }
        if parsed.repeatPattern != nil { parts.append("repeating") }
        if let priority = parsed.priority { parts.append("priority \(priority.displayName)") }
        if let project = parsed.projectName { parts.append("project \(project)") }
        if let context = parsed.context { parts.append("context \(context)") }
        if parsed.tags.isEmpty == false {
            parts.append("tags \(ListFormatter.localizedString(byJoining: parsed.tags))")
        }
        guard parts.isEmpty == false else { return "Nothing proposed" }
        return "Proposed \(ListFormatter.localizedString(byJoining: parts)). Not yet applied."
    }

    private func chip(_ text: String, symbol: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(Color.lifeboard.surfaceSecondary)
        )
    }

    /// Every swipe affordance also lives here, so the same decisions are
    /// reachable by pointer, keyboard and VoiceOver.
    private func triageMenu(for item: InboxItem) -> some View {
        Menu {
            Button("Move to Someday") { triage(item, to: .someday) }
            Button("Keep as reference") { triage(item, to: .reference) }
            Button("Return to Inbox") { triage(item, to: .inbox) }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
        .accessibilityLabel("Triage \(item.title)")
        .accessibilityIdentifier("plan.inbox.triage.\(item.id.uuidString)")
    }

    private var batchBar: some View {
        HStack(spacing: 12) {
            Text("\(selection.count) selected")
                .font(.subheadline)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            Spacer()
            Button("Someday") { triageSelection(to: .someday) }
            Button("Reference") { triageSelection(to: .reference) }
            Button("Clear") { selection.removeAll() }
        }
        .font(.subheadline)
        .padding(.vertical, 6)
        .accessibilityIdentifier("plan.inbox.batchBar")
    }

    private func undoRow(_ summary: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.lifeboard.statusSuccess)
            Text(summary)
                .font(.footnote)
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Undo") { Task { await store.undoLast() } }
                .font(.footnote.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("plan.inbox.undo")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
        .transition(.opacity)
        .lifeBoardMotion(.contentInsertion, value: summary)
    }

    private func triage(_ item: InboxItem, to disposition: UnscheduledDisposition) {
        guard case let .task(taskID) = item.origin else { return }
        Task {
            await store.apply(
                .setDisposition(taskID: taskID, before: .inbox, after: disposition)
            )
        }
    }

    private func triageSelection(to disposition: UnscheduledDisposition) {
        let taskIDs = store.items
            .filter { selection.contains($0.id) }
            .compactMap { item -> UUID? in
                guard case let .task(taskID) = item.origin else { return nil }
                return taskID
            }
        guard taskIDs.isEmpty == false else { return }
        let mutations = taskIDs.map {
            InboxTriageMutation.setDisposition(taskID: $0, before: .inbox, after: disposition)
        }
        selection.removeAll()
        Task { await store.apply(.batch(mutations)) }
    }
}

private struct InboxCaptureReviewSheet: View {
    let item: InboxItem
    @Bindable var store: InboxStore
    let onClose: () -> Void
    @State private var draft: InboxCaptureReviewDraft
    @State private var tagText: String
    @State private var projectText: String
    @State private var contextText: String
    @State private var selectedDuplicateID: UUID?
    @State private var mergeDestination: InboxMergeDestinationSnapshot?
    @State private var mergeResolution: DuplicateMergeResolution
    /// Drives `CommitControl`, so the button reports the real state of the
    /// write rather than dismissing optimistically.
    @State private var commitPhase: AsyncActionPhase<String> = .idle

    init(item: InboxItem, store: InboxStore, onClose: @escaping () -> Void) {
        self.item = item
        self.store = store
        self.onClose = onClose
        let parsed = TaskCaptureParser.parse(item.title, now: item.capturedAt)
        let captureID: UUID
        if case let .pendingCapture(id) = item.origin { captureID = id }
        else { captureID = item.id }
        let initialDraft = InboxCaptureReviewDraft(
            captureID: captureID,
            parsed: parsed,
            fallbackTitle: item.title
        )
        _draft = State(initialValue: initialDraft)
        _tagText = State(initialValue: initialDraft.tagNames.joined(separator: ", "))
        _projectText = State(initialValue: initialDraft.projectName ?? "")
        _contextText = State(initialValue: initialDraft.contextName ?? "")
        let duplicateID = store.duplicateCandidates(for: item).first?.existing.id
        _selectedDuplicateID = State(initialValue: duplicateID)
        _mergeResolution = State(initialValue: DuplicateMergeResolution(finalTitle: initialDraft.title))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What should this become?") {
                    TextField("Task title", text: $draft.title, axis: .vertical)
                        .accessibilityIdentifier("plan.inbox.review.title")
                }
                .lifeBoardFormRowSurface()

                metadataSection
                    .lifeBoardFormRowSurface()

                if duplicates.isEmpty == false {
                    duplicateSection
                        .lifeBoardFormRowSurface()
                }

                if let error = store.mutationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Color.lifeboard.statusWarning)
                    }
                    .lifeBoardFormRowSurface()
                }
            }
            // A bare `Form` renders on `systemGroupedBackground` — a cool grey
            // that belongs to no part of this design system, and which read as a
            // different app from the warm canvas the capture was flicked out of.
            .lifeBoardFormSurface()
            .navigationTitle("Review capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                }
                // No confirmation toolbar item: the primary action lives in the
                // sheet's bottom action zone, which is where `DESIGN.md` puts it
                // and where a control large enough to morph through its own state
                // actually fits. Two primaries in one sheet would also break the
                // one-dominant-action rule.
            }
            .safeAreaInset(edge: .bottom) {
                CommitControl(
                    title: duplicates.isEmpty ? "File It" : "Keep Both",
                    runningTitle: "Filing",
                    successTitle: "Filed",
                    phase: commitPhase,
                    isEnabled: draft.commitRequest.title.isEmpty == false,
                    action: commit
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(
                    Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea(edges: .bottom)
                )
                .accessibilityIdentifier("plan.inbox.review.file")
            }
            .interactiveDismissDisabled(store.isMutating)
            .onChange(of: draft.title) { _, newValue in
                mergeResolution.finalTitle = newValue
            }
            .onChange(of: tagText) { _, newValue in
                draft.tagNames = newValue
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
            }
            .onChange(of: projectText) { _, newValue in
                draft.projectName = newValue
            }
            .onChange(of: contextText) { _, newValue in
                draft.contextName = newValue
            }
            .task(id: selectedDuplicateID) {
                guard let selectedDuplicate else {
                    mergeDestination = nil
                    return
                }
                mergeDestination = await store.mergeDestination(for: selectedDuplicate.existing)
                mergeResolution = DuplicateMergeResolution(finalTitle: draft.title)
            }
        }
        .presentationDetents([.large])
    }

    /// Files the reviewed capture, letting the control show the write's real state.
    ///
    /// The sheet stays open until the write actually succeeds. Dismissing first
    /// would leave a failure with nowhere to report — the capture survives a failed
    /// file by design, so the user has to be able to see that and retry.
    private func commit() {
        guard draft.commitRequest.title.isEmpty == false else { return }
        commitPhase = .running(progress: nil)
        Task {
            let filed = await store.fileCapture(item, draft: draft)
            guard filed else {
                commitPhase = .recoverableFailure(
                    AsyncActionFailure(
                        message: store.mutationError ?? "Couldn’t file this capture.",
                        recovery: .retry
                    )
                )
                return
            }
            commitPhase = .success(receipt: draft.commitRequest.title)
            HapticFeedback.success()
            // Long enough to read as a confirmation, short enough not to feel like
            // a wait. The receipt and its Undo are waiting on the Inbox behind.
            try? await Task.sleep(for: .milliseconds(420))
            onClose()
        }
    }

    private var duplicates: [InboxDuplicateCandidate] {
        store.duplicateCandidates(for: item)
    }

    private var selectedDuplicate: InboxDuplicateCandidate? {
        guard let selectedDuplicateID else { return nil }
        return duplicates.first { $0.existing.id == selectedDuplicateID }
    }

    @ViewBuilder
    private var metadataSection: some View {
        Section("Reviewed details") {
            Toggle("Include date", isOn: Binding(
                get: { draft.dueDate != nil },
                set: { includesDate in
                    draft.dueDate = includesDate ? (draft.dueDate ?? item.capturedAt) : nil
                    if includesDate == false { draft.isAllDay = false }
                }
            ))
            if draft.dueDate != nil {
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { draft.dueDate ?? item.capturedAt },
                        set: { draft.dueDate = $0 }
                    ),
                    displayedComponents: draft.isAllDay ? .date : [.date, .hourAndMinute]
                )
                Toggle("All day", isOn: $draft.isAllDay)
            }

            Picker("Estimate", selection: $draft.estimatedDuration) {
                Text("None").tag(nil as TimeInterval?)
                Text("15 min").tag(15 * 60 as TimeInterval?)
                Text("30 min").tag(30 * 60 as TimeInterval?)
                Text("45 min").tag(45 * 60 as TimeInterval?)
                Text("1 hour").tag(60 * 60 as TimeInterval?)
                Text("90 min").tag(90 * 60 as TimeInterval?)
                Text("2 hours").tag(120 * 60 as TimeInterval?)
            }

            Picker("Priority", selection: $draft.priority) {
                Text("Not set").tag(nil as TaskPriority?)
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(priority as TaskPriority?)
                }
            }

            Picker("Repeat", selection: $draft.repeatPattern) {
                ForEach(Array(Self.recurrenceOptions.enumerated()), id: \.offset) { _, option in
                    Text(option.title).tag(option.pattern)
                }
            }

            // Labelled rather than placeholder-only. A `TextField` loses its
            // placeholder the moment it has a value, so a parsed capture showed
            // two unexplained rows reading "home" and "admin" beneath a column of
            // labelled pickers — the parse was correct but unreadable.
            LabeledContent("Project") {
                TextField("None", text: $projectText)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
                    .accessibilityHint("Unknown projects remain visible but file to Inbox")
            }
            LabeledContent("Context") {
                TextField("None", text: $contextText)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
            }
            LabeledContent("Tags") {
                TextField("Comma separated", text: $tagText)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
            }
        }
    }

    @ViewBuilder
    private var duplicateSection: some View {
        Section("Possible duplicate") {
            if duplicates.count > 1 {
                Picker("Compare with", selection: $selectedDuplicateID) {
                    ForEach(duplicates.prefix(3), id: \.existing.id) { candidate in
                        Text(candidate.existing.title).tag(candidate.existing.id as UUID?)
                    }
                }
            } else if let candidate = duplicates.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.existing.title)
                    Text("\(Int((candidate.similarity * 100).rounded()))% title match")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let destination = mergeDestination, let selectedDuplicate {
                comparisonRow(
                    "Date",
                    existing: Self.dateDescription(destination.dueDate, isAllDay: destination.isAllDay),
                    reviewed: Self.dateDescription(draft.dueDate, isAllDay: draft.isAllDay)
                )
                comparisonRow(
                    "Project",
                    existing: destination.projectName ?? "Inbox",
                    reviewed: draft.projectName ?? "Inbox"
                )
                comparisonRow(
                    "Priority",
                    existing: destination.priority?.displayName ?? "Not set",
                    reviewed: draft.priority?.displayName ?? "Not set"
                )
                comparisonRow(
                    "Repeat",
                    existing: destination.repeatPattern?.displayName ?? "Never",
                    reviewed: draft.repeatPattern?.displayName ?? "Never"
                )
                comparisonRow(
                    "Tags",
                    existing: destination.tagNames.isEmpty ? "None" : destination.tagNames.joined(separator: ", "),
                    reviewed: draft.tagNames.isEmpty ? "None" : draft.tagNames.joined(separator: ", ")
                )

                let conflicts = mergeResolution.conflicts(reviewed: draft, destination: destination)
                if conflicts.isEmpty == false {
                    Text("Confirm each highlighted choice before merging.")
                        .font(.footnote)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                ForEach(DuplicateMergeResolution.Field.allCases.filter(conflicts.contains), id: \.self) { field in
                    Picker("Use \(field.title)", selection: conflictBinding(field)) {
                        Text("Existing").tag(DuplicateMergeResolution.Choice.destination)
                        Text("Reviewed").tag(DuplicateMergeResolution.Choice.reviewed)
                    }
                    .accessibilityValue(
                        mergeResolution.acknowledgedFields.contains(field)
                            ? "Confirmed"
                            : "Existing selected, confirmation required"
                    )
                    .accessibilityHint("Choose a source to confirm the conflicting \(field.title.lowercased())")
                }

                Button("Merge into “\(selectedDuplicate.existing.title)”") {
                    guard let request = mergeResolution.commitRequest(
                        reviewed: draft,
                        destination: destination
                    ) else { return }
                    Task {
                        if await store.mergeCapture(item, request: request, with: selectedDuplicate.existing) {
                            onClose()
                        }
                    }
                }
                .disabled(
                    store.isMutating ||
                    mergeResolution.isComplete(reviewed: draft, destination: destination) == false
                )
                .accessibilityIdentifier("plan.inbox.review.merge")
            } else {
                ProgressView("Loading comparison…")
            }
        }
    }

    private func comparisonRow(_ label: String, existing: String, reviewed: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            HStack(alignment: .firstTextBaseline) {
                Text("Existing: \(existing)")
                Spacer(minLength: 12)
                Text("Reviewed: \(reviewed)")
            }
            .font(.footnote)
        }
        .accessibilityElement(children: .combine)
    }

    private func conflictBinding(
        _ field: DuplicateMergeResolution.Field
    ) -> Binding<DuplicateMergeResolution.Choice> {
        Binding(
            get: { mergeResolution.choices[field] ?? .destination },
            set: { mergeResolution.select($0, for: field) }
        )
    }

    private static var recurrenceOptions: [(title: String, pattern: TaskRepeatPattern?)] {
        [
            ("Never", nil),
            ("Daily", .daily),
            ("Weekdays", .weekdays),
            ("Weekly", .weekly(.allDays)),
            ("Monthly", .monthly(.onDate(Calendar.current.component(.day, from: Date())))),
            ("Yearly", .yearly(.onDate(
                month: Calendar.current.component(.month, from: Date()),
                day: Calendar.current.component(.day, from: Date())
            )))
        ]
    }

    private static func dateDescription(_ date: Date?, isAllDay: Bool) -> String {
        guard let date else { return "Not set" }
        return date.formatted(date: .abbreviated, time: isAllDay ? .omitted : .shortened)
    }
}

private extension DuplicateMergeResolution.Field {
    var title: String {
        switch self {
        case .date: "Date"
        case .project: "Project"
        case .priority: "Priority"
        case .recurrence: "Repeat"
        }
    }
}
