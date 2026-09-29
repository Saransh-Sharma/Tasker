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
            title: String(localized: "Why it\u{2019}s stuck"),
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
        case .evidence: String(localized: "History for this task.")
        case .choosingReason: String(localized: "Pick what got in the way.")
        case .choosingExperiment: String(localized: "Try one change.")
        case .previewing: String(localized: "Check the change.")
        case .applying: String(localized: "Changing the task\u{2026}")
        case .receipt: String(localized: "Task changed")
        case .failure: errorMessage ?? String(localized: "Nothing changed.")
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
            StatusSurface(state: .loading, title: String(localized: "Changing the task\u{2026}"), message: "")
        case .receipt: receipt
        case .failure:
            StatusSurface(
                state: .recoverableError,
                title: String(localized: "Couldn\u{2019}t change the task"),
                message: errorMessage ?? String(localized: "Nothing changed."),
                actionTitle: String(localized: "Try again"),
                action: { transition(to: .previewing) }
            )
        }
    }

    private var evidenceThread: some View {
        EvaRitualSection(
            eyebrow: String(localized: "History"),
            title: task.title,
            message: analysis.distinctEventCount == 0
                ? String(localized: "Not enough history yet.")
                : nil
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
                            .lifeboardFont(.support)
                            .padding(.bottom, 16)
                        Spacer()
                    }
                }
                if analysis.evidence.isEmpty {
                    Label("No history yet", systemImage: "circle.dashed")
                        .lifeboardFont(.support)
                }
            }
        }
    }

    private var reasonChoice: some View {
        VStack(spacing: 16) {
            if analysis.possibleReasons.isEmpty == false {
                EvaRitualSection(
                    eyebrow: String(localized: "Suggested"),
                    title: String(localized: "Possible reasons"),
                    message: nil
                ) {
                    ForEach(analysis.possibleReasons, id: \.self) { reason in
                        Label(reason.displayTitle, systemImage: "questionmark.bubble")
                            .lifeboardFont(.support)
                    }
                }
            }
            EvaRitualSection(
                eyebrow: String(localized: "Pick one"),
                title: String(localized: "What\u{2019}s blocking it?"),
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
            eyebrow: String(localized: "Pick one"),
            title: String(localized: "Try a change"),
            message: nil
        ) {
            ForEach(FrictionIntervention.allCases, id: \.self) { intervention in
                Button {
                    selectedIntervention = intervention
                    persistDraft()
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(intervention.displayTitle).lifeboardFont(.bodyStrong)
                            Text(intervention.explanation)
                                .lifeboardFont(.caption1)
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
                TextField(selectedIntervention?.textPrompt ?? String(localized: "Details"), text: $experimentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    // Clay well, not the system rounded border: that drew a pure white
                    // box on warm paper and a pure black one in dark appearance.
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
                    .lineLimit(2...4)
                    .onChange(of: experimentText) { _, _ in persistDraft() }
            }
        }
    }

    private var preview: some View {
        EvaRitualSection(
            eyebrow: String(localized: "Change"),
            title: selectedIntervention?.displayTitle ?? String(localized: "Pick a change"),
            message: selectedReason.map { String(localized: "Reason: \($0.displayTitle)") }
        ) {
            if let selectedIntervention {
                Label(selectedIntervention.explanation, systemImage: "arrow.triangle.2.circlepath")
                    .lifeboardFont(.support)
            }
        }
    }

    private var receipt: some View {
        EvaRitualSection(
            eyebrow: String(localized: "Done"),
            title: String(localized: "Task changed"),
            message: findingSaved
                ? String(localized: "Weekly reset will ask if it helped.")
                : String(localized: "Couldn\u{2019}t set up the follow-up.")
        ) {
            if findingSaved {
                Label("Saved on \(DeviceNoun.this)", systemImage: "checkmark.seal.fill")
                    .lifeboardFont(.bodyStrong)
            } else {
                Label("Follow-up not saved", systemImage: "exclamationmark.triangle.fill")
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(Color.lifeboard.statusWarning)
            }
            if let receiptIssue {
                Text(receiptIssue)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            if appliedReceipt != nil {
                Button(isUndoing ? "Undoing…" : "Undo") { undo() }
                    .buttonStyle(.lifeBoardChip)
                    .disabled(isUndoing)
                    .accessibilityHint("Restores the task")
            } else if taskMutationApplied {
                Text("Edit the task to change this.")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .evidence:
            PrimaryButton(title: String(localized: "Pick a reason"), systemImage: "arrow.right") { transition(to: .choosingReason) }
                .frame(maxWidth: .infinity)
        case .choosingReason:
            HStack(spacing: 12) {
                backButton(to: .evidence)
                PrimaryButton(title: String(localized: "Next"), systemImage: "arrow.right") { transition(to: .choosingExperiment) }
                    .frame(maxWidth: .infinity)
                    .disabled(selectedReason == nil)
                    .accessibilityHint(selectedReason == nil ? "Pick a reason first" : "Shows changes to try")
            }
        case .choosingExperiment:
            HStack(spacing: 12) {
                backButton(to: .choosingReason)
                PrimaryButton(title: String(localized: "Review change"), systemImage: "rectangle.and.text.magnifyingglass") { transition(to: .previewing) }
                    .frame(maxWidth: .infinity)
                    .disabled(canReviewExperiment == false)
                    .accessibilityHint(canReviewExperiment ? "Shows the change" : "Pick a change first")
            }
        case .previewing:
            HStack(spacing: 12) {
                backButton(to: .choosingExperiment)
                PrimaryButton(title: String(localized: "Apply change"), systemImage: "checkmark") { apply() }
                    .frame(maxWidth: .infinity)
            }
        case .applying:
            ProgressView().frame(maxWidth: .infinity, minHeight: 48)
        case .receipt:
            PrimaryButton(title: String(localized: "Done"), systemImage: "checkmark") { close() }
                .frame(maxWidth: .infinity)
        case .failure:
            PrimaryButton(title: String(localized: "Try again"), systemImage: "arrow.clockwise") { transition(to: .previewing) }
                .frame(maxWidth: .infinity)
        }
    }
}

extension FrictionDetectiveView {
    private func transition(to next: FrictionDetectivePhase) {
        withAnimation(MotionProfile.route.animation(reduceMotion: reduceMotion)) { phase = next }
        persistDraft()
    }

    /// Steps go back as well as forward; what was picked is kept.
    private func backButton(to previous: FrictionDetectivePhase) -> some View {
        Button {
            Haptic.pick.play()
            transition(to: previous)
        } label: {
            Label("Back", systemImage: "chevron.left")
                .lifeboardFont(.button)
                .frame(minWidth: 44, minHeight: 48)
        }
        .buttonStyle(.lifeBoardChip)
        .accessibilityIdentifier("eva.friction.back")
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
            errorMessage = String(localized: "Couldn\u{2019}t save from here. Nothing changed.")
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
                        Haptic.commit.play()
                        transition(to: .receipt)
                    case .failure(let error):
                        var receipt = mutationReceipt
                        receipt.reflectionNoteID = noteID
                        appliedReceipt = receipt
                        findingSaved = false
                        receiptIssue = String(localized: "Couldn\u{2019}t save the follow-up. \(error.localizedDescription)")
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
                receiptIssue = String(localized: "Task changed. Couldn\u{2019}t save your note. \(error.localizedDescription)")
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
                Haptic.decline.play()
                close()
            case .failure(let error):
                receiptIssue = String(localized: "Couldn\u{2019}t undo. \(error.localizedDescription)")
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
            ? String(localized: "Task changed earlier. Follow-up not found.")
            : String(localized: "Saved earlier.")
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
        case .scopeTooLarge: String(localized: "Too large")
        case .nextStepUnclear: String(localized: "Next step unclear")
        case .timingOrEnergy: String(localized: "Wrong time or energy")
        case .blockedOrWaiting: String(localized: "Blocked or waiting")
        case .interruptions: String(localized: "Too many interruptions")
        case .priorityChanged: String(localized: "Priority changed")
        case .other: String(localized: "Something else")
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
        case .clarifyNextAction: String(localized: "Add next action")
        case .splitTask: String(localized: "Add a first step")
        case .reduceScope: String(localized: "Make it smaller")
        case .moveToBetterWindow: String(localized: "Move to next week")
        case .moveLater: String(localized: "Move to Later")
        case .releaseToSomeday: String(localized: "Move to Someday")
        case .noteDependency: String(localized: "Note the blocker")
        }
    }

    var explanation: String {
        switch self {
        case .clarifyNextAction: String(localized: "Adds one next action to the task.")
        case .splitTask: String(localized: "Adds a 15 min subtask.")
        case .reduceScope: String(localized: "Sets a 15–30 min estimate.")
        case .moveToBetterWindow: String(localized: "The deadline stays the same.")
        case .moveLater: String(localized: "Takes it out of this week.")
        case .releaseToSomeday: String(localized: "Keeps the task with no date.")
        case .noteDependency: String(localized: "Adds it to the task details.")
        }
    }

    var acceptsText: Bool { self == .clarifyNextAction || self == .splitTask || self == .noteDependency }
    var textPrompt: String {
        switch self {
        case .clarifyNextAction: String(localized: "Next action")
        case .splitTask: String(localized: "First step")
        case .noteDependency: String(localized: "Waiting on")
        default: String(localized: "Details")
        }
    }
}
