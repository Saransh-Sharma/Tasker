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

    var scope: LifeBoardInboxQuery.Scope = .untriaged {
        didSet { guard oldValue != scope else { return }; Task { await load() } }
    }

    private let reader: InboxReader
    private let planningRepository: any PlanningRepository
    private let mutationRepository: any PlanningMutationRepository

    init(
        reader: InboxReader,
        planningRepository: any PlanningRepository,
        mutationRepository: any PlanningMutationRepository
    ) {
        self.reader = reader
        self.planningRepository = planningRepository
        self.mutationRepository = mutationRepository
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
            }
        case .failure:
            // `moveToProject` and `commitCapture` need the task repository
            // rather than the planning ledger; neither is offered by this view
            // yet, so reaching here means a decision could not be honored and
            // must not look like it was.
            loadFailed = true
        }
    }

    func undoLast() async {
        guard let receipt = lastReceipt else { return }
        try? await mutationRepository.undo(receiptID: receipt.id)
        lastReceipt = nil
        lastSummary = nil
        await load()
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
        return parsed.dueDate == nil ? nil : parsed
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
        }
        .task { await store.load() }
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
                    Text("Already added — safe to clear")
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
        HStack(spacing: 6) {
            if let due = parsed.dueDate {
                chip(
                    parsed.isAllDay
                        ? due.formatted(date: .abbreviated, time: .omitted)
                        : due.formatted(date: .abbreviated, time: .shortened),
                    symbol: "calendar"
                )
            }
            if let matched = parsed.matchedText {
                chip("from “\(matched)”", symbol: "text.magnifyingglass")
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            parsed.dueDate.map { "Proposed date \($0.formatted(date: .abbreviated, time: .shortened)), not yet applied" }
                ?? "No date proposed"
        )
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
