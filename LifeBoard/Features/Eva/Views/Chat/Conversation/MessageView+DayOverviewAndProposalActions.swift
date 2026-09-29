//
//  ConversationView.swift
//

import MarkdownUI
import SwiftData
import SwiftUI

extension MessageView {
    func handleDayHabitAction(_ action: EvaDayHabitAction, card: EvaDayHabitCard) {
        if action == .open {
            onOpenHabitFromCard?(card.habitID)
            return
        }
        guard let onPerformDayHabitAction else {
            appendDayOverviewNotice(String(localized: "Couldn’t update habit."))
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
                    appendDayOverviewNotice(String(localized: "\(card.title) · \(habitActionSuccessMessage(action))"))
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
        case .stayedClean: return String(localized: "Stayed clean")
        case .lapsed: return String(localized: "Slipped")
        case .logLapse: return String(localized: "Log slip")
        case .open: return "Open"
        }
    }

    func habitResolvedChipTitle(_ action: EvaDayHabitAction) -> String {
        switch action {
        case .done: return "Done"
        case .skip: return "Skipped"
        case .stayedClean: return "Stayed clean"
        case .lapsed, .logLapse: return String(localized: "Slip logged")
        case .open: return "Open"
        }
    }

    func habitActionSuccessMessage(_ action: EvaDayHabitAction) -> String {
        switch action {
        case .done: return String(localized: "Logged")
        case .skip: return String(localized: "Skipped")
        case .stayedClean: return String(localized: "Clean day logged")
        case .lapsed: return String(localized: "Slip logged")
        case .logLapse: return String(localized: "Slip logged")
        case .open: return String(localized: "Opened")
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
                    HStack(alignment: .center, spacing: Theme.Spacing.md) {
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

                        Spacer(minLength: Theme.Spacing.sm)

                        VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                            Text(evaCardOverrides[card.id]?.badgeText.map { String(localized: "Edited · \($0)") } ?? card.badgeText)
                                .font(.lifeboard(.caption2))
                                .fontWeight(.semibold)
                                .foregroundStyle(toneColor(card.tone))
                                .padding(.horizontal, Theme.Spacing.xs)
                                .padding(.vertical, 3)
                                .background(toneColor(card.tone).opacity(0.14))
                                .clipShape(Capsule())

                            Button {
                                toggleEvaSelection(card)
                            } label: {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .lifeboardFont(.title1)
                                    .foregroundStyle(isSelected ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.accentMuted))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isSelected ? "Deselect \(card.title)" : "Select \(card.title)")
                            .accessibilityValue(isSelected ? "Selected" : "Not selected")
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
                .buttonStyle(.plain)

                if isExpanded, editingEvaCardID == card.id {
                    evaCardInlineEditor(card)
                        .padding(Theme.Spacing.sm)
                        .background(Color.lifeboard(.surfaceSecondary).opacity(0.72))
                }
                if isExpanded {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 104), spacing: Theme.Spacing.sm)],
                        alignment: .leading,
                        spacing: Theme.Spacing.sm
                    ) {
                        ForEach(availableEvaActions(for: card), id: \.self) { action in
                            evaCardActionButton(action, card: card)
                        }
                    }
                    .padding(Theme.Spacing.sm)
                    .background(isSelected ? Color.lifeboard(.accentWash).opacity(0.38) : Color.lifeboard(.surfaceSecondary).opacity(0.72))
                }
            }
        }
        .background(isSelected ? Color.lifeboard(.accentWash).opacity(0.18) : Color.lifeboard(.surfacePrimary))
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .lifeboardElevation(isSelected ? .e1 : .e0, cornerRadius: Theme.CornerRadius.lg)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    func evaCardActionButton(_ action: EvaProposalAction, card: EvaProposalCard) -> some View {
        Button {
            switch action {
            case .discard:
                selectedEvaCardIDs.remove(card.id)
                expandedEvaCardID = nil
            case .notNow:
                // Set aside, not judged: it leaves the selection and is
                // counted with the discarded cards in the run's history.
                selectedEvaCardIDs.remove(card.id)
                notNowEvaCardIDs.insert(card.id)
                expandedEvaCardID = nil
            case .show:
                openEvaProposalCard(card)
            case .edit:
                // Edit in place: the line's when, duration and title, not the
                // whole task editor.
                editingEvaCardID = editingEvaCardID == card.id ? nil : card.id
                selectedEvaCardIDs.insert(card.id)
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
        .buttonStyle(.lifeBoardPrimaryCompact)
        .tint(action == .discard ? Color.lifeboard(.statusDanger) : Color.lifeboard(.accentPrimary))
    }

    func availableEvaActions(for card: EvaProposalCard) -> [EvaProposalAction] {
        var actions = [card.primaryAction]
        for action in card.secondaryActions where actions.contains(action) == false {
            switch action {
            case .show:
                if evaTaskDefinition(for: card) != nil, onOpenTaskFromCard != nil {
                    actions.append(action)
                }
            case .edit:
                // Editable in place whenever the card carries a schedulable line.
                if card.after != nil || card.kind != .noOp {
                    actions.append(action)
                }
            case .discard, .add, .save, .notNow:
                actions.append(action)
            }
        }
        if actions.contains(.notNow) == false, card.commandIndexes.isEmpty == false {
            actions.append(.notNow)
        }
        return actions
    }

    /// The inline mini-editor: when and how long, plus the title for a new
    /// task. Writes an override; the envelope is rewritten at apply time.
    func evaCardInlineEditor(_ card: EvaProposalCard) -> some View {
        let binding = Binding<EvaProposalCardOverride>(
            get: { evaCardOverrides[card.id] ?? EvaProposalCardOverride(cardID: card.id) },
            set: { evaCardOverrides[card.id] = $0.isEmpty ? nil : $0 }
        )
        let start = binding.wrappedValue.scheduledStartAt ?? card.after?.scheduledStartAt ?? card.before?.scheduledStartAt ?? Date()
        let durations: [TimeInterval] = [15, 30, 45, 60, 90].map { $0 * 60 }
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            DatePicker(
                "When",
                selection: Binding(get: { start }, set: { binding.wrappedValue.scheduledStartAt = $0 }),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .font(.lifeboard(.caption1))
            .accessibilityIdentifier("eva.proposal.edit.when")
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(durations, id: \.self) { duration in
                    let isOn = (binding.wrappedValue.estimatedDuration ?? card.after?.estimatedDuration) == duration
                    Button("\(Int(duration / 60)) min") {
                        binding.wrappedValue.estimatedDuration = isOn ? nil : duration
                    }
                    .buttonStyle(.lifeBoardChip)
                    .foregroundStyle(isOn ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.textSecondary))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("eva.proposal.edit.duration.\(Int(duration / 60))")
                }
            }
            if card.kind == .create {
                TextField("Title", text: Binding(get: { binding.wrappedValue.title ?? card.title }, set: { binding.wrappedValue.title = $0 }), prompt: Text("Title").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                    .textFieldStyle(.plain)
                    // Clay well, not the system rounded border: that drew a pure white
                    // box on warm paper and a pure black one in dark appearance.
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
                    .accessibilityIdentifier("eva.proposal.edit.title")
            }
            if evaCardOverrides[card.id] != nil {
                Button("Reset") { evaCardOverrides[card.id] = nil }
                    .font(.lifeboard(.caption1))
                    .frame(minHeight: 44)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("eva.proposal.edit.\(card.id.uuidString)")
    }

    func openEvaProposalCard(_ card: EvaProposalCard) {
        guard let task = evaTaskDefinition(for: card) else { return }
        onOpenTaskFromCard?(task)
    }

    func evaTaskDefinition(for card: EvaProposalCard) -> TaskDefinition? {
        if let reference = createdTaskReferencesByCardID[card.id], reference.kind == .task {
            return TaskDefinition(
                id: reference.recordID,
                title: reference.title,
                dueDate: card.after?.dueDate,
                scheduledStartAt: card.after?.scheduledStartAt,
                scheduledEndAt: card.after?.scheduledEndAt,
                estimatedDuration: card.after?.estimatedDuration
            )
        }
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
}
