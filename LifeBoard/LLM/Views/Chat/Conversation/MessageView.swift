//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct MessageView: View {


    @Environment(\.lifeboardLayoutClass) var layoutClass

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
    }
}
