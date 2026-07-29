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

    var scope: LifeBoardInboxQuery.Scope = .untriaged {
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
            items = try await reader.items(for: LifeBoardInboxQuery(scope: scope))
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
    func fileCapture(_ item: InboxItem, reviewedTitle: String) async -> Bool {
        guard let commitCoordinator,
              case let .pendingCapture(captureID) = item.origin,
              let capture = captureQueue.read().first(where: { $0.id == captureID })
        else {
            mutationError = "This capture can’t be filed from the current route."
            return false
        }

        isMutating = true
        mutationError = nil
        defer { isMutating = false }

        let editedRequest = reviewedRequest(for: item, title: reviewedTitle, captureID: captureID)

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
        reviewedTitle: String,
        with duplicate: InboxItem
    ) async -> Bool {
        guard let commitCoordinator,
              case let .pendingCapture(captureID) = item.origin,
              captureQueue.read().contains(where: { $0.id == captureID })
        else {
            mutationError = "This capture can’t be merged from the current route."
            return false
        }
        let request = reviewedRequest(for: item, title: reviewedTitle, captureID: captureID)
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

    private func reviewedRequest(
        for item: InboxItem,
        title: String,
        captureID: UUID
    ) -> InboxCaptureCommitRequest {
        let parsed = TaskCaptureParser.parse(item.title, now: item.capturedAt)
        let request = InboxCaptureCommitRequest.reviewed(
            captureID: captureID,
            parsed: parsed,
            fallbackTitle: title
        )
        return InboxCaptureCommitRequest(
            captureID: request.captureID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: request.dueDate,
            isAllDay: request.isAllDay,
            estimatedDuration: request.estimatedDuration,
            repeatPattern: request.repeatPattern,
            priority: request.priority,
            projectName: request.projectName,
            tagNames: request.tagNames,
            contextName: request.contextName
        )
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

struct LifeBoardInboxView: View {
    @Bindable var store: InboxStore
    /// Opens the normal task editor seeded with the capture's raw text.
    ///
    /// Reuses the app's real capture flow rather than committing from here, so
    /// filing an unreviewed capture goes through the same editor — and the same
    /// chance to disagree with the parser — as anything typed by hand.
    var onReviewCapture: ((InboxItem) -> Void)?
    @State private var selection: Set<UUID> = []
    @State private var filingItem: InboxItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            scopePicker

            if store.isLoading && store.items.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else if store.loadFailed {
                stateMessage(
                    title: "Couldn’t load your inbox",
                    detail: "Nothing has been lost. Pull to try again.",
                    symbol: "exclamationmark.circle"
                )
            } else if store.items.isEmpty {
                emptyState
            } else {
                if selection.isEmpty == false { batchBar }
                ForEach(store.items) { item in
                    row(item)
                    Divider().overlay(Color.lifeboard.strokeHairline)
                }
            }

            if let summary = store.lastSummary {
                undoRow(summary)
            }
            if let mutationError = store.mutationError {
                Label(mutationError, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(Color.lifeboard.statusWarning)
                    .accessibilityIdentifier("plan.inbox.mutation-error")
            }
        }
        .task { await store.load() }
        .sheet(item: $filingItem) { item in
            InboxCaptureReviewSheet(item: item, store: store) {
                filingItem = nil
            }
        }
        .accessibilityIdentifier("plan.inbox")
    }

    private var scopePicker: some View {
        Picker("Inbox scope", selection: Binding(
            get: { store.scope },
            set: { store.scope = $0 }
        )) {
            Text("Inbox").tag(LifeBoardInboxQuery.Scope.untriaged)
            Text("Someday").tag(LifeBoardInboxQuery.Scope.someday)
            Text("Reference").tag(LifeBoardInboxQuery.Scope.reference)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("plan.inbox.scope")
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
                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .accessibilityElement(children: .combine)
    }

    private func row(_ item: InboxItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                if selection.contains(item.id) { selection.remove(item.id) }
                else { selection.insert(item.id) }
            } label: {
                Image(systemName: selection.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selection.contains(item.id) ? "Deselect \(item.title)" : "Select \(item.title)")

            VStack(alignment: .leading, spacing: 3) {
                Text(proposalTitle(for: item))
                    .font(.body)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                if store.alreadyFiled(item) {
                    Text("Possible duplicate — choose what to keep")
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
            }

            Spacer(minLength: 0)

            if item.requiresCommitBeforeScheduling {
                HStack(spacing: 10) {
                    Button("File It") { filingItem = item }
                        .font(.footnote.weight(.semibold))
                        .disabled(store.isMutating)
                        .accessibilityIdentifier("plan.inbox.file.\(item.id.uuidString)")
                    if let onReviewCapture {
                        Button("Review") { onReviewCapture(item) }
                            .font(.footnote.weight(.medium))
                            .accessibilityIdentifier("plan.inbox.review.\(item.id.uuidString)")
                    }
                    Button("Discard") { Task { await store.discardCapture(item) } }
                        .font(.footnote)
                        .accessibilityIdentifier("plan.inbox.discard.\(item.id.uuidString)")
                }
            } else {
                triageMenu(for: item)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.inbox.row.\(item.id.uuidString)")
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
        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        }
        .accessibilityLabel("Triage \(item.title)")
        .accessibilityIdentifier("plan.inbox.triage.\(item.id.uuidString)")
    }

    private var batchBar: some View {
        HStack(spacing: 12) {
            Text("\(selection.count) selected")
                .font(.subheadline)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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
        HStack {
            Text(summary)
                .font(.footnote)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            Spacer()
            Button("Undo") { Task { await store.undoLast() } }
                .font(.footnote.weight(.medium))
                .accessibilityIdentifier("plan.inbox.undo")
        }
        .padding(.vertical, 6)
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
    @State private var title: String

    init(item: InboxItem, store: InboxStore, onClose: @escaping () -> Void) {
        self.item = item
        self.store = store
        self.onClose = onClose
        let parsed = TaskCaptureParser.parse(item.title, now: item.capturedAt)
        _title = State(initialValue: parsed.cleanTitle.isEmpty ? item.title : parsed.cleanTitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What should this become?") {
                    TextField("Task title", text: $title, axis: .vertical)
                        .accessibilityIdentifier("plan.inbox.review.title")
                }

                let duplicates = store.duplicateCandidates(for: item)
                if duplicates.isEmpty == false {
                    Section("Possible duplicate") {
                        ForEach(duplicates.prefix(3), id: \.existing.id) { candidate in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(candidate.existing.title)
                                Text("\(Int((candidate.similarity * 100).rounded()))% title match")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let candidate = duplicates.first {
                            Button("Merge into “\(candidate.existing.title)”") {
                                Task {
                                    if await store.mergeCapture(
                                        item,
                                        reviewedTitle: title,
                                        with: candidate.existing
                                    ) {
                                        onClose()
                                    }
                                }
                            }
                            .disabled(store.isMutating)
                            .accessibilityIdentifier("plan.inbox.review.merge")
                        }
                        Text("Merge keeps the existing item’s populated date, project, priority, and recurrence; it fills missing fields, combines tags, and uses the title above. Choosing Merge confirms those conflict choices. Keep Both creates a separate task. Cancel makes no changes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = store.mutationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Color.lifeboard.statusWarning)
                    }
                }
            }
            .navigationTitle("Review capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.duplicateCandidates(for: item).isEmpty ? "File It" : "Keep Both") {
                        Task {
                            if await store.fileCapture(item, reviewedTitle: title) {
                                onClose()
                            }
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isMutating)
                    .accessibilityIdentifier("plan.inbox.review.file")
                }
            }
            .interactiveDismissDisabled(store.isMutating)
        }
        .presentationDetents([.medium, .large])
    }
}
