import SwiftUI

private enum WeeklyResetPhase: String, Codable {
    case whatHeld
    case drag
    case shape
    case savingReview
    case proposal
    case applying
    case receipt
    case failure
}

struct WeeklyResetView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel
    let frictionRepository: FrictionFindingRepositoryProtocol
    let taskRepository: TaskDefinitionRepositoryProtocol
    let actionPipeline: AssistantActionPipelineUseCase
    let onClose: () -> Void
    let onOpenWeeklyPlanner: () -> Void
    let onOpenTask: (UUID) -> Void

    @State private var phase: WeeklyResetPhase = .whatHeld
    @State private var weeklyIntention = ""
    @State private var minimumViableWeek = ""
    @State private var protectedCommitment = ""
    @State private var findings: [FrictionFinding] = []
    @State private var findingTasks: [UUID: TaskDefinition] = [:]
    @State private var proposalLines: [WeeklyResetProposalLine] = []
    @State private var receipt: WeeklyResetApplyReceipt?
    @State private var pendingActionRunID: UUID?
    @State private var errorMessage: String?
    @State private var reviewFinished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var applier: WeeklyResetProposalApplier {
        WeeklyResetProposalApplier(
            repository: taskRepository,
            actionPipeline: actionPipeline
        )
    }

    var body: some View {
        Group {
            if viewModel.hasLoadedInitialData == false {
                loadingView
            } else {
                ritualView
            }
        }
        .task {
            restoreDraft()
            if viewModel.snapshot == nil && viewModel.isLoading == false { viewModel.load() }
            loadFindings()
            await restorePlanningReceiptIfNeeded()
        }
        .onChange(of: viewModel.hasLoadedInitialData) { _, loaded in
            if loaded { rebuildProposalLines() }
        }
        .alert("Weekly Reset needs another look", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .accessibilityIdentifier("eva.weeklyReset.view")
    }

    private var loadingView: some View {
        NavigationStack {
            Group {
                if let loadError = viewModel.errorMessage {
                    StatusSurface(
                        state: .recoverableError,
                        title: "The week is still here",
                        message: loadError,
                        actionTitle: "Retry",
                        action: { viewModel.load() }
                    )
                } else {
                    StatusSurface(
                        state: .loading,
                        title: "Gathering the week",
                        message: "Collecting outcomes, tasks, habits, and reflections."
                    )
                }
            }
            .padding(20)
            .navigationTitle("Weekly Reset with EVA")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
        }
    }

    private var ritualView: some View {
        EvaRitualShell(
            title: "Weekly Reset with EVA",
            orientation: orientation,
            evidence: evidence,
            onOpenEvidence: { reference in
                if reference.kind == .task { onOpenTask(reference.recordID) }
            },
            onClose: close,
            content: { phaseContent },
            footer: { footer }
        )
    }

    private var orientation: String {
        switch phase {
        case .whatHeld: "Close the week with evidence, not a score."
        case .drag: "Release carry-over that no longer deserves automatic consent."
        case .shape: "Give next week a viable opening shape, not a packed promise."
        case .savingReview: "Saving the reflection before touching next week's plan."
        case .proposal: "Your review is safe. These planning changes are still only a proposal."
        case .applying: "Rechecking each task before changing its planning home."
        case .receipt: "The week is closed. Next week has room to breathe."
        case .failure: errorMessage ?? "The review is safe; the planning proposal needs another look."
        }
    }

    private var evidence: [Insight.Evidence] {
        let completed = viewModel.completedTasks.prefix(3).map { task in
            Insight.Evidence(
                reference: .init(kind: .task, recordID: task.id, title: task.title, occurredAt: task.dateCompleted),
                reason: "Observed: completed this week",
                signalKey: "weekly_completed"
            )
        }
        let unfinished = viewModel.unfinishedTasks.prefix(3).map { task in
            Insight.Evidence(
                reference: .init(kind: .task, recordID: task.id, title: task.title, occurredAt: task.updatedAt),
                reason: "Observed: still open at review",
                signalKey: "weekly_open"
            )
        }
        return completed + unfinished
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .whatHeld: whatHeld
        case .drag: whatCreatedDrag
        case .shape: shapeNextWeek
        case .savingReview:
            StatusSurface(state: .loading, title: "Finishing the review", message: "Planning changes have not started.")
        case .proposal: proposalPreview
        case .applying:
            StatusSurface(state: .loading, title: "Shaping the handoff", message: "Stale or completed tasks will be skipped, never overwritten.")
        case .receipt: receiptView
        case .failure:
            StatusSurface(
                state: .recoverableError,
                title: reviewFinished ? "Your review is safely finished" : "Nothing was applied",
                message: errorMessage ?? "Try the planning proposal again when you're ready."
            )
        }
    }

    private var whatHeld: some View {
        VStack(spacing: 18) {
            EvaRitualSection(
                eyebrow: "Chapter 1 · What held",
                title: sparseWeek ? "A quiet week still counts" : "Start with what genuinely moved",
                message: "Correct or ignore any interpretation. These are observed records, not EVA's grade."
            ) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { weeklyMetrics }
                    VStack(spacing: 12) { weeklyMetrics }
                }
                if viewModel.completedTasks.isEmpty {
                    Text("What held you together may not be stored as a completed task. Capture it below.")
                        .font(.subheadline)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                } else {
                    ForEach(viewModel.completedTasks.prefix(4)) { task in
                        Label(task.title, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                    }
                }

                if let outcomes = viewModel.snapshot?.outcomes, outcomes.isEmpty == false {
                    Divider()
                    Text("Correct outcome status")
                        .font(.subheadline.weight(.semibold))
                    ForEach(outcomes) { outcome in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(outcome.title)
                                .font(.subheadline)
                                .lineLimit(2)
                            Spacer()
                            Picker(
                                "Status for \(outcome.title)",
                                selection: Binding(
                                    get: { viewModel.outcomeStatusesByID[outcome.id] ?? outcome.status },
                                    set: { viewModel.setOutcomeStatus($0, for: outcome.id) }
                                )
                            ) {
                                ForEach(WeeklyOutcomeStatus.allCases, id: \.self) { status in
                                    Text(status.displayTitle).tag(status)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
            }

            EvaRitualSection(eyebrow: "Chosen by you", title: "What deserves to be remembered?", message: nil) {
                TextField("A win, a boundary, or something that quietly worked", text: $viewModel.wins, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var whatCreatedDrag: some View {
        VStack(spacing: 18) {
            EvaRitualSection(
                eyebrow: "Chapter 2 · What created drag",
                title: "Every open task needs a conscious destination",
                message: "Carry, Later, and Release are different commitments. Release sends work to Someday; it never deletes it."
            ) {
                if viewModel.unfinishedTasks.isEmpty {
                    Text("There is no unfinished work asking for a decision.")
                        .font(.subheadline)
                } else {
                    ForEach(viewModel.unfinishedTasks) { task in
                        WeeklyResetDecisionRow(
                            task: task,
                            selection: Binding(
                                get: { viewModel.taskDecisions[task.id] },
                                set: { value in if let value { viewModel.setDecision(value, for: task.id) } }
                            ),
                            onOpen: { onOpenTask(task.id) }
                        )
                    }
                }
            }

            if let finding = findings.min(by: { $0.reviewAfter < $1.reviewAfter }) {
                EvaRitualSection(
                    eyebrow: "Recurring friction",
                    title: taskForFinding(finding)?.title ?? "A task no longer in this week's plan",
                    message: finding.reviewAfter <= Date()
                        ? "Chosen by you: \(finding.selectedReason.resetLabel). It is time to close the loop."
                        : "Chosen by you: \(finding.selectedReason.resetLabel). Follow-up on \(finding.reviewAfter.formatted(date: .abbreviated, time: .omitted))."
                ) {
                    if finding.reviewAfter <= Date() {
                        Text("Did this change help?")
                            .font(.subheadline.weight(.semibold))
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) { findingOutcomeButtons(for: finding) }
                            VStack(spacing: 8) { findingOutcomeButtons(for: finding) }
                        }
                    }
                    if taskForFinding(finding) != nil {
                        Button("Review the task and experiment") { onOpenTask(finding.taskID) }
                            .buttonStyle(.lifeBoardChip)
                            .frame(minHeight: 44)
                    }
                }
            }

            EvaRitualSection(eyebrow: "Possible, not proven", title: "What made the week heavier?", message: nil) {
                TextField("A condition, interruption, or constraint—not a verdict about you", text: $viewModel.blockers, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var shapeNextWeek: some View {
        VStack(spacing: 18) {
            EvaRitualSection(
                eyebrow: "Chapter 3 · Shape next week",
                title: "Name the minimum before adding the maximum",
                message: "Concrete day placement stays inside LifeBoard's canonical weekly workspace and its three-day horizon."
            ) {
                resetField("One weekly intention", placeholder: "How should the week feel or function?", text: $weeklyIntention)
                resetField("Minimum viable week", placeholder: "What would make the week meaningfully enough?", text: $minimumViableWeek)
                resetField("Protected commitment", placeholder: "A boundary, appointment, or recovery window", text: $protectedCommitment)
            }

            EvaRitualSection(
                eyebrow: "Meaningful outcomes",
                title: "Up to three threads worth carrying",
                message: "EVA keeps the first three reachable outcomes visible. It does not invent work to fill space."
            ) {
                if reachableOutcomes.isEmpty {
                    Text("No open outcomes are waiting. You can create or shape them in the weekly workspace.")
                        .font(.subheadline)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                } else {
                    ForEach(reachableOutcomes.prefix(3)) { outcome in
                        Label(outcome.title, systemImage: "sparkles")
                            .font(.subheadline)
                    }
                }
            }
        }
        .onChange(of: weeklyIntention) { _, _ in persistDraft() }
        .onChange(of: minimumViableWeek) { _, _ in persistDraft() }
        .onChange(of: protectedCommitment) { _, _ in persistDraft() }
    }

    private var proposalPreview: some View {
        EvaRitualSection(
            eyebrow: "Will change",
            title: proposalLines.isEmpty ? "No task homes need changing" : "Review the next-week handoff",
            message: "Your completed review is already saved. This second commit can fail, be skipped, or be undone without touching it."
        ) {
            ForEach(proposalLines) { line in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(line.task.title).lineLimit(2)
                    Spacer()
                    Text(line.destination.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
            }
            Text("No deadlines, calendar events, archives, or deletions will change.")
                .font(.caption)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
    }

    private var receiptView: some View {
        VStack(spacing: 18) {
            EvaRitualSection(
                eyebrow: "Review saved",
                title: "The folded week can rest",
                message: receipt?.summary ?? "No planning changes were needed."
            ) {
                Label("Reflection and planning remain independently recoverable", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.medium))
            }
            EvaRitualSection(
                eyebrow: "Next",
                title: "Place only what the near horizon can hold",
                message: "The weekly workspace will keep concrete placement to the first three reachable days and leave the rest soft."
            ) {
                Button("Open the weekly workspace", action: openPlanner)
                    .buttonStyle(.lifeBoardPrimary)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .whatHeld:
            PrimaryButton(title: "See what created drag", systemImage: "arrow.right") { transition(.drag) }
        case .drag:
            PrimaryButton(title: "Shape next week", systemImage: "arrow.right") { transition(.shape) }
                .disabled(viewModel.unfinishedTasks.contains { viewModel.taskDecisions[$0.id] == nil })
        case .shape:
            PrimaryButton(title: "Finish review", systemImage: "checkmark") { finishReview() }
                .disabled(viewModel.isSaving || viewModel.footerSnapshot.canFinishReview == false)
        case .savingReview, .applying:
            ProgressView().frame(maxWidth: .infinity, minHeight: 48)
        case .proposal:
            PrimaryButton(
                title: proposalLines.isEmpty ? "Continue" : "Apply \(proposalLines.count) planning changes",
                systemImage: "checkmark"
            ) { applyProposal() }
        case .receipt:
            HStack(spacing: 12) {
                if let receipt, receipt.changedTaskIDs.isEmpty == false {
                    Button("Undo") { undo(receipt) }
                        .frame(minWidth: 72, minHeight: 48)
                }
                PrimaryButton(title: "Shape next week", systemImage: "calendar.badge.plus", action: openPlanner)
            }
        case .failure:
            PrimaryButton(title: reviewFinished ? "Review proposal again" : "Return to review", systemImage: "arrow.clockwise") {
                transition(reviewFinished ? .proposal : .shape)
            }
        }
    }

    private var completedOutcomes: [WeeklyOutcome] {
        viewModel.snapshot?.outcomes.filter {
            (viewModel.outcomeStatusesByID[$0.id] ?? $0.status) == .completed
        } ?? []
    }

    private var reachableOutcomes: [WeeklyOutcome] {
        viewModel.snapshot?.outcomes
            .filter {
                let status = viewModel.outcomeStatusesByID[$0.id] ?? $0.status
                return status == .planned || status == .inProgress
            }
            .sorted { $0.orderIndex < $1.orderIndex } ?? []
    }

    private var sparseWeek: Bool {
        viewModel.completedTasks.isEmpty && viewModel.unfinishedTasks.count < 3
    }

    @ViewBuilder
    private var weeklyMetrics: some View {
        resetMetric(value: viewModel.completedTasks.count, label: "Tasks done")
        resetMetric(value: completedOutcomes.count, label: "Outcomes held")
        resetMetric(value: viewModel.selectedHabits.count, label: "Habits present")
    }

    private func resetMetric(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)").font(.title2.weight(.bold))
            Text(label).font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func resetField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold))
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func finishReview() {
        rebuildProposalLines()
        let shape = [
            weeklyIntention.resetNilIfBlank.map { "Intention: \($0)" },
            minimumViableWeek.resetNilIfBlank.map { "Minimum viable week: \($0)" },
            protectedCommitment.resetNilIfBlank.map { "Protected: \($0)" }
        ].compactMap { $0 }.joined(separator: "\n")
        if shape.isEmpty == false { viewModel.nextWeekPrepNotes = shape }

        transition(.savingReview)
        viewModel.completeReview(mutationMode: .recordOnly) { result in
            switch result {
            case .success:
                reviewFinished = true
                if let refreshIssue = viewModel.errorMessage {
                    errorMessage = "Your review was saved, but the latest screen could not refresh: \(refreshIssue)"
                }
                transition(.proposal)
            case .failure(let error):
                errorMessage = error.localizedDescription
                transition(.failure)
            }
        }
    }

    private func applyProposal() {
        guard proposalLines.isEmpty == false else {
            transition(.receipt)
            return
        }
        transition(.applying)
        Task { @MainActor in
            do {
                receipt = try await applier.apply(proposalLines) { runID in
                    pendingActionRunID = runID
                    persistDraft()
                }
                transition(.receipt)
            } catch {
                if let runID = pendingActionRunID,
                   let restored = try? await applier.restoreReceipt(id: runID) {
                    receipt = restored
                    transition(.receipt)
                } else {
                    pendingActionRunID = nil
                    errorMessage = error.localizedDescription
                    transition(.failure)
                }
            }
        }
    }

    private func undo(_ receipt: WeeklyResetApplyReceipt) {
        Task { @MainActor in
            do {
                try await applier.undo(receipt)
                self.receipt = nil
                pendingActionRunID = nil
                transition(.proposal)
            } catch {
                errorMessage = "Some planning changes could not be restored. \(error.localizedDescription)"
            }
        }
    }

    private func loadFindings() {
        frictionRepository.fetchFindings(
            query: FrictionFindingQuery(outcomes: [.pending], limit: 8)
        ) { result in
            Task { @MainActor in
                if case .success(let values) = result {
                    findings = values
                    loadFindingTasks(values)
                }
            }
        }
    }

    private func loadFindingTasks(_ values: [FrictionFinding]) {
        let currentWeekTasks = Dictionary(
            uniqueKeysWithValues: viewModel.unfinishedTasks.map { ($0.id, $0) }
        )
        findingTasks.merge(currentWeekTasks) { _, current in current }
        for taskID in Set(values.map(\.taskID)) where findingTasks[taskID] == nil {
            taskRepository.fetchTaskDefinition(id: taskID) { result in
                Task { @MainActor in
                    if case .success(let task?) = result { findingTasks[taskID] = task }
                }
            }
        }
    }

    private func taskForFinding(_ finding: FrictionFinding) -> TaskDefinition? {
        viewModel.unfinishedTasks.first { $0.id == finding.taskID } ?? findingTasks[finding.taskID]
    }

    private func findingOutcomeButton(
        _ title: String,
        outcome: FrictionFindingOutcome,
        finding: FrictionFinding
    ) -> some View {
        Button(title) { updateFinding(finding, outcome: outcome) }
            .buttonStyle(.lifeBoardChip)
            .frame(minHeight: 44)
    }

    @ViewBuilder
    private func findingOutcomeButtons(for finding: FrictionFinding) -> some View {
        findingOutcomeButton("Helped", outcome: .helped, finding: finding)
        findingOutcomeButton("Not really", outcome: .didNotHelp, finding: finding)
        findingOutcomeButton("Dismiss", outcome: .dismissed, finding: finding)
    }

    private func updateFinding(_ finding: FrictionFinding, outcome: FrictionFindingOutcome) {
        var updated = finding
        updated.outcome = outcome
        updated.updatedAt = Date()
        frictionRepository.saveFinding(updated) { result in
            Task { @MainActor in
                switch result {
                case .success:
                    findings.removeAll { $0.id == finding.id }
                    HapticFeedback.light()
                case .failure(let error):
                    errorMessage = "The experiment response could not be saved: \(error.localizedDescription)"
                }
            }
        }
    }

    private func rebuildProposalLines() {
        proposalLines = viewModel.unfinishedTasks.compactMap { task in
            viewModel.taskDecisions[task.id].map { WeeklyResetProposalLine(task: task, disposition: $0) }
        }
    }

    private func transition(_ next: WeeklyResetPhase) {
        if reduceMotion { phase = next }
        else { withAnimation(.easeInOut(duration: 0.24)) { phase = next } }
        persistDraft()
    }

    private func persistDraft() {
        EvaRitualDraftStore.shared.save(EvaRitualDraftReference(
            kind: .weeklyReset,
            recordIDs: findings.map(\.id),
            referenceDate: viewModel.weekStartDate,
            phaseRaw: phase.rawValue,
            choices: [
                "weeklyIntention": weeklyIntention,
                "minimumViableWeek": minimumViableWeek,
                "protectedCommitment": protectedCommitment,
                "reviewFinished": reviewFinished ? "true" : "false",
                "receiptSkippedTaskIDs": receipt?.skippedTaskIDs.map(\.uuidString).joined(separator: ",") ?? ""
            ],
            actionRunID: receipt?.actionRunID ?? pendingActionRunID
        ))
    }

    private func restoreDraft() {
        guard let draft = EvaRitualDraftStore.shared.load(.weeklyReset),
              Calendar.current.isDate(draft.referenceDate, equalTo: viewModel.weekStartDate, toGranularity: .weekOfYear) else { return }
        reviewFinished = draft.choices["reviewFinished"] == "true"
        if let restored = WeeklyResetPhase(rawValue: draft.phaseRaw) {
            switch restored {
            case .applying, .receipt:
                // Restore the durable action run by identity. Full task snapshots
                // remain in the action pipeline, never in navigation state.
                if reviewFinished {
                    phase = draft.actionRunID == nil ? .proposal : .applying
                    pendingActionRunID = draft.actionRunID
                    if draft.actionRunID == nil {
                        errorMessage = "Your review is safe. The planning proposal was refreshed because its prior receipt could not be restored."
                    }
                } else {
                    phase = .shape
                }
            case .savingReview:
                phase = .shape
            default:
                phase = restored
            }
        }
        weeklyIntention = draft.choices["weeklyIntention"] ?? ""
        minimumViableWeek = draft.choices["minimumViableWeek"] ?? ""
        protectedCommitment = draft.choices["protectedCommitment"] ?? ""
    }

    private func restorePlanningReceiptIfNeeded() async {
        guard phase == .applying,
              let draft = EvaRitualDraftStore.shared.load(.weeklyReset),
              let runID = draft.actionRunID else { return }
        do {
            if let restored = try await applier.restoreReceipt(id: runID) {
                let skippedIDs = Set(
                    (draft.choices["receiptSkippedTaskIDs"] ?? "")
                        .split(separator: ",")
                        .compactMap { UUID(uuidString: String($0)) }
                )
                receipt = WeeklyResetApplyReceipt(
                    id: restored.id,
                    appliedAt: restored.appliedAt,
                    originals: restored.originals,
                    changedTaskIDs: restored.changedTaskIDs,
                    skippedTaskIDs: Array(skippedIDs),
                    actionRunID: restored.actionRunID
                )
                pendingActionRunID = runID
                phase = .receipt
            } else {
                pendingActionRunID = nil
                phase = .proposal
                errorMessage = "Your review is safe. The previous planning run is no longer applied, so the proposal was refreshed."
            }
        } catch {
            pendingActionRunID = nil
            phase = .proposal
            errorMessage = "Your review is safe, but the planning receipt could not be restored: \(error.localizedDescription)"
        }
        persistDraft()
    }

    private func openPlanner() {
        EvaRitualDraftStore.shared.clear(.weeklyReset)
        onOpenWeeklyPlanner()
    }

    private func close() {
        persistDraft()
        onClose()
    }
}

private struct WeeklyResetDecisionRow: View {
    let task: TaskDefinition
    @Binding var selection: WeeklyReviewTaskDisposition?
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onOpen) {
                HStack {
                    Text(task.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption)
                }
            }
            .buttonStyle(.plain)

            Picker("Destination for \(task.title)", selection: $selection) {
                Text("Choose…").tag(WeeklyReviewTaskDisposition?.none)
                Text("Carry").tag(Optional(WeeklyReviewTaskDisposition.carry))
                Text("Later").tag(Optional(WeeklyReviewTaskDisposition.later))
                Text("Release").tag(Optional(WeeklyReviewTaskDisposition.drop))
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
        }
        .padding(.vertical, 5)
    }
}

private extension FrictionReason {
    var resetLabel: String {
        switch self {
        case .scopeTooLarge: "too large"
        case .nextStepUnclear: "next step unclear"
        case .timingOrEnergy: "wrong time or energy"
        case .blockedOrWaiting: "blocked or waiting"
        case .interruptions: "too many interruptions"
        case .priorityChanged: "priority changed"
        case .other: "something else"
        }
    }
}

private extension String {
    var resetNilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
