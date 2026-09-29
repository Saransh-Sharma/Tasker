import SwiftUI

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
    @State private var pickingDayTaskIDs: [UUID] = []
    @State private var pickedDay = Date()
    @State private var showsDayPicker = false
    @State private var filingItem: InboxItem?
    /// How many times each capture has been passed over.
    ///
    /// Presentation only — skipping is explicitly not a mutation, so a capture is
    /// never altered just because it was not the one you wanted next. The count
    /// lives beside the view rather than in the capture record, whose text,
    /// timestamp and id must stay exactly as captured.
    @State private var skipCounts: [UUID: Int] = [:]
    /// The capture a Discard removed, kept only long enough for Undo.
    @State private var discardedCapture: PendingCapture?
    @State private var discardReceipt: ActionReceiptPresentation?
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
            case .file: String(localized: "File it")
            case .skip: String(localized: "Skip")
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
            if let receipt = discardReceipt {
                ReceiptBar(
                    receipt,
                    undo: {
                        guard let capture = discardedCapture else { return }
                        discardReceipt = nil
                        discardedCapture = nil
                        Task { await store.restoreCapture(capture) }
                    },
                    onDismiss: {
                        discardReceipt = nil
                        discardedCapture = nil
                    }
                )
                .accessibilityIdentifier("plan.inbox.discard.receipt")
                .lifeBoardMotion(.contentInsertion, value: receipt.id)
            }

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
        .sheet(isPresented: $showsDayPicker) {
            NavigationStack {
                DatePicker("Plan for", selection: $pickedDay, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(16)
                    .navigationTitle("Pick a day")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showsDayPicker = false }.keyboardShortcut(.cancelAction) }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Plan it") {
                                let day = PlanningDay(date: pickedDay)
                                let mutations = pickingDayTaskIDs.map { InboxTriageMutation.schedule(taskID: $0, before: nil, after: day) }
                                showsDayPicker = false
                                Task { await store.apply(.batch(mutations)) }
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
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
        // Was `.pickerStyle(.segmented)`, the stock grey segmented control.
        // `OptionRail` is the design system's equivalent and keeps the
        // semantics: one selection, per-value accessibility identifiers,
        // and reflow at accessibility text sizes.
        OptionRail(
            "Inbox scope",
            selection: Binding(
                get: { store.scope },
                set: { store.scope = $0 }
            ),
            values: [.untriaged, .someday, .reference],
            identifierPrefix: "plan.inbox.scope",
            title: { scope in
                switch scope {
                case .untriaged: "Inbox"
                case .someday: "Someday"
                case .reference: "Reference"
                }
            },
            showsLabel: false
        )
        .accessibilityIdentifier("plan.inbox.scope")
    }

    // MARK: - Capture deck

    /// The decision surface. One capture is in the hand at a time because each
    /// one is a separate judgement, and a flat list of five equally weighted rows
    /// invites skimming past things that were captured in a hurry.
    private var captureDeckSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Capture's panoramic scene, which used to sit behind the root
            // header where the atmosphere swallowed it. Inbox is where captures
            // are actually reviewed, and its canvas is quiet enough to show it.
            .featureHeaderArtwork(.capture, cornerRadius: Radius.row)

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
                // A warning, not a success: something may be filed twice.
                Label("Possible duplicate. Choose what to keep.", systemImage: "square.on.square")
                    .font(.caption)
                    .foregroundStyle(Color.lifeboard.statusWarning)
            } else if let source = item.captureSource {
                // Named so an unreviewed capture is visibly different from a
                // task the user created deliberately in the app.
                Text("From \(InboxCaptureSourceCopy.label(for: source))")
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
                "Skipped \(passes) times",
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
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
}

extension InboxView {

    /// One dominant action, then quieter equivalents.
    ///
    /// This replaced three same-size `.footnote` text buttons crowded against the
    /// trailing edge — none of which reached the 44-point minimum, and which gave
    /// Discard exactly as much visual weight as File It.
    private func captureActions(for item: InboxItem) -> some View {
        HStack(spacing: 12) {
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
                .accessibilityLabel("Edit \(item.title)")
                .accessibilityIdentifier("plan.inbox.review.\(item.id.uuidString)")
            }

            Button {
                skip(item)
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.lifeBoardClay(.resting, cornerRadius: Radius.compact, fill: nil))
            .accessibilityLabel("Skip \(item.title)")
            .accessibilityIdentifier("plan.inbox.skip.\(item.id.uuidString)")

            Menu {
                Button("Discard", systemImage: "trash", role: .destructive) {
                    forgetSkips(for: item)
                    Task {
                        guard let removed = await store.discardCapture(item) else { return }
                        discardedCapture = removed
                        discardReceipt = ActionReceiptPresentation(
                            message: String(localized: "Discarded “\(item.title)”")
                        )
                    }
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
        Haptic.pick.play()
        triageSettleDirection = 1
        triageSettleTrigger &+= 1
        filingItem = item
    }

    /// Sinks the capture in the deck. No mutation, no receipt: the capture is
    /// untouched and will be waiting next time — including after a relaunch.
    private func skip(_ item: InboxItem) {
        Haptic.pick.play()
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
            Text("Already filed")
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
        HStack(alignment: .top, spacing: 12) {
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
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<2, id: \.self) { index in
                RoundedRectangle(cornerRadius: Radius.largeCard, style: .continuous)
                    .fill(Color(SemanticColorTokens.foundationSurfaceRecessed))
                    .frame(height: index == 0 ? 132 : 96)
                    .opacity(index == 0 ? 1 : 0.55)
            }
        }
        .accessibilityLabel("Loading…")
        .accessibilityIdentifier("plan.inbox.loading")
    }

    /// Deliberately not shaped like `emptyState`. A failed fetch that looks like
    /// an empty inbox congratulates someone for a load that never completed.
    private var loadFailure: some View {
        // The shared state surface, so a recoverable failure here looks like a
        // recoverable failure everywhere else in the product — and says what
        // remains safe.
        StatusSurface(
            state: .recoverableError,
            title: String(localized: "Couldn’t load Inbox"),
            message: String(localized: "Your captures are safe."),
            actionTitle: String(localized: "Try again"),
            action: { Task { await store.load() } }
        )
        .accessibilityIdentifier("plan.inbox.loadFailure")
    }

    /// An empty Inbox is a success state, not a void.
    private var emptyState: some View {
        StatusSurface(
            state: store.scope == .untriaged ? .empty : .noRecord,
            title: store.scope == .untriaged ? String(localized: "Inbox clear") : String(localized: "Nothing here"),
            message: "",
            density: .compact
        )
    }

    /// Every swipe affordance also lives here, so the same decisions are
    /// reachable by pointer, keyboard and VoiceOver.
    private func triageMenu(for item: InboxItem) -> some View {
        Menu {
            // Scheduling was the one triage decision the row could not make,
            // though `InboxTriageMutation.schedule` existed and is receipt-backed.
            Section("Schedule") {
                Button("Today", systemImage: "sun.max") { schedule(item, daysFromToday: 0) }
                Button("Tomorrow", systemImage: "sunrise") { schedule(item, daysFromToday: 1) }
                Button("Pick a day…", systemImage: "calendar") {
                    if case let .task(id) = item.origin { pickingDayTaskIDs = [id]; showsDayPicker = true }
                }
                Button("Next week", systemImage: "calendar") { schedule(item, daysFromToday: InboxScheduleShortcut.daysUntilNextWeek()) }
            }
            Button("Move to Someday") { triage(item, to: .someday) }
            Button("Move to Reference") { triage(item, to: .reference) }
            Button("Move to Inbox") { triage(item, to: .inbox) }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
        .accessibilityLabel("Actions for \(item.title)")
        .accessibilityIdentifier("plan.inbox.triage.\(item.id.uuidString)")
    }

    private var batchBar: some View {
        HStack(spacing: 12) {
            Text("\(selection.count) selected")
                .font(.subheadline)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            Spacer()
            Button("Today") { scheduleSelection(daysFromToday: 0) }
            Button("Tomorrow") { scheduleSelection(daysFromToday: 1) }
            Button("Pick a day…") {
                pickingDayTaskIDs = store.items.filter { selection.contains($0.id) }.compactMap {
                    if case let .task(id) = $0.origin { return id }; return nil
                }
                showsDayPicker = !pickingDayTaskIDs.isEmpty
            }
            Button("Someday") { triageSelection(to: .someday) }
            Button("Reference") { triageSelection(to: .reference) }
            Button("Clear") { selection.removeAll() }
        }
        .font(.subheadline)
        .padding(.vertical, 8)
        .accessibilityIdentifier("plan.inbox.batchBar")
    }

    /// The filing receipt.
    ///
    /// Was a hand-rolled footnote-sized row that never stacked at accessibility
    /// text sizes. `ReceiptBar` is the primitive for this, and it keeps Undo
    /// reachable rather than on a timer.
    private func undoRow(_ summary: String) -> some View {
        ReceiptBar(
            ActionReceiptPresentation(message: summary),
            undo: { Task { await store.undoLast() } },
            onDismiss: { store.clearLastSummary() }
        )
        .accessibilityIdentifier("plan.inbox.undo")
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

    private func schedule(_ item: InboxItem, daysFromToday: Int) {
        guard case let .task(taskID) = item.origin else { return }
        let day = InboxScheduleShortcut.day(daysFromToday: daysFromToday)
        Task { await store.apply(.schedule(taskID: taskID, before: nil, after: day)) }
    }

    private func scheduleSelection(daysFromToday: Int) {
        let day = InboxScheduleShortcut.day(daysFromToday: daysFromToday)
        let mutations = store.items
            .filter { selection.contains($0.id) }
            .compactMap { item -> InboxTriageMutation? in
                guard case let .task(taskID) = item.origin else { return nil }
                return .schedule(taskID: taskID, before: nil, after: day)
            }
        guard mutations.isEmpty == false else { return }
        selection.removeAll()
        Task { await store.apply(.batch(mutations)) }
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

/// The day behind Inbox's "Today / Tomorrow / Next week" shortcuts.
enum InboxScheduleShortcut {
    static func day(daysFromToday: Int, now: Date = Date(), calendar: Calendar = .current) -> PlanningDay {
        let date = calendar.date(byAdding: .day, value: daysFromToday, to: calendar.startOfDay(for: now)) ?? now
        return PlanningDay(date: date, calendar: calendar)
    }

    /// Days until the next Monday (never 0: "next week" from a Monday is a week out).
    static func daysUntilNextWeek(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: now) // 1 = Sunday
        let untilMonday = (9 - weekday) % 7
        return untilMonday == 0 ? 7 : untilMonday
    }
}

/// Where a capture came from, in the person's words. `PendingCapture.source`
/// is a storage id ("share-extension", "control"), and the card used to show
/// it verbatim.
enum InboxCaptureSourceCopy {
    static func label(for source: String) -> String {
        switch source.lowercased() {
        case "share-extension", "share": "Share sheet"
        case "siri", "shortcut", "shortcuts", "app-intent": "Siri"
        case "control", "control-center": "Control Center"
        case "widget": "Widget"
        case "watch": "Apple Watch"
        case "in-app", "app": "LifeBoard"
        default: "elsewhere"
        }
    }
}
