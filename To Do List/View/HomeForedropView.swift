//
//  HomeForedropView.swift
//  Tasker
//
//  New SwiftUI Home shell with backdrop/foredrop pattern.
//

import SwiftUI
import UIKit
import Combine

// MARK: - Foredrop Anchor

enum ForedropAnchor: Equatable {
    /// Foredrop covers calendar + charts. Default state.
    case collapsed
    /// Foredrop anchors below the weekly calendar strip.
    case midReveal
    /// Foredrop anchors below the chart cards (full analytics view).
    case fullReveal
}


private enum EvaRescueMoveChoice: String, CaseIterable {
    case tomorrow
    case weekend
    case custom

    var title: String {
        switch self {
        case .tomorrow: return "Tomorrow"
        case .weekend: return "Weekend"
        case .custom: return "Custom"
        }
    }
}

private struct EvaRescueSplitComposerState {
    var isOpen = false
    var childTitles: [String] = ["", ""]
    var duePreset: EvaTriageDeferPreset?
    var isCreating = false
    var errorMessage: String?
    var completed = false
    var createdChildIDs: [UUID] = []
}

private struct NeedsReplanTrayView: View {
    let title: String
    let subtitle: String
    let callToAction: String
    let accessibilityHint: String
    let accessibilityIdentifier: String
    let isProminent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.tasker.accentPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.tasker.accentWash.opacity(0.72), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.tasker(.headline).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                    Text(subtitle)
                        .font(.tasker(.support))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(callToAction)
                    .font(.tasker(.support).weight(.semibold))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.tasker.surfacePrimary.opacity(0.82), in: Capsule())
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.tasker.accentWash.opacity(isProminent ? 0.34 : 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.tasker.accentPrimary.opacity(isProminent ? 0.12 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint(accessibilityHint)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct NeedsReplanLauncherSheet: View {
    let summary: NeedsReplanSummary
    let onStart: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(Color.tasker.strokeHairline.opacity(0.7))
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(summary.launcherTitle)
                    .font(.tasker(.title1).weight(.semibold))
                    .foregroundStyle(Color.tasker.textPrimary)
                Text(summary.launcherBodyText)
                    .font(.tasker(.body))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if summary.count > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    launcherRow(summary.count == 1 ? "1 task needs a decision" : "\(summary.count) tasks need a decision", systemImage: "checklist")
                    if summary.datedCount > 0 {
                        let datedLabel = summary.datedCount == 1
                            ? "1 overdue or carry-over task"
                            : "\(summary.datedCount) overdue or carry-over tasks"
                        launcherRow(datedLabel, systemImage: "calendar.badge.exclamationmark")
                    }
                    if summary.unscheduledCount > 0 {
                        let unscheduledLabel = summary.unscheduledCount == 1
                            ? "1 task has no due date or time"
                            : "\(summary.unscheduledCount) tasks have no due date or time"
                        launcherRow(unscheduledLabel, systemImage: "tray")
                    }
                    if summary.dayCount > 1 {
                        launcherRow("Spanning \(summary.dayCount) past days", systemImage: "calendar")
                    }
                    if let newestDate = summary.newestDate {
                        launcherRow("Start with \(newestDate.formatted(.dateTime.weekday(.wide).month().day()))", systemImage: "arrow.forward.circle")
                    }
                }
            }

            Button(summary.launcherPrimaryActionTitle, action: onStart)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("home.needsReplan.start")

            HStack {
                Button("Later", action: onLater)
                    .font(.tasker(.body).weight(.semibold))
                Spacer()
            }
            .foregroundStyle(Color.tasker.textSecondary)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .accessibilityIdentifier("home.needsReplan.launcher")
    }

    private func launcherRow(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.tasker(.support))
            .foregroundStyle(Color.tasker.textSecondary)
            .labelStyle(.titleAndIcon)
    }
}

private struct NeedsReplanCardOverlay: View {
    let state: HomeReplanSessionState
    let onUndo: () -> Void
    let onSkip: () -> Void
    let onMoveToInbox: () -> Void
    let onReschedule: () -> Void
    let onCheckOff: () -> Void
    let onDelete: () -> Void
    let onClearError: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let candidate = state.currentCandidate {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button("Undo", action: onUndo)
                            .disabled(state.canUndo == false || state.isApplying)
                        Spacer()
                        Text("\(max(state.candidateIndex, 1)) of \(max(state.candidateTotal, 1))")
                            .font(.tasker(.support).weight(.semibold))
                            .foregroundStyle(Color.tasker.textSecondary)
                        Button("Skip", action: onSkip)
                            .disabled(state.isApplying)
                    }
                    .font(.tasker(.support).weight(.semibold))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(candidate.task.title)
                            .font(.tasker(.title2).weight(.semibold))
                            .foregroundStyle(Color.tasker.textPrimary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 3)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(originalLine(for: candidate))
                            .font(.tasker(.body))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .lineLimit(2)

                        if let projectName = candidate.projectName, projectName.isEmpty == false {
                            Text("Project: \(projectName)")
                                .font(.tasker(.support))
                                .foregroundStyle(Color.tasker.textSecondary)
                                .lineLimit(2)
                        }

                        if candidate.task.replanCount >= 3 {
                            Text("Replanned \(candidate.task.replanCount)x")
                                .font(.tasker(.support).weight(.semibold))
                                .foregroundStyle(Color.tasker.statusWarning)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.tasker.statusWarning.opacity(0.12), in: Capsule())
                            Text("This keeps slipping. Consider shrinking it.")
                                .font(.tasker(.support))
                                .foregroundStyle(Color.tasker.textSecondary)
                                .lineSpacing(1)
                        }
                    }

                    if state.isApplying {
                        ProgressView(applyingMessage)
                            .font(.tasker(.support).weight(.semibold))
                            .foregroundStyle(Color.tasker.textSecondary)
                    }

                    if let errorMessage = state.errorMessage {
                        errorBanner(errorMessage)
                    }

                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 10) {
                            fullWidthAction("Reschedule", systemImage: "calendar.badge.clock", disabled: state.isApplying, action: onReschedule)
                            fullWidthAction("Move to Inbox", systemImage: "tray.fill", disabled: state.isApplying, action: onMoveToInbox)
                            fullWidthAction("Check Off", systemImage: "checkmark.circle.fill", disabled: state.isApplying, action: onCheckOff)
                            fullWidthAction("Delete", systemImage: "trash.fill", role: .destructive, disabled: state.isApplying, action: onDelete)
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            compactAction("Move to Inbox", systemImage: "tray.fill", disabled: state.isApplying, action: onMoveToInbox)
                            compactAction("Reschedule", systemImage: "calendar.badge.clock", emphasized: true, disabled: state.isApplying, action: onReschedule)
                            compactAction("Check Off", systemImage: "checkmark.circle.fill", disabled: state.isApplying, action: onCheckOff)
                            compactAction("Delete", systemImage: "trash.fill", role: .destructive, disabled: state.isApplying, action: onDelete)
                        }
                    }
                }
                .padding(18)
            }
            .frame(maxHeight: maxCardHeight)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.tasker.strokeHairline.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 12)
            .accessibilityIdentifier("home.needsReplan.card")
        }
    }

    private var maxCardHeight: CGFloat {
        min(UIScreen.main.bounds.height * (dynamicTypeSize.isAccessibilitySize ? 0.72 : 0.58), dynamicTypeSize.isAccessibilitySize ? 620 : 470)
    }

    private var applyingMessage: String {
        switch state.applyingAction {
        case .moveToInbox:
            return "Moving to Inbox..."
        case .reschedule:
            return "Scheduling..."
        case .checkOff:
            return "Marking complete..."
        case .delete:
            return "Deleting..."
        case .undo:
            return "Undoing..."
        case nil:
            return "Updating..."
        }
    }

    private func originalLine(for candidate: HomeReplanCandidate) -> String {
        switch candidate.kind {
        case .pastDue:
            guard let anchorDate = candidate.anchorDate else { return "Due date needs a plan" }
            if candidate.task.isAllDay || isDateOnly(anchorDate) {
                return "Due \(anchorDate.formatted(.dateTime.weekday(.wide).month().day()))"
            }
            return "Due \(anchorDate.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))"
        case .scheduledCarryOver:
            guard let anchorDate = candidate.anchorDate else { return "Scheduled on a past day" }
            if candidate.task.isAllDay || isDateOnly(anchorDate) {
                return "Scheduled \(anchorDate.formatted(.dateTime.weekday(.wide).month().day()))"
            }
            return "Scheduled \(anchorDate.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))"
        case .unscheduledBacklog:
            return "No due date or time • Added \(candidate.task.createdAt.formatted(.dateTime.weekday(.wide).month().day()))"
        }
    }

    private func isDateOnly(_ date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) == 0 && (components.minute ?? 0) == 0 && (components.second ?? 0) == 0
    }

    private func fullWidthAction(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.borderedProminent)
        .disabled(disabled)
    }

    private func compactAction(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        emphasized: Bool = false,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            if emphasized {
                Button(role: role, action: action) {
                    Label(title, systemImage: systemImage)
                        .font(.tasker(.caption1).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(role: role, action: action) {
                    Label(title, systemImage: systemImage)
                        .font(.tasker(.caption1).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.bordered)
            }
        }
        .disabled(disabled)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.tasker.statusWarning)
                .accessibilityHidden(true)
            Text(message)
                .font(.tasker(.support))
                .foregroundStyle(Color.tasker.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Dismiss", action: onClearError)
                .font(.tasker(.support).weight(.semibold))
        }
        .padding(12)
        .background(Color.tasker.surfaceSecondary.opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct NeedsReplanSummaryOverlay: View {
    let state: HomeReplanSessionState
    let onReviewSkipped: () -> Void
    let onViewToday: () -> Void
    let onDone: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(state.skippedCount > 0 ? "You skipped \(state.skippedCount) tasks" : "All caught up")
                    .font(.tasker(.title1).weight(.semibold))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(state.skippedCount > 0 ? "You can review them now or leave them for later." : "You've resolved your unfinished tasks.")
                    .font(.tasker(.body))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .lineSpacing(2)

                VStack(alignment: .leading, spacing: 6) {
                    metric("rescheduled", state.outcomes.rescheduled)
                    metric("moved to Inbox", state.outcomes.movedToInbox)
                    metric("completed", state.outcomes.completed)
                    metric("deleted", state.outcomes.deleted)
                }

                if state.skippedCount > 0 {
                    Button("Review skipped", action: onReviewSkipped)
                        .buttonStyle(.borderedProminent)
                    Button("Finish", action: onDone)
                        .font(.tasker(.body).weight(.semibold))
                } else {
                    Button("View Today", action: onViewToday)
                        .buttonStyle(.borderedProminent)
                    Button("Done", action: onDone)
                        .font(.tasker(.body).weight(.semibold))
                }
            }
            .padding(20)
        }
        .frame(maxHeight: min(UIScreen.main.bounds.height * 0.52, 420))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.tasker.strokeHairline.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 12)
        .accessibilityIdentifier("home.needsReplan.summary")
    }

    private func metric(_ label: String, _ count: Int) -> some View {
        Text("\(count) \(label)")
            .font(.tasker(.support).weight(.semibold))
            .foregroundStyle(Color.tasker.textSecondary)
    }
}

private struct EvaOverdueRescueSheetV2: View {
    let plan: EvaRescuePlan?
    let tasksByID: [UUID: TaskDefinition]
    let lastBatchRunID: UUID?
    let onApply: ([EvaBatchMutationInstruction], @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onUndo: (@escaping (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onCreateSplit: (UUID, EvaSplitDraft, @escaping (Result<[TaskDefinition], Error>) -> Void) -> Void
    let onUndoSplit: ([UUID], @escaping (Result<Void, Error>) -> Void) -> Void
    let onTrack: (String, [String: Any]) -> Void

    @State private var selectedActionByTaskID: [UUID: EvaRescueActionType] = [:]
    @State private var moveChoiceByTaskID: [UUID: EvaRescueMoveChoice] = [:]
    @State private var customMoveDateByTaskID: [UUID: Date] = [:]
    @State private var splitStateByTaskID: [UUID: EvaRescueSplitComposerState] = [:]
    @State private var showDropConfirm = false
    @State private var pendingMutations: [EvaBatchMutationInstruction] = []
    @State private var isApplying = false
    @State private var isUndoing = false
    @State private var errorMessage: String?
    @State private var snackbar: SnackbarData?
    @State private var emptyStateAppeared = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    private var allRecommendations: [EvaRescueRecommendation] {
        guard let plan else { return [] }
        return plan.doToday + plan.move + plan.split + plan.dropCandidate
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let plan {
                    // 7B: Debt level header
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        HStack {
                            Text("Debt: \(plan.debtLevel.rawValue.capitalized)")
                                .font(.tasker(.title3))
                                .foregroundColor(debtLevelColor(plan.debtLevel))
                            Spacer()
                            Text("\(allRecommendations.count)")
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.textSecondary)
                                .contentTransition(.numericText())
                                .padding(.horizontal, spacing.s8)
                                .padding(.vertical, spacing.s4)
                                .background(Color.tasker.surfaceSecondary)
                                .clipShape(Capsule())
                            Text("overdue")
                                .font(.tasker(.caption2))
                                .foregroundColor(Color.tasker.textTertiary)
                        }

                        // 7B: Debt progress bar
                        TaskerProgressBar(
                            progress: min(plan.debtScore / 100.0, 1.0),
                            colors: [debtLevelColor(plan.debtLevel), debtLevelColor(plan.debtLevel)],
                            trackColor: Color.tasker.surfaceSecondary,
                            height: 6
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.tasker(.caption2))
                                .foregroundColor(Color.tasker.statusDanger)
                        }
                    }
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s12)
                    .enhancedStaggeredAppearance(index: 0)

                    Divider()

                    ScrollView {
                        VStack(alignment: .leading, spacing: spacing.s16) {
                            rescueGroup(title: "Do today", icon: "flame.fill", iconColor: Color.tasker.statusWarning, items: plan.doToday, startIndex: 0)
                            rescueGroup(title: "Move", icon: "calendar.badge.clock", iconColor: Color.tasker.accentPrimary, items: plan.move, startIndex: plan.doToday.count)
                            rescueGroup(title: "Split", icon: "scissors", iconColor: Color.tasker.priorityHigh, items: plan.split, startIndex: plan.doToday.count + plan.move.count)
                            rescueGroup(title: "Drop?", icon: "trash", iconColor: Color.tasker.statusDanger, items: plan.dropCandidate, startIndex: plan.doToday.count + plan.move.count + plan.split.count)
                        }
                        .padding(.horizontal, spacing.s16)
                        .padding(.top, spacing.s12)
                        .padding(.bottom, spacing.s24)
                    }

                    Divider()
                    stickyRescueActionBar(plan: plan)
                } else {
                    // 7I: Empty state
                    VStack(spacing: spacing.s16) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color.tasker.statusSuccess)
                            .breathingPulse(min: 0.7, max: 1.0, duration: 2.0)
                            .scaleEffect(emptyStateAppeared ? 1.0 : 0.3)
                            .animation(TaskerAnimation.expressive, value: emptyStateAppeared)
                        Text("All caught up!")
                            .font(.tasker(.title3))
                            .foregroundColor(Color.tasker.textPrimary)
                            .opacity(emptyStateAppeared ? 1.0 : 0)
                            .animation(TaskerAnimation.expressive.delay(0.1), value: emptyStateAppeared)
                        Text("No overdue tasks to rescue.")
                            .font(.tasker(.body))
                            .foregroundColor(Color.tasker.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(spacing.s16)
                    .onAppear { emptyStateAppeared = true }
                }
            }
            .background(Color.tasker.bgCanvas)
            .navigationTitle("Rescue")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                initializeDefaults()
            }
            .alert("Apply drop actions?", isPresented: $showDropConfirm) {
                Button("Apply", role: .destructive) {
                    runApply(mutations: pendingMutations)
                    pendingMutations = []
                }
                Button("Cancel", role: .cancel) {
                    pendingMutations = []
                }
            } message: {
                Text("Tasks marked Drop? will be moved to Inbox and their due dates cleared.")
            }
        }
        .taskerSnackbar($snackbar)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func debtLevelColor(_ level: EvaDebtLevel) -> Color {
        switch level {
        case .none: return Color.tasker.statusSuccess
        case .low: return Color.tasker.accentPrimary
        case .medium: return Color.tasker.statusWarning
        case .high: return Color.tasker.statusDanger
        }
    }

    private func stickyRescueActionBar(plan: EvaRescuePlan) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            if buildMutations(plan: plan).isEmpty {
                Text("Select at least one Today, Move, or Drop action to apply.")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
            }

            HStack(spacing: spacing.s8) {
                // 7H: Apply plan - primary filled
                Button {
                    let mutations = buildMutations(plan: plan)
                    if hasDropSelection(plan: plan) {
                        pendingMutations = mutations
                        showDropConfirm = true
                    } else {
                        runApply(mutations: mutations)
                    }
                } label: {
                    Text("Apply plan")
                        .font(.tasker(.button))
                        .foregroundColor(Color.tasker.accentOnPrimary)
                        .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                        .background(
                            (isApplying || buildMutations(plan: plan).isEmpty)
                                ? Color.tasker.accentMuted
                                : Color.tasker.accentPrimary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: corner.r2))
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .disabled(isApplying || buildMutations(plan: plan).isEmpty)

                // 7H: Undo - outline
                if lastBatchRunID != nil {
                    Button {
                        isUndoing = true
                        onTrack("rescue_undo_tap", [:])
                        onUndo { result in
                            DispatchQueue.main.async {
                                isUndoing = false
                                switch result {
                                case .success:
                                    snackbar = SnackbarData(message: "Rescue plan undone")
                                    TaskerFeedback.success()
                                case .failure(let error):
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    } label: {
                        Text("Undo")
                            .font(.tasker(.buttonSmall))
                            .foregroundColor(Color.tasker.textSecondary)
                            .frame(minWidth: 64, minHeight: spacing.buttonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: corner.r2)
                                    .stroke(Color.tasker.strokeHairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                    .disabled(isApplying || isUndoing)
                }
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s12)
        .padding(.bottom, spacing.s12)
        .background(Color.tasker.surfacePrimary)
    }

    @ViewBuilder
    private func rescueGroup(title: String, icon: String, iconColor: Color, items: [EvaRescueRecommendation], startIndex: Int) -> some View {
        if items.isEmpty == false {
            // 7C: Group header with icon and count badge
            HStack(spacing: spacing.s8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textPrimary)
                Text("\(items.count)")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
                    .padding(.horizontal, spacing.s8)
                    .padding(.vertical, spacing.s2)
                    .background(Color.tasker.surfaceSecondary)
                    .clipShape(Capsule())
                Spacer()
            }

            ForEach(Array(items.enumerated()), id: \.element.taskID) { index, item in
                let selectedAction = selectedActionByTaskID[item.taskID] ?? item.action
                let splitState = splitStateByTaskID[item.taskID] ?? EvaRescueSplitComposerState()
                let task = tasksByID[item.taskID]

                // 7D: Rescue item card
                HStack(spacing: 0) {
                    // Priority stripe
                    RoundedRectangle(cornerRadius: 2)
                        .fill(rescuePriorityColor(for: task?.priority))
                        .frame(width: 4)
                        .padding(.vertical, spacing.s8)

                    VStack(alignment: .leading, spacing: spacing.s8) {
                        HStack(spacing: spacing.s8) {
                            Text(task?.title ?? "Task")
                                .font(.tasker(.body))
                                .foregroundColor(Color.tasker.textPrimary)
                                .lineLimit(2)

                            Spacer()

                            // 7D: Confidence badge
                            Text(confidenceText(for: item.confidence))
                                .font(.tasker(.caption2))
                                .foregroundColor(rescueConfidenceBadgeTextColor(item.confidence))
                                .padding(.horizontal, spacing.s8)
                                .padding(.vertical, spacing.s4)
                                .background(rescueConfidenceBadgeColor(item.confidence))
                                .clipShape(Capsule())
                        }

                        // 7D: Overdue age badge + reason pills
                        HStack(spacing: spacing.s4) {
                            if let dueDate = task?.dueDate, dueDate < Date() {
                                let daysOverdue = max(0, Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0)
                                Text("\(daysOverdue)d overdue")
                                    .font(.tasker(.caption2))
                                    .foregroundColor(Color.tasker.statusDanger)
                                    .padding(.horizontal, spacing.s8)
                                    .padding(.vertical, spacing.s2)
                                    .background(Color.tasker.statusDanger.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        // 7D: Reason pills
                        if !item.reasons.isEmpty {
                            HStack(spacing: spacing.s4) {
                                ForEach(item.reasons, id: \.self) { reason in
                                    Text(reason)
                                        .font(.tasker(.caption2))
                                        .foregroundColor(Color.tasker.textTertiary)
                                        .padding(.horizontal, spacing.s8)
                                        .padding(.vertical, spacing.s2)
                                        .background(Color.tasker.surfaceSecondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        // 7E: Action chip row
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: spacing.s8) {
                                rescueActionChip(item: item, action: .doToday, selectedAction: selectedAction)
                                rescueActionChip(item: item, action: .move, selectedAction: selectedAction)
                                rescueActionChip(item: item, action: .split, selectedAction: selectedAction)
                                rescueActionChip(item: item, action: .dropCandidate, selectedAction: selectedAction)
                            }
                        }

                        // 7F: Move choice row
                        if selectedAction == .move {
                            moveChoiceRow(for: item)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if selectedAction == .split {
                            splitComposer(for: item, state: splitState)
                        }

                        if splitState.completed {
                            HStack(spacing: spacing.s4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.tasker.statusSuccess)
                                Text("Split done")
                                    .font(.tasker(.caption2))
                                    .foregroundColor(Color.tasker.accentPrimary)
                            }
                        }
                    }
                    .padding(spacing.s12)
                }
                .taskerDenseSurface(
                    cornerRadius: corner.r2,
                    fillColor: Color.tasker.surfacePrimary,
                    strokeColor: Color.tasker.strokeHairline
                )
                .enhancedStaggeredAppearance(index: startIndex + index + 1)
            }
        }
    }

    private func rescuePriorityColor(for priority: TaskPriority?) -> Color {
        guard let priority else { return Color.tasker.priorityNone }
        switch priority {
        case .max: return Color.tasker.priorityMax
        case .high: return Color.tasker.priorityHigh
        case .low: return Color.tasker.priorityLow
        case .none: return Color.tasker.priorityNone
        }
    }

    private func rescueConfidenceBadgeColor(_ value: Double) -> Color {
        switch value {
        case 0.75...: return Color.tasker.statusSuccess.opacity(0.15)
        case 0.45..<0.75: return Color.tasker.statusWarning.opacity(0.15)
        default: return Color.tasker.textTertiary.opacity(0.12)
        }
    }

    private func rescueConfidenceBadgeTextColor(_ value: Double) -> Color {
        switch value {
        case 0.75...: return Color.tasker.statusSuccess
        case 0.45..<0.75: return Color.tasker.statusWarning
        default: return Color.tasker.textTertiary
        }
    }

    private func moveChoiceRow(for item: EvaRescueRecommendation) -> some View {
        let selectedChoice = moveChoiceByTaskID[item.taskID] ?? .tomorrow
        return VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(spacing: spacing.s8) {
                ForEach(EvaRescueMoveChoice.allCases, id: \.self) { choice in
                    Button {
                        withAnimation(TaskerAnimation.quick) {
                            moveChoiceByTaskID[item.taskID] = choice
                        }
                        onTrack("rescue_action_changed", [
                            "task_id": item.taskID.uuidString,
                            "action": "move_\(choice.rawValue)"
                        ])
                        TaskerFeedback.selection()
                    } label: {
                        Text(choice.title)
                            .font(.tasker(.caption2))
                            .foregroundColor(selectedChoice == choice ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
                            .padding(.horizontal, spacing.s12)
                            .frame(minHeight: 36)
                            .background(selectedChoice == choice ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                }
            }

            if selectedChoice == .custom {
                let selectedDate = customMoveDateByTaskID[item.taskID] ?? Calendar.current.startOfDay(for: Date())
                DatePicker(
                    "Move date",
                    selection: Binding(
                        get: { selectedDate },
                        set: { customMoveDateByTaskID[item.taskID] = Calendar.current.startOfDay(for: $0) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .frame(minHeight: 44)
                .padding(spacing.s8)
                .background(Color.tasker.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: corner.r2))
                .tint(Color.tasker.accentPrimary)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // 7G: Split composer
    private func splitComposer(for item: EvaRescueRecommendation, state: EvaRescueSplitComposerState) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            if !state.isOpen {
                Button {
                    var next = state
                    next.isOpen = true
                    splitStateByTaskID[item.taskID] = next
                    onTrack("rescue_split_open", [
                        "task_id": item.taskID.uuidString
                    ])
                    TaskerFeedback.selection()
                } label: {
                    Text("Open split helper")
                        .font(.tasker(.buttonSmall))
                        .foregroundColor(Color.tasker.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: corner.r2)
                                .stroke(Color.tasker.strokeHairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .scaleOnPress()
            } else {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    ForEach(Array(state.childTitles.enumerated()), id: \.offset) { index, title in
                        TextField(
                            "Subtask \(index + 1)",
                            text: Binding(
                                get: { splitStateByTaskID[item.taskID]?.childTitles[safe: index] ?? title },
                                set: { newValue in
                                    var next = splitStateByTaskID[item.taskID] ?? state
                                    guard next.childTitles.indices.contains(index) else { return }
                                    next.childTitles[index] = newValue
                                    splitStateByTaskID[item.taskID] = next
                                }
                            )
                        )
                        .textInputAutocapitalization(.sentences)
                        .font(.tasker(.caption1))
                        .padding(.horizontal, spacing.s12)
                        .frame(minHeight: 40)
                        .background(Color.tasker.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: corner.r1))
                    }

                    if state.childTitles.count < 3 {
                        Button {
                            withAnimation(TaskerAnimation.bouncy) {
                                var next = splitStateByTaskID[item.taskID] ?? state
                                next.childTitles.append("")
                                splitStateByTaskID[item.taskID] = next
                            }
                        } label: {
                            HStack(spacing: spacing.s4) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Color.tasker.accentPrimary)
                                Text("Add child")
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.accentPrimary)
                            }
                            .frame(minHeight: 36)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: spacing.s8) {
                        splitDueChip(item: item, title: "No due", preset: nil, state: state)
                        splitDueChip(item: item, title: "Tomorrow", preset: .tomorrow, state: state)
                        splitDueChip(item: item, title: "Weekend", preset: .weekendSaturday, state: state)
                    }

                    if let splitError = state.errorMessage {
                        Text(splitError)
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker.statusDanger)
                    }

                    Button {
                        runSplitCreation(for: item, state: state)
                    } label: {
                        Text("Create subtasks")
                            .font(.tasker(.button))
                            .foregroundColor(Color.tasker.accentOnPrimary)
                            .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                            .background(
                                (state.isCreating || validSplitTitles(state).count < 2)
                                    ? Color.tasker.accentMuted
                                    : Color.tasker.accentPrimary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: corner.r2))
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                    .disabled(state.isCreating || validSplitTitles(state).count < 2)
                }
                .padding(spacing.s12)
                .background(Color.tasker.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: corner.r2))
            }
        }
    }

    private func splitDueChip(
        item: EvaRescueRecommendation,
        title: String,
        preset: EvaTriageDeferPreset?,
        state: EvaRescueSplitComposerState
    ) -> some View {
        let isSelected = state.duePreset == preset
        return Button {
            withAnimation(TaskerAnimation.quick) {
                var next = splitStateByTaskID[item.taskID] ?? state
                next.duePreset = preset
                splitStateByTaskID[item.taskID] = next
            }
            TaskerFeedback.selection()
        } label: {
            Text(title)
                .font(.tasker(.caption2))
                .foregroundColor(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
                .padding(.horizontal, spacing.s12)
                .frame(minHeight: 36)
                .background(isSelected ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    // 7E: Action chip with icon
    private func rescueActionChip(
        item: EvaRescueRecommendation,
        action: EvaRescueActionType,
        selectedAction: EvaRescueActionType
    ) -> some View {
        let isSelected = selectedAction == action
        return Button {
            withAnimation(TaskerAnimation.quick) {
                selectedActionByTaskID[item.taskID] = action
            }
            onTrack("rescue_action_changed", [
                "task_id": item.taskID.uuidString,
                "action": action.rawValue
            ])
            TaskerFeedback.selection()
        } label: {
            HStack(spacing: spacing.s4) {
                Image(systemName: rescueActionIcon(for: action))
                    .font(.system(size: 11))
                Text(actionTitle(for: action))
                    .font(.tasker(.caption2))
            }
            .foregroundColor(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
            .padding(.horizontal, spacing.s12)
            .frame(minHeight: 36)
            .background(
                isSelected
                    ? Color.tasker.accentPrimary
                    : Color.tasker.surfaceSecondary
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.tasker.strokeHairline, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .activeGlow(isActive: isSelected, color: Color.tasker.accentPrimary)
        .accessibilityLabel(actionTitle(for: action))
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func rescueActionIcon(for action: EvaRescueActionType) -> String {
        switch action {
        case .doToday: return "flame.fill"
        case .move: return "calendar"
        case .split: return "scissors"
        case .dropCandidate: return "trash"
        }
    }

    private func runSplitCreation(for item: EvaRescueRecommendation, state: EvaRescueSplitComposerState) {
        var next = state
        next.isCreating = true
        next.errorMessage = nil
        splitStateByTaskID[item.taskID] = next

        let draft = EvaSplitDraft(
            parentTaskID: item.taskID,
            children: validSplitTitles(state).map { EvaSplitDraftChild(title: $0) },
            childDuePreset: state.duePreset,
            createStatus: .creating,
            createdChildIDs: []
        )

        onCreateSplit(item.taskID, draft) { result in
            DispatchQueue.main.async {
                var updated = splitStateByTaskID[item.taskID] ?? state
                updated.isCreating = false
                switch result {
                case .success(let createdChildren):
                    let createdIDs = createdChildren.map(\.id)
                    updated.completed = true
                    updated.createdChildIDs = createdIDs
                    updated.errorMessage = nil
                    splitStateByTaskID[item.taskID] = updated
                    snackbar = SnackbarData(
                        message: "Split created (\(createdIDs.count))",
                        actions: [
                            SnackbarAction(title: "Undo") {
                                onUndoSplit(createdIDs) { undoResult in
                                    DispatchQueue.main.async {
                                        switch undoResult {
                                        case .success:
                                            var reset = splitStateByTaskID[item.taskID] ?? updated
                                            reset.completed = false
                                            reset.createdChildIDs = []
                                            splitStateByTaskID[item.taskID] = reset
                                        case .failure(let error):
                                            errorMessage = error.localizedDescription
                                        }
                                    }
                                }
                            }
                        ]
                    )
                    TaskerFeedback.success()
                case .failure(let error):
                    updated.errorMessage = error.localizedDescription
                    splitStateByTaskID[item.taskID] = updated
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func validSplitTitles(_ state: EvaRescueSplitComposerState) -> [String] {
        state.childTitles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func runApply(mutations: [EvaBatchMutationInstruction]) {
        guard mutations.isEmpty == false else {
            errorMessage = "No rescue changes selected."
            return
        }
        isApplying = true
        errorMessage = nil
        onTrack("rescue_apply_tap", ["mutation_count": mutations.count])
        onApply(mutations) { result in
            DispatchQueue.main.async {
                isApplying = false
                switch result {
                case .success:
                    snackbar = SnackbarData(
                        message: "Rescue plan applied",
                        actions: [
                            SnackbarAction(title: "Undo") {
                                onUndo { undoResult in
                                    DispatchQueue.main.async {
                                        switch undoResult {
                                        case .success:
                                            snackbar = SnackbarData(message: "Rescue plan undone")
                                        case .failure(let error):
                                            errorMessage = error.localizedDescription
                                        }
                                    }
                                }
                            }
                        ]
                    )
                    TaskerFeedback.success()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func initializeDefaults() {
        guard let plan else { return }
        var defaults: [UUID: EvaRescueActionType] = [:]
        for item in plan.doToday { defaults[item.taskID] = .doToday }
        for item in plan.move { defaults[item.taskID] = .move }
        for item in plan.split { defaults[item.taskID] = .split }
        for item in plan.dropCandidate { defaults[item.taskID] = .dropCandidate }
        selectedActionByTaskID = defaults

        for item in plan.move {
            moveChoiceByTaskID[item.taskID] = .tomorrow
            if let toDate = item.toDate {
                customMoveDateByTaskID[item.taskID] = toDate
            }
        }
    }

    private func actionTitle(for action: EvaRescueActionType) -> String {
        switch action {
        case .doToday: return "Today"
        case .move: return "Move"
        case .split: return "Split"
        case .dropCandidate: return "Drop"
        }
    }

    private func confidenceText(for confidence: Double) -> String {
        switch confidence {
        case 0.75...:
            return "High"
        case 0.45..<0.75:
            return "Medium"
        default:
            return "Low"
        }
    }

    private func buildMutations(plan: EvaRescuePlan) -> [EvaBatchMutationInstruction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let recommendations = plan.doToday + plan.move + plan.split + plan.dropCandidate

        return recommendations.compactMap { item in
            let selected = selectedActionByTaskID[item.taskID] ?? item.action
            switch selected {
            case .doToday:
                return EvaBatchMutationInstruction(taskID: item.taskID, dueDate: today)
            case .move:
                let choice = moveChoiceByTaskID[item.taskID] ?? .tomorrow
                let dueDate: Date?
                switch choice {
                case .tomorrow:
                    dueDate = calendar.date(byAdding: .day, value: 1, to: today)
                case .weekend:
                    dueDate = EvaTriageDeferPreset.weekendSaturday.resolveDueDate()
                case .custom:
                    dueDate = customMoveDateByTaskID[item.taskID] ?? item.toDate ?? calendar.date(byAdding: .day, value: 1, to: today)
                }
                return EvaBatchMutationInstruction(taskID: item.taskID, dueDate: dueDate)
            case .dropCandidate:
                return EvaBatchMutationInstruction(
                    taskID: item.taskID,
                    projectID: ProjectConstants.inboxProjectID,
                    clearDueDate: true
                )
            case .split:
                return nil
            }
        }
    }

    private func hasDropSelection(plan: EvaRescuePlan) -> Bool {
        let recommendations = plan.doToday + plan.move + plan.split + plan.dropCandidate
        return recommendations.contains { item in
            (selectedActionByTaskID[item.taskID] ?? item.action) == .dropCandidate
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

struct HomeForedropLayoutMetrics {
    var calendarExpandedHeight: CGFloat = 0
    var timelineHeaderHeight: CGFloat = 0
    var weeklyBackdropHeight: CGFloat = 0
    var geometryHeight: CGFloat = 0

    /// Executes offset.
    func offset(for anchor: ForedropAnchor) -> CGFloat {
        let measuredCalendarHeight = max(calendarExpandedHeight, 72)
        let measuredHeaderHeight = max(timelineHeaderHeight, 56)
        let measuredWeekHeight = max(weeklyBackdropHeight, measuredHeaderHeight + 44)
        let midRevealBase = measuredCalendarHeight + min(measuredWeekHeight * 0.52, measuredHeaderHeight + 56)
        let minimumMidReveal = max(104, measuredCalendarHeight + 20)
        let midReveal = min(
            max(midRevealBase, minimumMidReveal),
            geometryHeight * 0.24
        )
        let fullRevealBase = measuredCalendarHeight + measuredWeekHeight + max(24, measuredHeaderHeight * 0.28)
        let fullReveal = min(
            max(fullRevealBase, midReveal + 72),
            geometryHeight * 0.56
        )

        switch anchor {
        case .collapsed:
            return 0
        case .midReveal:
            return midReveal
        case .fullReveal:
            return fullReveal
        }
    }
}

struct HomeDaySwipeResolver {
    let minimumTranslation: CGFloat
    let minimumPredictedTranslation: CGFloat
    let horizontalDominanceRatio: CGFloat
    let liquidActivationMinimumTranslation: CGFloat
    let liquidActivationHorizontalDominanceRatio: CGFloat

    static let `default` = HomeDaySwipeResolver(
        minimumTranslation: 56,
        minimumPredictedTranslation: 92,
        horizontalDominanceRatio: 1.35,
        liquidActivationMinimumTranslation: 8,
        liquidActivationHorizontalDominanceRatio: 1.0
    )

    func resolvedDirection(
        translation: CGSize,
        predictedEndTranslation: CGSize
    ) -> HomeDayNavigationDirection? {
        let horizontal = translation.width
        let predictedHorizontal = predictedEndTranslation.width
        let vertical = translation.height
        let dominantDistance = max(abs(horizontal), abs(predictedHorizontal))

        guard isHorizontallyDominant(translation: translation) else { return nil }
        guard dominantDistance >= minimumTranslation || abs(predictedHorizontal) >= minimumPredictedTranslation else {
            return nil
        }

        let resolvedHorizontal = abs(predictedHorizontal) >= minimumPredictedTranslation
            ? predictedHorizontal
            : horizontal
        guard abs(resolvedHorizontal) >= max(abs(vertical) * horizontalDominanceRatio, minimumTranslation) else {
            return nil
        }

        return resolvedHorizontal < 0 ? .next : .previous
    }

    func isHorizontallyDominant(translation: CGSize) -> Bool {
        abs(translation.width) > max(abs(translation.height) * horizontalDominanceRatio, 28)
    }

    func liquidActivationSide(
        startLocation: CGPoint,
        translation: CGSize,
        containerSize: CGSize
    ) -> HomeDayLiquidSwipeSide? {
        guard isLiquidActivationCandidate(translation: translation) else { return nil }
        guard let side = HomeDayLiquidSwipeData.side(
            forStartLocation: startLocation,
            containerSize: containerSize
        ) else {
            return nil
        }
        guard side.horizontalSign * translation.width > 0 else { return nil }
        return side
    }

    func liquidActivationSide(
        startLocation: CGPoint,
        translation: CGSize,
        velocity: CGPoint,
        containerSize: CGSize
    ) -> HomeDayLiquidSwipeSide? {
        guard let side = HomeDayLiquidSwipeData.side(
            forStartLocation: startLocation,
            containerSize: containerSize
        ) else {
            return nil
        }

        let intent = liquidIntentTranslation(translation: translation, velocity: velocity)
        guard isLiquidActivationCandidate(translation: intent) else { return nil }
        guard side.horizontalSign * intent.width > 0 else { return nil }
        return side
    }

    func isLiquidActivationCandidate(translation: CGSize) -> Bool {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        guard horizontalDistance >= liquidActivationMinimumTranslation else { return false }
        return horizontalDistance > verticalDistance * liquidActivationHorizontalDominanceRatio
    }

    func predictedEndTranslation(translation: CGSize, velocity: CGPoint) -> CGSize {
        let projectionDuration: CGFloat = 0.18
        return CGSize(
            width: translation.width + velocity.x * projectionDuration,
            height: translation.height + velocity.y * projectionDuration
        )
    }

    private func liquidIntentTranslation(translation: CGSize, velocity: CGPoint) -> CGSize {
        let horizontal = abs(translation.width) >= liquidActivationMinimumTranslation
            ? translation.width
            : velocity.x
        let vertical = abs(translation.height) >= liquidActivationMinimumTranslation
            ? translation.height
            : velocity.y
        return CGSize(width: horizontal, height: vertical)
    }
}

struct HomeForedropHintEligibility {
    static let triggerCooldown: TimeInterval = 0.7

    /// Executes canTrigger.
    static func canTrigger(
        isHomeVisible: Bool,
        foredropAnchor: ForedropAnchor,
        reduceMotionEnabled: Bool,
        isUITesting: Bool,
        hasRunningAnimation: Bool,
        lastTriggerDate: Date?,
        now: Date = Date(),
        cooldown: TimeInterval = triggerCooldown
    ) -> Bool {
        guard isHomeVisible else { return false }
        guard foredropAnchor == .collapsed else { return false }
        guard !reduceMotionEnabled else { return false }
        guard !isUITesting else { return false }
        guard !hasRunningAnimation else { return false }
        guard let lastTriggerDate else { return true }

        return now.timeIntervalSince(lastTriggerDate) >= cooldown
    }
}

private extension TimeInterval {
    var nanoseconds: UInt64 {
        UInt64((self * 1_000_000_000).rounded())
    }
}

extension ForedropAnchor {
    var accessibilityValue: String {
        switch self {
        case .collapsed:
            return "collapsed"
        case .midReveal:
            return "midReveal"
        case .fullReveal:
            return "fullReveal"
        }
    }
}

enum HomeForedropFace: Equatable {
    case tasks
    case schedule
    case analytics
    case search
    case chat

    var isBackFace: Bool {
        self != .tasks
    }

    var selectedBottomBarItem: HomeBottomBarItem {
        switch self {
        case .tasks:
            return .home
        case .schedule:
            return .calendar
        case .analytics:
            return .charts
        case .search:
            return .search
        case .chat:
            return .chat
        }
    }

    var surfaceAccessibilityValue: String {
        switch self {
        case .tasks:
            return "collapsed"
        case .schedule, .analytics, .search, .chat:
            return "fullReveal"
        }
    }
}

enum HomeSearchStatusFilter: String, CaseIterable, Equatable, Identifiable {
    case all
    case today
    case overdue
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .today:
            return "Today"
        case .overdue:
            return "Overdue"
        case .completed:
            return "Completed"
        }
    }

    var analyticsName: String { rawValue }

    var accessibilityIdentifier: String {
        "search.status.\(rawValue)"
    }
}

private extension HomeSearchStatusFilter {
    var legacyValue: LGSearchViewModel.StatusFilterType {
        switch self {
        case .all:
            return .all
        case .today:
            return .today
        case .overdue:
            return .overdue
        case .completed:
            return .completed
        }
    }
}

struct HomeSearchSection: Identifiable, Equatable {
    let projectName: String
    let tasks: [TaskDefinition]

    var id: String { projectName }
}

struct HomeSearchRequestSignature: Equatable {
    let dataRevision: UInt64
    let query: String
    let status: HomeSearchStatusFilter
    let priorities: [Int32]
    let projects: [String]
}

enum HomeSearchFocusPolicyResolver {
    static func shouldAutoFocusOnSearchEntry(layoutClass: TaskerLayoutClass) -> Bool {
        guard V2FeatureFlags.iPadPerfSearchFocusStabilizationV3Enabled else {
            return false
        }
        return false
    }
}

@MainActor
protocol HomeSearchEngine: AnyObject {
    var onResultsUpdated: ((Int, [TaskDefinition]) -> Void)? { get set }
    var projects: [Project] { get }

    func search(query: String, revision: Int)
    func loadProjects(completion: (() -> Void)?)
    func setFilters(status: HomeSearchStatusFilter, projects: [String], priorities: [Int32])
    func clearFilters()
    func toggleProjectFilter(_ project: String)
    func togglePriorityFilter(_ priority: Int32)
    func setStatusFilter(_ filter: HomeSearchStatusFilter)
    func invalidateSearchCache(revision: Int)
    func releaseResources()
    func groupTasksByProject(_ tasks: [TaskDefinition]) -> [(project: String, tasks: [TaskDefinition])]
}

@MainActor
final class LGHomeSearchEngine: HomeSearchEngine {
    private let viewModel: LGSearchViewModel

    init(viewModel: LGSearchViewModel) {
        self.viewModel = viewModel
    }

    var onResultsUpdated: ((Int, [TaskDefinition]) -> Void)? {
        get { viewModel.onResultsUpdatedWithRevision }
        set { viewModel.onResultsUpdatedWithRevision = newValue }
    }

    var projects: [Project] {
        viewModel.projects
    }

    func search(query: String, revision: Int) {
        viewModel.search(query: query, revision: revision)
    }

    func loadProjects(completion: (() -> Void)?) {
        viewModel.loadProjects(completion: completion)
    }

    func setFilters(status: HomeSearchStatusFilter, projects: [String], priorities: [Int32]) {
        viewModel.replaceFilters(
            status: status.legacyValue,
            projects: projects,
            priorities: priorities
        )
    }

    func clearFilters() {
        viewModel.clearFilters()
    }

    func toggleProjectFilter(_ project: String) {
        viewModel.toggleProjectFilter(project)
    }

    func togglePriorityFilter(_ priority: Int32) {
        viewModel.togglePriorityFilter(priority)
    }

    func setStatusFilter(_ filter: HomeSearchStatusFilter) {
        viewModel.setStatusFilter(filter.legacyValue)
    }

    func invalidateSearchCache(revision: Int) {
        viewModel.invalidateSearchCache(revision: revision)
    }

    func releaseResources() {
        viewModel.purgeCaches()
        viewModel.onResultsUpdatedWithRevision = nil
    }

    func groupTasksByProject(_ tasks: [TaskDefinition]) -> [(project: String, tasks: [TaskDefinition])] {
        viewModel.groupTasksByProject(tasks)
    }
}

@MainActor
final class SearchRefreshCoordinator {
    private let debounceNanoseconds: UInt64
    private var debounceTask: Task<Void, Never>?
    private var generation: UInt64 = 0

    init(debounceDelay: TimeInterval = 0.18) {
        debounceNanoseconds = UInt64(max(0, debounceDelay) * 1_000_000_000)
    }

    @discardableResult
    func request(
        immediate: Bool,
        perform: @escaping @MainActor (UInt64) -> Void
    ) -> UInt64 {
        generation &+= 1
        let requestGeneration = generation
        debounceTask?.cancel()

        if immediate || debounceNanoseconds == 0 {
            perform(requestGeneration)
            return requestGeneration
        }

        let wait = debounceNanoseconds
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: wait)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                perform(requestGeneration)
            }
        }
        return requestGeneration
    }

    func cancel() {
        debounceTask?.cancel()
        debounceTask = nil
    }
}

@MainActor
final class HomeSearchState: ObservableObject {
    @Published var query: String = ""
    @Published var selectedStatus: HomeSearchStatusFilter = .all
    @Published var selectedPriorities: Set<Int32> = []
    @Published var selectedProjects: Set<String> = []
    @Published private(set) var sections: [HomeSearchSection] = []
    @Published private(set) var availableProjects: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false

    private var engine: HomeSearchEngine?
    private let refreshCoordinator: SearchRefreshCoordinator
    private var sharedDataRevisionProvider: (() -> HomeDataRevision)?
    private var latestIssuedSearchRevision: Int = 0
    private var needsRefreshOnNextActivation = false
    private var lastExecutedSignature: HomeSearchRequestSignature?

    init(debounceDelay: TimeInterval = 0.18) {
        refreshCoordinator = SearchRefreshCoordinator(debounceDelay: debounceDelay)
    }

    var hasActiveFilters: Bool {
        selectedStatus != .all || !selectedPriorities.isEmpty || !selectedProjects.isEmpty
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var shouldShowNoResultsMessage: Bool {
        hasLoaded && !isLoading && sections.isEmpty
    }

    var emptyStateTitle: String {
        if trimmedQuery.isEmpty && !hasActiveFilters {
            return "Start searching"
        }
        return "No tasks found"
    }

    var emptyStateSubtitle: String {
        if trimmedQuery.isEmpty && !hasActiveFilters {
            return "Type to search your tasks or use quick chips."
        }
        return "Try a different query or adjust quick chips."
    }

    func configureIfNeeded(
        makeEngine: () -> HomeSearchEngine,
        dataRevisionProvider: @escaping () -> HomeDataRevision
    ) {
        guard engine == nil else { return }
        sharedDataRevisionProvider = dataRevisionProvider
        let resolvedEngine = makeEngine()
        engine = resolvedEngine
        resolvedEngine.invalidateSearchCache(revision: currentSearchCacheRevision)
        resolvedEngine.onResultsUpdated = { [weak self] revision, tasks in
            guard let self else { return }
            Task { @MainActor in
                self.handleResults(tasks, revision: revision)
            }
        }
        resolvedEngine.loadProjects { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.refreshAvailableProjects()
            }
        }
    }

    func activate() {
        guard engine != nil else { return }
        let nextSignature = requestSignature
        if needsRefreshOnNextActivation == false,
           lastExecutedSignature == nextSignature {
            return
        }
        refresh(immediate: true)
    }

    func deactivate() {
        refreshCoordinator.cancel()
        isLoading = false
    }

    func releaseResources() {
        refreshCoordinator.cancel()
        engine?.releaseResources()
        engine = nil
        sharedDataRevisionProvider = nil
        latestIssuedSearchRevision = 0
        needsRefreshOnNextActivation = false
        lastExecutedSignature = nil
        isLoading = false
        hasLoaded = false
        sections = []
        availableProjects = []
    }

    func updateQuery(_ newValue: String) {
        guard query != newValue else { return }
        query = newValue
        refresh(immediate: false)
    }

    func clearQuery() {
        guard !query.isEmpty else { return }
        query = ""
        refresh(immediate: true)
    }

    func setStatus(_ status: HomeSearchStatusFilter) {
        guard selectedStatus != status else { return }
        selectedStatus = status
        refresh(immediate: true)
    }

    func togglePriority(_ priority: TaskPriorityConfig.Priority) {
        let raw = priority.rawValue
        if selectedPriorities.contains(raw) {
            selectedPriorities.remove(raw)
        } else {
            selectedPriorities.insert(raw)
        }
        refresh(immediate: true)
    }

    func toggleProject(_ project: String) {
        if selectedProjects.contains(project) {
            selectedProjects.remove(project)
        } else {
            selectedProjects.insert(project)
        }
        refresh(immediate: true)
    }

    func markDataMutated() {
        needsRefreshOnNextActivation = true
        engine?.invalidateSearchCache(revision: currentSearchCacheRevision)
    }

    func refresh(immediate: Bool) {
        guard engine != nil else { return }
        let nextSignature = requestSignature
        if hasLoaded,
           needsRefreshOnNextActivation == false,
           lastExecutedSignature == nextSignature {
            isLoading = false
            return
        }
        guard V2FeatureFlags.iPadPerfSearchCoalescingV2Enabled else {
            let nextRevision = max(1, latestIssuedSearchRevision &+ 1)
            performSearch(refreshGeneration: UInt64(nextRevision))
            return
        }
        logDebug(
            event: "searchRefresh",
            message: "Home search refresh requested",
            fields: [
                "immediate": immediate ? "true" : "false",
                "data_revision": String(currentDataRevision.rawValue),
                "query_length": String(trimmedQuery.count)
            ]
        )
        _ = refreshCoordinator.request(immediate: immediate) { [weak self] refreshGeneration in
            self?.performSearch(refreshGeneration: refreshGeneration)
        }
    }

    private func performSearch(refreshGeneration: UInt64) {
        guard let engine else { return }
        let cappedRevision = Int(refreshGeneration % UInt64(Int.max))
        latestIssuedSearchRevision = cappedRevision
        isLoading = true
        let signature = requestSignature
        let projects = signature.projects
        let priorities = signature.priorities
        engine.setFilters(
            status: selectedStatus,
            projects: projects,
            priorities: priorities
        )
        lastExecutedSignature = signature
        needsRefreshOnNextActivation = false
        logDebug(
            event: "searchPerform",
            message: "Home search execution started",
            fields: [
                "search_revision": String(cappedRevision),
                "data_revision": String(currentDataRevision.rawValue),
                "status": selectedStatus.analyticsName,
                "query_length": String(trimmedQuery.count),
                "project_filter_count": String(projects.count),
                "priority_filter_count": String(priorities.count)
            ]
        )
        engine.search(query: trimmedQuery, revision: cappedRevision)
    }

    private func handleResults(_ tasks: [TaskDefinition], revision: Int) {
        guard let engine else { return }
        guard revision >= latestIssuedSearchRevision else { return }
        let nextSections = engine
            .groupTasksByProject(tasks)
            .map { HomeSearchSection(projectName: $0.project, tasks: $0.tasks) }
        if sections != nextSections {
            sections = nextSections
        }
        hasLoaded = true
        isLoading = false
        refreshAvailableProjects()
        TaskerPerformanceTrace.event("HomeSearchResultsApplied")
    }

    private func refreshAvailableProjects() {
        let remoteProjectNames = Set((engine?.projects ?? []).map(\.name))
        let visibleProjectNames = Set(sections.map(\.projectName))
        let allProjects = remoteProjectNames
            .union(visibleProjectNames)
            .union([ProjectConstants.inboxProjectName])
        let nextAvailableProjects = allProjects.sorted()
        let nextSelectedProjects = selectedProjects.intersection(allProjects)
        if availableProjects != nextAvailableProjects {
            availableProjects = nextAvailableProjects
        }
        if selectedProjects != nextSelectedProjects {
            selectedProjects = nextSelectedProjects
        }
    }

    private var requestSignature: HomeSearchRequestSignature {
        HomeSearchRequestSignature(
            dataRevision: currentDataRevision.rawValue,
            query: trimmedQuery,
            status: selectedStatus,
            priorities: selectedPriorities.sorted(),
            projects: selectedProjects.sorted()
        )
    }

    private var currentDataRevision: HomeDataRevision {
        sharedDataRevisionProvider?() ?? .zero
    }

    private var currentSearchCacheRevision: Int {
        Int(truncatingIfNeeded: currentDataRevision.rawValue)
    }
}

private enum HomePerformanceSignposts {
    private static let habitMutationIntervalName: StaticString = "HomeHabitMutationLatency"
    private static let lastCellTapIntervalName: StaticString = "HomeHabitLastCellTap"
    private static let habitsSectionRenderEventName: StaticString = "home.habitsSection.render"

    // Points-of-interest signposts emit automatically while profiling with
    // Instruments. The verbose performance log still honors the explicit
    // Tasker performance flags.

    static func lastCellTapAccepted() {
        TaskerPerformanceTrace.event("home.lastCellTap.accepted")
    }

    static func beginLastCellTap() -> TaskerPerformanceInterval {
        TaskerPerformanceTrace.event("home.lastCellTap.begin")
        return TaskerPerformanceTrace.begin(lastCellTapIntervalName)
    }

    static func endLastCellTap(_ interval: TaskerPerformanceInterval?) {
        guard let interval else { return }
        TaskerPerformanceTrace.end(interval)
        TaskerPerformanceTrace.event("home.lastCellTap.end")
    }

    static func beginHabitMutation() -> TaskerPerformanceInterval {
        TaskerPerformanceTrace.event("home.habitMutation.begin")
        return TaskerPerformanceTrace.begin(habitMutationIntervalName)
    }

    static func endHabitMutation(_ interval: TaskerPerformanceInterval?) {
        guard let interval else { return }
        TaskerPerformanceTrace.end(interval)
        TaskerPerformanceTrace.event("home.habitMutation.end")
    }

    static func openDetailTap() {
        TaskerPerformanceTrace.event("home.openDetail.tap")
    }

    static func habitsSectionRendered(rowCount: Int) {
        TaskerPerformanceTrace.event(habitsSectionRenderEventName, value: rowCount)
    }
}

private struct HomeHabitSectionCardHost: View, Equatable {
    let title: String
    let summaryLine: String
    let rows: [HomeHabitRow]
    let accessibilityIdentifier: String
    let onOpenBoard: () -> Void
    let onPrimaryAction: (HomeHabitRow) -> Void
    let onSecondaryAction: (HomeHabitRow) -> Void
    let onRowAction: (HomeHabitRow) -> Void
    let onLastCellAction: (HomeHabitRow) -> Void
    let onOpenHabit: (HomeHabitRow) -> Void

    static func == (lhs: HomeHabitSectionCardHost, rhs: HomeHabitSectionCardHost) -> Bool {
        lhs.title == rhs.title
            && lhs.summaryLine == rhs.summaryLine
            && lhs.rows == rhs.rows
            && lhs.accessibilityIdentifier == rhs.accessibilityIdentifier
    }

    var body: some View {
        let _ = HomePerformanceSignposts.habitsSectionRendered(rowCount: rows.count)
        return HabitHomeSectionCard(
            title: title,
            summaryLine: summaryLine,
            rows: rows,
            onOpenBoard: onOpenBoard,
            onPrimaryAction: onPrimaryAction,
            onSecondaryAction: onSecondaryAction,
            onRowAction: onRowAction,
            onLastCellAction: onLastCellAction,
            onOpenHabit: onOpenHabit
        )
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

enum HomePrimaryWidgetKind: String, Equatable, CaseIterable, Identifiable {
    case focusNow
    case weeklyOperating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focusNow:
            return "Focus Now"
        case .weeklyOperating:
            return "This week"
        }
    }

    var indicatorTitle: String {
        switch self {
        case .focusNow:
            return "Focus"
        case .weeklyOperating:
            return "Weekly"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .focusNow:
            return "home.primaryWidget.page.focusNow"
        case .weeklyOperating:
            return "home.primaryWidget.page.weeklyOperating"
        }
    }

    var indicatorAccessibilityIdentifier: String {
        switch self {
        case .focusNow:
            return "home.primaryWidget.indicator.focusNow"
        case .weeklyOperating:
            return "home.primaryWidget.indicator.weeklyOperating"
        }
    }
}

struct HomePrimaryWidgetRailState: Equatable {
    let widgets: [HomePrimaryWidgetKind]

    static func build(
        tasksSnapshot: HomeTasksSnapshot,
        chromeSnapshot: HomeChromeSnapshot
    ) -> HomePrimaryWidgetRailState {
        var widgets: [HomePrimaryWidgetKind] = []

        if !tasksSnapshot.focusNowSectionState.rows.isEmpty {
            widgets.append(.focusNow)
        }

        if tasksSnapshot.activeQuickView == .today,
           chromeSnapshot.weeklySummary != nil {
            widgets.append(.weeklyOperating)
        }

        return HomePrimaryWidgetRailState(widgets: widgets)
    }

    var isVisible: Bool { !widgets.isEmpty }
    var isSingleWidget: Bool { widgets.count <= 1 }
}

enum HomePrimaryWidgetDefaultPolicy {
    static func resolve(
        availableWidgets: [HomePrimaryWidgetKind],
        currentSelection: HomePrimaryWidgetKind?,
        userHasInteracted: Bool
    ) -> HomePrimaryWidgetKind? {
        guard !availableWidgets.isEmpty else { return nil }

        if userHasInteracted,
           let currentSelection,
           availableWidgets.contains(currentSelection) {
            return currentSelection
        }

        if availableWidgets.contains(.focusNow) {
            return .focusNow
        }

        if availableWidgets.contains(.weeklyOperating) {
            return .weeklyOperating
        }

        return availableWidgets.first
    }
}

private struct HomePrimaryWidgetPage: Identifiable {
    let kind: HomePrimaryWidgetKind
    let content: AnyView

    var id: HomePrimaryWidgetKind { kind }
}

private struct HomePrimaryWidgetHostedPage: Identifiable {
    let kind: HomePrimaryWidgetKind
    let content: AnyView

    var id: HomePrimaryWidgetKind { kind }
}

private struct HomePrimaryWidgetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [HomePrimaryWidgetKind: CGFloat] = [:]

    static func reduce(value: inout [HomePrimaryWidgetKind: CGFloat], nextValue: () -> [HomePrimaryWidgetKind: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct HomePrimaryWidgetRail: View {
    let pages: [HomePrimaryWidgetPage]
    let selectedKind: HomePrimaryWidgetKind?
    let onSelectionChange: (HomePrimaryWidgetKind, Bool) -> Void

    @State private var measuredHeights: [HomePrimaryWidgetKind: CGFloat] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.tokens(for: layoutClass).corner }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            GeometryReader { proxy in
                let viewportWidth = max(proxy.size.width, 1)
                let pageWidth = resolvedPageWidth(for: viewportWidth)

                HomePrimaryWidgetPagerRepresentable(
                    pages: hostedPages,
                    selectedKind: selectedKind,
                    pageWidth: pageWidth,
                    pageHeight: resolvedContentHeight,
                    isScrollEnabled: pages.count > 1,
                    onSelectionChange: { kind in
                        onSelectionChange(kind, true)
                    }
                )
                .frame(height: resolvedContentHeight)
                .background(alignment: .topLeading) {
                    measurementLayer(pageWidth: pageWidth, selectedKind: selectedKind)
                }
            }
            .frame(height: resolvedContentHeight)

            indicatorRow
                .accessibilityIdentifier("home.primaryWidget.indicator")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.primaryWidgetRail")
        .onPreferenceChange(HomePrimaryWidgetHeightPreferenceKey.self) { heights in
            guard heights.isEmpty == false else { return }
            var updated = measuredHeights
            updated.merge(heights, uniquingKeysWith: { _, next in next })
            let validKinds = Set(pages.map(\.kind))
            updated = updated.filter { validKinds.contains($0.key) }
            guard updated != measuredHeights else { return }
            measuredHeights = updated
        }
    }

    private var hostedPages: [HomePrimaryWidgetHostedPage] {
        pages.enumerated().map { index, page in
            HomePrimaryWidgetHostedPage(
                kind: page.kind,
                content: AnyView(
                    pageShell(
                        for: page,
                        isActive: page.kind == selectedKind,
                        position: index + 1,
                        total: pages.count
                    )
                )
            )
        }
    }

    private var resolvedContentHeight: CGFloat {
        let measured = measuredHeights.values.max() ?? 0
        return max(measured, fallbackContentHeight)
    }

    private var fallbackContentHeight: CGFloat {
        if pages.contains(where: { $0.kind == .weeklyOperating }) {
            return 244
        }
        return 184
    }

    private func resolvedPageWidth(for viewportWidth: CGFloat) -> CGFloat {
        guard pages.count > 1 else { return viewportWidth }
        let peekInset = layoutClass.isPad ? spacing.s20 : spacing.s16
        return max(viewportWidth - (peekInset * 2), viewportWidth * 0.88)
    }

    private func pageShell(
        for page: HomePrimaryWidgetPage,
        isActive: Bool,
        position: Int,
        total: Int,
        includesAccessibility: Bool = true
    ) -> some View {
        page.content
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: corner.r3, style: .continuous)
                    .fill(Color.tasker.surfacePrimary.opacity(isActive ? 0.18 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner.r3, style: .continuous)
                    .stroke(
                        isActive
                            ? Color.tasker.accentPrimary.opacity(0.22)
                            : Color.tasker.strokeHairline.opacity(0.48),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isActive ? Color.tasker.accentPrimary.opacity(0.10) : .clear,
                radius: isActive ? 12 : 0,
                y: isActive ? 8 : 0
            )
            .scaleEffect(reduceMotion ? 1.0 : (isActive ? 1.0 : 0.988))
            .animation(reduceMotion ? nil : TaskerAnimation.stateChange, value: isActive)
            .modifier(
                HomePrimaryWidgetPageAccessibilityModifier(
                    page: page,
                    position: position,
                    total: total,
                    isEnabled: includesAccessibility
                )
            )
    }

    @ViewBuilder
    private func measurementLayer(pageWidth: CGFloat, selectedKind: HomePrimaryWidgetKind?) -> some View {
        if let measurementPage = page(for: selectedKind) ?? pages.first {
            pageShell(
                for: measurementPage,
                isActive: true,
                position: 1,
                total: max(pages.count, 1),
                includesAccessibility: false
            )
            .frame(width: pageWidth)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: HomePrimaryWidgetHeightPreferenceKey.self,
                        value: [measurementPage.kind: proxy.size.height]
                    )
                }
            )
            .fixedSize(horizontal: false, vertical: true)
            .opacity(0.001)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func page(for selectedKind: HomePrimaryWidgetKind?) -> HomePrimaryWidgetPage? {
        guard let selectedKind else { return nil }
        return pages.first(where: { $0.kind == selectedKind })
    }

    private var indicatorRow: some View {
        HStack(spacing: spacing.s8) {
            ForEach(Array(pages.indices), id: \.self) { pageIndex in
                indicatorButton(for: pages[pageIndex])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func indicatorButton(for page: HomePrimaryWidgetPage) -> some View {
        let isSelected = page.kind == selectedKind

        return Button {
            onSelectionChange(page.kind, true)
        } label: {
            Text(page.kind.indicatorTitle)
                .font(.tasker(.caption1).weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.tasker.textPrimary : Color.tasker.textSecondary)
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s8)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                                ? Color.tasker.accentPrimary.opacity(0.14)
                                : Color.tasker.surfaceSecondary.opacity(0.8)
                        )
                )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityIdentifier(page.kind.indicatorAccessibilityIdentifier)
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }
}

private struct HomePrimaryWidgetPageAccessibilityModifier: ViewModifier {
    let page: HomePrimaryWidgetPage
    let position: Int
    let total: Int
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(page.kind.accessibilityIdentifier)
                .accessibilityLabel("\(page.kind.title), \(position) of \(total)")
                .accessibilityHint(total > 1 ? "Swipe horizontally to switch widgets" : "")
        } else {
            content
                .accessibilityHidden(true)
        }
    }
}

private struct HomePrimaryWidgetPagerRepresentable: UIViewControllerRepresentable {
    let pages: [HomePrimaryWidgetHostedPage]
    let selectedKind: HomePrimaryWidgetKind?
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let isScrollEnabled: Bool
    let onSelectionChange: (HomePrimaryWidgetKind) -> Void

    func makeUIViewController(context: Context) -> HomePrimaryWidgetPagerController {
        HomePrimaryWidgetPagerController(
            pages: pages,
            selectedKind: selectedKind,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            isScrollEnabled: isScrollEnabled,
            onSelectionChange: onSelectionChange
        )
    }

    func updateUIViewController(_ uiViewController: HomePrimaryWidgetPagerController, context: Context) {
        uiViewController.apply(
            pages: pages,
            selectedKind: selectedKind,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            isScrollEnabled: isScrollEnabled,
            animated: context.transaction.animation != nil
        )
    }
}

private final class HomePrimaryWidgetPagerController: UICollectionViewController {
    private enum Constants {
        static let cellReuseIdentifier = "HomePrimaryWidgetPagerCell"
    }

    private var pages: [HomePrimaryWidgetHostedPage]
    private var selectedKind: HomePrimaryWidgetKind?
    private var pageWidth: CGFloat
    private var pageHeight: CGFloat
    private var isScrollEnabledForRail: Bool
    private let onSelectionChange: (HomePrimaryWidgetKind) -> Void

    private var didApplyInitialSelection = false
    private var isProgrammaticScroll = false

    init(
        pages: [HomePrimaryWidgetHostedPage],
        selectedKind: HomePrimaryWidgetKind?,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        isScrollEnabled: Bool,
        onSelectionChange: @escaping (HomePrimaryWidgetKind) -> Void
    ) {
        self.pages = pages
        self.selectedKind = selectedKind
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.isScrollEnabledForRail = isScrollEnabled
        self.onSelectionChange = onSelectionChange
        super.init(collectionViewLayout: Self.makeLayout(
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            isScrollEnabled: isScrollEnabled
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceVertical = false
        collectionView.decelerationRate = .fast
        collectionView.isDirectionalLockEnabled = true
        collectionView.clipsToBounds = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Constants.cellReuseIdentifier)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !didApplyInitialSelection else { return }
        didApplyInitialSelection = true
        scrollToSelectedKind(animated: false)
    }

    func apply(
        pages: [HomePrimaryWidgetHostedPage],
        selectedKind: HomePrimaryWidgetKind?,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        isScrollEnabled: Bool,
        animated: Bool
    ) {
        let didChangeLayout = abs(self.pageWidth - pageWidth) > 0.5
            || abs(self.pageHeight - pageHeight) > 0.5
            || self.isScrollEnabledForRail != isScrollEnabled

        self.pages = pages
        self.selectedKind = selectedKind
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.isScrollEnabledForRail = isScrollEnabled

        collectionView.isScrollEnabled = isScrollEnabled

        if didChangeLayout {
            collectionView.setCollectionViewLayout(
                Self.makeLayout(
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    isScrollEnabled: isScrollEnabled
                ),
                animated: false
            )
        }

        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        scrollToSelectedKind(animated: animated && view.window != nil)
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        pages.count
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: Constants.cellReuseIdentifier,
            for: indexPath
        )
        let page = pages[indexPath.item]
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.contentConfiguration = UIHostingConfiguration {
            page.content
        }
        .margins(.all, .zero)
        return cell
    }

    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        handleUserScrollCompletion()
    }

    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else { return }
        handleUserScrollCompletion()
    }

    override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isProgrammaticScroll = false
    }

    private func scrollToSelectedKind(animated: Bool) {
        guard let selectedKind,
              let itemIndex = pages.firstIndex(where: { $0.kind == selectedKind }) else { return }

        let indexPath = IndexPath(item: itemIndex, section: 0)
        guard collectionView.numberOfItems(inSection: 0) > itemIndex else { return }

        if centeredIndexPath() == indexPath {
            return
        }

        isProgrammaticScroll = animated
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
        if !animated {
            isProgrammaticScroll = false
        }
    }

    private func centeredIndexPath() -> IndexPath? {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        guard !visibleIndexPaths.isEmpty else { return nil }

        let centerPoint = CGPoint(
            x: collectionView.contentOffset.x + collectionView.bounds.midX,
            y: collectionView.bounds.midY
        )

        return visibleIndexPaths.min { lhs, rhs in
            let lhsCenter = collectionView.layoutAttributesForItem(at: lhs)?.center.x ?? .zero
            let rhsCenter = collectionView.layoutAttributesForItem(at: rhs)?.center.x ?? .zero
            return abs(lhsCenter - centerPoint.x) < abs(rhsCenter - centerPoint.x)
        }
    }

    private func handleUserScrollCompletion() {
        guard !isProgrammaticScroll,
              let centeredIndexPath = centeredIndexPath(),
              centeredIndexPath.item < pages.count else { return }

        let kind = pages[centeredIndexPath.item].kind
        guard kind != selectedKind else { return }

        selectedKind = kind
        onSelectionChange(kind)
    }

    private static func makeLayout(
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        isScrollEnabled: Bool
    ) -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupWidth: NSCollectionLayoutDimension = isScrollEnabled
            ? .absolute(pageWidth)
            : .fractionalWidth(1.0)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: groupWidth,
            heightDimension: .absolute(pageHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = isScrollEnabled ? .groupPagingCentered : .none
        section.contentInsets = .zero

        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(section: section, configuration: configuration)
    }
}

private struct HomeCalendarEventDetailSelection: Identifiable, Equatable {
    let eventID: String
    let selectedDate: Date
    let allowsTimelineHide: Bool

    var id: String {
        "\(eventID):\(HomeTimelineHiddenCalendarEventKey.dayStamp(for: selectedDate)):\(allowsTimelineHide)"
    }
}

struct HomeBackdropForedropRootView: View {
    let viewModel: HomeViewModel
    @ObservedObject var chromeStore: HomeChromeStore
    @ObservedObject var tasksStore: HomeTasksStore
    @ObservedObject var habitsStore: HomeHabitsStore
    @ObservedObject var calendarStore: HomeCalendarStore
    let calendarIntegrationService: CalendarIntegrationService?
    let chatAppManager: AppManager
    @ObservedObject var overlayStore: HomeOverlayStore
    @ObservedObject var faceCoordinator: HomeFaceCoordinator
    @ObservedObject var searchState: HomeSearchState
    let chartCardViewModel: ChartCardViewModel
    let radarChartCardViewModel: RadarChartCardViewModel
    let layoutClass: TaskerLayoutClass
    let forcedFace: Binding<HomeForedropFace>?
    @ObservedObject private var themeManager = TaskerThemeManager.shared
    @AppStorage(V2FeatureFlags.homeBackdropNoiseAmountUserKey)
    private var homeBackdropNoiseAmountStorage = V2FeatureFlags.defaultHomeBackdropNoiseAmount
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onTaskTap: (TaskDefinition) -> Void
    let onToggleComplete: (TaskDefinition) -> Void
    let onTimelineAnchorTap: (TimelineAnchorItem) -> Void
    let onDeleteTask: (TaskDefinition) -> Void
    let onRescheduleTask: (TaskDefinition) -> Void
    let onReorderCustomProjects: ([UUID]) -> Void
    let onAddTask: (Date?) -> Void
    let onOpenChat: () -> Void
    let onOpenProjectCreator: () -> Void
    let onOpenSettings: () -> Void
    let onOpenWeeklyPlanner: () -> Void
    let onOpenWeeklyReview: () -> Void
    let onRetryWeeklySummary: () -> Void
    let onOpenAnalytics: (String, Bool) -> Void
    let onCloseAnalytics: (String) -> Void
    let onOpenSearch: (String) -> Void
    let onCloseSearch: (String) -> Void
    let onReturnToTasks: (String) -> Void
    let onTaskListScrollChromeStateChange: (HomeScrollChromeState) -> Void
    let onStartFocus: (TaskDefinition) -> Void
    let onRequestCalendarPermission: () -> Void
    let onOpenCalendarChooser: () -> Void
    let onOpenCalendarSchedule: () -> Void
    let onRetryCalendarContext: () -> Void
    let onPerformChatDayTaskAction: EvaDayTaskActionHandler
    let onPerformChatDayHabitAction: EvaDayHabitActionHandler
    let onChatPromptFocusChange: (Bool) -> Void

    @State private var showAdvancedFilters = false
    @State private var showDatePicker = false
    @State private var draftDate = Date()
    @State private var celebrationRouter = DefaultCelebrationRouter()
    @State private var showXPBurst = false
    @State private var xpBurstValue = 0
    @State private var showLevelUp = false
    @State private var levelUpValue = 1
    @State private var showMilestone = false
    @State private var milestoneValue: XPCalculationEngine.Milestone?
    @State private var semanticCelebrationXP = 0
    @State private var showDailyReflectPlan = false
    @State private var dailyReflectPlanViewModel: DailyReflectPlanViewModel?
    @State private var activeNextActionFocusSession: FocusSessionDefinition?
    @State private var showNextActionFocusTimer = false
    @State private var nextActionFocusSummaryResult: FocusSessionResult?
    @State private var showNextActionFocusSummary = false
    @State private var isNextActionFocusRequestInFlight = false
    @State private var isNextActionFocusEnding = false
    @State private var foredropHintOffset: CGFloat = 0
    @State private var hintAnimationTask: _Concurrency.Task<Void, Never>?
    @State private var lastHintTriggerAt: Date?
    @State private var isHomeVisible = false
    @State private var snackbar: SnackbarData?
    @State private var shownUnlockKeys = Set<String>()
    @State private var lastSearchQueryTelemetryAt: Date?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var hasAutoFocusedSearchField = false
    @State private var searchDraftQuery = ""
    @State private var pendingSearchCommitTask: Task<Void, Never>?
    @State private var hasMountedSearchSurface = false
    @State private var hasMountedAnalyticsSurface = false
    @State private var hasMountedScheduleSurface = false
    @State private var chatNavigationChromeState = EvaChatNavigationChromeState.empty
    @State private var expandedAgendaTailItemIDs = Set<String>()
    @State private var selectedHomeCalendarEventDetail: HomeCalendarEventDetailSelection?
    @State private var suppressNextCalendarScheduleOpen = false
    @State private var showHabitBoardPresented = false
    @State private var showHabitLibraryPresented = false
    @State private var selectedHomeHabitRow: HabitLibraryRow?
    @State private var hasPresentedUITestHabitBoard = false
    @State private var isSchedulingUITestHabitBoardPresentation = false
    @State private var passiveTrackingRailViewportWidth: CGFloat = 0
    @State private var pendingFocusPromotionTask: TaskDefinition?
    @State private var focusReplacementOptions: [TaskDefinition] = []
    @State private var activeHabitMutationInterval: TaskerPerformanceInterval?
    @State private var activeLastCellTapInterval: TaskerPerformanceInterval?
    @State private var measuredTimelineHeaderHeight: CGFloat = 0
    @State private var measuredCalendarCardHeight: CGFloat = 0
    @State private var measuredWeekBackdropHeight: CGFloat = 0
    @State private var measuredPassiveTrackingRailHeight: CGFloat = 0
    @State private var measuredNeedsReplanTrayHeight: CGFloat = 0
    @State private var committedDaySwipeDirection: HomeDayNavigationDirection?
    @State private var isDaySwipeTracingActive = false
    @State private var leadingDayLiquidSwipeData = HomeDayLiquidSwipeData(side: .leading)
    @State private var trailingDayLiquidSwipeData = HomeDayLiquidSwipeData(side: .trailing)
    @State private var topDayLiquidSwipeSide: HomeDayLiquidSwipeSide = .trailing
    @State private var activeDayLiquidSwipeSide: HomeDayLiquidSwipeSide?
    @State private var isDayLiquidSwipeChromeVisible = true
    @State private var timelineScrollChromeStateTracker = HomeScrollChromeStateTracker()
    @StateObject private var timelineViewModel = HomeTimelineViewModel()
    private static let dayLiquidSwipeCoordinateSpaceName = "home.dayLiquidSwipe"
    private static let foredropHintLaunchDelay: TimeInterval = 0.10
    private static let foredropHintPeekDistance: CGFloat = 24
    private static let foredropHintPeekDuration: TimeInterval = 0.10
    private static let foredropHintReturnResponse: TimeInterval = 0.22
    private static let foredropHintReturnDampingFraction: CGFloat = 0.86
    private static let foredropHintSettleDuration: TimeInterval = 0.16
    private static let launchArguments = Set(ProcessInfo.processInfo.arguments)
    private static let searchCommitDebounceNanoseconds: UInt64 = 250_000_000
    private static let nextActionFocusDurationSeconds = 15 * 60

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.tokens(for: layoutClass).corner }
    private var forcedFaceValue: HomeForedropFace? { forcedFace?.wrappedValue }
    private var chromeSnapshot: HomeChromeSnapshot { chromeStore.snapshot }
    private var tasksSnapshot: HomeTasksSnapshot { tasksStore.snapshot }
    private var habitsSnapshot: HomeHabitsSnapshot { habitsStore.snapshot }
    private var calendarSnapshot: HomeCalendarSnapshot { calendarStore.snapshot }
    private var overlaySnapshot: HomeOverlaySnapshot { overlayStore.snapshot }
    private var activeFace: HomeForedropFace { faceCoordinator.activeFace }
    private var shellPhase: HomeShellPhase { faceCoordinator.shellPhase }
    private var analyticsSurfaceState: HomeAnalyticsSurfaceState { faceCoordinator.analyticsSurfaceState }
    private var searchSurfaceState: HomeSearchSurfaceState { faceCoordinator.searchSurfaceState }
    private var layoutMetrics: HomeLayoutMetrics { faceCoordinator.layoutMetrics }
    private var isUITesting: Bool {
        Self.launchArguments.contains("-UI_TESTING") || Self.launchArguments.contains("-DISABLE_ANIMATIONS")
    }
    private var shouldPresentHabitBoardForUITests: Bool {
        Self.launchArguments.contains("-TASKER_TEST_PRESENT_HABIT_BOARD")
    }
    private var isForedropHintAnimationEnabled: Bool {
        Self.launchArguments.contains("-ENABLE_FOREDROP_HINT_ANIMATION")
    }
    private var foredropAnchorForHint: ForedropAnchor {
        activeFace == .tasks ? timelineViewModel.foredropAnchor : .fullReveal
    }
    private var isSearchOpen: Bool { activeFace == .search }
    private var isChatOpen: Bool { activeFace == .chat }
    private var isBackFaceVisible: Bool { activeFace.isBackFace }
    private var isScheduleFaceVisible: Bool { activeFace == .schedule }
    private var isTodayTimelineVisible: Bool {
        activeFace == .tasks && tasksSnapshot.activeQuickView == .today
    }
    private var homeBackdropNoiseAmount: Int {
        V2FeatureFlags.clampedHomeBackdropNoiseAmount(homeBackdropNoiseAmountStorage)
    }
    private var isRescueEnabled: Bool { V2FeatureFlags.evaRescueEnabled }
    private var visibleAgendaTailItems: [HomeAgendaTailItem] {
        guard isRescueEnabled else { return [] }
        return tasksSnapshot.agendaTailItems
    }
    private var lifeAreasByID: [UUID: LifeArea] {
        Dictionary(viewModel.lifeAreas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
    private var agendaTailExpansionResetKey: String {
        let selectedDay = Calendar.current.startOfDay(for: chromeSnapshot.selectedDate).timeIntervalSince1970
        let compactTailSignature = visibleAgendaTailItems.compactMap { item -> String? in
            switch item {
            case .rescue(let state):
                guard state.mode == .compact else { return nil }
                let rowIDs = state.rows.map(\.id).joined(separator: ",")
                return "\(item.id):\(rowIDs):\(state.subtitle)"
            }
        }.joined(separator: "|")

        return [String(Int(selectedDay)), compactTailSignature, isRescueEnabled ? "1" : "0"].joined(separator: ":")
    }
    private var habitRenderSignature: String {
        let primary = habitsSnapshot.habitHomeSectionState.primaryRows.map { "\($0.id):\($0.state.rawValue)" }.joined(separator: "|")
        let recovery = habitsSnapshot.habitHomeSectionState.recoveryRows.map { "\($0.id):\($0.state.rawValue)" }.joined(separator: "|")
        let quiet = habitsSnapshot.quietTrackingSummaryState.stableRows.map { "\($0.id):\($0.state.rawValue)" }.joined(separator: "|")
        return "\(primary)#\(recovery)#\(quiet)"
    }
    private var timelineLayoutMetrics: HomeForedropLayoutMetrics {
        HomeForedropLayoutMetrics(
            calendarExpandedHeight: measuredCalendarCardHeight,
            timelineHeaderHeight: measuredTimelineHeaderHeight,
            weeklyBackdropHeight: measuredWeekBackdropHeight,
            geometryHeight: layoutMetrics.height
        )
    }
    private var timelineSnapshot: HomeTimelineSnapshot {
        viewModel.buildTimelineSnapshot(
            calendarSnapshot: calendarSnapshot,
            foredropAnchor: timelineViewModel.foredropAnchor
        )
    }
    private var isDaySwipeGestureEnabled: Bool {
        guard isTodayTimelineVisible || isScheduleFaceVisible else { return false }
        guard showDatePicker == false, showAdvancedFilters == false else { return false }
        guard overlaySnapshot.replanState.isApplying == false else { return false }
        if case .placement = overlaySnapshot.replanState.phase {
            return false
        }
        return true
    }
    private var isDaySwipeInteractionEnabled: Bool {
        isDaySwipeGestureEnabled && isDayLiquidSwipeChromeVisible
    }
    private var daySwipeAnimation: Animation {
        if reduceMotion || isUITesting {
            return .easeOut(duration: 0.12)
        }
        return .snappy(duration: 0.22)
    }
    private var daySwipeTransition: AnyTransition {
        guard reduceMotion == false, isUITesting == false else {
            return .opacity
        }

        switch committedDaySwipeDirection {
        case .previous:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case .next:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case nil:
            return .opacity
        }
    }
    private var passiveTrackingRailFallbackHeight: CGFloat {
        dynamicTypeSize >= .accessibility1 ? 72 : 56
    }
    private var needsReplanTrayFallbackHeight: CGFloat {
        dynamicTypeSize >= .accessibility1 ? 120 : 88
    }
    private var isNeedsReplanTrayVisible: Bool {
        if case .trayVisible = overlaySnapshot.replanState.phase {
            return true
        }
        return false
    }
    private var dayLiquidSwipeRestingCenterY: CGFloat {
        guard isScheduleFaceVisible == false else {
            return HomeDayLiquidSwipeData.timelineHandleCenterY
        }
        return HomeDayLiquidSwipeRestingPosition.centerY(
            defaultCenterY: HomeDayLiquidSwipeData.timelineHandleCenterY,
            showsQuietTrackingRail: habitsSnapshot.quietTrackingSummaryState.isVisible,
            measuredQuietTrackingRailHeight: measuredPassiveTrackingRailHeight,
            quietTrackingRailFallbackHeight: passiveTrackingRailFallbackHeight,
            showsNeedsReplanTray: isNeedsReplanTrayVisible,
            measuredNeedsReplanTrayHeight: measuredNeedsReplanTrayHeight,
            needsReplanTrayFallbackHeight: needsReplanTrayFallbackHeight,
            topPadding: spacing.s8,
            interModuleSpacing: spacing.s12,
            buttonRadius: HomeDayLiquidSwipeData.buttonRadius,
            clearance: spacing.s4
        )
    }
    @ViewBuilder
    private var needsReplanFloatingOverlay: some View {
        switch overlaySnapshot.replanState.phase {
        case .card:
            NeedsReplanCardOverlay(
                state: overlaySnapshot.replanState,
                onUndo: { viewModel.undoLastReplanAction() },
                onSkip: { viewModel.skipCurrentReplanCandidate() },
                onMoveToInbox: { viewModel.moveCurrentReplanCandidateToInbox() },
                onReschedule: { viewModel.beginCurrentReplanPlacement() },
                onCheckOff: { viewModel.checkOffCurrentReplanCandidate() },
                onDelete: { viewModel.deleteCurrentReplanCandidate() },
                onClearError: { viewModel.clearReplanError() }
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, layoutMetrics.safeAreaBottom + spacing.s20)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        case .summary:
            NeedsReplanSummaryOverlay(
                state: overlaySnapshot.replanState,
                onReviewSkipped: { viewModel.reviewSkippedReplanCandidates() },
                onViewToday: {
                    timelineViewModel.syncSelectedDate(Date())
                    viewModel.returnToToday(source: .backToToday)
                    viewModel.dismissNeedsReplanSessionUI()
                },
                onDone: { viewModel.dismissNeedsReplanSessionUI() }
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, layoutMetrics.safeAreaBottom + spacing.s20)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        default:
            EmptyView()
        }
    }
    private var foredropInteractiveOffset: CGFloat {
        guard isTodayTimelineVisible else { return 0 }
        return timelineViewModel.interactiveOffset(metrics: timelineLayoutMetrics)
    }
    private var foredropFlipAnimation: Animation {
        let duration: TimeInterval
        if reduceMotion || isUITesting {
            duration = 0.2
        } else if layoutClass.isPad && V2FeatureFlags.iPadPerfHomeAnimationTrimV3Enabled {
            duration = 0.12
        } else if layoutClass == .phone {
            duration = 0.16
        } else {
            duration = 0.42
        }
        return .easeInOut(duration: duration)
    }

    private var homeBackdropGradient: some View {
        ZStack {
            TaskerNoisyGradientBackdrop(opacity: 0.9)
            TaskerBackdropNoiseOverlay(amount: homeBackdropNoiseAmount)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            LinearGradient(
                colors: [
                    Color.tasker.accentSecondaryMuted.opacity(colorScheme == .dark ? 0.16 : 0.24),
                    Color.tasker.accentWash.opacity(colorScheme == .dark ? 0.11 : 0.18),
                    Color.tasker.bgCanvas.opacity(0.01)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color.tasker.accentSecondaryWash.opacity(colorScheme == .dark ? 0.28 : 0.34))
                .frame(width: 240, height: 240)
                .blur(radius: 28)
                .offset(x: 72, y: -48)
        }
    }

    var body: some View {
        let _ = themeManager.currentTheme.index

        homeScreenBody
    }

    private var homeScreenBody: some View {
        let baseHomeScreen = ZStack {
            ZStack(alignment: .top) {
                Color.tasker.bgCanvas
                    .ignoresSafeArea()

                homeBackdropGradient
                    .frame(height: max(layoutMetrics.backdropGradientHeight, 720))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                LinearGradient(
                    colors: [
                        Color.tasker(.overlayScrim).opacity(0.12),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: max(layoutMetrics.backdropGradientHeight, 720))
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    topNavigationBar()
                        .padding(.top, layoutMetrics.safeAreaTop + spacing.s8)
                        .accessibilityIdentifier("home.topNav.container")

                    ZStack(alignment: .top) {
                        backdropLayer()

                        foredropLayer(taskListBottomInset: layoutMetrics.taskListBottomInset)
                            .offset(y: foredropHintOffset + foredropInteractiveOffset)
                            .animation(foredropFlipAnimation, value: activeFace)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }

            if showXPBurst && shellPhase == .interactive {
                xpBurstOverlay
            }

            if showLevelUp && shellPhase == .interactive {
                LevelUpCelebrationView(
                    level: levelUpValue,
                    awardedXP: semanticCelebrationXP,
                    isPresented: $showLevelUp
                )
            }

            if showMilestone, let milestone = milestoneValue, shellPhase == .interactive {
                MilestoneCelebrationView(
                    milestone: milestone,
                    awardedXP: semanticCelebrationXP,
                    isPresented: $showMilestone
                )
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accessibilityIdentifier("home.view")
        .taskerSnackbar($snackbar)
        .overlay(alignment: .bottom) {
            needsReplanFloatingOverlay
        }
        .onPreferenceChange(TimelineHeaderHeightPreferenceKey.self) { measuredTimelineHeaderHeight = $0 }
        .onPreferenceChange(TimelineCalendarCardHeightPreferenceKey.self) { measuredCalendarCardHeight = $0 }
        .onPreferenceChange(TimelineBackdropWeekHeightPreferenceKey.self) { measuredWeekBackdropHeight = $0 }
        .onChange(of: dayLiquidSwipeRestingCenterY) { _, newValue in
            resetIdleDayLiquidSwipeHandles(restingCenterY: newValue)
        }
        .onChange(of: isTodayTimelineVisible) { _, isVisible in
            guard isVisible else { return }
            resetDayLiquidSwipeChromeVisibility()
        }
        .onChange(of: isScheduleFaceVisible) { _, isVisible in
            guard isVisible else { return }
            resetDayLiquidSwipeChromeVisibility()
            resetIdleDayLiquidSwipeHandles(restingCenterY: dayLiquidSwipeRestingCenterY)
        }
        .onChange(of: habitRenderSignature) { _, _ in
            HomePerformanceSignposts.endHabitMutation(activeHabitMutationInterval)
            activeHabitMutationInterval = nil
            HomePerformanceSignposts.endLastCellTap(activeLastCellTapInterval)
            activeLastCellTapInterval = nil
        }
        .confirmationDialog(
            "Replace a Focus Now item",
            isPresented: Binding(
                get: { pendingFocusPromotionTask != nil && focusReplacementOptions.isEmpty == false },
                set: { isPresented in
                    if !isPresented {
                        clearPendingFocusReplacement()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            ForEach(focusReplacementOptions, id: \.id) { focusTask in
                Button("Replace \(focusTask.title)") {
                    if let promotedTask = pendingFocusPromotionTask {
                        replaceFocusTask(promotedTask, replacing: focusTask, source: "today_agenda_replace")
                    }
                }
            }

            Button("Cancel", role: .cancel) {
                clearPendingFocusReplacement()
            }
        } message: {
            Text("Focus Now already has 3 items. Choose which one to swap out.")
        }
        .fullScreenCover(isPresented: $showNextActionFocusTimer, onDismiss: {
            if isNextActionFocusEnding == false {
                activeNextActionFocusSession = nil
            }
        }) {
            if let session = activeNextActionFocusSession {
                FocusTimerView(
                    taskTitle: resolveTaskForFocusSession(taskID: session.taskID)?.title,
                    taskPriority: resolveTaskForFocusSession(taskID: session.taskID)?.priority.displayName,
                    targetDurationSeconds: session.targetDurationSeconds,
                    onComplete: { _ in
                        finishNextActionFocusSession(sessionID: session.id, source: "next_action_module_15min_focus")
                    },
                    onCancel: {
                        finishNextActionFocusSession(sessionID: session.id, source: "next_action_module_15min_focus_cancel")
                    }
                )
            } else {
                Color.clear
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showNextActionFocusSummary, onDismiss: {
            nextActionFocusSummaryResult = nil
        }) {
            if let result = nextActionFocusSummaryResult {
                FocusSessionSummaryView(
                    durationSeconds: result.session.durationSeconds,
                    xpAwarded: result.xpResult?.awardedXP ?? result.session.xpAwarded,
                    dailyXPSoFar: result.xpResult?.dailyXPSoFar ?? viewModel.dailyScore,
                    dailyXPCap: GamificationTokens.dailyXPCap,
                    onDismiss: {
                        dismissNextActionFocusSummary()
                    },
                    onContinueMomentum: {
                        viewModel.setQuickView(.today)
                        dismissNextActionFocusSummary()
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                VStack(spacing: spacing.s16) {
                    DatePicker(
                        "Select date",
                        selection: $draftDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding(.horizontal, spacing.s16)

                    HStack(spacing: spacing.s12) {
                        Button("Today") {
                            draftDate = Date()
                            viewModel.returnToToday(source: .datePicker)
                            showDatePicker = false
                        }
                        .buttonStyle(.bordered)

                        Button("Apply") {
                            viewModel.selectDate(draftDate, source: .datePicker)
                            showDatePicker = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .navigationTitle("Date")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showDatePicker = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdvancedFilters) {
            HomeAdvancedFilterSheetView(
                initialFilter: viewModel.activeFilterState.advancedFilter,
                initialShowCompletedInline: viewModel.activeFilterState.showCompletedInline,
                savedViews: chromeSnapshot.savedHomeViews,
                activeSavedViewID: viewModel.activeFilterState.selectedSavedViewID,
                onApply: { filter, showCompletedInline in
                    viewModel.applyAdvancedFilter(filter, showCompletedInline: showCompletedInline)
                },
                onClear: {
                    viewModel.applyAdvancedFilter(nil, showCompletedInline: false)
                    viewModel.clearProjectFilters()
                    viewModel.setQuickView(.today)
                },
                onSaveNamedView: { filter, showCompletedInline, name in
                    viewModel.applyAdvancedFilter(filter, showCompletedInline: showCompletedInline)
                    viewModel.saveCurrentFilterAsView(name: name)
                },
                onApplySavedView: { id in
                    viewModel.applySavedView(id: id)
                },
                onDeleteSavedView: { id in
                    viewModel.deleteSavedView(id: id)
                }
            )
        }
        .sheet(item: $selectedHomeCalendarEventDetail) { selection in
            EventKitEventDetailView(
                eventID: selection.eventID,
                onDismiss: {
                    selectedHomeCalendarEventDetail = nil
                },
                onHideFromTimeline: selection.allowsTimelineHide ? {
                    viewModel.hideCalendarEventFromTimeline(
                        eventID: selection.eventID,
                        on: selection.selectedDate
                    )
                    selectedHomeCalendarEventDetail = nil
                    snackbar = SnackbarData(message: "Hidden from Home timeline for this day.", autoDismissSeconds: 2)
                } : nil
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.tasker(.bgElevated))
        }
        .onAppear {
            if let forcedFaceValue {
                setActiveFace(forcedFaceValue, animated: false)
            }
            isHomeVisible = true
            timelineViewModel.syncSelectedDate(viewModel.selectedDate)
            hasAutoFocusedSearchField = false
            searchDraftQuery = searchState.query
            hasMountedSearchSurface = activeFace == .search
            hasMountedAnalyticsSurface = activeFace == .analytics
            hasMountedScheduleSurface = activeFace == .schedule
            triggerForedropHintIfEligible()
            presentHabitBoardIfRequestedForUITests()
        }
        .onChange(of: habitRenderSignature) { _, _ in
            presentHabitBoardIfRequestedForUITests()
        }
        .onDisappear {
            HomePerformanceSignposts.endHabitMutation(activeHabitMutationInterval)
            activeHabitMutationInterval = nil
            HomePerformanceSignposts.endLastCellTap(activeLastCellTapInterval)
            activeLastCellTapInterval = nil
            isHomeVisible = false
            cancelForedropHintAnimation()
            cancelPendingSearchCommit()
            searchState.deactivate()
            isSearchFieldFocused = false
        }
        .overlay(alignment: .topTrailing) {
            if shouldPresentHabitBoardForUITests {
                Button {
                    showHabitBoardPresented = true
                } label: {
                    Text("Board")
                        .font(.tasker(.caption2).weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, layoutMetrics.safeAreaTop + spacing.s12)
                .padding(.trailing, spacing.s8)
                .contentShape(Rectangle())
                .accessibilityIdentifier("home.habits.openBoard")
                .accessibilityLabel("Open Habit Board")
                .opacity(0.16)
            }
        }

        let routedHomeScreen = AnyView(applyHabitPresentationRouting(to: baseHomeScreen))
        let observedHomeScreen = applyHomeStateObservers(to: routedHomeScreen)

        return observedHomeScreen
        .sheet(isPresented: Binding(
            get: { overlaySnapshot.focusWhyPresented },
            set: { viewModel.setEvaFocusWhyPresented($0) }
        )) {
            EvaFocusWhySheetView(
                focusTasks: tasksSnapshot.focusTasks,
                shuffleCandidates: viewModel.focusWhyShuffleCandidates,
                insightProvider: { taskID in
                    viewModel.evaFocusInsight(for: taskID)
                },
                onToggleComplete: { task in
                    trackTaskToggle(task, source: "focus_why_sheet")
                    onToggleComplete(task)
                },
                onStartFocus: { task in
                    onStartFocus(task)
                },
                onShuffleCandidates: {
                    refreshFocusWhyShuffleCandidates()
                },
                onReplaceFocusTask: { candidate, replacing in
                    replaceFocusTaskFromWhySheet(candidate, replacing: replacing)
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { overlaySnapshot.triagePresented },
            set: { viewModel.setEvaTriagePresented($0) }
        )) {
            EvaTriageSprintSheetV2(
                queue: overlaySnapshot.triageQueue,
                projectsByID: tasksSnapshot.projectsByID,
                activeScope: overlaySnapshot.triageScope,
                isLoadingScope: overlaySnapshot.triageQueueLoading,
                queueErrorMessage: overlaySnapshot.triageQueueErrorMessage,
                lastBatchRunID: overlaySnapshot.lastBatchRunID,
                onScopeChange: { scope, completion in
                    viewModel.refreshTriageQueue(scope: scope, completion: completion)
                },
                onApplyDecision: { item, decision, completion in
                    viewModel.applyTriageDecision(for: item, decision: decision, completion: completion)
                },
                onApplyAll: { completion in
                    viewModel.applyAllTriageSuggestions(completion: completion)
                },
                onUndoBulkApply: { completion in
                    viewModel.undoEvaBatchPlan(completion: completion)
                },
                onSkip: { taskID in
                    viewModel.removeTriageQueueItem(taskID: taskID)
                },
                onDelete: { taskID, completion in
                    viewModel.deleteTask(taskID: taskID, scope: .single) { result in
                        switch result {
                        case .success:
                            viewModel.removeTriageQueueItem(taskID: taskID)
                            completion(.success(()))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                },
                onTrack: { action, metadata in
                    viewModel.trackHomeInteraction(action: action, metadata: metadata)
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { overlaySnapshot.rescuePresented },
            set: { viewModel.setEvaRescuePresented($0) }
        )) {
            EvaOverdueRescueSheetV2(
                plan: overlaySnapshot.rescuePlan,
                tasksByID: rescueTasksByID,
                lastBatchRunID: overlaySnapshot.lastBatchRunID,
                onApply: { mutations, completion in
                    viewModel.applyRescuePlan(mutations: mutations, completion: completion)
                },
                onUndo: { completion in
                    viewModel.undoRescueRun(completion: completion)
                },
                onCreateSplit: { taskID, draft, completion in
                    viewModel.createSplitChildren(parentTaskID: taskID, draft: draft, completion: completion)
                },
                onUndoSplit: { childIDs, completion in
                    viewModel.undoCreatedSplitChildren(childTaskIDs: childIDs, completion: completion)
                },
                onTrack: { action, metadata in
                    viewModel.trackHomeInteraction(action: action, metadata: metadata)
                }
            )
            .accessibilityIdentifier("home.rescue.sheet")
        }
        .sheet(isPresented: Binding(
            get: { overlaySnapshot.replanState.launcherSummary != nil },
            set: { isPresented in
                if isPresented == false,
                   overlaySnapshot.replanState.launcherSummary != nil {
                    viewModel.dismissNeedsReplanLater()
                }
            }
        )) {
            NeedsReplanLauncherSheet(
                summary: overlaySnapshot.replanState.launcherSummary ?? .empty,
                onStart: {
                    if overlaySnapshot.replanState.launcherSummary?.count == 0 {
                        viewModel.dismissNeedsReplanSessionUI()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onAddTask(nil)
                        }
                    } else {
                        viewModel.startNeedsReplanSession()
                    }
                },
                onLater: {
                    viewModel.dismissNeedsReplanLater()
                }
            )
        }
        .sheet(item: Binding(
            get: { viewModel.habitRecoveryReflectionPrompt },
            set: { if $0 == nil { viewModel.clearHabitRecoveryReflectionPrompt() } }
        )) { prompt in
            ReflectionNoteComposerView(
                viewModel: ReflectionNoteComposerViewModel(
                    title: "Recovery note",
                    kind: .habitRecovery,
                    linkedHabitID: prompt.habitID,
                    prompt: "What helped \(prompt.habitTitle) recover today?",
                    saveNoteHandler: { note, completion in
                        viewModel.saveReflectionNote(note, completion: completion)
                    }
                )
            )
        }
        .sheet(isPresented: Binding(
            get: { layoutClass.isPad && showDailyReflectPlan },
            set: { showDailyReflectPlan = $0 }
        ), onDismiss: {
            dailyReflectPlanViewModel = nil
        }) {
            reflectPlanPresentation
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !layoutClass.isPad && showDailyReflectPlan },
            set: { showDailyReflectPlan = $0 }
        ), onDismiss: {
            dailyReflectPlanViewModel = nil
        }) {
            reflectPlanPresentation
        }
    }

    private func applyHomeStateObservers(to content: AnyView) -> AnyView {
        let withActiveFace = AnyView(
            content.onChange(of: activeFace) { _, newValue in
                forcedFace?.wrappedValue = newValue
                if newValue == .search {
                    hasMountedSearchSurface = true
                } else if newValue == .analytics {
                    hasMountedAnalyticsSurface = true
                } else if newValue == .schedule {
                    hasMountedScheduleSurface = true
                }
                if newValue != .chat {
                    chatNavigationChromeState = .empty
                }
                if newValue != .search {
                    isSearchFieldFocused = false
                    cancelPendingSearchCommit()
                } else {
                    searchDraftQuery = searchState.query
                }
            }
        )

        let withSearchState = AnyView(
            withActiveFace
                .onChange(of: searchSurfaceState) { _, newValue in
                    switch newValue {
                    case .idle:
                        hasAutoFocusedSearchField = false
                        isSearchFieldFocused = false
                        cancelPendingSearchCommit()
                        searchDraftQuery = searchState.query
                        searchState.deactivate()
                    case .presenting, .preparing:
                        isSearchFieldFocused = false
                    case .ready:
                        guard activeFace == .search else { return }
                        hasAutoFocusedSearchField = false
                    }
                }
                .onChange(of: searchState.query) { _, newValue in
                    guard newValue != searchDraftQuery else { return }
                    guard isSearchFieldFocused == false else { return }
                    searchDraftQuery = newValue
                }
                .onChange(of: overlaySnapshot.guidanceState) { _, state in
                    guard state != nil, activeFace != .tasks else { return }
                    setActiveFace(.tasks, animated: true)
                }
                .onChange(of: agendaTailExpansionResetKey) { _, _ in
                    expandedAgendaTailItemIDs.removeAll()
                }
        )

        return AnyView(
            withSearchState
                .onChange(of: forcedFaceValue) { _, newValue in
                    guard let newValue, newValue != activeFace else { return }
                    setActiveFace(newValue, animated: true)
                }
                .onChange(of: chromeSnapshot.selectedDate) { _, newValue in
                    timelineViewModel.syncSelectedDate(newValue)
                }
                .onReceive(overlayStore.$snapshot.map(\.lastXPResult).receive(on: RunLoop.main)) { result in
                    handleXPResult(result)
                }
        )
    }

    private func applyHabitPresentationRouting<Content: View>(to content: Content) -> some View {
        content
            .sheet(isPresented: $showHabitBoardPresented) {
                HabitBoardScreen(
                    viewModel: PresentationDependencyContainer.shared.makeHabitBoardViewModel()
                )
            }
            .sheet(isPresented: $showHabitLibraryPresented) {
                HabitLibraryView(
                    viewModel: PresentationDependencyContainer.shared.makeNewHabitLibraryViewModel()
                )
            }
            .sheet(item: $selectedHomeHabitRow) { row in
                HabitDetailSheetView(
                    viewModel: PresentationDependencyContainer.shared.makeHabitDetailViewModel(row: row),
                    onMutation: {
                        viewModel.refreshCurrentScopeContent(source: "habit_detail_sheet_mutation")
                    }
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .taskerPresentHabitBoard)) { _ in
                presentHabitBoardFromDeepLink()
            }
            .onReceive(NotificationCenter.default.publisher(for: .taskerPresentHabitLibrary)) { _ in
                presentHabitLibraryFromDeepLink()
            }
            .onReceive(NotificationCenter.default.publisher(for: .taskerPresentHabitDetail)) { notification in
                guard let rawHabitID = notification.userInfo?["habitID"] as? String,
                      let habitID = UUID(uuidString: rawHabitID) else {
                    return
                }
                presentHabitDetailFromDeepLink(habitID: habitID)
            }
            .onChange(of: habitsSnapshot.errorMessage) { _, message in
                guard let message, message.isEmpty == false else { return }
                snackbar = SnackbarData(
                    message: message,
                    actions: [
                        SnackbarAction(title: "Open board") {
                            showHabitBoardPresented = true
                        }
                    ]
                )
                viewModel.clearHabitMutationErrorMessage()
            }
            .onReceive(viewModel.$habitMutationFeedback.compactMap { $0 }) { feedback in
                snackbar = SnackbarData(message: feedback.message, autoDismissSeconds: 2)
                playHabitMutationFeedbackHaptic(feedback.haptic)
                viewModel.consumeHabitMutationFeedback(id: feedback.id)
            }
    }

    /// Executes triggerForedropHintIfEligible.
    private func triggerForedropHintIfEligible(now: Date = Date()) {
        guard isForedropHintAnimationEnabled else {
            cancelForedropHintAnimation()
            return
        }
        if layoutClass.isPad && V2FeatureFlags.iPadPerfHomeAnimationTrimV3Enabled {
            logWarning(
                event: "ipadForedropHintSuppressed",
                message: "Suppressed decorative foredrop hint animation on iPad"
            )
            return
        }

        let canTrigger = HomeForedropHintEligibility.canTrigger(
            isHomeVisible: isHomeVisible && shellPhase == .interactive,
            foredropAnchor: foredropAnchorForHint,
            reduceMotionEnabled: reduceMotion,
            isUITesting: isUITesting,
            hasRunningAnimation: hintAnimationTask != nil,
            lastTriggerDate: lastHintTriggerAt,
            now: now
        )
        guard canTrigger else { return }

        startForedropHintAnimation(triggeredAt: now)
    }

    /// Executes startForedropHintAnimation.
    private func startForedropHintAnimation(triggeredAt timestamp: Date) {
        cancelForedropHintAnimation()
        lastHintTriggerAt = timestamp

        hintAnimationTask = _Concurrency.Task { @MainActor in
            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.foredropHintLaunchDelay.nanoseconds)
            } catch {
                return
            }
            guard !_Concurrency.Task.isCancelled else { return }

            withAnimation(.easeOut(duration: Self.foredropHintPeekDuration)) {
                foredropHintOffset = Self.foredropHintPeekDistance
            }

            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.foredropHintPeekDuration.nanoseconds)
            } catch {
                return
            }
            guard !_Concurrency.Task.isCancelled else { return }

            withAnimation(
                .spring(
                    response: Self.foredropHintReturnResponse,
                    dampingFraction: Self.foredropHintReturnDampingFraction
                )
            ) {
                foredropHintOffset = 0
            }

            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.foredropHintSettleDuration.nanoseconds)
            } catch {
                return
            }

            hintAnimationTask = nil
        }
    }

    /// Executes cancelForedropHintAnimation.
    private func cancelForedropHintAnimation() {
        hintAnimationTask?.cancel()
        hintAnimationTask = nil
        foredropHintOffset = 0
    }

    private func scheduleSearchCommit(for newValue: String) {
        pendingSearchCommitTask?.cancel()
        let pendingValue = newValue
        pendingSearchCommitTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: Self.searchCommitDebounceNanoseconds)
            } catch {
                pendingSearchCommitTask = nil
                return
            }
            guard !Task.isCancelled else { return }
            commitDraftSearchQuery(pendingValue)
            pendingSearchCommitTask = nil
        }
    }

    private func commitDraftSearchQueryImmediately() {
        cancelPendingSearchCommit()
        commitDraftSearchQuery(searchDraftQuery)
    }

    private func commitDraftSearchQuery(_ newValue: String) {
        let committedQuery = searchState.trimmedQuery
        let nextCommittedQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard committedQuery != nextCommittedQuery else { return }
        TaskerPerformanceTrace.event("HomeSearchQueryCommitted")
        searchState.updateQuery(newValue)
    }

    private func cancelPendingSearchCommit() {
        pendingSearchCommitTask?.cancel()
        pendingSearchCommitTask = nil
    }

    /// Executes backdropLayer.
    private func backdropLayer() -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: max(480, layoutMetrics.height * 0.65))
                .overlay(alignment: .topLeading) {
                    TimelineBackdropWeekView(
                        snapshot: timelineSnapshot,
                        onSelectDate: { date in
                            timelineViewModel.syncSelectedDate(date)
                            viewModel.selectDate(date, source: .weekStrip)
                            withAnimation(foredropFlipAnimation) {
                                timelineViewModel.snap(to: .collapsed)
                            }
                        },
                        onStartReplanForDate: { date in
                            viewModel.openNeedsReplanLauncher(for: date)
                        },
                        onPlaceReplanAllDay: { candidate, date in
                            timelineViewModel.syncSelectedDate(date)
                            viewModel.selectDate(date, source: .replan)
                            viewModel.placeReplanCandidateAllDay(taskID: candidate.taskID, on: date)
                        }
                    )
                    .padding(.horizontal, spacing.s16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(isBackFaceVisible ? 0.001 : 1)
                    .allowsHitTesting(!isBackFaceVisible)
                    .accessibilityHidden(isBackFaceVisible)
                }
            Spacer(minLength: 0)
        }
    }

    /// Executes foredropLayer.
    private func foredropLayer(taskListBottomInset: CGFloat) -> some View {
        ZStack {
            persistentFace(.tasks) {
                foredropFrontFace(taskListBottomInset: taskListBottomInset)
            }

            if hasMountedScheduleSurface || activeFace == .schedule {
                persistentFace(.schedule) {
                    foredropScheduleFace()
                }
            }

            if hasMountedAnalyticsSurface || activeFace == .analytics {
                persistentFace(.analytics) {
                    foredropAnalyticsFace()
                }
            }

            if hasMountedSearchSurface || activeFace == .search {
                persistentFace(.search) {
                    foredropSearchFace(taskListBottomInset: taskListBottomInset)
                }
            }

            if activeFace == .chat {
                persistentFace(.chat) {
                    foredropChatFace()
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
        .modifier(HomeDenseSurfaceModifier(cornerRadius: corner.modal))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.foredrop.surface")
        .accessibilityValue(activeFace == .tasks ? timelineViewModel.foredropAnchor.accessibilityValue : activeFace.surfaceAccessibilityValue)
        .animation(foredropFlipAnimation, value: activeFace)
    }

    private func persistentFace<Content: View>(
        _ face: HomeForedropFace,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isVisible = activeFace == face
        return content()
            .opacity(isVisible ? 1 : 0.001)
            .offset(x: isVisible ? 0 : (layoutClass.isPad ? 0 : (face == .tasks ? 0 : 10)))
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
            .zIndex(isVisible ? 1 : 0)
    }

    private func foredropFrontFace(taskListBottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            if tasksSnapshot.activeQuickView == .today {
                todayTimelineSurface(taskListBottomInset: taskListBottomInset)
            } else {
                TaskListView(
                    headerContent: AnyView(taskListScrollHeader),
                    footerContent: taskListFooterContent,
                    footerContentCountsAsContentForEmptyState: false,
                    morningTasks: tasksSnapshot.morningTasks,
                    eveningTasks: tasksSnapshot.eveningTasks,
                    overdueTasks: tasksSnapshot.overdueTasks,
                    inlineCompletedTasks: tasksSnapshot.inlineCompletedTasks,
                    projects: tasksSnapshot.projects,
                    lifeAreas: viewModel.lifeAreas,
                    doneTimelineTasks: tasksSnapshot.doneTimelineTasks,
                    tagNameByID: tasksSnapshot.tagNameByID,
                    activeQuickView: tasksSnapshot.activeQuickView,
                    todayXPSoFar: tasksSnapshot.todayXPSoFar,
                    isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled,
                    projectGroupingMode: tasksSnapshot.projectGroupingMode,
                    customProjectOrderIDs: tasksSnapshot.customProjectOrderIDs,
                    emptyStateMessage: tasksSnapshot.emptyStateMessage,
                    emptyStateActionTitle: tasksSnapshot.emptyStateActionTitle,
                    isTaskDragEnabled: false,
                    todaySections: tasksSnapshot.todayAgendaSectionState.sections,
                    agendaTailItems: visibleAgendaTailItems,
                    expandedAgendaTailItemIDs: expandedAgendaTailItemIDs,
                    layoutStyle: .edgeToEdgeHome,
                    onTaskTap: onTaskTap,
                    onToggleComplete: { task in
                        trackTaskToggle(task, source: "task_list")
                        onToggleComplete(task)
                    },
                    onDeleteTask: onDeleteTask,
                    onRescheduleTask: onRescheduleTask,
                    onPromoteTaskToFocus: { task in
                        promoteAgendaTaskToFocus(task)
                    },
                    onCompleteHabit: { habit in
                        viewModel.completeHabit(habit, source: "task_list")
                    },
                    onSkipHabit: { habit in
                        viewModel.skipHabit(habit, source: "task_list")
                    },
                    onLapseHabit: { habit in
                        viewModel.lapseHabit(habit, source: "task_list")
                    },
                    onCycleHabit: { habit in
                        performHabitRowAction(habit, source: "task_list_row_tap")
                    },
                    onOpenHabit: { habit in
                        openHabitDetail(habit)
                    },
                    onReorderCustomProjects: onReorderCustomProjects,
                    onInboxHeaderAction: shouldShowInboxTriageAction ? {
                        viewModel.startTriage()
                    } : nil,
                    inboxHeaderActionTitle: shouldShowInboxTriageAction ? "Start triage" : nil,
                    onCompletedSectionToggle: { sectionID, collapsed, count in
                        viewModel.trackHomeInteraction(
                            action: "home_completed_group_toggled",
                            metadata: [
                                "section_id": sectionID.uuidString,
                                "collapsed": collapsed,
                                "count": count
                            ]
                        )
                    },
                    onEmptyStateAction: { onAddTask(nil) },
                    onToggleAgendaTailItemExpansion: { itemID in
                        if expandedAgendaTailItemIDs.contains(itemID) {
                            expandedAgendaTailItemIDs.remove(itemID)
                        } else {
                            expandedAgendaTailItemIDs.insert(itemID)
                        }
                    },
                    onOpenRescue: isRescueEnabled ? {
                        viewModel.openRescue()
                    } : nil,
                    onTaskDragStarted: { task in
                        trackTaskDragStarted(task, source: "task_list")
                    },
                    onScrollChromeStateChange: { state in
                        onTaskListScrollChromeStateChange(state)
                    },
                    onPullToSearch: {
                        openSearch(source: "task_list_pull")
                    },
                    highlightedTaskID: overlaySnapshot.guidanceState?.taskID,
                    scrollResetKey: taskListScrollResetKey,
                    bottomContentInset: taskListBottomInset
                )
                .padding(.top, spacing.s4)
                .onDrop(of: ["public.text"], isTargeted: nil, perform: handleListDrop)
                .accessibilityIdentifier("home.list.dropzone")
            }
        }
    }

    private func foredropScheduleFace() -> some View {
        ZStack {
            if let calendarIntegrationService {
                CalendarScheduleView(
                    service: calendarIntegrationService,
                    weekStartsOn: calendarIntegrationService.weekStartsOn,
                    presentationMode: .embedded,
                    selectedDate: Binding(
                        get: { viewModel.selectedDate },
                        set: { date in
                            viewModel.selectDate(date, source: .datePicker)
                        }
                    )
                )
            } else {
                Text("Schedule unavailable")
                    .font(.tasker(.body))
                    .foregroundColor(Color.tasker.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            dayLiquidSwipeOverlay
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func foredropAnalyticsFace() -> some View {
        VStack(spacing: spacing.s8) {
            HStack(spacing: spacing.s8) {
                Text("Analytics")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)
                Spacer()
                Button {
                    onReturnToTasks("back_chip")
                } label: {
                    HStack(spacing: spacing.s4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Back to tasks")
                            .font(.tasker(.caption2))
                    }
                    .foregroundColor(Color.tasker.textQuaternary.opacity(0.92))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.foredrop.collapseHint")
                .accessibilityLabel("Back to tasks")
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s12)

            Group {
                if let insightsViewModel = faceCoordinator.insightsViewModel,
                   analyticsSurfaceState == .ready {
                    InsightsTabView(
                        viewModel: insightsViewModel,
                        homeProgress: chromeSnapshot.progressState,
                        homeCompletionRate: chromeSnapshot.completionRate,
                        reflectionEligible: false,
                        dailyReflectionEntryState: chromeSnapshot.dailyReflectionEntryState,
                        momentumGuidanceText: momentumGuidanceText,
                        animateMomentumCard: shellPhase == .interactive && !reduceMotion,
                        onOpenReflection: {
                            openDailyReflectPlan()
                        }
                    )
                } else {
                    VStack(spacing: spacing.s8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text(analyticsSurfaceState == .placeholder ? "Opening analytics…" : "Loading analytics…")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func presentHabitBoardIfRequestedForUITests() {
        guard shouldPresentHabitBoardForUITests else { return }
        let hasVisibleHabits =
            habitsSnapshot.habitHomeSectionState.primaryRows.isEmpty == false
            || habitsSnapshot.habitHomeSectionState.recoveryRows.isEmpty == false
        guard hasVisibleHabits else { return }
        guard hasPresentedUITestHabitBoard == false, showHabitBoardPresented == false else { return }
        guard isSchedulingUITestHabitBoardPresentation == false else { return }
        isSchedulingUITestHabitBoardPresentation = true

        Task { @MainActor in
            setActiveFace(.tasks, animated: false)
            await Task.yield()
            await Task.yield()
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard showHabitBoardPresented == false else {
                isSchedulingUITestHabitBoardPresentation = false
                return
            }
            showHabitBoardPresented = true
            hasPresentedUITestHabitBoard = true
            isSchedulingUITestHabitBoardPresentation = false
        }
    }

    private func foredropSearchFace(taskListBottomInset: CGFloat) -> some View {
        let effectiveSearchBottomInset = max(
            taskListBottomInset,
            layoutMetrics.keyboardOverlapHeight + spacing.s16
        )

        return VStack(spacing: 0) {
            searchFaceHeader

            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    searchFaceContentBody(
                        availableHeight: proxy.size.height,
                        contentBottomInset: effectiveSearchBottomInset
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: max(proxy.size.height - effectiveSearchBottomInset, 0),
                        alignment: searchContentAlignment
                    )
                    .padding(.horizontal, searchContentHorizontalPadding)
                    .padding(.top, spacing.s8)
                    .padding(.bottom, effectiveSearchBottomInset + spacing.s8)
                }
                .scrollDismissesKeyboard(.interactively)
                .accessibilityIdentifier("search.contentContainer")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.view")
    }

    @ViewBuilder
    private func foredropChatFace() -> some View {
        if let container = LLMDataController.shared {
            ChatContainerView(
                onNavigationChromeChange: { state in
                    chatNavigationChromeState = state
                },
                onPromptFocusChange: onChatPromptFocusChange,
                onOpenTaskDetail: { task in
                    onTaskTap(task)
                },
                onOpenHabitDetail: { habitID in
                    openHabitDetail(habitID: habitID)
                },
                onPerformDayTaskAction: onPerformChatDayTaskAction,
                onPerformDayHabitAction: { action, card, completion in
                    if action == .open {
                        openHabitDetail(habitID: card.habitID)
                        completion(.success(()))
                        return
                    }
                    onPerformChatDayHabitAction(action, card, completion)
                }
            )
            .environmentObject(chatAppManager)
            .environment(LLMRuntimeCoordinator.shared.evaluator)
            .modelContainer(container)
            .padding(.bottom, layoutMetrics.chatComposerBottomInset + spacing.s16)
        } else {
            LLMStoreUnavailableView()
        }
    }

    private var searchFaceHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: spacing.s8) {
                Text("Search")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)
                Spacer()
                Button {
                    onReturnToTasks("back_chip")
                } label: {
                    HStack(spacing: spacing.s4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Back to tasks")
                            .font(.tasker(.caption2))
                    }
                    .foregroundColor(Color.tasker.textQuaternary.opacity(0.92))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search.backChip")
                .accessibilityLabel("Back to tasks")
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s12)
            .padding(.bottom, spacing.s8)

            VStack(alignment: .leading, spacing: spacing.s8) {
                TaskerSearchFilterChipsView(chips: searchStatusChipDescriptors)
                TaskerSearchFilterChipsView(chips: searchPriorityChipDescriptors)
                if !searchProjectChipDescriptors.isEmpty {
                    TaskerSearchFilterChipsView(chips: searchProjectChipDescriptors)
                }
            }
            .padding(.horizontal, spacing.s12)
            .padding(.bottom, spacing.s8)

            Divider()
                .overlay(Color.tasker.strokeHairline)
        }
    }

    @ViewBuilder
    private func searchFaceContentBody(
        availableHeight: CGFloat,
        contentBottomInset: CGFloat
    ) -> some View {
        if isSearchLoadingContentVisible {
            VStack(spacing: spacing.s8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Text(searchLoadingMessage)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
            }
        } else if searchState.shouldShowNoResultsMessage {
            VStack(spacing: spacing.s8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color.tasker.textTertiary)
                Text(searchState.emptyStateTitle)
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)
                    .accessibilityIdentifier("search.emptyStateLabel")
                Text(searchState.emptyStateSubtitle)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: max(availableHeight - contentBottomInset, 0),
                alignment: .center
            )
        } else {
            LazyVStack(alignment: .leading, spacing: spacing.s12) {
                Color.clear
                    .frame(height: 0)
                    .accessibilityIdentifier("search.resultsList")

                ForEach(searchState.sections) { section in
                    TaskSectionView(
                        project: searchProject(for: section.projectName),
                        tasks: section.tasks,
                        tagNameByID: tasksSnapshot.tagNameByID,
                        completedCollapsed: false,
                        isTaskDragEnabled: false,
                        onTaskTap: { task in
                            trackSearchResultOpened(task, projectName: section.projectName)
                            onTaskTap(task)
                        },
                        onToggleComplete: { task in
                            trackTaskToggle(task, source: "search_results")
                            onToggleComplete(task)
                        },
                        onDeleteTask: { task in
                            onDeleteTask(task)
                        },
                        onRescheduleTask: { task in
                            onRescheduleTask(task)
                        }
                    )
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: max(availableHeight - contentBottomInset, 0),
                alignment: .topLeading
            )
        }
    }

    private var isSearchLoadingContentVisible: Bool {
        (searchSurfaceState != .ready && !searchState.hasLoaded) || (searchState.isLoading && !searchState.hasLoaded)
    }

    private var searchLoadingMessage: String {
        if searchSurfaceState != .ready && !searchState.hasLoaded {
            return searchSurfaceState == .presenting ? "Opening search…" : "Loading tasks…"
        }
        return "Loading tasks…"
    }

    private var searchContentAlignment: Alignment {
        (isSearchLoadingContentVisible || searchState.shouldShowNoResultsMessage) ? .center : .topLeading
    }

    private var searchContentHorizontalPadding: CGFloat {
        searchState.shouldShowNoResultsMessage ? spacing.s20 : spacing.s16
    }

    @ViewBuilder
    private func topNavigationBar() -> some View {
        if isSearchOpen {
            HomeSearchChromeView(
                query: $searchDraftQuery,
                isFocused: $isSearchFieldFocused,
                onQueryChanged: { newValue in
                    trackSearchQueryChanged(newValue)
                    scheduleSearchCommit(for: newValue)
                },
                onSubmit: {
                    commitDraftSearchQueryImmediately()
                },
                onClear: {
                    cancelPendingSearchCommit()
                    searchDraftQuery = ""
                    searchState.clearQuery()
                    trackSearchQueryChanged("")
                }
            )
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)
            .padding(.bottom, spacing.s8)
            .ignoresSafeArea(.keyboard)
            .zIndex(1)
        } else if isChatOpen {
            HomeEvaChatTopChromeView(
                chromeState: chatNavigationChromeState,
                onBack: {
                    returnToTasks(source: "chat_top_chrome_back")
                },
                onSettings: {
                    NotificationCenter.default.post(name: .requestEvaChatSettings, object: nil)
                },
                onHistory: {
                    NotificationCenter.default.post(name: .toggleChatHistory, object: nil)
                },
                onNewChat: {
                    NotificationCenter.default.post(name: .requestEvaChatNewThread, object: nil)
                }
            )
            .padding(.top, layoutClass.isPad ? 18 : 0)
        } else {
            VStack(alignment: .leading, spacing: spacing.s12) {
                let headerPresentation = chromeSnapshot.homeHeaderPresentation(
                    tasks: tasksSnapshot,
                    habits: habitsSnapshot
                )

                HomeCompactHeaderView(
                    presentation: headerPresentation,
                    selectedQuickView: chromeSnapshot.activeScope.quickView,
                    taskCounts: chromeSnapshot.quickViewCounts,
                    extraTopPadding: layoutClass.isPad ? 18 : 0,
                    reduceMotion: reduceMotion,
                    onSelectQuickView: { viewModel.setQuickView($0) },
                    onBackToToday: {
                        viewModel.returnToToday(source: .backToToday)
                    },
                    onShowDatePicker: {
                        draftDate = chromeSnapshot.selectedDate
                        showDatePicker = true
                    },
                    onShowAdvancedFilters: {
                        showAdvancedFilters = true
                    },
                    onResetFilters: {
                        viewModel.resetAllFilters()
                    },
                    onOpenMenuSearch: {
                        openSearch(source: "scope_menu_search")
                    },
                    onOpenReflection: {
                        openDailyReflectPlan()
                    },
                    onOpenSettings: {
                        onOpenSettings()
                    }
                )
            }
        }
    }

    private var searchStatusChipDescriptors: [TaskerSearchFilterChipDescriptor] {
        HomeSearchStatusFilter.allCases.map { status in
            TaskerSearchFilterChipDescriptor(
                id: "status-\(status.rawValue)",
                title: status.title,
                isSelected: searchState.selectedStatus == status,
                tintColor: Color.tasker.accentPrimary,
                accessibilityIdentifier: status.accessibilityIdentifier
            ) {
                searchState.setStatus(status)
                trackSearchChipToggled(kind: "status", value: status.analyticsName, isSelected: true)
            }
        }
    }

    private var searchPriorityChipDescriptors: [TaskerSearchFilterChipDescriptor] {
        TaskPriorityConfig.Priority.allCases.map { priority in
            let isSelected = searchState.selectedPriorities.contains(priority.rawValue)
            return TaskerSearchFilterChipDescriptor(
                id: "priority-\(priority.rawValue)",
                title: priority.code,
                isSelected: isSelected,
                tintColor: Color(uiColor: priority.color),
                accessibilityIdentifier: "search.priority.\(priority.code.lowercased())"
            ) {
                searchState.togglePriority(priority)
                trackSearchChipToggled(
                    kind: "priority",
                    value: priority.code.lowercased(),
                    isSelected: !isSelected
                )
            }
        }
    }

    private var searchProjectChipDescriptors: [TaskerSearchFilterChipDescriptor] {
        searchState.availableProjects.map { projectName in
            let isSelected = searchState.selectedProjects.contains(projectName)
            return TaskerSearchFilterChipDescriptor(
                id: "project-\(projectName)",
                title: projectName,
                isSelected: isSelected,
                tintColor: Color.tasker.accentSecondary,
                accessibilityIdentifier: "search.project.\(searchIdentifierToken(projectName))"
            ) {
                searchState.toggleProject(projectName)
                trackSearchChipToggled(
                    kind: "project",
                    value: projectName,
                    isSelected: !isSelected
                )
            }
        }
    }

    private func searchProject(for name: String) -> Project {
        if let resolved = tasksSnapshot.projects.first(where: { $0.name == name }) {
            return resolved
        }
        if name == ProjectConstants.inboxProjectName {
            return Project.createInbox()
        }
        return Project(name: name)
    }

    private var rescueTasksByID: [UUID: TaskDefinition] {
        Dictionary(
            uniqueKeysWithValues: (
                tasksSnapshot.overdueTasks
                + tasksSnapshot.morningTasks
                + tasksSnapshot.eveningTasks
                + overlaySnapshot.triageQueue.map(\.task)
            ).map { ($0.id, $0) }
        )
    }

    private func searchIdentifierToken(_ rawValue: String) -> String {
        rawValue
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    private func trackSearchQueryChanged(_ query: String) {
        let now = Date()
        if let lastSearchQueryTelemetryAt, now.timeIntervalSince(lastSearchQueryTelemetryAt) < 0.7 {
            return
        }
        lastSearchQueryTelemetryAt = now
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.trackHomeInteraction(
            action: "home_search_query_changed",
            metadata: [
                "length": trimmed.count,
                "has_query": trimmed.isEmpty ? "false" : "true"
            ]
        )
    }

    private func trackSearchChipToggled(kind: String, value: String, isSelected: Bool) {
        viewModel.trackHomeInteraction(
            action: "home_search_chip_toggled",
            metadata: [
                "kind": kind,
                "value": value,
                "selected": isSelected ? "true" : "false"
            ]
        )
    }

    private func trackSearchResultOpened(_ task: TaskDefinition, projectName: String) {
        viewModel.trackHomeInteraction(
            action: "home_search_result_opened",
            metadata: [
                "task_id": task.id.uuidString,
                "project": projectName
            ]
        )
    }

    private var shouldShowInboxTriageAction: Bool {
        V2FeatureFlags.evaTriageEnabled && chromeSnapshot.activeScope.quickView == .today
    }

    private var taskListHorizontalGutter: CGFloat {
        TaskerTheme.Spacing.lg
    }

    private func fullBleedTaskListHeaderModule<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, -taskListHorizontalGutter)
    }

    @ViewBuilder
    private var taskListScrollHeader: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            if let guidanceState = overlaySnapshot.guidanceState {
                HomeOnboardingGuidanceBanner(state: guidanceState)
                    .padding(.top, spacing.s8)
                    .modifier(HomeStaggerModifier(isEnabled: shellPhase == .interactive, index: 3))
            }
        }
    }

    private var timelineColumnMaxWidth: CGFloat? {
        switch layoutClass {
        case .padRegular:
            return 760
        case .padExpanded:
            return 840
        default:
            return nil
        }
    }

    private var timelineHasNextHomeWidget: Bool {
        true
    }

    @ViewBuilder
    private func timelineColumnContent<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if let maxWidth = timelineColumnMaxWidth {
            content()
                .frame(maxWidth: maxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            content()
        }
    }

    private func beginDaySwipeTrace() {
        guard isDaySwipeTracingActive == false else { return }
        isDaySwipeTracingActive = true
        TaskerPerformanceTrace.event("HomeDaySwipeStarted")
    }

    private func cancelDaySwipeTraceIfNeeded() {
        guard isDaySwipeTracingActive else { return }
        TaskerPerformanceTrace.event("HomeDaySwipeCancelled")
        isDaySwipeTracingActive = false
    }

    private var dayLiquidSwipeContainerSize: CGSize {
        CGSize(
            width: max(layoutMetrics.width, 1),
            height: max(layoutMetrics.height - measuredTimelineHeaderHeight, 1)
        )
    }

    private func normalizedDayLiquidSwipeSize(_ size: CGSize) -> CGSize {
        let fallback = dayLiquidSwipeContainerSize
        return CGSize(
            width: max(size.width, fallback.width, 1),
            height: max(size.height, fallback.height, 1)
        )
    }

    private func dayLiquidSwipeData(for side: HomeDayLiquidSwipeSide, size: CGSize) -> HomeDayLiquidSwipeData {
        let data = side == .leading ? leadingDayLiquidSwipeData : trailingDayLiquidSwipeData
        return data
            .resting(at: dayLiquidSwipeRestingCenterY)
            .sized(to: size)
    }

    private func setDayLiquidSwipeData(_ data: HomeDayLiquidSwipeData) {
        switch data.side {
        case .leading:
            leadingDayLiquidSwipeData = data
        case .trailing:
            trailingDayLiquidSwipeData = data
        }
    }

    private func handleTimelineScrollOffsetChange(_ newOffset: CGFloat) {
        if let nextState = timelineScrollChromeStateTracker.consume(offset: newOffset) {
            updateDayLiquidSwipeChromeVisibility(for: nextState)
        }
    }

    private func updateDayLiquidSwipeChromeVisibility(for state: HomeScrollChromeState) {
        let nextVisibility = HomeDayLiquidSwipeChromeVisibilityPolicy.nextVisibility(
            currentVisibility: isDayLiquidSwipeChromeVisible,
            for: state
        )
        guard nextVisibility != isDayLiquidSwipeChromeVisible else { return }
        isDayLiquidSwipeChromeVisible = nextVisibility
        if nextVisibility == false {
            activeDayLiquidSwipeSide = nil
            cancelDaySwipeTraceIfNeeded()
        }
    }

    private func resetDayLiquidSwipeChromeVisibility() {
        timelineScrollChromeStateTracker = HomeScrollChromeStateTracker()
        isDayLiquidSwipeChromeVisible = true
    }

    private func updateDayLiquidSwipe(
        side: HomeDayLiquidSwipeSide,
        translation: CGSize,
        location: CGPoint,
        size: CGSize
    ) {
        guard isDaySwipeGestureEnabled else { return }
        let containerSize = normalizedDayLiquidSwipeSize(size)
        activeDayLiquidSwipeSide = side
        topDayLiquidSwipeSide = side
        setDayLiquidSwipeData(
            dayLiquidSwipeData(for: side, size: containerSize)
                .drag(translation: translation, location: location)
        )
    }

    private func endDayLiquidSwipe(
        side: HomeDayLiquidSwipeSide,
        translation: CGSize,
        predictedEndTranslation: CGSize,
        size: CGSize
    ) {
        activeDayLiquidSwipeSide = nil
        let containerSize = normalizedDayLiquidSwipeSize(size)

        guard isDaySwipeGestureEnabled else {
            resetDayLiquidSwipe(side, size: containerSize)
            return
        }

        guard let direction = HomeDaySwipeResolver.default.resolvedDirection(
            translation: translation,
            predictedEndTranslation: predictedEndTranslation
        ), direction == side.direction else {
            cancelDaySwipeTraceIfNeeded()
            resetDayLiquidSwipe(side, size: containerSize)
            return
        }

        commitDayLiquidSwipe(side, size: containerSize)
    }

    private func cancelDayLiquidSwipe(side: HomeDayLiquidSwipeSide, size: CGSize) {
        activeDayLiquidSwipeSide = nil
        cancelDaySwipeTraceIfNeeded()
        resetDayLiquidSwipe(side, size: normalizedDayLiquidSwipeSize(size))
    }

    private func resetDayLiquidSwipe(_ side: HomeDayLiquidSwipeSide, size: CGSize) {
        let data = dayLiquidSwipeData(for: side, size: size).initial()
        if reduceMotion || isUITesting {
            setDayLiquidSwipeData(data)
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                setDayLiquidSwipeData(data)
            }
        }
    }

    private func resetIdleDayLiquidSwipeHandles(restingCenterY: CGFloat) {
        guard activeDayLiquidSwipeSide == nil else { return }
        let size = normalizedDayLiquidSwipeSize(dayLiquidSwipeContainerSize)
        leadingDayLiquidSwipeData = leadingDayLiquidSwipeData
            .resting(at: restingCenterY)
            .sized(to: size)
            .initial()
        trailingDayLiquidSwipeData = trailingDayLiquidSwipeData
            .resting(at: restingCenterY)
            .sized(to: size)
            .initial()
    }

    private func commitDayLiquidSwipe(_ side: HomeDayLiquidSwipeSide, size: CGSize) {
        topDayLiquidSwipeSide = side
        if reduceMotion || isUITesting {
            commitDaySwipe(side.direction)
            resetDayLiquidSwipe(side, size: size)
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            setDayLiquidSwipeData(dayLiquidSwipeData(for: side, size: size).final())
        } completion: {
            commitDaySwipe(side.direction)
            resetDayLiquidSwipe(side, size: size)
        }
    }

    private func commitDaySwipe(_ direction: HomeDayNavigationDirection) {
        guard isDaySwipeGestureEnabled else { return }
        isDaySwipeTracingActive = false
        committedDaySwipeDirection = direction
        let dayOffset = direction == .previous ? -1 : 1
        TaskerFeedback.selection()
        withAnimation(daySwipeAnimation) {
            viewModel.shiftSelectedDay(byDays: dayOffset, source: .swipe)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if committedDaySwipeDirection == direction {
                committedDaySwipeDirection = nil
            }
        }
    }

    private func todayTimelineSurface(taskListBottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            TimelineForedropBar(
                onSnapAnchor: { anchor in
                    withAnimation(foredropFlipAnimation) {
                        timelineViewModel.snap(to: anchor)
                    }
                },
                onDragChanged: { translation in
                    timelineViewModel.updateDrag(translation, metrics: timelineLayoutMetrics)
                },
                onDragEnded: { translation in
                    timelineViewModel.endDrag(predictedTranslation: translation, metrics: timelineLayoutMetrics)
                }
            )
            .reportHeight(to: TimelineHeaderHeightPreferenceKey.self)
            .padding(.horizontal, spacing.s16)

            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        if habitsSnapshot.quietTrackingSummaryState.isVisible {
                            passiveTrackingRail
                                .padding(.horizontal, passiveTrackingRailHorizontalInset)
                        }

                        if case .trayVisible(let summary) = overlaySnapshot.replanState.phase {
                            timelineColumnContent {
                                NeedsReplanTrayView(
                                    title: summary.title,
                                    subtitle: summary.subtitle,
                                    callToAction: summary.callToAction,
                                    accessibilityHint: "Opens Plan the Day.",
                                    accessibilityIdentifier: "home.needsReplan.tray",
                                    isProminent: true
                                ) {
                                    viewModel.openNeedsReplanLauncher()
                                }
                                .padding(.horizontal, spacing.s16)
                                .onGeometryChange(for: CGFloat.self) { proxy in
                                    proxy.size.height
                                } action: { newHeight in
                                    guard abs(newHeight - measuredNeedsReplanTrayHeight) > 0.5 else { return }
                                    measuredNeedsReplanTrayHeight = newHeight
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        timelineColumnContent {
                            let snapshot = timelineSnapshot
                            let selectedDayKey = Int(Calendar.current.startOfDay(for: snapshot.selectedDate).timeIntervalSince1970)
                            TimelineForedropView(
                                snapshot: snapshot,
                                layoutClass: layoutClass,
                                showsRevealHandle: false,
                                hasNextHomeWidget: timelineHasNextHomeWidget,
                                onSelectDate: { date in
                                    timelineViewModel.syncSelectedDate(date)
                                    viewModel.selectDate(date, source: .weekStrip)
                                },
                                onSnapAnchor: { anchor in
                                    withAnimation(foredropFlipAnimation) {
                                        timelineViewModel.snap(to: anchor)
                                    }
                                },
                                onDragChanged: { translation in
                                    timelineViewModel.updateDrag(translation, metrics: timelineLayoutMetrics)
                                },
                                onDragEnded: { translation in
                                    timelineViewModel.endDrag(predictedTranslation: translation, metrics: timelineLayoutMetrics)
                                },
                                onTaskTap: { item in
                                    if let eventID = item.eventID {
                                        handleHomeCalendarEventSelection(eventID: eventID, allowsTimelineHide: true)
                                        return
                                    }
                                    if let taskID = item.taskID, let task = viewModel.taskSnapshot(for: taskID) {
                                        onTaskTap(task)
                                    }
                                },
                                onToggleComplete: { item in
                                    guard let taskID = item.taskID, let task = viewModel.taskSnapshot(for: taskID) else { return }
                                    trackTaskToggle(task, source: "timeline")
                                    onToggleComplete(task)
                                },
                                onAnchorTap: onTimelineAnchorTap,
                                onAddTask: onAddTask,
                                onScheduleInbox: {
                                    viewModel.startTriage()
                                },
                                onShowCalendarInTimeline: {
                                    viewModel.showCalendarEventsInTimelineFromHome()
                                },
                                onPlaceReplanAtTime: { candidate, date in
                                    viewModel.placeReplanCandidate(taskID: candidate.taskID, at: date)
                                },
                                onPlaceReplanAllDay: { candidate, date in
                                    viewModel.placeReplanCandidateAllDay(taskID: candidate.taskID, on: date)
                                },
                                onCancelReplanPlacement: {
                                    viewModel.cancelCurrentReplanPlacement()
                                },
                                onSkipReplanPlacement: {
                                    viewModel.skipCurrentReplanCandidate()
                                },
                                onClearReplanError: {
                                    viewModel.clearReplanError()
                                }
                            )
                            .id(selectedDayKey)
                            .transition(daySwipeTransition)
                            .animation(daySwipeAnimation, value: selectedDayKey)
                            .padding(.horizontal, spacing.s16)
                            .accessibilityAction(named: Text("Previous Day")) {
                                beginDaySwipeTrace()
                                commitDaySwipe(.previous)
                            }
                            .accessibilityAction(named: Text("Next Day")) {
                                beginDaySwipeTrace()
                                commitDaySwipe(.next)
                            }
                        }

                        if let entryState = chromeSnapshot.dailyReflectionEntryState {
                            timelineColumnContent {
                                HomeDailyReflectionEntryCard(
                                    state: entryState,
                                    mode: .compact
                                ) {
                                    openDailyReflectPlan(preferredReflectionDate: entryState.reflectionDate)
                                }
                                .padding(.horizontal, spacing.s16)
                            }
                        }

                        if let footerContent = timelineFooterModules {
                            footerContent
                        }

                        if let guidanceState = overlaySnapshot.guidanceState {
                            HomeOnboardingGuidanceBanner(state: guidanceState)
                                .padding(.horizontal, spacing.s16)
                        }

                        timelineColumnContent {
                            persistentReplanDayEntry
                                .padding(.horizontal, spacing.s16)
                        }

                        timelineBottomContentSpacer(taskListBottomInset: taskListBottomInset)
                    }
                    .padding(.top, spacing.s8)
                    .contentShape(Rectangle())
                    .background {
                        HomeDayLiquidSwipeGestureSurface(
                            isEnabled: isDaySwipeInteractionEnabled,
                            containerSize: dayLiquidSwipeContainerSize,
                            restingCenterY: dayLiquidSwipeRestingCenterY,
                            resolver: .default,
                            onInteractionStarted: beginDaySwipeTrace,
                            onChanged: { side, translation, location in
                                updateDayLiquidSwipe(
                                    side: side,
                                    translation: translation,
                                    location: location,
                                    size: dayLiquidSwipeContainerSize
                                )
                            },
                            onEnded: { side, translation, predictedEndTranslation, _ in
                                endDayLiquidSwipe(
                                    side: side,
                                    translation: translation,
                                    predictedEndTranslation: predictedEndTranslation,
                                    size: dayLiquidSwipeContainerSize
                                )
                            },
                            onCancelled: { side in
                                cancelDayLiquidSwipe(
                                    side: side,
                                    size: dayLiquidSwipeContainerSize
                                )
                            }
                        )
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                    }
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(
                    for: CGFloat.self,
                    of: { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    },
                    action: { _, newOffset in
                        handleTimelineScrollOffsetChange(max(0, newOffset))
                    }
                )

                dayLiquidSwipeOverlay
            }
            .coordinateSpace(name: Self.dayLiquidSwipeCoordinateSpaceName)
        }
        .accessibilityIdentifier("home.timeline.surface")
    }

    private var dayLiquidSwipeOverlay: some View {
        HomeDayLiquidSwipeOverlay(
            isEnabled: isDaySwipeGestureEnabled,
            isChromeVisible: isDayLiquidSwipeChromeVisible,
            reduceMotion: reduceMotion || isUITesting,
            restingCenterY: dayLiquidSwipeRestingCenterY,
            onInteractionStarted: beginDaySwipeTrace,
            onInteractionCancelled: cancelDaySwipeTraceIfNeeded,
            onCommit: commitDaySwipe,
            onHandleDragChanged: { side, translation, location, size in
                updateDayLiquidSwipe(
                    side: side,
                    translation: translation,
                    location: location,
                    size: size
                )
            },
            onHandleDragEnded: { side, translation, predictedEndTranslation, _, size in
                endDayLiquidSwipe(
                    side: side,
                    translation: translation,
                    predictedEndTranslation: predictedEndTranslation,
                    size: size
                )
            },
            leadingData: $leadingDayLiquidSwipeData,
            trailingData: $trailingDayLiquidSwipeData,
            topSide: $topDayLiquidSwipeSide
        )
    }

    private func timelineBottomContentSpacer(taskListBottomInset: CGFloat) -> some View {
        Color.clear
            .frame(height: timelineBottomContentClearance(taskListBottomInset: taskListBottomInset))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func timelineBottomContentClearance(taskListBottomInset: CGFloat) -> CGFloat {
        guard layoutClass == .phone else {
            return taskListBottomInset
        }
        return max(taskListBottomInset + spacing.s40 + spacing.s8, 132)
    }

    @ViewBuilder
    private var calendarScheduleModuleCard: some View {
        if calendarSnapshot.moduleState == .permissionRequired {
            calendarCardChrome {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    calendarSummaryHeader
                    calendarModuleBody
                    calendarPermissionCTA
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            calendarCardChrome {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    calendarSummaryHeader
                    calendarModuleBody
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous))
            .gesture(
                TapGesture().onEnded {
                    handleOpenScheduleAction()
                },
                including: .gesture
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(calendarCardAccessibilityLabel)
            .accessibilityHint(String(localized: "Opens the full calendar schedule"))
        }
    }

    @ViewBuilder
    private func calendarCardChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .modifier(CalendarCardChromeModifier())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.calendar.card")
    }

    @ViewBuilder
    private var calendarPermissionCTA: some View {
        if shouldShowCalendarPermissionCTA {
            Button(action: onRequestCalendarPermission) {
                Text(calendarPermissionButtonTitle)
                    .font(.tasker(.bodyStrong))
                    .foregroundStyle(Color.tasker.textInverse)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.tasker.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.calendar.connect")
        }
    }

    private var calendarSummaryHeader: some View {
        Text(calendarSummaryLine)
            .font(.tasker(.bodyStrong))
            .foregroundStyle(Color.tasker.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("home.calendar.nextMeeting")
    }

    private var calendarSummaryLine: String {
        let dateText = TaskerCalendarPresentation.compactDateText(for: calendarSnapshot.selectedDate)

        if let nextMeeting = calendarSnapshot.nextMeeting {
            let timeText = TaskerCalendarPresentation.timeRangeText(for: nextMeeting.event)
            return "\(dateText) · Next up: \(nextMeeting.event.title) · \(timeText)"
        }

        if let freeUntil = calendarSnapshot.freeUntil {
            return "\(dateText) · Next up: Clear · Free until \(freeUntil.formatted(date: .omitted, time: .shortened))"
        }

        return "\(dateText) · Next up: Clear"
    }

    private var calendarCardAccessibilityLabel: String {
        let spokenLine = calendarSummaryLine.replacingOccurrences(of: " - ", with: " to ")
        return String(localized: "Open schedule, \(spokenLine)")
    }

    @ViewBuilder
    private var calendarModuleBody: some View {
        switch calendarSnapshot.moduleState {
        case .permissionRequired:
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text(calendarPermissionBodyText)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .accessibilityIdentifier(calendarPermissionStateAccessibilityID)
            }
            .accessibilityLabel(calendarPermissionBodyText)
            .accessibilityIdentifier("home.calendar.state.permission")
        case .noCalendarsSelected:
            Text(String(localized: "No calendars selected. Choose at least one calendar for schedule insights."))
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker.textSecondary)
                .accessibilityIdentifier("home.calendar.state.noCalendars")
        case .allDayOnly:
            Text(String(localized: "Only all-day events are scheduled. No timed blocks for this day."))
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker.textSecondary)
                .accessibilityIdentifier("home.calendar.state.allDayOnly")
        case .empty:
            Text(String(localized: "No events are scheduled. Use this open window for focused work."))
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker.textSecondary)
                .accessibilityIdentifier("home.calendar.state.empty")
        case .error(let message):
            Text(message)
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker.statusWarning)
                .accessibilityIdentifier("home.calendar.state.error")
        case .active:
            VStack(alignment: .leading, spacing: spacing.s8) {
                calendarTimelinePreview
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.calendar.state.active")
        }
    }

    @ViewBuilder
    private var calendarTimelinePreview: some View {
        if calendarSnapshot.selectedDayTimelineEvents.isEmpty == false {
            TaskerCalendarTimelineView(
                date: calendarSnapshot.selectedDate,
                events: calendarSnapshot.selectedDayEvents,
                density: .compact,
                showsDateLabel: false,
                accessibilityIdentifier: "home.calendar.timelinePreview",
                accessibilityLabelText: String(localized: "Home calendar timeline preview."),
                eventAccessibilityIdentifierPrefix: "home.calendar.event",
                onSelectEvent: handleHomeCalendarEventSelection
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var shouldShowCalendarPermissionCTA: Bool {
        guard calendarSnapshot.moduleState == .permissionRequired else { return false }
        switch calendarSnapshot.accessAction {
        case .requestPermission, .openSystemSettings:
            return true
        case .unavailable, .noneNeeded:
            return false
        }
    }

    private var calendarPermissionButtonTitle: String {
        switch calendarSnapshot.accessAction {
        case .openSystemSettings:
            return String(localized: "Open Settings")
        case .requestPermission:
            return String(localized: "Allow Full Calendar Access")
        case .unavailable, .noneNeeded:
            return String(localized: "Connect")
        }
    }

    private var calendarPermissionBodyText: String {
        switch calendarSnapshot.authorizationStatus {
        case .notDetermined:
            return String(localized: "Connect Calendar to surface next meetings and free windows.")
        case .denied:
            return String(localized: "Calendar access is denied by iOS. Enable Tasker in Settings > Privacy & Security > Calendars. If Tasker is missing, restart your device, reinstall Tasker, or reset Location & Privacy.")
        case .restricted:
            return String(localized: "Calendar access is restricted by system policy.")
        case .writeOnly:
            return String(localized: "Tasker has write-only access. Allow full calendar access so schedule events can appear.")
        case .authorized:
            return String(localized: "Connect Calendar to surface next meetings and free windows.")
        }
    }

    private var calendarPermissionStateAccessibilityID: String {
        switch calendarSnapshot.authorizationStatus {
        case .notDetermined:
            return "home.calendar.state.permission.notDetermined"
        case .denied:
            return "home.calendar.state.permission.denied"
        case .restricted:
            return "home.calendar.state.permission.restricted"
        case .writeOnly:
            return "home.calendar.state.permission.writeOnly"
        case .authorized:
            return "home.calendar.state.permission"
        }
    }

    private func handleHomeCalendarEventSelection(_ event: TaskerCalendarEventSnapshot) {
        handleHomeCalendarEventSelection(eventID: event.id, allowsTimelineHide: false)
    }

    private func handleHomeCalendarEventSelection(eventID: String, allowsTimelineHide: Bool) {
        suppressNextCalendarScheduleOpen = true
        selectedHomeCalendarEventDetail = HomeCalendarEventDetailSelection(
            eventID: eventID,
            selectedDate: viewModel.selectedDate,
            allowsTimelineHide: allowsTimelineHide
        )
        DispatchQueue.main.async {
            suppressNextCalendarScheduleOpen = false
        }
    }

    private func handleOpenScheduleAction() {
        if suppressNextCalendarScheduleOpen {
            suppressNextCalendarScheduleOpen = false
            return
        }
        onOpenCalendarSchedule()
    }

    private var weeklySummaryCard: some View {
        HomeWeeklySummaryCard(
            summary: chromeSnapshot.weeklySummary,
            isLoading: chromeSnapshot.weeklySummaryIsLoading,
            errorMessage: chromeSnapshot.weeklySummaryErrorMessage,
            onPrimaryAction: {
                guard let summary = chromeSnapshot.weeklySummary else { return }
                switch summary.ctaState {
                case .planThisWeek, .planUpcomingWeek:
                    onOpenWeeklyPlanner()
                case .reviewWeek:
                    onOpenWeeklyReview()
                }
            },
            onRetryAction: onRetryWeeklySummary
        )
        .accessibilityIdentifier("home.weeklySummary.card")
    }

    private var taskListFooterContent: AnyView? {
        guard tasksSnapshot.activeQuickView != .today else { return nil }
        return AnyView(
            persistentReplanDayEntry
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
        )
    }

    private var timelineFooterModules: AnyView? {
        guard tasksSnapshot.activeQuickView == .today else { return nil }

        let hasWeeklySummary = chromeSnapshot.weeklySummary != nil
            || chromeSnapshot.weeklySummaryIsLoading
            || chromeSnapshot.weeklySummaryErrorMessage != nil
        let hasPrimaryHabits = habitsSnapshot.habitHomeSectionState.primaryRows.isEmpty == false
        let hasRecoveryHabits = habitsSnapshot.habitHomeSectionState.recoveryRows.isEmpty == false

        guard hasWeeklySummary || hasPrimaryHabits || hasRecoveryHabits else { return nil }

        return AnyView(
            VStack(alignment: .leading, spacing: spacing.s12) {
                if hasPrimaryHabits {
                    habitsSectionCard
                }

                if hasRecoveryHabits {
                    recoveryHabitsSectionCard
                }

                if hasWeeklySummary {
                    weeklySummaryCard
                }
            }
        )
    }

    private var persistentReplanDayEntry: some View {
        let summary = overlaySnapshot.replanState.persistentSummary
        return NeedsReplanTrayView(
            title: summary.persistentTitle,
            subtitle: summary.persistentSubtitle,
            callToAction: summary.persistentCallToAction,
            accessibilityHint: "Opens Replan Day.",
            accessibilityIdentifier: "home.replanDay.entry",
            isProminent: false
        ) {
            viewModel.openNeedsReplanLauncher()
        }
    }

    private var shouldShowDueTodayAgenda: Bool {
        chromeSnapshot.activeScope.quickView == .today && tasksSnapshot.dueTodaySection?.rows.isEmpty == false
    }

    private var passiveTrackingRailCards: [QuietTrackingRailCardPresentation] {
        habitsSnapshot.quietTrackingSummaryState.railCards
    }

    private var passiveTrackingRailHorizontalInset: CGFloat {
        5
    }

    private var passiveTrackingRailLayout: QuietTrackingRailLayoutSpec {
        QuietTrackingRailLayoutSpec.resolve(
            viewportWidth: passiveTrackingRailViewportWidth,
            totalCardCount: passiveTrackingRailCards.count,
            historyCellCount: passiveTrackingRailCards.map(\.historyCells.count).max() ?? 0,
            interItemSpacing: spacing.s8
        )
    }

    private var passiveTrackingRail: some View {
        let layout = passiveTrackingRailLayout

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s8) {
                ForEach(passiveTrackingRailCards) { card in
                    passiveTrackingRailButton(for: card, layout: layout)
                        .frame(width: layout.slotWidth, alignment: .leading)
                }
            }
            .padding(.horizontal, spacing.s16)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            max(proxy.size.width - (spacing.s16 * 2), 0)
        } action: { newWidth in
            guard abs(newWidth - passiveTrackingRailViewportWidth) > 0.5 else { return }
            passiveTrackingRailViewportWidth = newWidth
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            guard abs(newHeight - measuredPassiveTrackingRailHeight) > 0.5 else { return }
            measuredPassiveTrackingRailHeight = newHeight
        }
        .accessibilityIdentifier("home.passiveTracking.rail")
    }

    private func passiveTrackingRailButton(
        for card: QuietTrackingRailCardPresentation,
        layout: QuietTrackingRailLayoutSpec
    ) -> some View {
        let visibleDayCount = min(layout.visibleDayCount, card.historyCells.count)

        return Button {
            openHabitDetail(habitID: card.habitID)
        } label: {
            QuietTrackingRailStreakWidget(
                card: card,
                slotWidth: layout.slotWidth,
                visibleDayCount: visibleDayCount
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityIdentifier("home.passiveTracking.card.\(card.id)")
        .accessibilityHint("Opens habit details for \(card.title)")
    }

    private var todayAgendaHeader: some View {
        HStack(alignment: .center, spacing: spacing.s8) {
            Label("Today Agenda", systemImage: "list.bullet.rectangle.portrait")
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker.textPrimary)
            Spacer(minLength: 0)
            Text("\(tasksSnapshot.todayAgendaSectionState.totalCount)")
                .font(.tasker(.caption2).weight(.semibold))
                .foregroundStyle(Color.tasker.textSecondary)
                .padding(.horizontal, spacing.s8)
                .padding(.vertical, spacing.s4)
                .background(Color.tasker.surfaceSecondary)
                .clipShape(Capsule())
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s4)
        .accessibilityIdentifier("home.todayAgenda.header")
    }

    private var habitsSectionCard: some View {
        HomeHabitSectionCardHost(
            title: "Habits",
            summaryLine: "\(habitsSnapshot.habitHomeSectionState.totalCount) active · \(habitsSnapshot.habitHomeSectionState.onStreakCount) streak · \(habitsSnapshot.habitHomeSectionState.atRiskCount) risk",
            rows: habitsSnapshot.habitHomeSectionState.primaryRows,
            accessibilityIdentifier: "home.habits.section",
            onOpenBoard: { showHabitBoardPresented = true },
            onPrimaryAction: handleHabitPrimaryAction(_:),
            onSecondaryAction: handleHabitSecondaryAction(_:),
            onRowAction: handleHabitRowAction(_:),
            onLastCellAction: handleHabitLastCellAction(_:),
            onOpenHabit: openHabitDetail
        )
        .equatable()
    }

    private var recoveryHabitsSectionCard: some View {
        HomeHabitSectionCardHost(
            title: "Recovery",
            summaryLine: "\(habitsSnapshot.habitHomeSectionState.recoveryRows.count) in recovery",
            rows: habitsSnapshot.habitHomeSectionState.recoveryRows,
            accessibilityIdentifier: "home.habits.recovery",
            onOpenBoard: { showHabitBoardPresented = true },
            onPrimaryAction: handleHabitPrimaryAction(_:),
            onSecondaryAction: handleHabitSecondaryAction(_:),
            onRowAction: handleHabitRowAction(_:),
            onLastCellAction: handleHabitLastCellAction(_:),
            onOpenHabit: openHabitDetail
        )
        .equatable()
    }

    private func handleHabitPrimaryAction(_ habit: HomeHabitRow) {
        performHabitPrimaryAction(habit, source: "habit_home")
    }

    private func handleHabitSecondaryAction(_ habit: HomeHabitRow) {
        performHabitSecondaryAction(habit, source: "habit_home")
    }

    private func handleHabitRowAction(_ habit: HomeHabitRow) {
        performHabitRowAction(habit, source: "habit_home_row_tap")
    }

    private func handleHabitLastCellAction(_ habit: HomeHabitRow) {
        performHabitLastCellAction(habit, source: "habit_home_last_cell")
    }

    private var habitDetailFallbackRows: [HomeHabitRow] {
        habitsSnapshot.habitHomeSectionState.primaryRows
        + habitsSnapshot.habitHomeSectionState.recoveryRows
        + habitsSnapshot.quietTrackingSummaryState.stableRows
    }

    private func makeFallbackHabitLibraryRow(from habit: HomeHabitRow) -> HabitLibraryRow {
        HabitLibraryRow(
            habitID: habit.habitID,
            title: habit.title,
            kind: habit.kind,
            trackingMode: habit.trackingMode,
            cadence: habit.cadence,
            lifeAreaID: habit.lifeAreaID,
            lifeAreaName: habit.lifeAreaName,
            projectID: habit.projectID,
            projectName: habit.projectName,
            icon: HabitIconMetadata(symbolName: habit.iconSymbolName, categoryKey: "home_fallback"),
            colorHex: habit.accentHex,
            isPaused: false,
            isArchived: false,
            currentStreak: habit.currentStreak,
            bestStreak: habit.bestStreak,
            last14Days: habit.last14Days,
            nextDueAt: habit.dueAt,
            lastCompletedAt: nil,
            reminderWindowStart: nil,
            reminderWindowEnd: nil,
            notes: habit.helperText
        )
    }

    private func openHabitDetail(_ habit: HomeHabitRow) {
        HomePerformanceSignposts.openDetailTap()
        TaskerPerformanceTrace.event("HabitDetailTapReceived")
        if let row = viewModel.habitLibraryRow(for: habit.habitID) {
            selectedHomeHabitRow = row
            return
        }

        // Fallback keeps detail navigation available when Home rows are ready
        // before the library cache hydrates.
        selectedHomeHabitRow = makeFallbackHabitLibraryRow(from: habit)
    }

    private func openHabitDetail(habitID: UUID) {
        HomePerformanceSignposts.openDetailTap()
        TaskerPerformanceTrace.event("HabitDetailTapReceived")

        if let row = viewModel.habitLibraryRow(for: habitID) {
            selectedHomeHabitRow = row
            return
        }

        if let fallback = habitDetailFallbackRows.first(where: { $0.habitID == habitID }) {
            selectedHomeHabitRow = makeFallbackHabitLibraryRow(from: fallback)
            return
        }
    }

    private func presentHabitBoardFromDeepLink() {
        showHabitLibraryPresented = false
        selectedHomeHabitRow = nil
        showHabitBoardPresented = true
    }

    private func presentHabitLibraryFromDeepLink() {
        selectedHomeHabitRow = nil
        showHabitBoardPresented = false
        showHabitLibraryPresented = true
    }

    private func presentHabitDetailFromDeepLink(habitID: UUID) {
        showHabitLibraryPresented = false
        showHabitBoardPresented = false
        selectedHomeHabitRow = nil
        if let row = viewModel.habitLibraryRow(for: habitID) {
            selectedHomeHabitRow = row
            return
        }

        if let fallback = habitDetailFallbackRows.first(where: { $0.habitID == habitID }) {
            selectedHomeHabitRow = makeFallbackHabitLibraryRow(from: fallback)
            return
        }

        snackbar = SnackbarData(message: "Couldn't find that habit. Opening Habit Board.")
        showHabitBoardPresented = true
    }

    private func beginHabitMutationSignpost(trackLastCellTap: Bool = false) {
        HomePerformanceSignposts.endHabitMutation(activeHabitMutationInterval)
        activeHabitMutationInterval = HomePerformanceSignposts.beginHabitMutation()

        if trackLastCellTap {
            HomePerformanceSignposts.endLastCellTap(activeLastCellTapInterval)
            activeLastCellTapInterval = HomePerformanceSignposts.beginLastCellTap()
        }
    }

    private func performHabitPrimaryAction(_ habit: HomeHabitRow, source: String) {
        beginHabitMutationSignpost()
        switch (habit.kind, habit.trackingMode) {
        case (_, .lapseOnly):
            viewModel.lapseHabit(habit, source: source)
        case (.positive, _):
            viewModel.completeHabit(habit, source: source)
        case (.negative, .dailyCheckIn):
            viewModel.completeHabit(habit, source: source)
        }
    }

    private func performHabitSecondaryAction(_ habit: HomeHabitRow, source: String) {
        beginHabitMutationSignpost()
        switch (habit.kind, habit.trackingMode) {
        case (.positive, _):
            viewModel.skipHabit(habit, source: source)
        case (.negative, .dailyCheckIn):
            viewModel.lapseHabit(habit, source: source)
        case (.negative, .lapseOnly):
            break
        }
    }

    private func performHabitRowAction(_ habit: HomeHabitRow, source: String) {
        TaskerPerformanceTrace.event("home.habitRowTap.accepted")
        HomePerformanceSignposts.lastCellTapAccepted()
        beginHabitMutationSignpost(trackLastCellTap: true)
        viewModel.performHabitLastCellAction(habit, source: source)
    }

    private func performHabitLastCellAction(_ habit: HomeHabitRow, source: String) {
        HomePerformanceSignposts.lastCellTapAccepted()
        beginHabitMutationSignpost(trackLastCellTap: true)
        viewModel.performHabitLastCellAction(habit, source: source)
    }

    @ViewBuilder
    private var dueTodayAgendaSection: some View {
        let rows = Array((tasksSnapshot.dueTodaySection?.rows ?? []).prefix(5))
        let hasHabitRows = rows.contains { row in
            if case .habit = row { return true }
            return false
        }

        fullBleedTaskListHeaderModule {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                    Label("Due today", systemImage: "calendar.badge.clock")
                        .font(.tasker(.headline))
                        .foregroundColor(Color.tasker.textPrimary)

                    Spacer(minLength: 0)

                    Text("\(tasksSnapshot.dueTodaySection?.rows.count ?? 0)")
                        .font(.tasker(.caption2).weight(.semibold))
                        .foregroundColor(Color.tasker.textSecondary)
                        .padding(.horizontal, spacing.s8)
                        .padding(.vertical, spacing.s4)
                        .background(Color.tasker.surfaceSecondary)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, spacing.s16)
                .padding(.bottom, spacing.s8)

                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        dueTodayAgendaRow(row, showTypeBadge: hasHabitRows)

                        if index < rows.count - 1 {
                            HomeTaskRowDivider()
                        }
                    }
                }
            }
            .padding(.vertical, spacing.s12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.dueTodayAgenda.section")
        }
    }

    @ViewBuilder
    private func dueTodayAgendaRow(_ row: HomeTodayRow, showTypeBadge: Bool) -> some View {
        switch row {
        case .task(let task):
            let fallbackIconSymbolName = projectIconSymbolName(for: task.projectID)
            TaskRowView(
                task: task,
                fallbackIconSymbolName: fallbackIconSymbolName,
                accentHex: HomeTaskTintResolver.rowAccentHex(
                    for: row,
                    projectsByID: tasksSnapshot.projectsByID,
                    lifeAreasByID: lifeAreasByID
                ),
                showTypeBadge: showTypeBadge,
                isInOverdueSection: task.isOverdue,
                tagNameByID: tasksSnapshot.tagNameByID,
                todayXPSoFar: tasksSnapshot.todayXPSoFar,
                isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled,
                isTaskDragEnabled: false,
                metadataPolicy: .homeUnifiedList,
                chromeStyle: .flatHomeList,
                onTap: { onTaskTap(task) },
                onToggleComplete: {
                    trackTaskToggle(task, source: "due_today_agenda")
                    onToggleComplete(task)
                },
                onDelete: { onDeleteTask(task) },
                onReschedule: { onRescheduleTask(task) },
                onPromoteToFocus: { promoteAgendaTaskToFocus(task) }
            )
            .equatable()

        case .habit(let habit):
            HomeHabitRowView(
                row: habit,
                onPrimaryAction: {
                    performHabitPrimaryAction(habit, source: "due_today_agenda")
                },
                onSecondaryAction: {
                    performHabitSecondaryAction(habit, source: "due_today_agenda")
                },
                onRowAction: {
                    performHabitRowAction(habit, source: "due_today_agenda_row_tap")
                },
                onOpenDetail: {
                    openHabitDetail(habit)
                },
                onLastCellAction: {
                    performHabitLastCellAction(habit, source: "due_today_agenda_last_cell")
                }
            )
        }
    }

    private func projectIconSymbolName(for projectID: UUID) -> String? {
        tasksSnapshot.projectsByID[projectID]?.icon.systemImageName
    }

    private var focusStrip: some View {
        FocusZone(
            rows: tasksSnapshot.focusNowSectionState.rows,
            maxVisibleRows: 3,
            canDrag: false,
            pinnedTaskIDs: tasksSnapshot.focusNowSectionState.pinnedTaskIDs,
            shellPhase: shellPhase,
            insightForTaskID: { taskID in
                viewModel.evaFocusInsight(for: taskID)
            },
            onWhy: {
                viewModel.openFocusWhy()
            },
            onPinTask: { task in
                pinFocusTask(task)
            },
            onUnpinTask: { task in
                unpinFocusTask(task)
            },
            onTaskTap: { task in
                onTaskTap(task)
            },
            onToggleComplete: { task in
                trackTaskToggle(task, source: "focus_strip")
                onToggleComplete(task)
            },
            onStartFocus: { task in
                onStartFocus(task)
            },
            onTaskDragStarted: { task in
                trackTaskDragStarted(task, source: "focus_strip")
            },
            onCompleteHabit: { habit in
                viewModel.completeHabit(habit, source: "focus_strip")
            },
            onSkipHabit: { habit in
                viewModel.skipHabit(habit, source: "focus_strip")
            },
            onLapseHabit: { habit in
                viewModel.lapseHabit(habit, source: "focus_strip")
            },
            onCycleHabit: { habit in
                performHabitRowAction(habit, source: "focus_strip_row_tap")
            },
            onOpenHabit: { habit in
                openHabitDetail(habit)
            },
            onDrop: handleFocusDrop
        )
    }

    private var xpBurstOverlay: some View {
        XPCelebrationView(xpValue: xpBurstValue, isPresented: $showXPBurst)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 100)
            .allowsHitTesting(false)
    }

    /// Executes trackTaskToggle.
    private func trackTaskToggle(_ task: TaskDefinition, source: String) {
        viewModel.trackHomeInteraction(
            action: "home_task_toggle",
            metadata: [
                "source": source,
                "task_id": task.id.uuidString,
                "current_state": task.isComplete ? "done" : "open"
            ]
        )
    }

    /// Executes trackTaskDragStarted.
    private func trackTaskDragStarted(_ task: TaskDefinition, source: String) {
        var metadata = focusScopeMetadata(source: source, taskID: task.id)
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
        viewModel.trackHomeInteraction(
            action: "home_focus_drag_started",
            metadata: metadata
        )
    }

    /// Executes pinFocusTask.
    private func pinFocusTask(_ task: TaskDefinition) {
        let result = viewModel.pinTaskToFocus(task.id)
        var metadata = focusScopeMetadata(source: "focus_strip_pin", taskID: task.id)
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count

        switch result {
        case .pinned:
            TaskerFeedback.success()
            viewModel.trackHomeInteraction(action: "home_focus_pin", metadata: metadata)
        case .alreadyPinned:
            TaskerFeedback.selection()
        case .capacityReached(let limit):
            TaskerFeedback.light()
            metadata["limit"] = limit
            viewModel.trackHomeInteraction(action: "home_focus_pin_rejected_capacity", metadata: metadata)
        case .taskIneligible:
            TaskerFeedback.selection()
        }
    }

    private func promoteAgendaTaskToFocus(_ task: TaskDefinition) {
        let result = viewModel.promoteTaskToFocus(task.id)
        var metadata = focusScopeMetadata(source: "today_agenda_promote", taskID: task.id)
        metadata["visible_count"] = viewModel.focusNowSectionState.visibleCount
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count

        switch result {
        case .promoted:
            TaskerFeedback.success()
            viewModel.trackHomeInteraction(action: "home_focus_promote", metadata: metadata)
        case .alreadyPinned:
            TaskerFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_promote_already_pinned", metadata: metadata)
        case .alreadyVisible:
            TaskerFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_promote_already_visible", metadata: metadata)
        case .replacementRequired(let currentFocusTaskIDs):
            pendingFocusPromotionTask = task
            focusReplacementOptions = currentFocusTaskIDs.compactMap(viewModel.taskSnapshot(for:))
            TaskerFeedback.light()
            metadata["replacement_count"] = focusReplacementOptions.count
            viewModel.trackHomeInteraction(action: "home_focus_promote_replace_prompt", metadata: metadata)
        case .taskIneligible:
            TaskerFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_promote_rejected_ineligible", metadata: metadata)
        }
    }

    private func replaceFocusTask(
        _ promotedTask: TaskDefinition,
        replacing focusTask: TaskDefinition,
        source: String
    ) {
        let result = viewModel.replaceFocusTask(with: promotedTask.id, replacing: focusTask.id)
        var metadata = focusScopeMetadata(source: source, taskID: promotedTask.id)
        metadata["replaced_task_id"] = focusTask.id.uuidString

        switch result {
        case .promoted:
            TaskerFeedback.success()
            viewModel.trackHomeInteraction(action: "home_focus_replace", metadata: metadata)
        case .alreadyVisible:
            TaskerFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_replace_already_visible", metadata: metadata)
        case .alreadyPinned:
            TaskerFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_replace_already_pinned", metadata: metadata)
        case .replacementRequired:
            TaskerFeedback.light()
        case .taskIneligible:
            TaskerFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_replace_rejected_ineligible", metadata: metadata)
        }

        clearPendingFocusReplacement()
    }

    private func clearPendingFocusReplacement() {
        pendingFocusPromotionTask = nil
        focusReplacementOptions = []
    }

    private func refreshFocusWhyShuffleCandidates() {
        _ = viewModel.refreshFocusWhyShuffleCandidates()
        TaskerFeedback.selection()
    }

    private func replaceFocusTaskFromWhySheet(_ candidate: TaskDefinition, replacing focusTask: TaskDefinition) {
        replaceFocusTask(candidate, replacing: focusTask, source: "focus_why_replace")
        _ = viewModel.refreshFocusWhyShuffleCandidates()
    }

    /// Executes unpinFocusTask.
    private func unpinFocusTask(_ task: TaskDefinition) {
        guard viewModel.pinnedFocusTaskIDs.contains(task.id) else { return }
        viewModel.unpinTaskFromFocus(task.id)
        TaskerFeedback.selection()

        var metadata = focusScopeMetadata(source: "focus_strip_unpin", taskID: task.id)
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
        viewModel.trackHomeInteraction(action: "home_focus_unpin", metadata: metadata)
    }

    /// Executes handleFocusDrop.
    private func handleFocusDrop(providers: [NSItemProvider]) -> Bool {
        guard viewModel.canUseManualFocusDrag else { return false }

        return loadTaskIDFromDrop(providers: providers) { taskID in
            guard let taskID else { return }

            let pinResult = viewModel.pinTaskToFocus(taskID)
            var metadata = focusScopeMetadata(source: "task_list", taskID: taskID)
            metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count

            switch pinResult {
            case .pinned:
                TaskerFeedback.success()
                viewModel.trackHomeInteraction(action: "home_focus_dropped_in", metadata: metadata)
            case .alreadyPinned:
                TaskerFeedback.selection()
                metadata["result"] = "already_pinned"
                viewModel.trackHomeInteraction(action: "home_focus_dropped_in", metadata: metadata)
            case .capacityReached(let limit):
                TaskerFeedback.light()
                metadata["limit"] = limit
                viewModel.trackHomeInteraction(action: "home_focus_drop_rejected_capacity", metadata: metadata)
            case .taskIneligible:
                TaskerFeedback.selection()
            }
        }
    }

    /// Executes handleListDrop.
    private func handleListDrop(providers: [NSItemProvider]) -> Bool {
        guard viewModel.canUseManualFocusDrag else { return false }

        return loadTaskIDFromDrop(providers: providers) { taskID in
            guard let taskID else { return }
            let wasPinned = viewModel.pinnedFocusTaskIDs.contains(taskID)
            guard wasPinned else { return }

            viewModel.unpinTaskFromFocus(taskID)
            TaskerFeedback.selection()

            var metadata = focusScopeMetadata(source: "focus_strip", taskID: taskID)
            metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
            viewModel.trackHomeInteraction(action: "home_focus_dropped_out", metadata: metadata)
        }
    }

    /// Executes loadTaskIDFromDrop.
    private func loadTaskIDFromDrop(
        providers: [NSItemProvider],
        completion: @escaping (UUID?) -> Void
    ) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            completion(nil)
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            let rawValue = (object as? NSString)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let taskID = rawValue.flatMap(UUID.init(uuidString:))
            DispatchQueue.main.async {
                completion(taskID)
            }
        }
        return true
    }

    /// Executes focusScopeMetadata.
    private func focusScopeMetadata(source: String, taskID: UUID) -> [String: Any] {
        [
            "source": source,
            "task_id": taskID.uuidString,
            "quick_view": viewModel.activeScope.quickView.analyticsAction,
            "scope": scopeAnalyticsName
        ]
    }

    private var scopeAnalyticsName: String {
        switch viewModel.activeScope {
        case .today:
            return "today"
        case .customDate:
            return "custom_date"
        case .upcoming:
            return "upcoming"
        case .overdue:
            return "overdue"
        case .done:
            return "done"
        case .morning:
            return "morning"
        case .evening:
            return "evening"
        }
    }

    private var momentumGuidanceText: String {
        chromeSnapshot.momentumGuidanceText
    }

    private func handleXPResult(_ result: XPEventResult?) {
        guard let result, let event = CelebrationEvent.from(result) else { return }
        guard let routed = celebrationRouter.route(event: event) else { return }
        let routedEvent = routed.event
        semanticCelebrationXP = routedEvent.awardedXP

        switch routedEvent.kind {
        case .milestone:
            if let milestone = routedEvent.milestone {
                milestoneValue = milestone
                showMilestone = true
            }
        case .levelUp:
            levelUpValue = routedEvent.level
            showLevelUp = true
        case .achievementUnlock:
            if V2FeatureFlags.gamificationOverhaulV1Enabled {
                showAchievementUnlockToast(for: routedEvent)
            } else {
                xpBurstValue = routedEvent.awardedXP
                showXPBurst = true
            }
        case .xpBurst:
            xpBurstValue = routedEvent.awardedXP
            showXPBurst = true
        }

        if routedEvent.awardedXP >= 7 {
            TaskerFeedback.success()
        } else if routedEvent.awardedXP >= 4 {
            TaskerFeedback.medium()
        } else {
            TaskerFeedback.light()
        }

        viewModel.trackHomeInteraction(
            action: "home_reward_xp_burst",
            metadata: ["delta": routedEvent.awardedXP, "new_score": viewModel.dailyScore, "kind": routedEvent.kind.rawValue]
        )
    }

    private func toggleInsights(source: String) {
        let shouldOpenInsights = activeFace != .analytics
        if shouldOpenInsights {
            openAnalytics(source: source, launchDefaultInsights: true)
        } else {
            closeAnalytics(source: source)
        }
    }

    private func setActiveFace(_ face: HomeForedropFace, animated: Bool) {
        if animated {
            withAnimation(foredropFlipAnimation) {
                faceCoordinator.setActiveFace(face)
            }
        } else {
            faceCoordinator.setActiveFace(face)
        }
    }

    private func openAnalytics(source: String, launchDefaultInsights: Bool) {
        onOpenAnalytics(source, launchDefaultInsights)
    }

    private func closeAnalytics(source: String) {
        onCloseAnalytics(source)
    }

    private func toggleSearch(source: String) {
        let shouldOpenSearch = activeFace != .search
        if shouldOpenSearch {
            openSearch(source: source)
        } else {
            closeSearch(source: source)
        }
    }

    private func openSearch(source: String) {
        onOpenSearch(source)
    }

    private var taskListScrollResetKey: String {
        switch chromeSnapshot.activeScope {
        case .today:
            return "today"
        case .customDate(let date):
            return "customDate-\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)"
        case .upcoming:
            return "upcoming"
        case .overdue:
            return "overdue"
        case .done:
            return "done"
        case .morning:
            return "morning"
        case .evening:
            return "evening"
        }
    }

    private func closeSearch(source: String) {
        onCloseSearch(source)
    }

    private func returnToTasks(source: String) {
        onReturnToTasks(source)
    }

    private func trackSearchFlipOpen(source: String) {
        viewModel.trackHomeInteraction(
            action: "home_search_flip_open",
            metadata: ["source": source]
        )
    }

    private func trackSearchFlipClose(source: String) {
        viewModel.trackHomeInteraction(
            action: "home_search_flip_close",
            metadata: ["source": source]
        )
    }

    private func showAchievementUnlockToast(for event: CelebrationEvent) {
        guard let achievementKey = event.achievementKey else { return }
        guard !shownUnlockKeys.contains(achievementKey) else { return }
        shownUnlockKeys.insert(achievementKey)

        let badgeName = AchievementCatalog.definition(for: achievementKey)?.name ?? "Badge"
        snackbar = SnackbarData(
            message: "Achievement unlocked: \(badgeName)",
            actions: [
                SnackbarAction(title: "View badge") {
                    viewModel.launchInsights(
                        InsightsLaunchRequest(
                            targetTab: .systems,
                            highlightedAchievementKey: achievementKey
                        )
                    )
                }
            ]
        )
    }

    private func playHabitMutationFeedbackHaptic(_ haptic: HomeHabitMutationFeedbackHaptic) {
        switch haptic {
        case .selection:
            TaskerFeedback.selection()
        case .success:
            TaskerFeedback.success()
        case .warning:
            TaskerFeedback.warning()
        }
    }

    private func startNextActionFocusTimer() {
        guard isNextActionFocusRequestInFlight == false else { return }
        isNextActionFocusRequestInFlight = true
        TaskerFeedback.selection()
        viewModel.trackHomeInteraction(
            action: "home_next_action_focus_start_tapped",
            metadata: [
                "source": "next_action_module_15min_focus",
                "target_duration_seconds": Self.nextActionFocusDurationSeconds
            ]
        )
        viewModel.startFocusSession(taskID: nil, targetDurationSeconds: Self.nextActionFocusDurationSeconds) { result in
            isNextActionFocusRequestInFlight = false
            switch result {
            case .success(let session):
                activeNextActionFocusSession = session
                showNextActionFocusTimer = true
            case .failure(let error):
                if let focusError = error as? FocusSessionError, case .alreadyActive = focusError {
                    resumeNextActionFocusSession(source: "next_action_module_15min_focus")
                } else {
                    logWarning(
                        event: "focus_session_start_failed",
                        message: "Failed to start focus session from next action module",
                        fields: [
                            "source": "next_action_module_15min_focus",
                            "error": error.localizedDescription
                        ]
                    )
                    snackbar = SnackbarData(message: "Couldn't start focus timer")
                }
            }
        }
    }

    private func resumeNextActionFocusSession(source: String) {
        viewModel.fetchActiveFocusSession { result in
            switch result {
            case .success(let session):
                guard let session else {
                    viewModel.setQuickView(.today)
                    logWarning(
                        event: "focus_session_resume_missing",
                        message: "Expected an active focus session to resume, but none was found",
                        fields: ["source": source]
                    )
                    snackbar = SnackbarData(message: "No active focus timer was found")
                    return
                }
                activeNextActionFocusSession = session
                showNextActionFocusTimer = true
            case .failure(let error):
                logWarning(
                    event: "focus_session_resume_failed",
                    message: "Failed to resume active focus session",
                    fields: [
                        "source": source,
                        "error": error.localizedDescription
                    ]
                )
                snackbar = SnackbarData(message: "Couldn't resume focus timer")
            }
        }
    }

    private func finishNextActionFocusSession(sessionID: UUID, source: String) {
        guard isNextActionFocusEnding == false else { return }
        isNextActionFocusEnding = true
        viewModel.endFocusSession(sessionID: sessionID) { result in
            isNextActionFocusEnding = false
            switch result {
            case .success(let focusResult):
                showNextActionFocusTimer = false
                activeNextActionFocusSession = nil
                viewModel.trackHomeInteraction(
                    action: "focus_session_finished",
                    metadata: [
                        "source": source,
                        "duration_seconds": focusResult.session.durationSeconds,
                        "awarded_xp": focusResult.xpResult?.awardedXP ?? 0
                    ]
                )
                DispatchQueue.main.async {
                    nextActionFocusSummaryResult = focusResult
                    showNextActionFocusSummary = true
                }
            case .failure(let error):
                logWarning(
                    event: "focus_session_end_failed",
                    message: "Failed to end focus session from next action module",
                    fields: [
                        "source": source,
                        "error": error.localizedDescription
                    ]
                )
                snackbar = SnackbarData(message: "Couldn't finish focus timer")
                showNextActionFocusTimer = false
                activeNextActionFocusSession = nil
            }
        }
    }

    private func dismissNextActionFocusSummary() {
        showNextActionFocusSummary = false
        nextActionFocusSummaryResult = nil
    }

    private func resolveTaskForFocusSession(taskID: UUID?) -> TaskDefinition? {
        guard let taskID else { return nil }
        var candidates: [TaskDefinition] = []
        candidates.append(contentsOf: viewModel.focusTasks)
        candidates.append(contentsOf: viewModel.morningTasks)
        candidates.append(contentsOf: viewModel.eveningTasks)
        candidates.append(contentsOf: viewModel.overdueTasks)
        return candidates.first(where: { $0.id == taskID })
    }

    @ViewBuilder
    private var reflectPlanPresentation: some View {
        if let dailyReflectPlanViewModel {
            ReflectPlanScreen(
                viewModel: dailyReflectPlanViewModel,
                onClose: {
                    showDailyReflectPlan = false
                }
            )
        } else {
            Color.clear
                .ignoresSafeArea()
                .onAppear {
                    showDailyReflectPlan = false
                }
        }
    }

    private func openDailyReflectPlan(preferredReflectionDate: Date? = nil) {
        dailyReflectPlanViewModel = PresentationDependencyContainer.shared.makeDailyReflectPlanViewModel(
            preferredReflectionDate: preferredReflectionDate,
            analyticsTracker: { action, metadata in
                viewModel.trackHomeInteraction(action: action, metadata: metadata.reduce(into: [String: Any]()) { partialResult, item in
                    partialResult[item.key] = item.value
                })
            },
            onComplete: { result in
                viewModel.refreshAfterDailyReflectPlanSave(planningDate: result.target.planningDate)
                showDailyReflectPlan = false
            }
        )
        showDailyReflectPlan = true
    }
}

private struct CalendarCardChromeModifier: ViewModifier {
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, spacing.s16)
            .padding(.vertical, spacing.s12)
            .background(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                    .fill(Color.tasker.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                    .stroke(Color.tasker.strokeHairline.opacity(0.72), lineWidth: 1)
            )
    }
}

private struct HomeStaggerModifier: ViewModifier {
    let isEnabled: Bool
    let index: Int

    func body(content: Content) -> some View {
        if isEnabled {
            content.enhancedStaggeredAppearance(index: index)
        } else {
            content
        }
    }
}

private struct HomeDenseSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: cornerRadius
                )
                .fill(Color.tasker.surfaceTertiary)
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: cornerRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: cornerRadius
                    )
                    .stroke(Color.tasker.strokeHairline.opacity(0.35), lineWidth: 1)
                )
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: cornerRadius
                )
            )
    }
}

struct TaskerProgressBar: View {
    let progress: Double
    let colors: [Color]
    var trackColor: Color = Color.tasker.surfaceSecondary
    var height: CGFloat = 6
    var animate: Bool = true

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(trackColor)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(x: clampedProgress, y: 1, anchor: .leading)
                    .animation(animate ? .spring(response: 0.34, dampingFraction: 0.82) : .linear(duration: 0.01), value: clampedProgress)
            }
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityValue("\(Int((clampedProgress * 100).rounded())) percent")
    }
}

enum HomeiPadDestination: String, CaseIterable, Identifiable {
    case tasks
    case schedule
    case search
    case analytics
    case addTask
    case settings
    case lifeManagement
    case projects
    case chat
    case models

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks: return "Tasks"
        case .schedule: return "Schedule"
        case .search: return "Search"
        case .analytics: return "Analytics"
        case .addTask: return "Add Task"
        case .settings: return "Settings"
        case .lifeManagement: return "Life Management"
        case .projects: return "Projects"
        case .chat: return "Eva"
        case .models: return "Models"
        }
    }

    var icon: String {
        switch self {
        case .tasks: return "checklist"
        case .schedule: return "calendar.badge.clock"
        case .search: return "magnifyingglass"
        case .analytics: return "chart.bar.xaxis"
        case .addTask: return "plus.circle"
        case .settings: return "gearshape"
        case .lifeManagement: return "square.grid.2x2"
        case .projects: return "folder"
        case .chat: return "sparkles"
        case .models: return "cpu"
        }
    }

    var homeFace: HomeForedropFace? {
        switch self {
        case .tasks: return .tasks
        case .schedule: return .schedule
        case .search: return .search
        case .analytics: return .analytics
        case .chat: return .chat
        case .addTask, .settings, .lifeManagement, .projects, .models: return nil
        }
    }

    var isPrimaryHomeDestination: Bool {
        homeFace != nil
    }
}

@MainActor
enum HomeiPadModalRequest: Equatable {
    case addTask
}

@MainActor
final class HomeiPadShellState: ObservableObject {
    @Published var destination: HomeiPadDestination = .tasks
    @Published var selectedTask: TaskDefinition?
    @Published var modalRequest: HomeiPadModalRequest?
}

// MARK: - iPad Sidebar Sections

enum HomeiPadSidebarSection: String, CaseIterable, Identifiable {
    case primary
    case create
    case manage

    var id: String { rawValue }

    var title: String? {
        switch self {
        case .primary: return nil
        case .create: return "Create"
        case .manage: return "Manage"
        }
    }

    var destinations: [HomeiPadDestination] {
        switch self {
        case .primary: return [.tasks, .schedule, .search, .analytics]
        case .create: return [.addTask]
        case .manage: return [.lifeManagement, .projects, .chat, .models, .settings]
        }
    }
}

@MainActor
final class HomeiPadPrimarySurfaceMonitor: ObservableObject {
    private var baselineShellEpoch: Int?
    private var baselineHostID: UUID?

    func recordAppearance(hostID: UUID, destination: HomeiPadDestination, shellEpoch: Int) {
        if baselineShellEpoch != shellEpoch {
            if let previousEpoch = baselineShellEpoch {
                logWarning(
                    event: "ipadPrimarySurfaceShellEpochReset",
                    message: "Reset the iPad primary surface host baseline after an expected shell rebuild",
                    fields: [
                        "destination": destination.rawValue,
                        "previous_epoch": String(previousEpoch),
                        "next_epoch": String(shellEpoch)
                    ]
                )
            }

            baselineShellEpoch = shellEpoch
            baselineHostID = hostID
            logWarning(
                event: "ipadPrimarySurfaceMounted",
                message: "Mounted the persistent iPad primary surface host",
                fields: [
                    "destination": destination.rawValue,
                    "shell_epoch": String(shellEpoch)
                ]
            )
            return
        }

        if let baselineHostID {
            if baselineHostID != hostID {
                logWarning(
                    event: "ipadPrimarySurfaceHostRemounted",
                    message: "The iPad primary surface host was remounted",
                    fields: [
                        "destination": destination.rawValue,
                        "shell_epoch": String(shellEpoch)
                    ]
                )
                self.baselineHostID = hostID
                return
            }

            logWarning(
                event: "ipadPrimarySurfaceReused",
                message: "Reused the persistent iPad primary surface host",
                fields: [
                    "destination": destination.rawValue,
                    "shell_epoch": String(shellEpoch)
                ]
            )
            return
        }

        baselineShellEpoch = shellEpoch
        baselineHostID = hostID
        logWarning(
            event: "ipadPrimarySurfaceMounted",
            message: "Mounted the persistent iPad primary surface host",
            fields: [
                "destination": destination.rawValue,
                "shell_epoch": String(shellEpoch)
            ]
        )
    }
}

@MainActor
private final class HomeiPadPrimaryPaneLifecycle: ObservableObject {
    let id = UUID()
}

// MARK: - iPad Split Shell

private struct HomeiPadPrimaryPaneHost: View {
    @Binding var activeFace: HomeForedropFace
    let layoutClass: TaskerLayoutClass
    let destination: HomeiPadDestination
    let shellEpoch: Int
    let homeSurface: (Binding<HomeForedropFace>) -> AnyView
    @ObservedObject var monitor: HomeiPadPrimarySurfaceMonitor
    @StateObject private var lifecycle = HomeiPadPrimaryPaneLifecycle()

    var body: some View {
        homeSurface($activeFace)
            .accessibilityIdentifier("home.ipad.detail.\(destination.rawValue)")
            .onAppear {
                guard layoutClass.isPad, V2FeatureFlags.iPadPerfPrimarySurfacePersistenceV3Enabled else { return }
                monitor.recordAppearance(hostID: lifecycle.id, destination: destination, shellEpoch: shellEpoch)
            }
    }
}

struct HomeiPadSplitShellView: View {
    private enum HomeiPadShellCommand {
        case tasks
        case search
        case analytics
        case chat
        case addTask
        case settings
        case dismiss
    }

    let layoutClass: TaskerLayoutClass
    @ObservedObject var shellState: HomeiPadShellState
    let shellEpoch: Int
    let homeSurface: (Binding<HomeForedropFace>) -> AnyView
    let addTaskSurface: () -> AnyView
    let scheduleSurface: () -> AnyView
    let settingsSurface: () -> AnyView
    let lifeManagementSurface: () -> AnyView
    let projectsSurface: () -> AnyView
    let chatSurface: () -> AnyView
    let modelsSurface: () -> AnyView
    let inspectorSurface: (TaskDefinition) -> AnyView
    let onOpenTaskDetailSheet: (TaskDefinition) -> Void

    @State private var activeHomeFace: HomeForedropFace = .tasks
    @State private var showCompactSidebar = false
    @State private var showHabitLibrarySheet = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @StateObject private var primarySurfaceMonitor = HomeiPadPrimarySurfaceMonitor()

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var isPrimaryHomeDestination: Bool {
        shellState.destination.isPrimaryHomeDestination
    }

    private var showsPrimaryHomeTaskToolbarItems: Bool {
        switch shellState.destination {
        case .tasks, .search, .analytics:
            return true
        case .schedule, .chat, .addTask, .settings, .lifeManagement, .projects, .models:
            return false
        }
    }

    var body: some View {
        shellLayout
            .accessibilityIdentifier("home.ipad.shell")
            .background {
                hiddenKeyboardShortcuts
            }
            .sheet(isPresented: $showHabitLibrarySheet) {
                HabitLibraryView(
                    viewModel: PresentationDependencyContainer.shared.makeNewHabitLibraryViewModel()
                )
            }
            .onAppear {
                if let face = shellState.destination.homeFace {
                    activeHomeFace = face
                }
            }
        .onChange(of: shellState.destination) { _, newValue in
            if newValue.isPrimaryHomeDestination {
                logWarning(
                    event: "ipadPrimaryDestinationSwitchStart",
                    message: "Switched iPad primary destination",
                    fields: ["destination": newValue.rawValue]
                )
            }
            if newValue == .addTask, layoutClass != .padExpanded {
                shellState.modalRequest = .addTask
                shellState.destination = .tasks
                return
            }
            if let face = newValue.homeFace {
                activeHomeFace = face
            } else {
                shellState.selectedTask = nil
            }
        }
        .onChange(of: activeHomeFace) {
            handleActiveHomeFaceChange()
        }
    }

    @ViewBuilder
    private var shellLayout: some View {
        if layoutClass == .padCompact {
            compactShell
        } else if layoutClass == .padExpanded {
            expandedShell
        } else {
            regularShell
        }
    }

    private var compactShell: some View {
        NavigationStack {
            detailContent
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        compactSidebarToggle
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        detailToolbarItems
                    }
                }
        }
        .sheet(isPresented: $showCompactSidebar) {
            compactSidebarSheet
        }
    }

    private var expandedShell: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        } content: {
            detailContent
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        detailToolbarItems
                    }
                }
                .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: .infinity)
        } detail: {
            inspectorPanel
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 420)
                .background(Color.tasker.bgElevated)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var regularShell: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        } detail: {
            detailContent
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        detailToolbarItems
                    }
                }
        }
        .navigationSplitViewStyle(.prominentDetail)
    }

    private var hiddenKeyboardShortcuts: some View {
        Group {
            Button("") { performShellCommand(.search) }
                .keyboardShortcut("f", modifiers: .command)
            Button("") { performShellCommand(.tasks) }
                .keyboardShortcut("1", modifiers: .command)
            Button("") { performShellCommand(.search) }
                .keyboardShortcut("2", modifiers: .command)
            Button("") { performShellCommand(.analytics) }
                .keyboardShortcut("3", modifiers: .command)
            Button("") { performShellCommand(.chat) }
                .keyboardShortcut("4", modifiers: .command)
            Button("") { performShellCommand(.addTask) }
                .keyboardShortcut("n", modifiers: .command)
            Button("") { performShellCommand(.settings) }
                .keyboardShortcut(",", modifiers: .command)
            Button("") { performShellCommand(.dismiss) }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
    }

    private func analyticsName(for face: HomeForedropFace) -> String {
        switch face {
        case .tasks:
            return "tasks"
        case .schedule:
            return "schedule"
        case .analytics:
            return "analytics"
        case .search:
            return "search"
        case .chat:
            return "chat"
        }
    }

    private func handleActiveHomeFaceChange() {
        let newValue = activeHomeFace
        if layoutClass.isPad && V2FeatureFlags.iPadPerfPrimarySurfacePersistenceV3Enabled {
            logWarning(
                event: "ipadPrimaryDestinationSwitchEnd",
                message: "Completed iPad primary destination switch",
                fields: ["face": analyticsName(for: newValue)]
            )
        }
        let nextDestination = destination(for: newValue)
        if shellState.destination != nextDestination {
            shellState.destination = nextDestination
        }
    }

    // MARK: - Toolbar Items

    @ViewBuilder
    private var detailToolbarItems: some View {
        if showsPrimaryHomeTaskToolbarItems {
            Button {
                showHabitLibrarySheet = true
            } label: {
                Image(systemName: "repeat.circle")
            }
            .hoverEffect(.highlight)
            .accessibilityIdentifier("home.ipad.toolbar.manageHabits")
            .accessibilityLabel("Manage Habits")

            Button {
                performShellCommand(.addTask)
            } label: {
                Image(systemName: "plus")
            }
            .hoverEffect(.highlight)
            .accessibilityIdentifier("home.ipad.toolbar.addTask")
            .accessibilityLabel("New Task")
        }
    }

    // MARK: - Compact Sidebar Toggle

    private var compactSidebarToggle: some View {
        Button {
            showCompactSidebar = true
        } label: {
            Label(shellState.destination.title, systemImage: "sidebar.left")
                .labelStyle(.titleAndIcon)
                .frame(minWidth: 44, minHeight: 44)
        }
        .hoverEffect(.highlight)
        .accessibilityIdentifier("home.ipad.sidebar.toggle")
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: Binding<HomeiPadDestination?>(
            get: { shellState.destination },
            set: { newValue in
                if let newValue { shellState.destination = newValue }
            }
        )) {
            ForEach(HomeiPadSidebarSection.allCases) { section in
                Section {
                    ForEach(section.destinations) { dest in
                        Label(dest.title, systemImage: dest.icon)
                            .tag(dest)
                            .hoverEffect(.highlight)
                            .accessibilityIdentifier("home.ipad.destination.\(dest.rawValue)")
                    }
                } header: {
                    if let title = section.title {
                        Text(title)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.tasker.bgCanvas)
        .navigationTitle("Tasker")
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
        .accessibilityIdentifier("home.ipad.sidebar")
    }

    private var sidebarFooter: some View {
        VStack(spacing: spacing.s4) {
            Divider()
            Text("Tasker v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textQuaternary)
                .padding(.vertical, spacing.s8)
        }
        .padding(.horizontal, spacing.s16)
    }

    // MARK: - Compact Sidebar Sheet

    private var compactSidebarSheet: some View {
        NavigationStack {
            List {
                ForEach(HomeiPadSidebarSection.allCases) { section in
                    Section {
                        ForEach(section.destinations) { dest in
                            Button {
                                shellState.destination = dest
                                showCompactSidebar = false
                            } label: {
                                Label(dest.title, systemImage: dest.icon)
                            }
                            .hoverEffect(.highlight)
                            .accessibilityIdentifier("home.ipad.compact.destination.\(dest.rawValue)")
                        }
                    } header: {
                        if let title = section.title {
                            Text(title)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Navigate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showCompactSidebar = false
                    }
                }
            }
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch shellState.destination {
        case .tasks, .schedule, .search, .analytics, .chat:
            HomeiPadPrimaryPaneHost(
                activeFace: $activeHomeFace,
                layoutClass: layoutClass,
                destination: shellState.destination,
                shellEpoch: shellEpoch,
                homeSurface: homeSurface,
                monitor: primarySurfaceMonitor
            )
        case .addTask:
            if layoutClass == .padExpanded {
                addTaskSurface()
                    .accessibilityIdentifier("home.ipad.detail.addTask")
            } else {
                HomeiPadPrimaryPaneHost(
                    activeFace: $activeHomeFace,
                    layoutClass: layoutClass,
                    destination: .tasks,
                    shellEpoch: shellEpoch,
                    homeSurface: homeSurface,
                    monitor: primarySurfaceMonitor
                )
            }
        case .settings:
            settingsSurface()
                .accessibilityIdentifier("home.ipad.detail.settings")
        case .lifeManagement:
            lifeManagementSurface()
                .accessibilityIdentifier("home.ipad.detail.lifeManagement")
        case .projects:
            projectsSurface()
                .accessibilityIdentifier("home.ipad.detail.projects")
        case .models:
            modelsSurface()
                .accessibilityIdentifier("home.ipad.detail.models")
        }
    }

    // MARK: - Inspector Panel

    @ViewBuilder
    private var inspectorPanel: some View {
        if let task = shellState.selectedTask {
            NavigationStack {
                inspectorSurface(task)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text(task.title)
                                .font(.tasker(.headline))
                                .foregroundColor(Color.tasker.textPrimary)
                                .lineLimit(1)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                onOpenTaskDetailSheet(task)
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                            }
                            .hoverEffect(.highlight)
                            .accessibilityLabel("Expand to sheet")
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))
            .id(task.id)
            .accessibilityIdentifier("home.ipad.inspector.task")
        } else {
            VStack(spacing: spacing.s16) {
                Image(systemName: "rectangle.righthalf.inset.filled")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(Color.tasker.accentMuted)
                Text("No task selected")
                    .font(.tasker(.title3))
                    .foregroundColor(Color.tasker.textSecondary)
                Text("Tap a task in the list to see its details here.")
                    .font(.tasker(.body))
                    .foregroundColor(Color.tasker.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.tasker.bgCanvas)
            .accessibilityIdentifier("home.ipad.inspector.empty")
        }
    }

    private func destination(for face: HomeForedropFace) -> HomeiPadDestination {
        switch face {
        case .tasks:
            return .tasks
        case .schedule:
            return .schedule
        case .analytics:
            return .analytics
        case .search:
            return .search
        case .chat:
            return .chat
        }
    }

    private func performShellCommand(_ command: HomeiPadShellCommand) {
        switch command {
        case .tasks:
            shellState.destination = .tasks
        case .search:
            shellState.destination = .search
        case .analytics:
            shellState.destination = .analytics
        case .chat:
            shellState.destination = .chat
        case .addTask:
            if layoutClass == .padExpanded {
                shellState.destination = .addTask
            } else {
                shellState.modalRequest = .addTask
            }
        case .settings:
            shellState.destination = .settings
        case .dismiss:
            if shellState.selectedTask != nil {
                shellState.selectedTask = nil
            } else if shellState.destination != .tasks {
                shellState.destination = .tasks
            } else {
                showCompactSidebar = false
            }
        }
    }
}

private struct QuietTrackingRailStreakWidget: View {
    let card: QuietTrackingRailCardPresentation
    let slotWidth: CGFloat
    let visibleDayCount: Int

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    private var isExpandedType: Bool {
        dynamicTypeSize >= .accessibility1
    }

    private var widgetVerticalPadding: CGFloat {
        isExpandedType ? 6 : spacing.s4
    }

    private var visibleCells: [HabitBoardCell] {
        card.visibleCells(dayCount: visibleDayCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HabitBoardStripView(
                cells: visibleCells,
                family: card.colorFamily,
                mode: .compact
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: card.iconSymbolName)
                    .font(.system(size: 10, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.tasker.textSecondary.opacity(0.82))
                    .accessibilityHidden(true)

                Text(card.title)
                    .font(.tasker(.caption2).weight(.medium))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .lineLimit(isExpandedType ? 2 : 1)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: slotWidth, alignment: .leading)
        .frame(minHeight: 44, alignment: .topLeading)
        .padding(.vertical, widgetVerticalPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityValue(card.accessibilityValue(visibleDayCount: visibleDayCount))
    }
}

struct HomeiPadSettingsContainer: View {
    let onNavigateToLifeManagement: () -> Void
    let onNavigateToChats: () -> Void
    let onNavigateToModels: () -> Void
    let onRestartOnboarding: () -> Void
    let onOpenCalendarChooser: () -> Void

    @StateObject private var viewModel: SettingsViewModel

    init(
        onNavigateToLifeManagement: @escaping () -> Void,
        onNavigateToChats: @escaping () -> Void,
        onNavigateToModels: @escaping () -> Void,
        onRestartOnboarding: @escaping () -> Void,
        calendarIntegrationService: CalendarIntegrationService,
        onOpenCalendarChooser: @escaping () -> Void
    ) {
        self.onNavigateToLifeManagement = onNavigateToLifeManagement
        self.onNavigateToChats = onNavigateToChats
        self.onNavigateToModels = onNavigateToModels
        self.onRestartOnboarding = onRestartOnboarding
        self.onOpenCalendarChooser = onOpenCalendarChooser
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                calendarIntegrationService: calendarIntegrationService
            )
        )
    }

    var body: some View {
        NavigationStack {
            SettingsRootView(viewModel: viewModel)
                .onAppear {
                    viewModel.onNavigateToLifeManagement = onNavigateToLifeManagement
                    viewModel.onNavigateToChats = onNavigateToChats
                    viewModel.onNavigateToModels = onNavigateToModels
                    viewModel.onRestartOnboarding = onRestartOnboarding
                    viewModel.onOpenCalendarChooser = onOpenCalendarChooser
                }
        }
        .accessibilityIdentifier("home.ipad.detail.settings")
    }
}
