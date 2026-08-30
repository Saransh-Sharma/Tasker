import SwiftUI

private enum FrictionDetectivePhase: String, Codable {
    case evidence
    case choosingReason
    case choosingExperiment
    case previewing
    case applying
    case receipt
    case failure
}

struct FrictionDetectiveView: View {
    let task: TaskDefinition
    let repository: FrictionFindingRepositoryProtocol?
    let onSaveReflectionNote: (ReflectionNote, @escaping @MainActor @Sendable (Result<ReflectionNote, Error>) -> Void) -> Void
    let onApply: (FrictionIntervention, String?, @escaping @MainActor @Sendable (Result<FrictionInterventionReceipt, Error>) -> Void) -> Void
    let onUndo: (FrictionInterventionReceipt, @escaping @MainActor @Sendable (Result<Void, Error>) -> Void) -> Void
    let onClose: () -> Void

    @State private var phase: FrictionDetectivePhase = .evidence
    @State private var selectedReason: FrictionReason?
    @State private var selectedIntervention: FrictionIntervention?
    @State private var experimentText = ""
    @State private var errorMessage: String?
    @State private var appliedReceipt: FrictionInterventionReceipt?
    @State private var findingSaved = false
    @State private var savedFindingID: UUID?
    @State private var taskMutationApplied = false
    @State private var receiptIssue: String?
    @State private var isUndoing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var analysis: FrictionEvidenceSnapshot { FrictionEvidenceIndex.analyze(task: task) }

    var body: some View {
        EvaRitualShell(
            title: "Friction Detective",
            orientation: orientation,
            evidence: analysis.evidence,
            onOpenEvidence: { _ in onClose() },
            onClose: close,
            content: { phaseContent },
            footer: { footer }
        )
        .task { await restoreDraft() }
    }

    private var orientation: String {
        switch phase {
        case .evidence: "This is evidence about the work, not a verdict about you."
        case .choosingReason: "EVA can offer possibilities. Only you can name what was actually in the way."
        case .choosingExperiment: "Change one condition and see what becomes easier."
        case .previewing: "One experiment. One explicit task change."
        case .applying: "Applying the experiment you reviewed."
        case .receipt: "We changed the conditions, not your score."
        case .failure: errorMessage ?? "Nothing was changed."
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .evidence: evidenceThread
        case .choosingReason: reasonChoice
        case .choosingExperiment: experimentChoice
        case .previewing: preview
        case .applying:
            StatusSurface(state: .loading, title: "Changing one condition", message: "Saving the task change and your confirmed finding.")
        case .receipt: receipt
        case .failure:
            StatusSurface(
                state: .recoverableError,
                title: "The task is still safe",
                message: errorMessage ?? "Nothing was changed.",
                actionTitle: "Review again",
                action: { transition(to: .previewing) }
            )
        }
    }

    private var evidenceThread: some View {
        EvaRitualSection(
            eyebrow: "Observed",
            title: task.title,
            message: analysis.distinctEventCount == 0
                ? "There is not enough history for a confident pattern. You can still inspect the task manually."
                : "These are the signals LifeBoard can verify."
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(analysis.evidence.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle().fill(Color.lifeboard.accentPrimary).frame(width: 10, height: 10)
                            if index < analysis.evidence.count - 1 {
                                Rectangle().fill(Color.lifeboard.accentWash).frame(width: 2, height: 36)
                            }
                        }
                        Text(item.reason)
                            .font(.subheadline)
                            .padding(.bottom, 18)
                        Spacer()
                    }
                }
                if analysis.evidence.isEmpty {
                    Label("No repeated event history yet", systemImage: "circle.dashed")
                        .font(.subheadline)
                }
            }
        }
    }

    private var reasonChoice: some View {
        VStack(spacing: 18) {
            if analysis.possibleReasons.isEmpty == false {
                EvaRitualSection(
                    eyebrow: "Possible explanation",
                    title: "A few hypotheses—not conclusions",
                    message: "These come from task structure and planning signals. EVA will not save them."
                ) {
                    ForEach(analysis.possibleReasons, id: \.self) { reason in
                        Label(reason.displayTitle, systemImage: "questionmark.bubble")
                            .font(.subheadline)
                    }
                }
            }
            EvaRitualSection(
                eyebrow: "Chosen by you",
                title: "What was actually in the way?",
                message: nil
            ) {
                ForEach(FrictionReason.allCases, id: \.self) { reason in
                    Button {
                        selectedReason = reason
                        selectedIntervention = reason.defaultIntervention
                        persistDraft()
                    } label: {
                        HStack {
                            Text(reason.displayTitle)
                            Spacer()
                            Image(systemName: selectedReason == reason ? "checkmark.circle.fill" : "circle")
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedReason == reason ? .isSelected : [])
                    .accessibilityValue(selectedReason == reason ? "Selected" : "Not selected")
                }
            }
        }
    }

    private var experimentChoice: some View {
        EvaRitualSection(
            eyebrow: "One experiment",
            title: "What should change this time?",
            message: "Pick one small intervention. You can come back if it does not help."
        ) {
            ForEach(FrictionIntervention.allCases, id: \.self) { intervention in
                Button {
                    selectedIntervention = intervention
                    persistDraft()
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(intervention.displayTitle).font(.subheadline.weight(.semibold))
                            Text(intervention.explanation)
                                .font(.caption)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        }
                        Spacer()
                        Image(systemName: selectedIntervention == intervention ? "checkmark.circle.fill" : "circle")
                    }
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedIntervention == intervention ? .isSelected : [])
                .accessibilityValue(selectedIntervention == intervention ? "Selected" : "Not selected")
            }
            if selectedIntervention?.acceptsText == true {
                TextField(selectedIntervention?.textPrompt ?? "Optional detail", text: $experimentText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .onChange(of: experimentText) { _, _ in persistDraft() }
            }
        }
    }

    private var preview: some View {
        EvaRitualSection(
            eyebrow: "Will change",
            title: selectedIntervention?.displayTitle ?? "Choose an experiment",
            message: selectedReason.map { "You named the friction as “\($0.displayTitle.lowercased())”." }
        ) {
            if let selectedIntervention {
                Label(selectedIntervention.explanation, systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                Text("The evidence remains observed history. EVA's hypotheses will not be saved as memory.")
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
        }
    }

    private var receipt: some View {
        EvaRitualSection(
            eyebrow: findingSaved ? "Experiment started" : "Task changed",
            title: "We changed the conditions, not your score.",
            message: findingSaved
                ? "Weekly Reset will ask whether this helped after seven days."
                : "The task change succeeded, but no seven-day follow-up was scheduled."
        ) {
            if findingSaved {
                Label("Finding saved locally", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
            } else {
                Label("Follow-up not saved", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.lifeboard.statusWarning)
            }
            if let receiptIssue {
                Text(receiptIssue)
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            if appliedReceipt != nil {
                Button(isUndoing ? "Undoing…" : "Undo experiment") { undo() }
                    .buttonStyle(.bordered)
                    .disabled(isUndoing)
                    .accessibilityHint("Restores the task and removes the saved friction finding")
            } else if taskMutationApplied {
                Text("The in-session Undo is unavailable after reopening this ritual. The saved task remains editable in Task Detail.")
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .evidence:
            PrimaryButton(title: "What was in the way?", systemImage: "arrow.right") { transition(to: .choosingReason) }
                .frame(maxWidth: .infinity)
        case .choosingReason:
            PrimaryButton(title: "Choose one experiment", systemImage: "arrow.right") { transition(to: .choosingExperiment) }
                .frame(maxWidth: .infinity)
                .disabled(selectedReason == nil)
                .accessibilityHint(selectedReason == nil ? "Choose what was in the way first" : "Continues to intervention choices")
        case .choosingExperiment:
            PrimaryButton(title: "Review the change", systemImage: "rectangle.and.text.magnifyingglass") { transition(to: .previewing) }
                .frame(maxWidth: .infinity)
                .disabled(canReviewExperiment == false)
                .accessibilityHint(canReviewExperiment ? "Shows the exact task change" : "Choose and complete one experiment first")
        case .previewing:
            PrimaryButton(title: "Start this experiment", systemImage: "checkmark") { apply() }
                .frame(maxWidth: .infinity)
        case .applying:
            ProgressView().frame(maxWidth: .infinity, minHeight: 48)
        case .receipt:
            PrimaryButton(title: "Done", systemImage: "checkmark") { close() }
                .frame(maxWidth: .infinity)
        case .failure:
            PrimaryButton(title: "Review again", systemImage: "arrow.clockwise") { transition(to: .previewing) }
                .frame(maxWidth: .infinity)
        }
    }

    private func transition(to next: FrictionDetectivePhase) {
        if reduceMotion { phase = next }
        else { withAnimation(.easeInOut(duration: 0.24)) { phase = next } }
        persistDraft()
    }

    private var canReviewExperiment: Bool {
        guard let selectedIntervention else { return false }
        if selectedIntervention.acceptsText {
            return experimentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        return true
    }

    private func apply() {
        guard let selectedReason, let selectedIntervention, let repository else {
            errorMessage = "Friction findings are unavailable in this context. Nothing was changed."
            transition(to: .failure)
            return
        }
        taskMutationApplied = false
        findingSaved = false
        receiptIssue = nil
        transition(to: .applying)
        let noteText = experimentText.trimmingCharacters(in: .whitespacesAndNewlines)
        onApply(selectedIntervention, noteText.isEmpty ? nil : noteText) { result in
            switch result {
            case .failure(let error):
                errorMessage = error.localizedDescription
                transition(to: .failure)
            case .success(let mutationReceipt):
                // Record the successful task mutation before the secondary note
                // and finding writes. A restart must never invite a duplicate edit.
                taskMutationApplied = true
                persistDraft()
                saveFinding(
                    repository: repository,
                    reason: selectedReason,
                    intervention: selectedIntervention,
                    noteText: noteText,
                    mutationReceipt: mutationReceipt
                )
            }
        }
    }

    private func saveFinding(
        repository: FrictionFindingRepositoryProtocol,
        reason: FrictionReason,
        intervention: FrictionIntervention,
        noteText: String,
        mutationReceipt: FrictionInterventionReceipt
    ) {
        let finish: @MainActor @Sendable (UUID?) -> Void = { noteID in
            let reviewDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            let finding = FrictionFinding(
                taskID: task.id,
                deferredCountAtDetection: task.deferredCount,
                replanCountAtDetection: task.replanCount,
                evidence: analysis.evidence,
                selectedReason: reason,
                customReflectionNoteID: noteID,
                intervention: intervention,
                reviewAfter: reviewDate
            )
            repository.saveFinding(finding) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let savedFinding):
                        var receipt = mutationReceipt
                        receipt.findingID = savedFinding.id
                        receipt.reflectionNoteID = noteID
                        appliedReceipt = receipt
                        findingSaved = true
                        savedFindingID = savedFinding.id
                        receiptIssue = nil
                        HapticFeedback.light()
                        transition(to: .receipt)
                    case .failure(let error):
                        var receipt = mutationReceipt
                        receipt.reflectionNoteID = noteID
                        appliedReceipt = receipt
                        findingSaved = false
                        receiptIssue = "The follow-up could not be saved: \(error.localizedDescription)"
                        transition(to: .receipt)
                    }
                }
            }
        }

        guard noteText.isEmpty == false else { finish(nil); return }
        onSaveReflectionNote(
            ReflectionNote(
                kind: .frictionFinding,
                linkedTaskID: task.id,
                prompt: "What was actually in the way?",
                noteText: noteText
            )
        ) { result in
            switch result {
            case .success(let note):
                finish(note.id)
            case .failure(let error):
                appliedReceipt = mutationReceipt
                findingSaved = false
                receiptIssue = "Your task change succeeded, but the private note could not be saved: \(error.localizedDescription)"
                transition(to: .receipt)
            }
        }
    }

    private func undo() {
        guard let appliedReceipt else { return }
        isUndoing = true
        onUndo(appliedReceipt) { result in
            isUndoing = false
            switch result {
            case .success:
                self.appliedReceipt = nil
                taskMutationApplied = false
                savedFindingID = nil
                EvaRitualDraftStore.shared.clear(.frictionDetective)
                HapticFeedback.light()
                close()
            case .failure(let error):
                receiptIssue = "Undo could not finish cleanly: \(error.localizedDescription)"
            }
        }
    }

    private func persistDraft() {
        var choices: [String: String] = [:]
        if let selectedReason { choices["reason"] = selectedReason.rawValue }
        if let selectedIntervention { choices["intervention"] = selectedIntervention.rawValue }
        if experimentText.isEmpty == false { choices["experimentText"] = experimentText }
        choices["taskMutationApplied"] = taskMutationApplied ? "true" : "false"
        if let savedFindingID { choices["findingID"] = savedFindingID.uuidString }
        EvaRitualDraftStore.shared.save(.init(
            kind: .frictionDetective,
            recordIDs: [task.id],
            phaseRaw: phase.rawValue,
            choices: choices
        ))
    }

    private func restoreDraft() async {
        guard let draft = EvaRitualDraftStore.shared.load(.frictionDetective),
              draft.recordIDs == [task.id] else { return }
        selectedReason = draft.choices["reason"].flatMap(FrictionReason.init(rawValue:))
        selectedIntervention = draft.choices["intervention"].flatMap(FrictionIntervention.init(rawValue:))
        experimentText = draft.choices["experimentText"] ?? ""
        taskMutationApplied = draft.choices["taskMutationApplied"] == "true"
        savedFindingID = draft.choices["findingID"].flatMap(UUID.init(uuidString:))
        phase = FrictionDetectivePhase(rawValue: draft.phaseRaw) ?? .evidence
        guard phase == .applying || phase == .receipt else { return }
        guard taskMutationApplied else {
            phase = .previewing
            return
        }

        let matchingFinding = await fetchMatchingFinding()
        findingSaved = matchingFinding != nil
        receiptIssue = matchingFinding == nil
            ? "The task change was saved earlier, but its seven-day follow-up was not found."
            : "This experiment was saved earlier."
        phase = .receipt
    }

    private func fetchMatchingFinding() async -> FrictionFinding? {
        guard let repository, let savedFindingID else { return nil }
        let findings: [FrictionFinding]
        do {
            findings = try await withCheckedThrowingContinuation { continuation in
                repository.fetchFindings(
                    query: FrictionFindingQuery(taskID: task.id, outcomes: [.pending], limit: 10)
                ) { continuation.resume(with: $0) }
            }
        } catch {
            return nil
        }
        return findings.first { $0.id == savedFindingID }
    }

    private func close() {
        if phase == .receipt { EvaRitualDraftStore.shared.clear(.frictionDetective) }
        onClose()
    }
}

private extension FrictionReason {
    var displayTitle: String {
        switch self {
        case .scopeTooLarge: "Too large"
        case .nextStepUnclear: "Next step unclear"
        case .timingOrEnergy: "Wrong time or energy"
        case .blockedOrWaiting: "Blocked or waiting"
        case .interruptions: "Too many interruptions"
        case .priorityChanged: "Priority changed"
        case .other: "Something else"
        }
    }

    var defaultIntervention: FrictionIntervention {
        switch self {
        case .scopeTooLarge: .splitTask
        case .nextStepUnclear: .clarifyNextAction
        case .timingOrEnergy, .interruptions: .moveToBetterWindow
        case .blockedOrWaiting: .noteDependency
        case .priorityChanged: .moveLater
        case .other: .clarifyNextAction
        }
    }
}

private extension FrictionIntervention {
    var displayTitle: String {
        switch self {
        case .clarifyNextAction: "Clarify the next action"
        case .splitTask: "Create a first step"
        case .reduceScope: "Reduce the working scope"
        case .moveToBetterWindow: "Move to a better window"
        case .moveLater: "Move to Later"
        case .releaseToSomeday: "Release to Someday"
        case .noteDependency: "Name what it is waiting on"
        }
    }

    var explanation: String {
        switch self {
        case .clarifyNextAction: "Add one concrete next action to the task."
        case .splitTask: "Create a 15-minute child step so starting is visible."
        case .reduceScope: "Set a smaller 15–30 minute working estimate."
        case .moveToBetterWindow: "Move the task to Next Week without changing its deadline."
        case .moveLater: "Remove it from the active week and place it in Later."
        case .releaseToSomeday: "Keep the task, but stop asking when it will happen."
        case .noteDependency: "Record the dependency in task details."
        }
    }

    var acceptsText: Bool { self == .clarifyNextAction || self == .splitTask || self == .noteDependency }
    var textPrompt: String {
        switch self {
        case .clarifyNextAction: "What is the next physical action?"
        case .splitTask: "Name the first small step"
        case .noteDependency: "What or who is this waiting on?"
        default: "Optional detail"
        }
    }
}
