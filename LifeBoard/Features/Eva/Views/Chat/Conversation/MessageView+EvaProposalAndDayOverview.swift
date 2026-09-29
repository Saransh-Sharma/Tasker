//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

extension MessageView {
    func evaProposalCardView(payload: AssistantCardPayload, proposal: EvaProposalReviewPayload) -> some View {
        let isApplyable = payload.runID != nil && proposal.cards.contains { $0.commandIndexes.isEmpty == false }
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            evaPromptCard(prompt: proposal.prompt)

            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                EvaMascotView(placement: .proposalReview, size: .inline)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Suggested changes")
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                }
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.md)
            .background(Color.lifeboard(.surfaceSecondary))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))

            DisclosureGroup {
                Text(proposal.contextReceipt.sources.isEmpty ? String(localized: "No details") : proposal.contextReceipt.sources.joined(separator: "\n"))
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.xs)
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
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Color.lifeboard(.surfaceSecondary))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            .accessibilityLabel(proposal.contextReceipt.compactReviewText)

            Text(summaryText(proposal.summary))
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(Theme.Spacing.md)
                .background(Color.lifeboard(.surfaceSecondary))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))

            ForEach(EvaProposalCardBuilder.groups(for: proposal.cards)) { group in
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(group.title)
                        .font(.lifeboard(.caption1))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                        .padding(.horizontal, Theme.Spacing.xs)

                    ForEach(group.cards) { card in
                        evaProposalRow(card)
                    }
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    selectedEvaCardIDs = Set(proposal.cards.filter(\.isSelectedByDefault).map(\.id))
                    expandedEvaCardID = nil
                    evaApplyMessage = nil
                    pendingEvaApplyConfirmationIDs = nil
                } label: {
                    // It restores the suggested selection; "Start New" read as
                    // a new chat.
                    Label("Reset selection", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .tint(Color.lifeboard(.accentPrimary))

                Spacer()

                // The thumbs-up/down pair used to sit here. Nothing recorded
                // what they were told: both only printed "Thanks", which is
                // `DESIGN.md`'s "simulate success with a delay" in its plainest
                // form — and both were bare glyphs well under the 44pt target.
                // They come back when there is somewhere for the feedback to go.
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
                    HStack(spacing: Theme.Spacing.sm) {
                        Button {
                            undoEvaRun(appliedRunID, payloadRunID: payloadRunID)
                        } label: {
                            Label(undoExpired ? "Undo expired" : "Undo", systemImage: "arrow.uturn.backward")
                                .font(.lifeboard(.buttonSmall))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.lifeBoardPrimaryCompact)
                        .tint(Color.lifeboard(.accentPrimary))
                        .disabled(isUndoingEvaRun || undoExpired)
                        .accessibilityIdentifier("eva.proposal.undo")
                    }
                } else {
                    if pendingEvaApplyConfirmationIDs == selectedEvaCardIDs {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Apply these changes?")
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard(.textSecondary))

                            HStack(spacing: Theme.Spacing.sm) {
                                Button("Cancel") {
                                    pendingEvaApplyConfirmationIDs = nil
                                    evaApplyMessage = nil
                                }
                                .buttonStyle(.lifeBoardChip)

                                Button {
                                    applyEvaProposal(payload: payload, proposal: proposal)
                                } label: {
                                    Text("Apply")
                                        .font(.lifeboard(.buttonSmall))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.lifeBoardPrimaryCompact)
                                .tint(Color.lifeboard(.accentPrimary))
                                .disabled(isApplyingEvaProposal || selectedEvaCardIDs.isEmpty || payload.runID == nil)
                                .accessibilityIdentifier("eva.proposal.confirm_apply")
                            }
                        }
                    } else if let runID = payload.runID, dismissedEvaRunIDs.contains(runID) {
                        // Set aside, not gone: it can come back from here.
                        HStack(spacing: Theme.Spacing.sm) {
                            Text("Not applied")
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                                .accessibilityIdentifier("eva.proposal.not_now.receipt")
                            Spacer(minLength: Theme.Spacing.sm)
                            Button("Bring back") {
                                Haptic.pick.play()
                                bringBackEvaProposal(runID: runID, proposal: proposal)
                            }
                            .font(.lifeboard(.buttonSmall))
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("eva.proposal.bring_back")
                        }
                    } else {
                        Button {
                            guard let runID = payload.runID else { return }
                            dismissedEvaRunIDs.insert(runID)
                            selectedEvaCardIDs.removeAll()
                            expandedEvaCardID = nil
                            recordEvaDismissedRunHistory(runID: runID, payload: payload, proposal: proposal)
                            Haptic.pick.play()
                            EvaChatReceiptCenter.shared.show(.init(
                                message: String(localized: "Not applied"),
                                detail: nil,
                                undo: {
                                    bringBackEvaProposal(runID: runID, proposal: proposal)
                                    return true
                                }
                            ))
                        } label: {
                            Text(EvaProposalAction.notNow.rawValue)
                                .font(.lifeboard(.buttonSmall))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.lifeBoardChip)
                        .frame(minHeight: 44)
                        .disabled(isApplyingEvaProposal || payload.runID == nil)
                        .accessibilityIdentifier("eva.proposal.not_now")
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
                        .buttonStyle(.lifeBoardPrimaryCompact)
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
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "chevron.right")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                Text("You asked")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            Text(prompt)
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard(.textPrimary))
        }
        .padding(Theme.Spacing.md)
        .background(Color.lifeboard(.surfacePrimary))
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .stroke(Color.lifeboard(.accentPrimary), lineWidth: 1.5)
        )
    }

    func dayOverviewCardView(payload: AssistantCardPayload, overview: EvaDayOverviewPayload) -> some View {
        let sections = visibleDayOverviewSections(for: overview)

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            evaPromptCard(prompt: overview.prompt)

            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                EvaMascotView(placement: .dayOverview, size: .inline)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your day")
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                }
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.md)
            .background(Color.lifeboard(.surfaceSecondary))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))

            if overview.isPartialContext {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.lifeboard(.statusWarning))
                    Text("Some data didn’t load.")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Color.lifeboard(.surfaceSecondary))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            }

            DisclosureGroup {
                Text(overview.contextReceipt.sources.joined(separator: "\n"))
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.xs)
            } label: {
                Label(overview.contextReceipt.collapsedText, systemImage: "lock.shield")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }

            markdownText(overview.summaryMarkdown, color: Color.lifeboard(.textPrimary))
                .padding(Theme.Spacing.md)
                .background(Color.lifeboard(.surfaceSecondary))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))

            if dayOverviewNotices.isEmpty == false {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(Array(dayOverviewNotices.enumerated()), id: \.offset) { _, notice in
                        Text(notice)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Color.lifeboard(.accentWash).opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            }

            if sections.isEmpty {
                Text("All done")
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
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
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
            .padding(.horizontal, Theme.Spacing.xs)

            if let message = section.message, message.isEmpty == false,
               section.taskCards.isEmpty && section.habitCards.isEmpty {
                Text(message)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.lifeboard(.surfaceSecondary))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
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
}
