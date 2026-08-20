//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct MessageView: View {


    @Environment(\.lifeboardLayoutClass) var layoutClass

    @Environment(\.evaAuthorizedEvidenceContext) var authorizedLifeEvidence

    @Environment(\.evaEvidenceOpenAction) var evidenceOpenAction

    @State var collapsed = true

    @State var undoExpiredLogged = false

    @State var selectedEvaCardIDs: Set<UUID> = []

    @State var expandedEvaCardID: UUID?

    @State var evaApplyMessage: String?

    @State var isApplyingEvaProposal = false

    @State var appliedEvaRunIDs: Set<UUID> = []

    @State var appliedEvaRunIDByPayloadRunID: [UUID: UUID] = [:]

    @State var appliedEvaUndoExpiresAtByPayloadRunID: [UUID: Date] = [:]

    @State var pendingEvaApplyConfirmationIDs: Set<UUID>?

    @State var isUndoingEvaRun = false

    @State var dayTaskOverlayStates: [UUID: EvaDayTaskOverlayState] = [:]

    @State var dayHabitOverlayStates: [UUID: EvaDayHabitOverlayState] = [:]

    @State var dayOverviewNotices: [String] = []

    @State var spokenOutput = EvaSpokenOutputController.shared

    @State var paidSpeechRegenerationText: String?

    @State var showsContextReceipt = false

    @State var memoryCandidateDraft = ""

    @State var isEditingMemoryCandidate = false

    @State var memoryCandidateRevision = 0

    let renderModel: ChatMessageRenderModel

    let now: Date

    var runtime: LLMEvaluator? = nil

    var isLiveOutput: Bool = false

    var workingStatuses: [String] = []

    var pendingPhase: ChatPendingResponsePhase = .idle

    var pendingStatusText: String? = nil

    var onOpenTaskFromCard: ((TaskDefinition) -> Void)?

    var onOpenHabitFromCard: ((UUID) -> Void)?

    var onPerformDayTaskAction: EvaDayTaskActionHandler?

    var onPerformDayHabitAction: EvaDayHabitActionHandler?

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
            "Regenerate spoken audio for one cloud credit?",
            isPresented: Binding(
                get: { paidSpeechRegenerationText != nil },
                set: { if !$0 { paidSpeechRegenerationText = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Regenerate · 1 credit") {
                guard let text = paidSpeechRegenerationText else { return }
                paidSpeechRegenerationText = nil
                spokenOutput.play(text: text, allowPaidRegeneration: true)
            }
            Button("Cancel", role: .cancel) { paidSpeechRegenerationText = nil }
        } message: {
            Text("The local audio copy is unavailable. A new cloud rendering uses one credit.")
        }
        .sheet(isPresented: $showsContextReceipt) {
            if let receipt = renderModel.contextReceipt {
                EvaContextReceiptSheet(receipt: receipt)
            }
        }
    }
}
