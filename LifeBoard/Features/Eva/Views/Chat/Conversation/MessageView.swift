//
//  ConversationView.swift
//

import MarkdownUI
import LifeBoardDomain
import SwiftData
import SwiftUI

struct MessageView: View {

    @Environment(\.lifeboardLayoutClass) var layoutClass

    @Environment(\.evaAuthorizedEvidenceContext) var authorizedLifeEvidence

    @Environment(\.evaEvidenceOpenAction) var evidenceOpenAction

    @Environment(\.modelContext) var modelContext

    @State var collapsed = true

    @State var spokenOutput = EvaSpokenOutputController.shared

    @State var paidSpeechRegenerationText: String?

    @State var showsContextReceipt = false

    @State var memoryCandidateDraft = ""

    @State var isEditingMemoryCandidate = false

    @State var memoryCandidateRevision = 0

    // MARK: Card session

    /// The conversation's store, or this view's own when rendered alone.
    @Environment(\.evaProposalCardSessions) private var injectedCardSessions
    @State private var localCardSessions = EvaProposalCardSessions()

    var cardSessions: EvaProposalCardSessions {
        injectedCardSessions ?? localCardSessions
    }

    /// Read and written through the session so it survives the lazy stack
    /// tearing this view down; see `EvaProposalCardSession`.
    var cardSession: EvaProposalCardSession {
        get { cardSessions[renderModel.id] }
        nonmutating set { cardSessions[renderModel.id] = newValue }
    }

    var undoExpiredLogged: Bool {
        get { cardSession.undoExpiredLogged }
        nonmutating set { cardSession.undoExpiredLogged = newValue }
    }

    var selectedEvaCardIDs: Set<UUID> {
        get { cardSession.selectedEvaCardIDs }
        nonmutating set { cardSession.selectedEvaCardIDs = newValue }
    }

    var expandedEvaCardID: UUID? {
        get { cardSession.expandedEvaCardID }
        nonmutating set { cardSession.expandedEvaCardID = newValue }
    }

    var evaCardOverrides: [UUID: EvaProposalCardOverride] {
        get { cardSession.evaCardOverrides }
        nonmutating set { cardSession.evaCardOverrides = newValue }
    }

    var editingEvaCardID: UUID? {
        get { cardSession.editingEvaCardID }
        nonmutating set { cardSession.editingEvaCardID = newValue }
    }

    var notNowEvaCardIDs: Set<UUID> {
        get { cardSession.notNowEvaCardIDs }
        nonmutating set { cardSession.notNowEvaCardIDs = newValue }
    }

    var dismissedEvaRunIDs: Set<UUID> {
        get { cardSession.dismissedEvaRunIDs }
        nonmutating set { cardSession.dismissedEvaRunIDs = newValue }
    }

    var evaApplyMessage: String? {
        get { cardSession.evaApplyMessage }
        nonmutating set { cardSession.evaApplyMessage = newValue }
    }

    var isApplyingEvaProposal: Bool {
        get { cardSession.isApplyingEvaProposal }
        nonmutating set { cardSession.isApplyingEvaProposal = newValue }
    }

    var appliedEvaRunIDs: Set<UUID> {
        get { cardSession.appliedEvaRunIDs }
        nonmutating set { cardSession.appliedEvaRunIDs = newValue }
    }

    var appliedEvaRunIDByPayloadRunID: [UUID: UUID] {
        get { cardSession.appliedEvaRunIDByPayloadRunID }
        nonmutating set { cardSession.appliedEvaRunIDByPayloadRunID = newValue }
    }

    var appliedEvaUndoExpiresAtByPayloadRunID: [UUID: Date] {
        get { cardSession.appliedEvaUndoExpiresAtByPayloadRunID }
        nonmutating set { cardSession.appliedEvaUndoExpiresAtByPayloadRunID = newValue }
    }

    var pendingEvaApplyConfirmationIDs: Set<UUID>? {
        get { cardSession.pendingEvaApplyConfirmationIDs }
        nonmutating set { cardSession.pendingEvaApplyConfirmationIDs = newValue }
    }

    var isUndoingEvaRun: Bool {
        get { cardSession.isUndoingEvaRun }
        nonmutating set { cardSession.isUndoingEvaRun = newValue }
    }

    var dayTaskOverlayStates: [UUID: EvaDayTaskOverlayState] {
        get { cardSession.dayTaskOverlayStates }
        nonmutating set { cardSession.dayTaskOverlayStates = newValue }
    }

    var dayHabitOverlayStates: [UUID: EvaDayHabitOverlayState] {
        get { cardSession.dayHabitOverlayStates }
        nonmutating set { cardSession.dayHabitOverlayStates = newValue }
    }

    var dayOverviewNotices: [String] {
        get { cardSession.dayOverviewNotices }
        nonmutating set { cardSession.dayOverviewNotices = newValue }
    }

    var createdTaskReferencesByCardID: [UUID: EvaRecordReference] {
        get { cardSession.createdTaskReferencesByCardID }
        nonmutating set { cardSession.createdTaskReferencesByCardID = newValue }
    }

    let renderModel: ChatMessageRenderModel

    let now: Date

    var runtime: LLMEvaluator? = nil

    var isLiveOutput: Bool = false

    var workingStatuses: [String] = []

    var pendingPhase: ChatPendingResponsePhase = .idle

    var pendingStatusText: String? = nil

    var onOpenTaskFromCard: ((TaskDefinition) -> Void)?

    var onOpenHabitFromCard: ((UUID) -> Void)?

    var onOpenRecordFromCard: ((EvaRecordReference) -> Void)?

    var onOpenNavigationTargetFromCard: ((EvaNavigationTarget) -> Void)?

    var onPerformDayTaskAction: EvaDayTaskActionHandler?

    var onPerformDayHabitAction: EvaDayHabitActionHandler?

    /// Long-press "Edit and resend" on a user message; the chat owns the confirmation and the rewrite.
    var onEditResend: ((UUID) -> Void)? = nil

    var body: some View {
        HStack {
            if renderModel.role == .user {
                Spacer()
            }

            if renderModel.role == .assistant {
                assistantBody
            } else {
                userBody
            }

            if renderModel.role == .assistant {
                Spacer()
            }
        }
        .onAppear {
            if runtimeRunning {
                collapsed = false
            }
        }
        .onChange(of: runtimeElapsedTime) {
            if isLiveOutput, isThinking {
                runtime?.thinkingTime = runtimeElapsedTime
            }
        }
        .onChange(of: isThinking) { _, thinkingNow in
            if isLiveOutput, runtimeRunning {
                runtime?.isThinking = thinkingNow
                runtime?.collapsed = collapsed
            }
        }
        .onChange(of: now) { _, _ in
            if let payload = renderModel.cardPayload,
               payload.cardType == .undo,
               isUndoExpired(payload: payload),
               !undoExpiredLogged {
                undoExpiredLogged = true
                logWarning(
                    event: "assistant_undo_expired",
                    message: "Undo window expired for assistant run",
                    fields: ["run_id": payload.runID?.uuidString ?? "unknown"]
                )
            }
        }
        .confirmationDialog(
            "Regenerate audio?",
            isPresented: Binding(
                get: { paidSpeechRegenerationText != nil },
                set: { if !$0 { paidSpeechRegenerationText = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Regenerate") {
                guard let text = paidSpeechRegenerationText else { return }
                paidSpeechRegenerationText = nil
                spokenOutput.play(text: text, allowPaidRegeneration: true)
            }
            Button("Cancel", role: .cancel) { paidSpeechRegenerationText = nil }
        } message: {
            Text("Uses 1 cloud credit.")
        }
        .sheet(isPresented: $showsContextReceipt) {
            if let receipt = renderModel.contextReceipt {
                EvaContextReceiptSheet(receipt: receipt)
            }
        }
    }
}

extension MessageView {
    func prepareEvaProposalConfirmation(proposal: EvaProposalReviewPayload) {
        let selectedCards = proposal.cards.filter { selectedEvaCardIDs.contains($0.id) }
        let gate = EvaProposalApplyGate.validate(selectedCards: selectedCards)
        guard case .allowed = gate else {
            if case .blocked(let message) = gate {
                evaApplyMessage = message
            }
            return
        }
        pendingEvaApplyConfirmationIDs = selectedEvaCardIDs
        evaApplyMessage = String(localized: "Confirm to apply.")
    }

    func applyEvaProposal(payload: AssistantCardPayload, proposal: EvaProposalReviewPayload) {
        guard let runID = payload.runID, let pipeline = LLMAssistantPipelineFactory.pipeline else {
            evaApplyMessage = String(localized: "Couldn’t apply changes.")
            return
        }
        guard pendingEvaApplyConfirmationIDs == selectedEvaCardIDs else {
            prepareEvaProposalConfirmation(proposal: proposal)
            return
        }
        let selectedCards = proposal.cards.filter { selectedEvaCardIDs.contains($0.id) }
        let gate = EvaProposalApplyGate.validate(selectedCards: selectedCards)
        guard case .allowed(let appliedCount) = gate else {
            if case .blocked(let message) = gate {
                evaApplyMessage = message
            }
            return
        }
        isApplyingEvaProposal = true
        evaApplyMessage = String(localized: "Applying…")

        pipeline.fetchRun(id: runID) { fetchResult in
            Task { @MainActor in
                switch fetchResult {
                case .failure(let error):
                    finishEvaApply(message: error.localizedDescription)
                case .success(let run):
                    guard
                        let run,
                        let data = run.proposalData,
                        let envelope = try? JSONDecoder().decode(AssistantCommandEnvelope.self, from: data)
                    else {
                        finishEvaApply(message: String(localized: "Couldn’t load changes."))
                        return
                    }

                    let selectedEnvelope = EvaProposalCardBuilder.selectedEnvelope(
                        from: envelope,
                        selectedCardIDs: selectedEvaCardIDs,
                        cards: proposal.cards,
                        overrides: evaCardOverrides
                    )
                    // An edited line is a different envelope even when every
                    // card is selected, so it goes through propose again.
                    if selectedEnvelope.commands.count == envelope.commands.count, evaCardOverrides.isEmpty {
                        confirmAndApply(
                            pipeline: pipeline,
                            runID: runID,
                            appliedCount: appliedCount,
                            payload: payload,
                            proposal: proposal,
                            selectedCards: selectedCards,
                            payloadRunID: runID
                        )
                    } else {
                        pipeline.propose(threadID: run.threadID ?? "eva-selected-\(UUID().uuidString)", envelope: selectedEnvelope) { proposeResult in
                            Task { @MainActor in
                                switch proposeResult {
                                case .failure(let error):
                                    finishEvaApply(message: error.localizedDescription)
                                case .success(let selectedRun):
                                    confirmAndApply(
                                        pipeline: pipeline,
                                        runID: selectedRun.id,
                                        appliedCount: appliedCount,
                                        payload: payload,
                                        proposal: proposal,
                                        selectedCards: selectedCards,
                                        payloadRunID: runID
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func confirmAndApply(
        pipeline: AssistantActionPipelineUseCase,
        runID: UUID,
        appliedCount: Int,
        payload: AssistantCardPayload,
        proposal: EvaProposalReviewPayload,
        selectedCards: [EvaProposalCard],
        payloadRunID: UUID
    ) {
        pipeline.confirm(runID: runID) { confirmResult in
            Task { @MainActor in
                switch confirmResult {
                case .failure(let error):
                    finishEvaApply(message: error.localizedDescription)
                case .success:
                    pipeline.applyConfirmedRun(id: runID) { applyResult in
                        Task { @MainActor in
                            switch applyResult {
                            case .failure(let error):
                                finishEvaApply(message: error.localizedDescription)
                            case .success(let appliedRun):
                                persistAppliedProposalReferences(
                                    appliedRun: appliedRun,
                                    payload: payload,
                                    proposal: proposal,
                                    selectedCards: selectedCards
                                )
                                recordEvaAppliedRunHistory(
                                    runID: runID,
                                    payload: payload,
                                    proposal: proposal,
                                    selectedCards: selectedCards
                                )
                                finishEvaApply(
                                    message: appliedCount == 1 ? String(localized: "Updated 1 task") : String(localized: "Updated \(appliedCount) tasks"),
                                    appliedRunID: runID,
                                    payloadRunID: payloadRunID
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func persistAppliedProposalReferences(
        appliedRun: AssistantActionRunDefinition,
        payload: AssistantCardPayload,
        proposal: EvaProposalReviewPayload,
        selectedCards: [EvaProposalCard]
    ) {
        guard let traceData = appliedRun.executionTraceData,
              let trace = try? JSONDecoder().decode(AssistantExecutionTrace.self, from: traceData),
              trace.createdReferences.isEmpty == false else { return }

        let createCards = selectedCards.filter { $0.kind == .create }
        for (card, reference) in zip(createCards, trace.createdReferences) where reference.kind == .task {
            createdTaskReferencesByCardID[card.id] = reference
        }

        var updatedPayload = payload
        updatedPayload.status = .applied
        var updatedProposal = proposal
        updatedProposal.appliedCardIDs = selectedCards.map(\.id)
        var references = trace.createdReferences.makeIterator()
        updatedProposal.cards = proposal.cards.map { card in
            guard selectedCards.contains(where: { $0.id == card.id }), card.kind == .create,
                  let reference = references.next(), reference.kind == .task else { return card }
            var updated = card
            if var after = updated.after {
                after.taskID = reference.recordID
                updated.after = after
            }
            return updated
        }
        updatedPayload.evaProposal = updatedProposal

        let messageID = renderModel.id
        var descriptor = FetchDescriptor<Message>(predicate: #Predicate<Message> { message in
            message.id == messageID
        })
        descriptor.fetchLimit = 1
        if let message = try? modelContext.fetch(descriptor).first {
            message.content = AssistantCardCodec.encode(updatedPayload)
            try? modelContext.save()
        }
    }
}

extension MessageView {
    func handleDayTaskAction(_ action: EvaDayTaskAction, card: EvaDayTaskCard) {
        if action == .open {
            onOpenTaskFromCard?(card.taskSnapshot)
            return
        }
        guard let onPerformDayTaskAction else {
            appendDayOverviewNotice(String(localized: "Couldn’t update task."))
            return
        }

        var overlay = dayTaskOverlayStates[card.taskID] ?? EvaDayTaskOverlayState()
        overlay.isProcessing = true
        overlay.statusMessage = nil
        dayTaskOverlayStates[card.taskID] = overlay

        onPerformDayTaskAction(action, card) { result in
            Task { @MainActor in
                var resolved = dayTaskOverlayStates[card.taskID] ?? EvaDayTaskOverlayState()
                resolved.isProcessing = false
                switch result {
                case .success:
                    switch action {
                    case .done:
                        resolved.isHidden = true
                        appendDayOverviewNotice(String(localized: "Completed ‘\(card.title)’"))
                    case .reopen:
                        resolved.isHidden = true
                        appendDayOverviewNotice(String(localized: "Reopened ‘\(card.title)’"))
                    case .tomorrow:
                        resolved.isHidden = true
                        appendDayOverviewNotice(String(localized: "Moved ‘\(card.title)’ to Tomorrow"))
                    case .open:
                        break
                    }
                case .failure(let error):
                    resolved.statusMessage = error.localizedDescription
                }
                dayTaskOverlayStates[card.taskID] = resolved
            }
        }
    }
}
