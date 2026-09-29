import SwiftUI

private enum MakeItFitPhase: String, Codable {
    case evidence
    case choosing
    case previewing
    case applying
    case receipt
    case failure
}

struct MakeItFitTodayView: View {
    let store: PlanStore
    let onOpenTask: (UUID) -> Void
    let onClose: () -> Void
    @State private var phase: MakeItFitPhase = .evidence
    @State private var ritualSnapshot: CommitmentRealismSnapshot?
    @State private var choices: [UUID: MakeItFitDestination] = [:]
    @State private var anchorTaskID: UUID?
    @State private var errorMessage: String?
    @State private var undoError: String?
    @State private var appliedChangeCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var snapshot: CommitmentRealismSnapshot? {
        ritualSnapshot ?? store.daySnapshot.map(CommitmentRealismEngine.snapshot)
    }

    var body: some View {
        EvaRitualShell(
            title: String(localized: "Make today fit"),
            orientation: orientation,
            evidence: evidence,
            onOpenEvidence: { reference in onOpenTask(reference.recordID) },
            onClose: close,
            content: { phaseContent },
            footer: { footer }
        )
        .task { await restoreOrStart() }
    }

    private var orientation: String {
        switch phase {
        case .evidence, .choosing, .previewing: snapshot?.orientation ?? String(localized: "Loading\u{2026}")
        case .applying: String(localized: "Moving tasks\u{2026}")
        case .receipt: remainingOverload == 0 || appliedChangeCount == 0
            ? String(localized: "Plan set.")
            : String(localized: "Today is lighter.")
        case .failure: errorMessage ?? String(localized: "Today changed. Check again.")
        }
    }

    private var evidence: [Insight.Evidence] {
        guard let snapshot else { return [] }
        return snapshot.flexibleTasks.map { task in
            Insight.Evidence(
                reference: EvaRecordReference(
                    kind: .task,
                    recordID: task.id,
                    title: task.title,
                    occurredAt: task.metadata.updatedAt
                ),
                reason: task.estimatedDuration.map {
                    String(localized: "Planned for today · \(LifeBoardDuration.text(minutes: Int($0 / 60)))")
                } ?? String(localized: "Planned for today · no estimate"),
                signalKey: task.estimatedDuration == nil ? "missing_estimate" : "planned_today"
            )
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .evidence:
            truthContent
        case .choosing:
            choiceContent
        case .previewing:
            previewContent
        case .applying:
            StatusSurface(state: .loading, title: String(localized: "Moving tasks\u{2026}"), message: "")
        case .receipt:
            receiptContent
        case .failure:
            StatusSurface(
                state: .recoverableError,
                title: String(localized: "Couldn\u{2019}t change the plan"),
                message: errorMessage ?? String(localized: "Nothing changed."),
                actionTitle: String(localized: "Try again"),
                action: { transition(to: .choosing) }
            )
        }
    }

    private var truthContent: some View {
        VStack(spacing: 16) {
            EvaRitualSection(
                eyebrow: String(localized: "Today"),
                title: String(localized: "Fixed and flexible"),
                message: String(localized: "Events stay put. Tasks can move.")
            ) {
                if let snapshot {
                    MakeItFitCapacityRibbon(snapshot: snapshot, remainingOverload: snapshot.overloadMinutes)
                    ForEach(snapshot.fixedCommitments, id: \.id) { commitment in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: "lock.fill")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(commitment.title).lifeboardFont(.bodyStrong)
                                Text(commitmentTime(commitment))
                                    .lifeboardFont(.caption1)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if snapshot.fixedCommitments.isEmpty {
                        Text("No events today")
                            .lifeboardFont(.support)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                }
            }
        }
    }

    private var choiceContent: some View {
        VStack(spacing: 16) {
            EvaRitualSection(
                eyebrow: String(localized: "Anchor"),
                title: String(localized: "Most important task"),
                message: String(localized: "Suggested from what you usually do first.")
            ) {
                if let snapshot {
                    Picker("Anchor task", selection: $anchorTaskID) {
                        Text("None").tag(UUID?.none)
                        ForEach(snapshot.flexibleTasks) { task in
                            Text(task.title).tag(Optional(task.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: anchorTaskID) { _, newAnchor in
                        if let newAnchor { choices[newAnchor] = .keepToday }
                        persistDraft()
                    }
                }
            }

            EvaRitualSection(
                eyebrow: String(localized: "The rest"),
                title: String(localized: "Move the rest"),
                message: String(localized: "Deadlines stay. Tasks with no estimate don\u{2019}t count.")
            ) {
                if let snapshot {
                    ForEach(snapshot.flexibleTasks) { task in
                        MakeItFitTaskChoiceRow(
                            task: task,
                            isAnchor: anchorTaskID == task.id,
                            selection: Binding(
                                get: { choices[task.id] ?? .keepToday },
                                set: {
                                    guard anchorTaskID != task.id || $0 == .keepToday else { return }
                                    choices[task.id] = $0
                                    persistDraft()
                                }
                            ),
                            onSaveEstimate: { minutes in
                                await saveEstimate(minutes, for: task.id)
                            }
                        )
                    }
                }
            }
        }
    }

    private var previewContent: some View {
        EvaRitualSection(
            eyebrow: String(localized: "Changes"),
            title: remainingOverload == 0 ? String(localized: "Everything fits") : String(localized: "\(LifeBoardDuration.text(minutes: remainingOverload)) over"),
            message: String(localized: "Deadlines and events don\u{2019}t change.")
        ) {
            if let snapshot {
                MakeItFitCapacityRibbon(snapshot: snapshot, remainingOverload: remainingOverload)
                ForEach(changedTasks, id: \.0.id) { task, destination in
                    HStack {
                        Text(task.title).lineLimit(2)
                        Spacer()
                        Text(destination.displayTitle)
                            .lifeboardFont(.caption1)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                }
                if changedTasks.isEmpty {
                    Text("Plan unchanged")
                        .lifeboardFont(.support)
                }
            }
        }
    }

    /// Truthful: "Today fits" only when the moves really cleared the overload.
    private var receiptTitle: String {
        if appliedChangeCount == 0 { return String(localized: "Plan unchanged") }
        if remainingOverload == 0 { return String(localized: "Today fits") }
        return String(localized: "\(LifeBoardDuration.text(minutes: remainingOverload)) over")
    }

    private var receiptContent: some View {
        EvaRitualSection(
            eyebrow: String(localized: "Done"),
            title: receiptTitle,
            message: appliedChangeCount == 0
                ? nil
                : String(localized: "Deadlines didn\u{2019}t change.")
        ) {
            if appliedChangeCount > 0 {
                Label(receiptSummary, systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            }
            if let undoError {
                Text(undoError)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard.statusWarning)
                    .accessibilityLabel("Undo error: \(undoError)")
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .evidence:
            PrimaryButton(title: String(localized: "Next"), systemImage: "arrow.right") {
                transition(to: .choosing)
            }
            .frame(maxWidth: .infinity)
        case .choosing:
            HStack(spacing: 12) {
                backButton(to: .evidence)
                PrimaryButton(title: String(localized: "Review changes"), systemImage: "rectangle.and.text.magnifyingglass") {
                    transition(to: .previewing)
                }
                .frame(maxWidth: .infinity)
            }
        case .previewing:
            HStack(spacing: 12) {
                backButton(to: .choosing)
                PrimaryButton(
                    title: changedTasks.isEmpty
                        ? String(localized: "Keep plan")
                        : (changedTasks.count == 1 ? String(localized: "Move 1 task") : String(localized: "Move \(changedTasks.count) tasks")),
                    systemImage: "checkmark"
                ) { apply() }
                .frame(maxWidth: .infinity)
            }
        case .applying:
            ProgressView().frame(maxWidth: .infinity, minHeight: 48)
        case .receipt:
            HStack(spacing: 12) {
                if appliedChangeCount > 0 {
                    Button("Undo") {
                        Task {
                            if await store.undoLastMutation() {
                                undoError = nil
                                appliedChangeCount = 0
                                if let current = store.daySnapshot.map(CommitmentRealismEngine.snapshot) {
                                    ritualSnapshot = current
                                }
                                transition(to: .choosing)
                            } else {
                                undoError = store.errorMessage ?? String(localized: "Couldn\u{2019}t undo.")
                            }
                        }
                    }
                    .frame(minWidth: 72, minHeight: 48)
                }
                PrimaryButton(title: String(localized: "Start next task"), systemImage: "arrow.right") {
                    startNextMove()
                }
            }
        case .failure:
            PrimaryButton(title: String(localized: "Try again"), systemImage: "arrow.clockwise") {
                transition(to: .choosing)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

extension MakeItFitTodayView {
    private var remainingOverload: Int {
        guard let snapshot else { return 0 }
        return CommitmentRealismEngine.remainingOverloadMinutes(snapshot: snapshot, choices: choices)
    }

    private var changedTasks: [(PlanningTaskSummary, MakeItFitDestination)] {
        guard let snapshot else { return [] }
        return snapshot.flexibleTasks.compactMap { task in
            guard let destination = choices[task.id], destination != .keepToday else { return nil }
            return (task, destination)
        }
    }

    private func transition(to next: MakeItFitPhase) {
        withAnimation(MotionProfile.route.animation(reduceMotion: reduceMotion)) { phase = next }
        persistDraft()
    }

    /// Steps go back as well as forward; choices made so far are kept.
    private func backButton(to previous: MakeItFitPhase) -> some View {
        Button {
            Haptic.pick.play()
            transition(to: previous)
        } label: {
            Label("Back", systemImage: "chevron.left")
                .lifeboardFont(.button)
                .frame(minWidth: 44, minHeight: 48)
        }
        .buttonStyle(.lifeBoardChip)
        .accessibilityIdentifier("eva.makeItFit.back")
    }

    private func apply() {
        guard changedTasks.isEmpty == false else {
            appliedChangeCount = 0
            transition(to: .receipt)
            return
        }
        guard let expectedSnapshot = snapshot else {
            errorMessage = String(localized: "Couldn\u{2019}t check today. Nothing changed.")
            transition(to: .failure)
            return
        }
        transition(to: .applying)
        Task {
            switch await store.applyMakeItFit(choices: choices, expectedSnapshot: expectedSnapshot) {
            case .applied(let changedCount):
                appliedChangeCount = changedCount
                Haptic.commit.play()
                transition(to: .receipt)
            case .noChanges:
                appliedChangeCount = 0
                transition(to: .receipt)
            case .stale(let refreshed):
                ritualSnapshot = refreshed
                reconcileChoices(with: refreshed)
                errorMessage = String(localized: "Today changed. Check the moves again.")
                transition(to: .failure)
            case .failed(let message):
                errorMessage = message
                transition(to: .failure)
            }
        }
    }

    private func restoreOrStart() async {
        guard let current = store.daySnapshot.map(CommitmentRealismEngine.snapshot) else { return }
        ritualSnapshot = current
        anchorTaskID = current.anchorTaskID
        guard let draft = EvaRitualDraftStore.shared.load(.makeItFitToday),
              Calendar.current.isDate(draft.referenceDate, inSameDayAs: Date()) else { return }
        let validIDs = Set(current.flexibleTasks.map(\.id))
        choices = draft.choices.reduce(into: [:]) { result, pair in
            guard let id = UUID(uuidString: pair.key), validIDs.contains(id),
                  let destination = MakeItFitDestination(rawValue: pair.value) else { return }
            result[id] = destination
        }
        if let anchorRaw = draft.choices["anchor"], let anchor = UUID(uuidString: anchorRaw), validIDs.contains(anchor) {
            anchorTaskID = anchor
        }
        if let anchorTaskID { choices[anchorTaskID] = .keepToday }
        phase = MakeItFitPhase(rawValue: draft.phaseRaw) ?? .evidence
        if phase == .receipt,
           let receiptID = draft.actionRunID,
           await store.restoreMutationReceipt(id: receiptID) {
            appliedChangeCount = Int(draft.choices["appliedChangeCount"] ?? "") ?? changedTasks.count
        } else if phase == .applying || phase == .receipt {
            phase = .previewing
        }
    }

    private func persistDraft() {
        var encoded = Dictionary(uniqueKeysWithValues: choices.map { ($0.key.uuidString, $0.value.rawValue) })
        if let anchorTaskID { encoded["anchor"] = anchorTaskID.uuidString }
        if appliedChangeCount > 0 { encoded["appliedChangeCount"] = String(appliedChangeCount) }
        EvaRitualDraftStore.shared.save(.init(
            kind: .makeItFitToday,
            recordIDs: snapshot?.flexibleTasks.map(\.id) ?? [],
            referenceDate: Date(),
            phaseRaw: phase.rawValue,
            choices: encoded,
            actionRunID: appliedChangeCount > 0 ? store.lastMutationReceiptID : nil
        ))
    }

    private func close() {
        if phase == .receipt { EvaRitualDraftStore.shared.clear(.makeItFitToday) }
        onClose()
    }

    @MainActor
    private func saveEstimate(_ minutes: Int, for taskID: UUID) async -> Bool {
        guard await store.updateTaskEstimate(taskID: taskID, minutes: minutes),
              let refreshed = store.daySnapshot.map(CommitmentRealismEngine.snapshot) else {
            errorMessage = store.errorMessage ?? String(localized: "Couldn\u{2019}t save the estimate.")
            return false
        }
        ritualSnapshot = refreshed
        reconcileChoices(with: refreshed)
        persistDraft()
        return true
    }

    private func reconcileChoices(with refreshed: CommitmentRealismSnapshot) {
        let validIDs = Set(refreshed.flexibleTasks.map(\.id))
        choices = choices.filter { validIDs.contains($0.key) }
        if let anchorTaskID, validIDs.contains(anchorTaskID) == false {
            self.anchorTaskID = refreshed.anchorTaskID
        }
        if let anchorTaskID { choices[anchorTaskID] = .keepToday }
    }

    private var nextMoveTaskID: UUID? {
        guard let snapshot else { return nil }
        if let anchorTaskID, choices[anchorTaskID] == nil || choices[anchorTaskID] == .keepToday {
            return anchorTaskID
        }
        return snapshot.flexibleTasks.first { choices[$0.id] == nil || choices[$0.id] == .keepToday }?.id
    }

    private func startNextMove() {
        EvaRitualDraftStore.shared.clear(.makeItFitToday)
        guard let nextMoveTaskID else { onClose(); return }
        onOpenTask(nextMoveTaskID)
    }

    private var receiptSummary: String {
        // Use the persisted choices rather than today's current task list: moved
        // tasks legitimately disappear from that list when a receipt is restored.
        let moved = choices.values.filter { $0 == .tomorrow }.count
        let later = choices.values.filter { $0 == .later }.count
        let released = choices.values.filter { $0 == .someday }.count
        let inbox = choices.values.filter { $0 == .inbox }.count
        return [
            moved > 0 ? String(localized: "\(moved) to Tomorrow") : nil,
            later > 0 ? String(localized: "\(later) to Later") : nil,
            released > 0 ? String(localized: "\(released) to Someday") : nil,
            inbox > 0 ? String(localized: "\(inbox) to Inbox") : nil
        ].compactMap { $0 }.joined(separator: " · ")
    }

    private func commitmentTime(_ commitment: PlanningFixedCommitment) -> String {
        let format = Date.FormatStyle(date: .omitted, time: .shortened)
        return "\(commitment.startAt.formatted(format))–\(commitment.endAt.formatted(format))"
    }
}

private struct MakeItFitCapacityRibbon: View {
    let snapshot: CommitmentRealismSnapshot
    let remainingOverload: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { proxy in
                let usable = max(snapshot.usableMinutes, 1)
                let movedKnown = max(0, snapshot.overloadMinutes - remainingOverload)
                let knownAfter = max(0, snapshot.plannedKnownMinutes - movedKnown)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.lifeboard.surfaceSecondary)
                    Capsule()
                        .fill(remainingOverload > 0 ? Color.lifeboard.statusWarning : Color.lifeboard.statusSuccess)
                        .frame(width: proxy.size.width * min(1, Double(knownAfter) / Double(usable)))
                }
            }
            .frame(height: 16)
            Text(remainingOverload > 0 ? String(localized: "\(LifeBoardDuration.text(minutes: remainingOverload)) over") : String(localized: "Everything fits"))
                .lifeboardFont(.caption1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(remainingOverload > 0 ? String(localized: "\(LifeBoardDuration.text(minutes: remainingOverload)) over today") : String(localized: "Everything fits today"))
    }
}

private struct MakeItFitTaskChoiceRow: View {
    let task: PlanningTaskSummary
    let isAnchor: Bool
    @Binding var selection: MakeItFitDestination
    let onSaveEstimate: (Int) async -> Bool
    @State private var estimateText = ""
    @State private var isEditingEstimate = false
    @State private var isSavingEstimate = false
    @State private var estimateError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title).lifeboardFont(.bodyStrong)
                    Text(task.estimatedDuration.map { LifeBoardDuration.text(minutes: Int($0 / 60)) } ?? String(localized: "No estimate"))
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                Spacer()
                if isAnchor { Image(systemName: "pin.fill").accessibilityLabel("Anchor") }
            }
            Picker("Destination for \(task.title)", selection: $selection) {
                ForEach(MakeItFitDestination.allCases, id: \.self) { destination in
                    Text(destination.displayTitle).tag(destination)
                }
            }
            .pickerStyle(.menu)
            .disabled(isAnchor)
            .accessibilityHint(isAnchor ? "Anchor stays today" : "Choose where it goes")
            if task.estimatedDuration == nil {
                if isEditingEstimate {
                    HStack(spacing: 12) {
                        TextField("Minutes", text: $estimateText, prompt: Text("Minutes").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                            .padKeyboard(.numberPad)
                            .textFieldStyle(.plain)
                            // Clay well, not the system rounded border: that drew a pure white
                            // box on warm paper and a pure black one in dark appearance.
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
                            .accessibilityLabel("Estimate in minutes for \(task.title)")
                        Button(isSavingEstimate ? "Saving…" : "Save") { saveEstimate() }
                            .buttonStyle(.lifeBoardChip)
                            .disabled(isSavingEstimate || validEstimate == nil)
                    }
                    if let estimateError {
                        Text(estimateError)
                            .lifeboardFont(.caption1)
                            .foregroundStyle(Color.lifeboard.statusWarning)
                            .accessibilityLabel("Estimate error: \(estimateError)")
                    }
                } else {
                    Button("Add estimate") {
                        estimateText = "30"
                        estimateError = nil
                        isEditingEstimate = true
                    }
                    .lifeboardFont(.caption1)
                    .frame(minHeight: 44)
                }
            }
        }
        .padding(.vertical, 5)
    }

    private var validEstimate: Int? {
        guard let minutes = Int(estimateText), (5...1_440).contains(minutes) else { return nil }
        return minutes
    }

    private func saveEstimate() {
        guard let minutes = validEstimate else {
            estimateError = String(localized: "Use 5–1,440 minutes.")
            return
        }
        isSavingEstimate = true
        estimateError = nil
        Task { @MainActor in
            if await onSaveEstimate(minutes) {
                isEditingEstimate = false
            } else {
                estimateError = String(localized: "Couldn\u{2019}t save estimate. Try again.")
            }
            isSavingEstimate = false
        }
    }
}

private extension MakeItFitDestination {
    /// The shared "where does this go" words where they map (DESIGN.md
    /// contract 4); Later and Inbox are backlog places, not days.
    var displayTitle: String {
        switch self {
        case .keepToday: DecisionDestination.today.title
        case .tomorrow: DecisionDestination.tomorrow.title
        case .later: String(localized: "Later")
        case .someday: DecisionDestination.someday.title
        case .inbox: String(localized: "Inbox")
        }
    }
}
