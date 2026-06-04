//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

extension MessageView {
    func evaProposalCardView(payload: AssistantCardPayload, proposal: EvaProposalReviewPayload) -> some View {
        let isApplyable = payload.runID != nil && proposal.cards.contains { $0.commandIndexes.isEmpty == false }
        return VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.md) {
            evaPromptCard(prompt: proposal.prompt)

            HStack(alignment: .center, spacing: LifeBoardTheme.Spacing.sm) {
                EvaMascotView(placement: .proposalReview, size: .inline)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(AssistantIdentityText.currentSnapshot().displayName) review")
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text("Check the plan before anything changes.")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
                Spacer(minLength: 0)
            }
            .padding(LifeBoardTheme.Spacing.md)
            .background(Color.lifeboard(.surfaceSecondary))
            .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous))

            DisclosureGroup {
                Text(proposal.contextReceipt.sources.isEmpty ? "No additional context receipt." : proposal.contextReceipt.sources.joined(separator: "\n"))
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, LifeBoardTheme.Spacing.xs)
            } label: {
                Label {
                    Text(proposal.contextReceipt.compactReviewText)
                        .font(.lifeboard(.caption1))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                } icon: {
                    Image(systemName: "info.circle.fill")
                }
                .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            .padding(.horizontal, LifeBoardTheme.Spacing.sm)
            .padding(.vertical, LifeBoardTheme.Spacing.xs)
            .background(Color.lifeboard(.surfaceSecondary))
            .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous))
            .accessibilityLabel(proposal.contextReceipt.compactReviewText)

            Text(summaryText(proposal.summary))
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(LifeBoardTheme.Spacing.md)
                .background(Color.lifeboard(.surfaceSecondary))
                .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous))

            ForEach(EvaProposalCardBuilder.groups(for: proposal.cards)) { group in
                VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
                    Text(group.title)
                        .font(.lifeboard(.caption1))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                        .padding(.horizontal, LifeBoardTheme.Spacing.xs)

                    ForEach(group.cards) { card in
                        evaProposalRow(card)
                    }
                }
            }

            HStack(spacing: LifeBoardTheme.Spacing.sm) {
                Button {
                    selectedEvaCardIDs = Set(proposal.cards.filter(\.isSelectedByDefault).map(\.id))
                    expandedEvaCardID = nil
                    evaApplyMessage = nil
                    pendingEvaApplyConfirmationIDs = nil
                } label: {
                    Label("Start New", systemImage: "square.and.pencil")
                }
                .buttonStyle(.bordered)
                .tint(Color.lifeboard(.accentPrimary))

                Spacer()

                Button {
                    evaApplyMessage = "Thanks for the feedback."
                } label: {
                    Image(systemName: "hand.thumbsup")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .accessibilityLabel("Helpful")

                Button {
                    evaApplyMessage = "Thanks. \(AssistantIdentityText.currentSnapshot().displayName) will use this feedback later."
                } label: {
                    Image(systemName: "hand.thumbsdown")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .accessibilityLabel("Not helpful")
            }

            if let evaApplyMessage {
                Text(evaApplyMessage)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }

            if isApplyable {
                if let payloadRunID = payload.runID,
                   let appliedRunID = appliedEvaRunIDByPayloadRunID[payloadRunID] {
                    let undoExpired = isProposalUndoExpired(payloadRunID: payloadRunID)
                    HStack(spacing: LifeBoardTheme.Spacing.sm) {
                        Button {
                            undoEvaRun(appliedRunID, payloadRunID: payloadRunID)
                        } label: {
                            Label(undoExpired ? "Undo expired" : "Undo", systemImage: "arrow.uturn.backward")
                                .font(.lifeboard(.buttonSmall))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.lifeboard(.accentPrimary))
                        .disabled(isUndoingEvaRun || undoExpired)
                        .accessibilityIdentifier("eva.proposal.undo")
                    }
                } else {
                    if pendingEvaApplyConfirmationIDs == selectedEvaCardIDs {
                        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
                            Text("Confirm before \(AssistantIdentityText.currentSnapshot().displayName) changes your tasks.")
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard(.textSecondary))

                            HStack(spacing: LifeBoardTheme.Spacing.sm) {
                                Button("Cancel") {
                                    pendingEvaApplyConfirmationIDs = nil
                                    evaApplyMessage = nil
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    applyEvaProposal(payload: payload, proposal: proposal)
                                } label: {
                                    Text("Confirm Apply")
                                        .font(.lifeboard(.buttonSmall))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.lifeboard(.accentPrimary))
                                .disabled(isApplyingEvaProposal || selectedEvaCardIDs.isEmpty || payload.runID == nil)
                                .accessibilityIdentifier("eva.proposal.confirm_apply")
                            }
                        }
                    } else {
                        Button {
                            prepareEvaProposalConfirmation(proposal: proposal)
                        } label: {
                            HStack {
                                Spacer()
                                Text(applyButtonTitle(cards: proposal.cards))
                                    .font(.lifeboard(.buttonSmall))
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.lifeboard(.accentPrimary))
                        .disabled(
                            isApplyingEvaProposal
                                || selectedEvaCardIDs.isEmpty
                                || payload.runID == nil
                                || payload.runID.map { appliedEvaRunIDs.contains($0) } == true
                        )
                        .accessibilityIdentifier("eva.proposal.apply_selected")
                    }
                }
            }
        }
        .onAppear {
            if isApplyable && selectedEvaCardIDs.isEmpty {
                selectedEvaCardIDs = Set(proposal.cards.filter(\.isSelectedByDefault).map(\.id))
            }
        }
    }

    func evaPromptCard(prompt: String) -> some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
            HStack(spacing: LifeBoardTheme.Spacing.xs) {
                Image(systemName: "chevron.right")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                Text("Your plans")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            Text(prompt)
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard(.textPrimary))
        }
        .padding(LifeBoardTheme.Spacing.md)
        .background(Color.lifeboard(.surfacePrimary))
        .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous)
                .stroke(Color.lifeboard(.accentPrimary), lineWidth: 1.5)
        )
    }

    func dayOverviewCardView(payload: AssistantCardPayload, overview: EvaDayOverviewPayload) -> some View {
        let sections = visibleDayOverviewSections(for: overview)

        return VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.md) {
            evaPromptCard(prompt: overview.prompt)

            HStack(alignment: .center, spacing: LifeBoardTheme.Spacing.sm) {
                EvaMascotView(placement: .dayOverview, size: .inline)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(AssistantIdentityText.currentSnapshot().displayName) noticed")
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text("A grounded brief from your current task and habit context.")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(LifeBoardTheme.Spacing.md)
            .background(Color.lifeboard(.surfaceSecondary))
            .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous))

            if overview.isPartialContext {
                HStack(alignment: .top, spacing: LifeBoardTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.lifeboard(.statusWarning))
                    Text("Context is partial. \(AssistantIdentityText.currentSnapshot().displayName) is only showing grounded tasks and habits from the slices that loaded.")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, LifeBoardTheme.Spacing.md)
                .padding(.vertical, LifeBoardTheme.Spacing.sm)
                .background(Color.lifeboard(.surfaceSecondary))
                .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous))
            }

            DisclosureGroup {
                Text(overview.contextReceipt.sources.joined(separator: "\n"))
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, LifeBoardTheme.Spacing.xs)
            } label: {
                Label(overview.contextReceipt.collapsedText, systemImage: "lock.shield")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }

            markdownText(overview.summaryMarkdown, color: Color.lifeboard(.textPrimary))
                .padding(LifeBoardTheme.Spacing.md)
                .background(Color.lifeboard(.surfaceSecondary))
                .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous))

            if dayOverviewNotices.isEmpty == false {
                VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
                    ForEach(Array(dayOverviewNotices.enumerated()), id: \.offset) { _, notice in
                        Text(notice)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
                }
                .padding(.horizontal, LifeBoardTheme.Spacing.md)
                .padding(.vertical, LifeBoardTheme.Spacing.sm)
                .background(Color.lifeboard(.accentWash).opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous))
            }

            if sections.isEmpty {
                Text("Everything visible in this brief has already been handled.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            } else {
                ForEach(sections) { section in
                    dayOverviewSectionView(section)
                }
            }
        }
    }

    func visibleDayOverviewSections(for overview: EvaDayOverviewPayload) -> [EvaDayOverviewSection] {
        overview.sections.compactMap { section in
            let visibleTaskCards = section.taskCards.filter { !(dayTaskOverlayStates[$0.taskID]?.isHidden ?? false) }
            let visibleHabitCards = section.habitCards

            if visibleTaskCards.isEmpty && visibleHabitCards.isEmpty {
                guard section.kind == .emptyState || section.message?.isEmpty == false else {
                    return nil
                }
            }

            return EvaDayOverviewSection(
                kind: section.kind,
                title: section.title,
                subtitle: section.subtitle,
                taskCards: visibleTaskCards,
                habitCards: visibleHabitCards,
                message: section.message
            )
        }
    }

    func dayOverviewSectionView(_ section: EvaDayOverviewSection) -> some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.lifeboard(.caption1))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                if let subtitle = section.subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                }
            }
            .padding(.horizontal, LifeBoardTheme.Spacing.xs)

            if let message = section.message, message.isEmpty == false,
               section.taskCards.isEmpty && section.habitCards.isEmpty {
                Text(message)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .padding(LifeBoardTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.lifeboard(.surfaceSecondary))
                    .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous))
            }

            ForEach(section.taskCards) { card in
                dayTaskRow(card)
            }

            ForEach(section.habitCards) { card in
                dayHabitRow(card)
            }
        }
    }

    func dayTaskRow(_ card: EvaDayTaskCard) -> some View {
        let overlay = dayTaskOverlayStates[card.taskID] ?? EvaDayTaskOverlayState()
        return EvaDaySunriseTaskRowView(
            card: card,
            overlay: overlay,
            chipColorProvider: dayChipColor,
            actionTitle: taskActionTitle,
            actionHandler: { action in
                handleDayTaskAction(action, card: card)
            }
        )
    }

    func dayHabitRow(_ card: EvaDayHabitCard) -> some View {
        let overlay = dayHabitOverlayStates[card.habitID] ?? EvaDayHabitOverlayState()
        let chips = overlay.statusChips ?? card.statusChips
        let actions = overlay.actions ?? card.actions

        return EvaDayHabitRowView(
            card: card,
            overlay: overlay,
            chips: chips,
            actions: actions,
            chipColorProvider: dayChipColor,
            actionTitle: habitActionTitle,
            actionHandler: { action in
                handleDayHabitAction(action, card: card)
            }
        )
    }

    @ViewBuilder
    func dayStatusChips(_ chips: [EvaDayStatusChip]) -> some View {
        EvaDayStatusChipsView(chips: chips, colorProvider: dayChipColor)
    }

    func handleDayTaskAction(_ action: EvaDayTaskAction, card: EvaDayTaskCard) {
        if action == .open {
            onOpenTaskFromCard?(card.taskSnapshot)
            return
        }
        guard let onPerformDayTaskAction else {
            appendDayOverviewNotice("Task actions are unavailable right now.")
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
                        appendDayOverviewNotice("Marked \"\(card.title)\" done.")
                    case .reopen:
                        resolved.isHidden = true
                        appendDayOverviewNotice("Reopened \"\(card.title)\".")
                    case .tomorrow:
                        resolved.isHidden = true
                        appendDayOverviewNotice("Moved \"\(card.title)\" to tomorrow.")
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
