//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

extension MessageView {
    func handleDayHabitAction(_ action: EvaDayHabitAction, card: EvaDayHabitCard) {
        if action == .open {
            onOpenHabitFromCard?(card.habitID)
            return
        }
        guard let onPerformDayHabitAction else {
            appendDayOverviewNotice("Habit actions are unavailable right now.")
            return
        }

        var overlay = dayHabitOverlayStates[card.habitID] ?? EvaDayHabitOverlayState()
        overlay.isProcessing = true
        overlay.statusMessage = nil
        dayHabitOverlayStates[card.habitID] = overlay

        onPerformDayHabitAction(action, card) { result in
            Task { @MainActor in
                var resolved = dayHabitOverlayStates[card.habitID] ?? EvaDayHabitOverlayState()
                resolved.isProcessing = false
                switch result {
                case .success:
                    resolved.statusMessage = habitActionSuccessMessage(action)
                    resolved.actions = [.open]
                    resolved.resolvedTodayState = habitActionDayState(action)
                    resolved.statusChips = [EvaDayStatusChip(
                        text: habitResolvedChipTitle(action),
                        tone: action == .lapsed || action == .logLapse ? "warning" : "accent"
                    )]
                    appendDayOverviewNotice("\(habitActionSuccessMessage(action)) \(card.title).")
                case .failure(let error):
                    resolved.statusMessage = error.localizedDescription
                }
                dayHabitOverlayStates[card.habitID] = resolved
            }
        }
    }

    func appendDayOverviewNotice(_ notice: String) {
        guard dayOverviewNotices.contains(notice) == false else { return }
        dayOverviewNotices.append(notice)
    }

    func taskActionTitle(_ action: EvaDayTaskAction) -> String {
        switch action {
        case .done: return "Done"
        case .reopen: return "Reopen"
        case .tomorrow: return "Tomorrow"
        case .open: return "Open"
        }
    }

    func habitActionTitle(_ action: EvaDayHabitAction) -> String {
        switch action {
        case .done: return "Done"
        case .skip: return "Skip"
        case .stayedClean: return "Stayed Clean"
        case .lapsed: return "Lapsed"
        case .logLapse: return "Log Lapse"
        case .open: return "Open"
        }
    }

    func habitResolvedChipTitle(_ action: EvaDayHabitAction) -> String {
        switch action {
        case .done: return "Done"
        case .skip: return "Skipped"
        case .stayedClean: return "Stayed clean"
        case .lapsed, .logLapse: return "Lapsed"
        case .open: return "Open"
        }
    }

    func habitActionSuccessMessage(_ action: EvaDayHabitAction) -> String {
        switch action {
        case .done: return "Logged completion for"
        case .skip: return "Skipped"
        case .stayedClean: return "Logged stayed clean for"
        case .lapsed: return "Logged a lapse for"
        case .logLapse: return "Logged a lapse for"
        case .open: return "Opened"
        }
    }

    func habitActionDayState(_ action: EvaDayHabitAction) -> HabitDayState? {
        switch action {
        case .done, .stayedClean:
            return .success
        case .skip:
            return .skipped
        case .lapsed, .logLapse:
            return .failure
        case .open:
            return nil
        }
    }

    func dayChipColor(_ tone: String) -> Color {
        switch tone {
        case "danger":
            return Color.lifeboard(.statusDanger)
        case "warning":
            return Color.lifeboard(.statusWarning)
        default:
            return Color.lifeboard(.accentPrimary)
        }
    }

    func evaProposalRow(_ card: EvaProposalCard) -> some View {
        let isSelected = selectedEvaCardIDs.contains(card.id)
        let isExpanded = expandedEvaCardID == card.id
        let borderColor = isSelected ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.strokeHairline)
        let borderWidth: CGFloat = isSelected ? 2 : 1

        return HStack(spacing: 0) {
            if isSelected {
                Color.lifeboard(.accentPrimary)
                    .frame(width: 4)
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                Button {
                    if isExpanded {
                        expandedEvaCardID = nil
                    } else {
                        expandedEvaCardID = card.id
                    }
                } label: {
                    HStack(alignment: .center, spacing: LifeBoardTheme.Spacing.md) {
                        Image(systemName: iconName(for: card))
                            .font(.lifeboard(.title3))
                            .foregroundStyle(toneColor(card.tone))
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.subtitle)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard(.textTertiary))
                                .lineLimit(2)
                            Text(card.title)
                                .font(.lifeboard(.headline))
                                .foregroundStyle(Color.lifeboard(.textPrimary))
                                .lineLimit(2)
                        }

                        Spacer(minLength: LifeBoardTheme.Spacing.sm)

                        VStack(alignment: .trailing, spacing: LifeBoardTheme.Spacing.xs) {
                            Text(card.badgeText)
                                .font(.lifeboard(.caption2))
                                .fontWeight(.semibold)
                                .foregroundStyle(toneColor(card.tone))
                                .padding(.horizontal, LifeBoardTheme.Spacing.xs)
                                .padding(.vertical, 3)
                                .background(toneColor(card.tone).opacity(0.14))
                                .clipShape(Capsule())

                            Button {
                                toggleEvaSelection(card)
                            } label: {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(isSelected ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.accentMuted))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isSelected ? "Deselect \(card.title)" : "Select \(card.title)")
                            .accessibilityValue(isSelected ? "Selected" : "Not selected")
                        }
                    }
                    .padding(LifeBoardTheme.Spacing.md)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 104), spacing: LifeBoardTheme.Spacing.sm)],
                        alignment: .leading,
                        spacing: LifeBoardTheme.Spacing.sm
                    ) {
                        ForEach(availableEvaActions(for: card), id: \.self) { action in
                            evaCardActionButton(action, card: card)
                        }
                    }
                    .padding(LifeBoardTheme.Spacing.sm)
                    .background(isSelected ? Color.lifeboard(.accentWash).opacity(0.38) : Color.lifeboard(.surfaceSecondary).opacity(0.72))
                }
            }
        }
        .background(isSelected ? Color.lifeboard(.accentWash).opacity(0.18) : Color.lifeboard(.surfacePrimary))
        .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .shadow(color: isSelected ? Color.lifeboard(.accentPrimary).opacity(0.18) : .clear, radius: isSelected ? 8 : 0, x: 0, y: isSelected ? 3 : 0)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    func evaCardActionButton(_ action: EvaProposalAction, card: EvaProposalCard) -> some View {
        Button {
            switch action {
            case .discard:
                selectedEvaCardIDs.remove(card.id)
                expandedEvaCardID = nil
            case .show:
                openEvaProposalCard(card)
            case .edit:
                openEvaProposalCard(card)
            case .add, .save:
                selectedEvaCardIDs.insert(card.id)
            }
        } label: {
            Label {
                Text(action.rawValue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
            } icon: {
                Image(systemName: actionIcon(action))
            }
                .font(.lifeboard(.buttonSmall))
                .frame(minWidth: 104, minHeight: 44)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(action == .discard ? Color.lifeboard(.statusDanger) : Color.lifeboard(.accentPrimary))
    }

    func availableEvaActions(for card: EvaProposalCard) -> [EvaProposalAction] {
        var actions = [card.primaryAction]
        for action in card.secondaryActions where actions.contains(action) == false {
            switch action {
            case .show, .edit:
                if evaTaskDefinition(for: card) != nil, onOpenTaskFromCard != nil {
                    actions.append(action)
                }
            case .discard, .add, .save:
                actions.append(action)
            }
        }
        return actions
    }

    func openEvaProposalCard(_ card: EvaProposalCard) {
        guard let task = evaTaskDefinition(for: card) else { return }
        onOpenTaskFromCard?(task)
    }

    func evaTaskDefinition(for card: EvaProposalCard) -> TaskDefinition? {
        guard let snapshot = card.after ?? card.before,
              let taskID = snapshot.taskID else {
            return nil
        }
        return TaskDefinition(
            id: taskID,
            iconSymbolName: snapshot.iconSymbolName,
            title: snapshot.title,
            dueDate: snapshot.dueDate,
            scheduledStartAt: snapshot.scheduledStartAt,
            scheduledEndAt: snapshot.scheduledEndAt,
            estimatedDuration: snapshot.estimatedDuration
        )
    }

    func toggleEvaSelection(_ card: EvaProposalCard) {
        if selectedEvaCardIDs.contains(card.id) {
            selectedEvaCardIDs.remove(card.id)
        } else {
            selectedEvaCardIDs.insert(card.id)
        }
        pendingEvaApplyConfirmationIDs = nil
    }

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
        evaApplyMessage = "Review the selected changes, then confirm to apply."
    }

    func applyEvaProposal(payload: AssistantCardPayload, proposal: EvaProposalReviewPayload) {
        guard let runID = payload.runID, let pipeline = LLMAssistantPipelineProvider.pipeline else {
            evaApplyMessage = "\(AssistantIdentityText.currentSnapshot().displayName) cannot apply this plan right now."
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
        evaApplyMessage = "Applying selected changes..."

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
                        finishEvaApply(message: "\(AssistantIdentityText.currentSnapshot().displayName) could not read this proposal.")
                        return
                    }

                    let selectedEnvelope = EvaProposalCardBuilder.selectedEnvelope(
                        from: envelope,
                        selectedCardIDs: selectedEvaCardIDs,
                        cards: proposal.cards
                    )
                    if selectedEnvelope.commands.count == envelope.commands.count {
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
                            case .success:
                                recordEvaAppliedRunHistory(
                                    runID: runID,
                                    payload: payload,
                                    proposal: proposal,
                                    selectedCards: selectedCards
                                )
                                finishEvaApply(
                                    message: "\(AssistantIdentityText.currentSnapshot().displayName) updated \(appliedCount) tasks. Undo for 30 min.",
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
}
