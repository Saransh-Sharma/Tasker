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
    /// False when pushed onto an existing stack; see `OptionalNavigationStack`.
    var embedsInNavigationStack = true

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
        .alert("Weekly reset", isPresented: Binding(
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
        OptionalNavigationStack(isEnabled: embedsInNavigationStack) {
            Group {
                if let loadError = viewModel.errorMessage {
                    StatusSurface(
                        state: .recoverableError,
                        title: String(localized: "Couldn\u{2019}t load the week"),
                        message: loadError,
                        actionTitle: String(localized: "Try again"),
                        action: { viewModel.load() }
                    )
                } else {
                    StatusSurface(
                        state: .loading,
                        title: String(localized: "Loading\u{2026}"),
                        message: ""
                    )
                }
            }
            .padding(20)
            .navigationTitle("Weekly reset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
    }

    private var ritualView: some View {
        EvaRitualShell(
            title: String(localized: "Weekly reset"),
            orientation: orientation,
            evidence: evidence,
            onOpenEvidence: { reference in
                if reference.kind == .task { onOpenTask(reference.recordID) }
            },
            onClose: close,
            embedsInNavigationStack: embedsInNavigationStack,
            content: { phaseContent },
            footer: { footer }
        )
    }

    private var orientation: String {
        switch phase {
        case .whatHeld: String(localized: "Look back at the week.")
        case .drag: String(localized: "Sort unfinished tasks.")
        case .shape: String(localized: "Set up next week.")
        case .savingReview: String(localized: "Saving your review\u{2026}")
        case .proposal: String(localized: "Your review is saved.")
        case .applying: String(localized: "Moving tasks\u{2026}")
        case .receipt: String(localized: "Week reviewed")
        case .failure: errorMessage ?? String(localized: "Couldn\u{2019}t move tasks. Your review is saved.")
        }
    }

    private var evidence: [Insight.Evidence] {
        let completed = viewModel.completedTasks.prefix(3).map { task in
            Insight.Evidence(
                reference: .init(kind: .task, recordID: task.id, title: task.title, occurredAt: task.dateCompleted),
                reason: String(localized: "Done this week"),
                signalKey: "weekly_completed"
            )
        }
        let unfinished = viewModel.unfinishedTasks.prefix(3).map { task in
            Insight.Evidence(
                reference: .init(kind: .task, recordID: task.id, title: task.title, occurredAt: task.updatedAt),
                reason: String(localized: "Still open"),
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
            StatusSurface(state: .loading, title: String(localized: "Saving review\u{2026}"), message: "")
        case .proposal: proposalPreview
        case .applying:
            StatusSurface(state: .loading, title: String(localized: "Moving tasks\u{2026}"), message: "")
        case .receipt: receiptView
        case .failure:
            StatusSurface(
                state: .recoverableError,
                title: reviewFinished ? String(localized: "Review saved") : String(localized: "Nothing changed"),
                message: errorMessage ?? String(localized: "Couldn\u{2019}t move tasks.")
            )
        }
    }
}

extension WeeklyResetView {
    private var whatHeld: some View {
        VStack(spacing: 16) {
            EvaRitualSection(
                eyebrow: String(localized: "Step 1 of 3"),
                title: sparseWeek ? String(localized: "This week") : String(localized: "What got done"),
                message: nil
            ) {
                // Only when there is something to count: an empty week drew
                // a row of zeros.
                if hasWeeklyMetrics {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { weeklyMetrics }
                        VStack(spacing: 12) { weeklyMetrics }
                    }
                }
                ForEach(viewModel.completedTasks.prefix(4)) { task in
                    Label(task.title, systemImage: "checkmark.circle.fill")
                        .lifeboardFont(.support)
                }

                if let outcomes = viewModel.snapshot?.outcomes, outcomes.isEmpty == false {
                    Divider()
                    Text("Goals")
                        .lifeboardFont(.bodyStrong)
                    ForEach(outcomes) { outcome in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(outcome.title)
                                .lifeboardFont(.support)
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

            EvaRitualSection(eyebrow: String(localized: "Optional"), title: String(localized: "Worth remembering"), message: nil) {
                TextField("What went well", text: $viewModel.wins, prompt: Text("What went well").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    // Clay well, not the system rounded border: that drew a pure white
                    // box on warm paper and a pure black one in dark appearance.
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
            }
        }
    }

    private var whatCreatedDrag: some View {
        VStack(spacing: 16) {
            EvaRitualSection(
                eyebrow: String(localized: "Step 2 of 3"),
                title: String(localized: "Unfinished tasks"),
                message: nil
            ) {
                if viewModel.unfinishedTasks.isEmpty {
                    Text("No unfinished tasks")
                        .lifeboardFont(.support)
                } else {
                    Button {
                        Haptic.pick.play()
                        for task in viewModel.unfinishedTasks {
                            viewModel.setDecision(.carry, for: task.id)
                        }
                    } label: {
                        Label("All to next week", systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.lifeBoardChip)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("eva.weeklyReset.carryAll")
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
                    eyebrow: String(localized: "Follow-up"),
                    title: taskForFinding(finding)?.title ?? String(localized: "Earlier task"),
                    message: finding.reviewAfter <= Date()
                        ? String(localized: "Reason: \(finding.selectedReason.resetLabel)")
                        : String(localized: "Reason: \(finding.selectedReason.resetLabel) · Follow-up \(finding.reviewAfter.formatted(date: .abbreviated, time: .omitted))")
                ) {
                    if finding.reviewAfter <= Date() {
                        Text("Did it help?")
                            .lifeboardFont(.bodyStrong)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) { findingOutcomeButtons(for: finding) }
                            VStack(spacing: 8) { findingOutcomeButtons(for: finding) }
                        }
                    }
                    if taskForFinding(finding) != nil {
                        Button("Open task") { onOpenTask(finding.taskID) }
                            .buttonStyle(.lifeBoardChip)
                            .frame(minHeight: 44)
                    }
                }
            }

            EvaRitualSection(eyebrow: String(localized: "Optional"), title: String(localized: "Blockers"), message: nil) {
                TextField("What got in the way", text: $viewModel.blockers, prompt: Text("What got in the way").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    // Clay well, not the system rounded border: that drew a pure white
                    // box on warm paper and a pure black one in dark appearance.
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
            }
        }
    }

    private var shapeNextWeek: some View {
        VStack(spacing: 16) {
            EvaRitualSection(
                eyebrow: String(localized: "Step 3 of 3"),
                title: String(localized: "Next week"),
                message: nil
            ) {
                resetField(String(localized: "Focus this week"), placeholder: String(localized: "One line"), text: $weeklyIntention)
                resetField(String(localized: "Smallest version"), placeholder: String(localized: "The essentials"), text: $minimumViableWeek)
                resetField(String(localized: "Protected time"), placeholder: String(localized: "Appointment or boundary"), text: $protectedCommitment)
            }

            EvaRitualSection(
                eyebrow: String(localized: "Goals"),
                title: String(localized: "Open goals"),
                message: String(localized: "Up to 3 stay in view.")
            ) {
                if reachableOutcomes.isEmpty {
                    Text("No open goals. Add them in the weekly plan.")
                        .lifeboardFont(.support)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                } else {
                    ForEach(reachableOutcomes.prefix(3)) { outcome in
                        Label(outcome.title, systemImage: "sparkles")
                            .lifeboardFont(.support)
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
            eyebrow: String(localized: "Changes"),
            title: proposalLines.isEmpty ? String(localized: "No tasks to move") : String(localized: "Check the moves"),
            message: String(localized: "Your review is saved.")
        ) {
            ForEach(proposalLines) { line in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(line.task.title).lineLimit(2)
                    Spacer()
                    Text(line.disposition.resetTitle)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
            }
            Text("Deadlines and events don\u{2019}t change.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
    }

    private var receiptView: some View {
        VStack(spacing: 16) {
            EvaRitualSection(
                eyebrow: String(localized: "Done"),
                title: String(localized: "Week reviewed"),
                message: receipt?.summary ?? String(localized: "No tasks moved.")
            ) {
                Label("Review saved", systemImage: "checkmark.seal.fill")
                    .lifeboardFont(.bodyStrong)
            }
            EvaRitualSection(
                eyebrow: String(localized: "Up next"),
                title: String(localized: "Schedule tasks"),
                message: nil
            ) {
                Button("Plan week", action: openPlanner)
                    .buttonStyle(.lifeBoardPrimary)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .whatHeld:
            PrimaryButton(title: String(localized: "Next"), systemImage: "arrow.right") { transition(.drag) }
        case .drag:
            HStack(spacing: 12) {
                backButton(to: .whatHeld)
                PrimaryButton(title: String(localized: "Next"), systemImage: "arrow.right") { transition(.shape) }
                    .disabled(viewModel.unfinishedTasks.contains { viewModel.taskDecisions[$0.id] == nil })
            }
        case .shape:
            HStack(spacing: 12) {
                backButton(to: .drag)
                PrimaryButton(title: String(localized: "Finish review"), systemImage: "checkmark") { finishReview() }
                    .disabled(viewModel.isSaving || viewModel.footerSnapshot.canFinishReview == false)
            }
        case .savingReview, .applying:
            ProgressView().frame(maxWidth: .infinity, minHeight: 48)
        case .proposal:
            PrimaryButton(
                title: proposalLines.isEmpty
                    ? String(localized: "Continue")
                    : (proposalLines.count == 1 ? String(localized: "Move 1 task") : String(localized: "Move \(proposalLines.count) tasks")),
                systemImage: "checkmark"
            ) { applyProposal() }
        case .receipt:
            HStack(spacing: 12) {
                if let receipt, receipt.changedTaskIDs.isEmpty == false {
                    Button("Undo") { undo(receipt) }
                        .frame(minWidth: 72, minHeight: 48)
                }
                PrimaryButton(title: String(localized: "Plan week"), systemImage: "calendar.badge.plus", action: openPlanner)
            }
        case .failure:
            PrimaryButton(title: reviewFinished ? String(localized: "Try again") : String(localized: "Back to review"), systemImage: "arrow.clockwise") {
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

    private var hasWeeklyMetrics: Bool {
        viewModel.completedTasks.isEmpty == false
            || completedOutcomes.isEmpty == false
            || viewModel.selectedHabits.isEmpty == false
    }

    /// Chapters move back as well as forward; decisions made so far are kept.
    private func backButton(to previous: WeeklyResetPhase) -> some View {
        Button {
            Haptic.pick.play()
            transition(previous)
        } label: {
            Label("Back", systemImage: "chevron.left")
                .lifeboardFont(.button)
                .frame(minWidth: 44, minHeight: 48)
        }
        .buttonStyle(.lifeBoardChip)
        .accessibilityIdentifier("eva.weeklyReset.back")
    }

    private var sparseWeek: Bool {
        viewModel.completedTasks.isEmpty && viewModel.unfinishedTasks.count < 3
    }

    @ViewBuilder
    private var weeklyMetrics: some View {
        resetMetric(value: viewModel.completedTasks.count, label: String(localized: "Tasks done"))
        resetMetric(value: completedOutcomes.count, label: String(localized: "Goals done"))
        resetMetric(value: viewModel.selectedHabits.count, label: String(localized: "Habits"))
    }

    private func resetMetric(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)").lifeboardFont(.title2)
            Text(label).lifeboardFont(.caption1).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func resetField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).lifeboardFont(.bodyStrong)
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                // Clay well, not the system rounded border: that drew a pure white
                // box on warm paper and a pure black one in dark appearance.
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
        }
    }
}

extension WeeklyResetView {
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
                    errorMessage = String(localized: "Your review is saved. Couldn\u{2019}t refresh: \(refreshIssue)")
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
                errorMessage = String(localized: "Couldn\u{2019}t undo every move. \(error.localizedDescription)")
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
        findingOutcomeButton(String(localized: "Helped"), outcome: .helped, finding: finding)
        findingOutcomeButton(String(localized: "Not really"), outcome: .didNotHelp, finding: finding)
        findingOutcomeButton(String(localized: "Dismiss"), outcome: .dismissed, finding: finding)
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
                    Haptic.pick.play()
                case .failure(let error):
                    errorMessage = String(localized: "Couldn\u{2019}t save your answer. \(error.localizedDescription)")
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
        withAnimation(MotionProfile.route.animation(reduceMotion: reduceMotion)) { phase = next }
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
                        errorMessage = String(localized: "Your review is saved. Check the moves again.")
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
                errorMessage = String(localized: "Your review is saved. Check the moves again.")
            }
        } catch {
            pendingActionRunID = nil
            phase = .proposal
            errorMessage = String(localized: "Your review is saved. Couldn\u{2019}t restore the last moves.")
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
                    Text(task.title).lifeboardFont(.bodyStrong).multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right").lifeboardFont(.caption1)
                }
            }
            .buttonStyle(.plain)

            Picker("Destination for \(task.title)", selection: $selection) {
                Text("Choose\u{2026}").tag(WeeklyReviewTaskDisposition?.none)
                ForEach(WeeklyReviewTaskDisposition.allCases, id: \.self) { disposition in
                    Label(disposition.resetTitle, systemImage: disposition.resetSymbol)
                        .tag(Optional(disposition))
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
        }
        .padding(.vertical, 4)
    }
}

/// Where a weekly decision sends a task, in the shared vocabulary. "Release"
/// sent work to Someday, so it now says Someday.
private extension WeeklyReviewTaskDisposition {
    var resetTitle: String {
        switch self {
        case .carry: String(localized: "Next week")
        case .later: String(localized: "Later")
        case .drop: DecisionDestination.someday.title
        }
    }

    var resetSymbol: String {
        switch self {
        case .carry: "calendar"
        case .later: "clock"
        case .drop: DecisionDestination.someday.systemImage
        }
    }
}

private extension FrictionReason {
    var resetLabel: String {
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
}

private extension String {
    var resetNilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
