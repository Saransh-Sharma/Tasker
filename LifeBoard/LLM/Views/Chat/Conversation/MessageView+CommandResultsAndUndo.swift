//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

extension MessageView {
    func recordEvaAppliedRunHistory(
        runID: UUID,
        payload: AssistantCardPayload,
        proposal: EvaProposalReviewPayload,
        selectedCards: [EvaProposalCard]
    ) {
        guard V2FeatureFlags.evaAppliedRunHistory else { return }
        let appliedAt = Date()
        let entry = EvaAppliedRunHistoryEntry(
            runID: runID,
            threadID: payload.threadID,
            prompt: proposal.prompt,
            summary: summaryText(proposal.summary),
            appliedCards: selectedCards,
            discardedCardCount: max(0, proposal.cards.count - selectedCards.count),
            contextReceipt: proposal.contextReceipt,
            appliedAt: appliedAt,
            undoExpiresAt: appliedAt.addingTimeInterval(30 * 60),
            status: AssistantCardStatus.applied.rawValue,
            undoStatus: AssistantCardStatus.undoAvailable.rawValue
        )
        EvaAppliedRunHistoryStore.shared.record(entry)
    }

    func finishEvaApply(message: String, appliedRunID: UUID? = nil, payloadRunID: UUID? = nil) {
        Task { @MainActor in
            isApplyingEvaProposal = false
            evaApplyMessage = message
            pendingEvaApplyConfirmationIDs = nil
            if let appliedRunID {
                appliedEvaRunIDs.insert(appliedRunID)
                if let payloadRunID {
                    appliedEvaRunIDByPayloadRunID[payloadRunID] = appliedRunID
                    appliedEvaUndoExpiresAtByPayloadRunID[payloadRunID] = Date().addingTimeInterval(30 * 60)
                }
                selectedEvaCardIDs.removeAll()
            }
        }
    }

    func undoEvaRun(_ runID: UUID, payloadRunID: UUID?) {
        guard let pipeline = LLMAssistantPipelineProvider.pipeline else {
            evaApplyMessage = "\(AssistantIdentityText.currentSnapshot().displayName) cannot undo this plan right now."
            return
        }
        isUndoingEvaRun = true
        evaApplyMessage = "Undoing \(AssistantIdentityText.currentSnapshot().displayName) changes..."
        pipeline.undoAppliedRun(id: runID) { result in
            Task { @MainActor in
                isUndoingEvaRun = false
                switch result {
                case .success:
                    appliedEvaRunIDs.remove(runID)
                    if let payloadRunID {
                        appliedEvaRunIDByPayloadRunID[payloadRunID] = nil
                        appliedEvaUndoExpiresAtByPayloadRunID[payloadRunID] = nil
                    }
                    evaApplyMessage = "\(AssistantIdentityText.currentSnapshot().displayName) reverted those changes."
                case .failure(let error):
                    evaApplyMessage = error.localizedDescription
                }
            }
        }
    }

    func applyButtonTitle(cards: [EvaProposalCard]) -> String {
        EvaProposalApplyButtonTitleResolver.title(cards: cards, selectedCardIDs: selectedEvaCardIDs)
    }

    func summaryText(_ summary: String) -> String {
        summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Here's how your day is planned:"
            : summary
    }

    func toneColor(_ tone: EvaProposalTone) -> Color {
        switch tone {
        case .create:
            return Color.lifeboard(.accentPrimary)
        case .edit:
            return Color.lifeboard(.statusWarning)
        case .neutral:
            return Color.lifeboard(.textTertiary)
        case .warning:
            return Color.lifeboard(.statusWarning)
        case .destructive:
            return Color.lifeboard(.statusDanger)
        }
    }

    func iconName(for card: EvaProposalCard) -> String {
        if let icon = card.after?.iconSymbolName ?? card.before?.iconSymbolName {
            return icon
        }
        switch card.kind {
        case .create:
            return "sparkles"
        case .move:
            return "arrow.right"
        case .shorten:
            return "timer"
        case .deferred:
            return "arrow.uturn.forward"
        case .drop, .delete:
            return "trash"
        case .unchanged:
            return "checkmark.seal"
        case .noOp:
            return "info.circle"
        case .needsReview:
            return "exclamationmark.triangle"
        case .edit:
            return "pencil"
        }
    }

    func actionIcon(_ action: EvaProposalAction) -> String {
        switch action {
        case .add:
            return "plus"
        case .save:
            return "checkmark"
        case .edit:
            return "pencil"
        case .discard:
            return "xmark"
        case .show:
            return "eye"
        }
    }

    @ViewBuilder
    func commandResultCardView(_ result: SlashCommandExecutionResult) -> some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
            HStack {
                Label(result.commandLabel, systemImage: result.commandID.icon)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Spacer()
                Text("\(result.totalTaskCount)")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }

            Text(result.summary)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))

            if result.sections.isEmpty {
                Text("No tasks to show.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            } else {
                VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
                    ForEach(Array(result.sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
                            Text("\(section.title) (\(section.totalCount))")
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard(.textTertiary))

                            ForEach(Array(section.tasks.enumerated()), id: \.element.taskID) { _, item in
                                Button {
                                    logWarning(
                                        event: "chat_slash_card_task_opened",
                                        message: "Opened task detail from slash command card",
                                        fields: [
                                            "command_id": result.commandID.rawValue,
                                            "task_id": item.taskID.uuidString
                                        ]
                                    )
                                    onOpenTaskFromCard?(item.taskSnapshot)
                                } label: {
                                    VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
                                        Text(item.title)
                                            .font(.lifeboard(.callout))
                                            .foregroundStyle(Color.lifeboard(.textPrimary))
                                            .multilineTextAlignment(.leading)
                                        HStack(spacing: LifeBoardTheme.Spacing.xs) {
                                            if let dueLabel = item.dueLabel, !dueLabel.isEmpty {
                                                Text(dueLabel)
                                                    .font(.lifeboard(.caption1))
                                                    .foregroundStyle(dueLabelColor(dueLabel))
                                            }
                                            Text(item.projectName)
                                                .font(.lifeboard(.caption1))
                                                .foregroundStyle(Color.lifeboard(.textTertiary))
                                        }
                                    }
                                    .padding(.horizontal, LifeBoardTheme.Spacing.sm)
                                    .padding(.vertical, LifeBoardTheme.Spacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.lifeboard(.surfaceSecondary))
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: LifeBoardTheme.CornerRadius.md,
                                            style: .continuous
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Open task \(item.title)")
                                .accessibilityHint("Opens task details")
                                .accessibilityIdentifier("chat.command_card.task_row.\(item.taskID.uuidString)")
                            }
                        }
                    }
                }
            }
        }
    }

    func dueLabelColor(_ dueLabel: String) -> Color {
        dueLabel.localizedCaseInsensitiveContains("late")
            ? Color.lifeboard(.statusDanger)
            : Color.lifeboard(.textTertiary)
    }

    func proposalStatusText(_ status: AssistantCardStatus) -> String {
        switch status {
        case .applied:
            return "Applied successfully."
        case .rejected:
            return "Rejected."
        case .failed:
            return "Failed."
        case .rollbackComplete:
            return "Apply failed, but all changes were rolled back."
        case .rollbackFailed:
            return "Apply failed and rollback could not be fully verified."
        case .undone:
            return "Changes reverted."
        default:
            return "Updated."
        }
    }

    func isUndoExpired(payload: AssistantCardPayload) -> Bool {
        guard let expiresAt = payload.expiresAt else { return true }
        return now >= expiresAt
    }

    func isProposalUndoExpired(payloadRunID: UUID) -> Bool {
        guard let expiresAt = appliedEvaUndoExpiresAtByPayloadRunID[payloadRunID] else { return true }
        return now >= expiresAt
    }

    func undoLabel(payload: AssistantCardPayload) -> String {
        guard let expiresAt = payload.expiresAt else {
            return "Undo unavailable"
        }
        let remaining = Int(expiresAt.timeIntervalSince(now) / 60)
        if remaining <= 0 {
            return "Undo window expired"
        }
        return "Undo available for \(remaining) min"
    }
}
