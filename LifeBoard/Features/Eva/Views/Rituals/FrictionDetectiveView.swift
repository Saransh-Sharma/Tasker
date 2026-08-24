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
    @State private var isUndoing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var analysis: FrictionEvidenceSnapshot { FrictionEvidenceIndex.analyze(task: task) }

    var body: some View {
        EvaRitualShell(
            title: "Friction Detective",
            orientation: orientation,
            evidence: analysis.evidence,
            onClose: close,
            content: { phaseContent },
            footer: { footer }
        )
        .task { restoreDraft() }
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
            eyebrow: "Experiment started",
            title: "We changed the conditions, not your score.",
            message: "Weekly Reset will ask whether this helped after seven days."
        ) {
            Label("Finding saved locally", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
            Button(isUndoing ? "Undoing…" : "Undo experiment") { undo() }
                .buttonStyle(.bordered)
                .disabled(isUndoing || appliedReceipt == nil)
                .accessibilityHint("Restores the task and removes the saved friction finding")
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
                .opacity(selectedReason == nil ? 0.45 : 1)
                .allowsHitTesting(selectedReason != nil)
        case .choosingExperiment:
            PrimaryButton(title: "Review the change", systemImage: "rectangle.and.text.magnifyingglass") { transition(to: .previewing) }
                .frame(maxWidth: .infinity)
                .opacity(canReviewExperiment ? 1 : 0.45)
                .allowsHitTesting(canReviewExperiment)
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
        transition(to: .applying)
        let noteText = experimentText.trimmingCharacters(in: .whitespacesAndNewlines)
        onApply(selectedIntervention, noteText.isEmpty ? nil : noteText) { result in
            switch result {
            case .failure(let error):
                errorMessage = error.localizedDescription
                transition(to: .failure)
            case .success(let mutationReceipt):
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
                        HapticFeedback.light()
                        transition(to: .receipt)
                    case .failure(let error):
                        var receipt = mutationReceipt
                        receipt.reflectionNoteID = noteID
                        appliedReceipt = receipt
                        errorMessage = "The task changed, but the follow-up could not be saved: \(error.localizedDescription)"
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
            finish((try? result.get())?.id)
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
                EvaRitualDraftStore.shared.clear(.frictionDetective)
                HapticFeedback.light()
                close()
            case .failure(let error):
                errorMessage = "Undo could not finish cleanly: \(error.localizedDescription)"
            }
        }
    }

    private func persistDraft() {
        var choices: [String: String] = [:]
        if let selectedReason { choices["reason"] = selectedReason.rawValue }
        if let selectedIntervention { choices["intervention"] = selectedIntervention.rawValue }
        if experimentText.isEmpty == false { choices["experimentText"] = experimentText }
        EvaRitualDraftStore.shared.save(.init(
            kind: .frictionDetective,
            recordIDs: [task.id],
            phaseRaw: phase.rawValue,
            choices: choices
        ))
    }

    private func restoreDraft() {
        guard let draft = EvaRitualDraftStore.shared.load(.frictionDetective),
              draft.recordIDs == [task.id] else { return }
        selectedReason = draft.choices["reason"].flatMap(FrictionReason.init(rawValue:))
        selectedIntervention = draft.choices["intervention"].flatMap(FrictionIntervention.init(rawValue:))
        experimentText = draft.choices["experimentText"] ?? ""
        phase = FrictionDetectivePhase(rawValue: draft.phaseRaw) ?? .evidence
        if phase == .applying { phase = .previewing }
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
