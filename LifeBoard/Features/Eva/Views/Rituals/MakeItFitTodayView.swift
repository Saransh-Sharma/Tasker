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
            title: "Make It Fit Today",
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
        case .evidence, .choosing, .previewing: snapshot?.orientation ?? "Gathering the shape of today."
        case .applying: "Applying only the changes you reviewed."
        case .receipt: "Today fits the plan you chose."
        case .failure: errorMessage ?? "The plan changed before it could be applied."
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
                    "Planned for today · \(CommitmentRealismSnapshot.duration(Int($0 / 60)))"
                } ?? "Planned for today · size unknown",
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
            StatusSurface(state: .loading, title: "Making room", message: "Rechecking the day and writing one reversible planning receipt.")
        case .receipt:
            receiptContent
        case .failure:
            StatusSurface(
                state: .recoverableError,
                title: "Your plan is still safe",
                message: errorMessage ?? "Nothing was changed.",
                actionTitle: "Review again",
                action: { transition(to: .choosing) }
            )
        }
    }

    private var truthContent: some View {
        VStack(spacing: 18) {
            EvaRitualSection(
                eyebrow: "See the truth",
                title: "Fixed first. Flexible second.",
                message: "Calendar commitments are read-only here. EVA only helps renegotiate the work around them."
            ) {
                if let snapshot {
                    MakeItFitCapacityRibbon(snapshot: snapshot, remainingOverload: snapshot.overloadMinutes)
                    ForEach(snapshot.fixedCommitments, id: \.id) { commitment in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: "lock.fill")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(commitment.title).font(.subheadline.weight(.medium))
                                Text(commitmentTime(commitment))
                                    .font(.caption)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if snapshot.fixedCommitments.isEmpty {
                        Text("No fixed commitments are claiming the working window.")
                            .font(.subheadline)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                }
            }
        }
    }

    private var choiceContent: some View {
        VStack(spacing: 18) {
            EvaRitualSection(
                eyebrow: "Protect one anchor",
                title: "If one meaningful thing moves, which is it?",
                message: "EVA used your existing focus ranking. You stay in charge."
            ) {
                if let snapshot {
                    Picker("Anchor task", selection: $anchorTaskID) {
                        Text("No anchor").tag(UUID?.none)
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
                eyebrow: "Make room",
                title: "Give flexible work an honest home",
                message: "Deadlines stay untouched. Unknown-size work is shown as risk, never counted as free."
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
            eyebrow: "Review",
            title: remainingOverload == 0 ? "The known work now fits" : "\(CommitmentRealismSnapshot.duration(remainingOverload)) still needs room",
            message: "No deadlines or calendar commitments will change."
        ) {
            if let snapshot {
                MakeItFitCapacityRibbon(snapshot: snapshot, remainingOverload: remainingOverload)
                ForEach(changedTasks, id: \.0.id) { task, destination in
                    HStack {
                        Text(task.title).lineLimit(2)
                        Spacer()
                        Text(destination.displayTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                }
                if changedTasks.isEmpty {
                    Text("You kept the plan as it is. That is still an intentional decision.")
                        .font(.subheadline)
                }
            }
        }
    }

    private var receiptContent: some View {
        EvaRitualSection(
            eyebrow: "Done",
            title: appliedChangeCount == 0 ? "Today stays as it is" : "Today fits",
            message: appliedChangeCount == 0
                ? "No planning changes were needed."
                : "We changed the plan, not your deadlines."
        ) {
            if appliedChangeCount > 0 {
                Label(receiptSummary, systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                Text("One planning receipt · Undo available")
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            } else {
                Label("Your existing plan was kept", systemImage: "checkmark.circle")
            }
            if let undoError {
                Text(undoError)
                    .font(.caption)
                    .foregroundStyle(Color.lifeboard.statusWarning)
                    .accessibilityLabel("Undo error: \(undoError)")
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .evidence:
            PrimaryButton(title: "Choose what stays", systemImage: "arrow.right") {
                transition(to: .choosing)
            }
            .frame(maxWidth: .infinity)
        case .choosing:
            PrimaryButton(title: "Review the new shape", systemImage: "rectangle.and.text.magnifyingglass") {
                transition(to: .previewing)
            }
            .frame(maxWidth: .infinity)
        case .previewing:
            PrimaryButton(
                title: changedTasks.isEmpty ? "Keep today as it is" : "Apply \(changedTasks.count) changes",
                systemImage: "checkmark"
            ) { apply() }
            .frame(maxWidth: .infinity)
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
                                undoError = store.errorMessage ?? "Undo could not be completed. Your current plan is still visible."
                            }
                        }
                    }
                    .frame(minWidth: 72, minHeight: 48)
                }
                PrimaryButton(title: "Today fits — start the next move", systemImage: "arrow.right") {
                    startNextMove()
                }
            }
        case .failure:
            PrimaryButton(title: "Review again", systemImage: "arrow.clockwise") {
                transition(to: .choosing)
            }
            .frame(maxWidth: .infinity)
        }
    }

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
        if reduceMotion { phase = next }
        else { withAnimation(.easeInOut(duration: 0.24)) { phase = next } }
        persistDraft()
    }

    private func apply() {
        guard changedTasks.isEmpty == false else {
            appliedChangeCount = 0
            transition(to: .receipt)
            return
        }
        guard let expectedSnapshot = snapshot else {
            errorMessage = "Today could not be rechecked. Nothing was changed."
            transition(to: .failure)
            return
        }
        transition(to: .applying)
        Task {
            switch await store.applyMakeItFit(choices: choices, expectedSnapshot: expectedSnapshot) {
            case .applied(let changedCount):
                appliedChangeCount = changedCount
                HapticFeedback.light()
                transition(to: .receipt)
            case .noChanges:
                appliedChangeCount = 0
                transition(to: .receipt)
            case .stale(let refreshed):
                ritualSnapshot = refreshed
                reconcileChoices(with: refreshed)
                errorMessage = "Today changed while this ritual was open. The preview has been refreshed; review it once more."
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
            errorMessage = store.errorMessage ?? "The estimate could not be saved."
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
            moved > 0 ? "\(moved) to tomorrow" : nil,
            later > 0 ? "\(later) to Later" : nil,
            released > 0 ? "\(released) to Someday" : nil,
            inbox > 0 ? "\(inbox) to Inbox" : nil
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
            Text(remainingOverload > 0 ? "\(CommitmentRealismSnapshot.duration(remainingOverload)) over known capacity" : "Known work fits")
                .font(.caption.weight(.medium))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(remainingOverload > 0 ? "\(remainingOverload) minutes over known capacity" : "Known work fits today")
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
                    Text(task.title).font(.subheadline.weight(.semibold))
                    Text(task.estimatedDuration.map { CommitmentRealismSnapshot.duration(Int($0 / 60)) } ?? "Unknown size · not treated as free")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                Spacer()
                if isAnchor { Image(systemName: "pin.fill").accessibilityLabel("Protected anchor") }
            }
            Picker("Home for \(task.title)", selection: $selection) {
                ForEach(MakeItFitDestination.allCases, id: \.self) { destination in
                    Text(destination.displayTitle).tag(destination)
                }
            }
            .pickerStyle(.menu)
            .disabled(isAnchor)
            .accessibilityHint(isAnchor ? "This task is protected as today's anchor" : "Choose where this task belongs")
            if task.estimatedDuration == nil {
                if isEditingEstimate {
                    HStack(spacing: 12) {
                        TextField("Minutes", text: $estimateText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Estimate in minutes for \(task.title)")
                        Button(isSavingEstimate ? "Saving…" : "Save") { saveEstimate() }
                            .buttonStyle(.lifeBoardChip)
                            .disabled(isSavingEstimate || validEstimate == nil)
                    }
                    if let estimateError {
                        Text(estimateError)
                            .font(.caption)
                            .foregroundStyle(Color.lifeboard.statusWarning)
                            .accessibilityLabel("Estimate error: \(estimateError)")
                    }
                } else {
                    Button("Add estimate here") {
                        estimateText = "30"
                        estimateError = nil
                        isEditingEstimate = true
                    }
                    .font(.caption.weight(.semibold))
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
            estimateError = "Use 5–1,440 minutes."
            return
        }
        isSavingEstimate = true
        estimateError = nil
        Task { @MainActor in
            if await onSaveEstimate(minutes) {
                isEditingEstimate = false
            } else {
                estimateError = "Could not save this estimate. Try again."
            }
            isSavingEstimate = false
        }
    }
}

private extension MakeItFitDestination {
    var displayTitle: String {
        switch self {
        case .keepToday: "Keep today"
        case .tomorrow: "Tomorrow"
        case .later: "Later"
        case .someday: "Someday"
        case .inbox: "Inbox"
        }
    }
}
