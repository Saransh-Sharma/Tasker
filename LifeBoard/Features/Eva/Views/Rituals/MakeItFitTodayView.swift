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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var snapshot: CommitmentRealismSnapshot? {
        ritualSnapshot ?? store.daySnapshot.map(CommitmentRealismEngine.snapshot)
    }

    var body: some View {
        EvaRitualShell(
            title: "Make It Fit Today",
            orientation: orientation,
            evidence: evidence,
            onClose: close,
            content: { phaseContent },
            footer: { footer }
        )
        .task { restoreOrStart() }
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
                        Label(commitment.title, systemImage: "lock.fill")
                            .font(.subheadline)
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
                            onAddEstimate: { onOpenTask(task.id) }
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
            title: "Today fits",
            message: "We changed the plan, not your deadlines."
        ) {
            Label("One planning receipt · Undo available", systemImage: "checkmark.seal.fill")
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
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
                Button("Undo") {
                    Task {
                        await store.undoLastMutation()
                        transition(to: .choosing)
                    }
                }
                .frame(minWidth: 72, minHeight: 48)
                PrimaryButton(title: "Today fits — close", systemImage: "arrow.right") { close() }
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
            transition(to: .receipt)
            return
        }
        transition(to: .applying)
        Task {
            let succeeded = await store.applyMakeItFit(choices: choices)
            if succeeded {
                HapticFeedback.light()
                transition(to: .receipt)
            } else {
                errorMessage = store.errorMessage ?? "The plan changed while this ritual was open. Nothing else was applied."
                transition(to: .failure)
            }
        }
    }

    private func restoreOrStart() {
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
        if phase == .applying { phase = .previewing }
    }

    private func persistDraft() {
        var encoded = Dictionary(uniqueKeysWithValues: choices.map { ($0.key.uuidString, $0.value.rawValue) })
        if let anchorTaskID { encoded["anchor"] = anchorTaskID.uuidString }
        EvaRitualDraftStore.shared.save(.init(
            kind: .makeItFitToday,
            recordIDs: snapshot?.flexibleTasks.map(\.id) ?? [],
            referenceDate: Date(),
            phaseRaw: phase.rawValue,
            choices: encoded
        ))
    }

    private func close() {
        if phase == .receipt { EvaRitualDraftStore.shared.clear(.makeItFitToday) }
        onClose()
    }
}

private struct MakeItFitCapacityRibbon: View {
    let snapshot: CommitmentRealismSnapshot
    let remainingOverload: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { proxy in
                let usable = max(snapshot.usableMinutes, 1)
                let knownAfter = max(0, snapshot.usableMinutes + remainingOverload)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.lifeboard.surfaceSecondary)
                    Capsule()
                        .fill(remainingOverload > 0 ? Color.orange.opacity(0.78) : Color.green.opacity(0.72))
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
    let onAddEstimate: () -> Void

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
                Button("Add an estimate in task details", action: onAddEstimate)
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 44)
            }
        }
        .padding(.vertical, 5)
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
