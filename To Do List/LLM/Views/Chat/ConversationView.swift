//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

extension TimeInterval {
    var formatted: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        }
        return "\(seconds)s"
    }
}

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.tasker(.accentPrimary))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.top, TaskerTheme.Spacing.xs)
        .onAppear { animating = true }
    }
}

private enum EvaWorkingStatusLibrary {
    static let general = [
        "Reviewing your context...",
        "Looking at what matters...",
        "Pulling the key signals...",
        "Organizing the big picture...",
        "Working through the details...",
        "Sorting the important pieces...",
        "Checking the strongest path...",
        "Building a clear answer...",
        "Turning this into a plan...",
        "Pulling this into focus...",
        "Structuring the next steps...",
        "Tightening the recommendation...",
        "Comparing the options...",
        "Simplifying the decision...",
        "Getting this into shape...",
        "Finding the clearest path...",
        "Breaking this down carefully...",
        "Preparing a focused response...",
        "Lining up the next steps...",
        "Refining the plan..."
    ]

    static let dailyPlanning = [
        "Reviewing your tasks...",
        "Checking today's priorities...",
        "Finding the highest-leverage task...",
        "Looking for what matters most today...",
        "Sorting urgent from important...",
        "Narrowing today's focus...",
        "Building today's plan...",
        "Pulling out your top priorities...",
        "Checking where momentum is strongest...",
        "Looking for the best next move...",
        "Trimming the list down...",
        "Turning today into a clear plan...",
        "Looking for quick wins...",
        "Balancing urgency and impact...",
        "Picking what deserves focus first...",
        "Reducing the noise...",
        "Aligning today's priorities...",
        "Building a realistic plan for today...",
        "Deciding what can wait...",
        "Protecting your focus window..."
    ]

    static func statuses(for recentUserFragments: [String]) -> [String] {
        let combined = recentUserFragments.joined(separator: " ").lowercased()
        let planningSignals = [
            "/today",
            "today",
            "task",
            "priority",
            "priorities",
            "focus",
            "plan",
            "urgent",
            "important",
            "what should i focus"
        ]
        if planningSignals.contains(where: { combined.contains($0) }) {
            return dailyPlanning
        }
        return general
    }
}

private struct EvaLiveWorkingStatusView: View {
    let statuses: [String]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var statusIndex = 0

    private var currentStatus: String {
        let source = statuses.isEmpty ? EvaWorkingStatusLibrary.general : statuses
        return source[min(statusIndex, source.count - 1)]
    }

    var body: some View {
        HStack(spacing: TaskerTheme.Spacing.sm) {
            Image(systemName: "sparkle")
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker(.accentPrimary))
            Text(currentStatus)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textTertiary))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, TaskerTheme.Spacing.md)
        .padding(.vertical, TaskerTheme.Spacing.xs)
        .taskerChromeSurface(
            cornerRadius: 16,
            accentColor: Color.tasker(.accentSecondary),
            level: .e1
        )
        .animation(reduceMotion ? nil : TaskerAnimation.quick, value: statusIndex)
        .task(id: statuses) {
            let source = statuses.isEmpty ? EvaWorkingStatusLibrary.general : statuses
            guard source.count > 1, reduceMotion == false else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_100_000_000)
                guard !Task.isCancelled else { return }
                statusIndex = (statusIndex + 1) % source.count
            }
        }
    }
}

private struct EvaDayTaskOverlayState {
    var isHidden = false
    var isProcessing = false
    var statusMessage: String?
}

private struct EvaDayHabitOverlayState {
    var isProcessing = false
    var statusMessage: String?
    var statusChips: [EvaDayStatusChip]?
    var actions: [EvaDayHabitAction]?
    var resolvedTodayState: HabitDayState?
}

private struct EvaDayStatusChipsView: View {
    let chips: [EvaDayStatusChip]
    let colorProvider: (String) -> Color

    var body: some View {
        if chips.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(chips, id: \.self) { chip in
                    let color = colorProvider(chip.tone)
                    Text(chip.text)
                        .font(.tasker(.caption2))
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                        .padding(.horizontal, TaskerTheme.Spacing.xs)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private struct EvaDayTaskRowView: View {
    let card: EvaDayTaskCard
    let overlay: EvaDayTaskOverlayState
    let chipColorProvider: (String) -> Color
    let actionTitle: (EvaDayTaskAction) -> String
    let actionHandler: (EvaDayTaskAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            EvaDayTaskHeaderView(
                card: card,
                overlay: overlay,
                chipColorProvider: chipColorProvider
            )

            EvaDayTaskActionsView(
                actions: card.actions,
                isProcessing: overlay.isProcessing,
                actionTitle: actionTitle,
                actionHandler: actionHandler
            )

            if let statusMessage = overlay.statusMessage, statusMessage.isEmpty == false {
                Text(statusMessage)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }
        }
        .padding(TaskerTheme.Spacing.md)
        .background(Color.tasker(.surfaceSecondary))
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
    }
}

private struct EvaDayHabitRowView: View {
    let card: EvaDayHabitCard
    let overlay: EvaDayHabitOverlayState
    let chips: [EvaDayStatusChip]
    let actions: [EvaDayHabitAction]
    let chipColorProvider: (String) -> Color
    let actionTitle: (EvaDayHabitAction) -> String
    let actionHandler: (EvaDayHabitAction) -> Void

    private var family: HabitColorFamily {
        HabitColorFamily.family(
            for: card.accentHex,
            fallback: card.kind == .positive ? .green : .coral
        )
    }

    private var cadence: HabitCadenceDraft {
        card.cadence ?? .daily()
    }

    private var boardCells: [HabitBoardCell] {
        HabitBoardPresentationBuilder.buildCells(
            marks: resolvedMarks,
            cadence: cadence,
            referenceDate: Date(),
            dayCount: 14
        )
    }

    private var resolvedMarks: [HabitDayMark] {
        guard let resolvedTodayState = overlay.resolvedTodayState else {
            return card.last14Days
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var marks = card.last14Days.filter { !calendar.isDate($0.date, inSameDayAs: today) }
        marks.append(HabitDayMark(date: today, state: resolvedTodayState))
        return marks.sorted { $0.date < $1.date }
    }

    private var accentColor: Color {
        HabitEverydayPalette.familyPreview(family)
    }

    private var streakLabel: String {
        card.currentStreak > 0 ? "\(card.currentStreak)d streak" : "Streak ready"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            habitTile

            EvaDayHabitActionsView(
                actions: actions,
                isProcessing: overlay.isProcessing,
                actionTitle: actionTitle,
                actionHandler: actionHandler
            )

            if let statusMessage = overlay.statusMessage, statusMessage.isEmpty == false {
                Text(statusMessage)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }
        }
        .padding(TaskerTheme.Spacing.md)
        .background(Color.tasker(.surfacePrimary))
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
        )
    }

    private var habitTile: some View {
        Button {
            actionHandler(.open)
        } label: {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                HStack(alignment: .top, spacing: TaskerTheme.Spacing.sm) {
                    ZStack {
                        accentColor.opacity(0.14)
                        Image(systemName: card.iconSymbolName ?? "circle.dashed")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.title)
                            .font(.tasker(.headline))
                            .foregroundStyle(Color.tasker(.textPrimary))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: TaskerTheme.Spacing.xs) {
                            Text(card.cadenceLabel)
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker(.textSecondary))
                                .lineLimit(1)
                            Text(streakLabel)
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker(.textTertiary))
                                .lineLimit(1)
                            if let projectName = card.projectName, projectName.isEmpty == false {
                                Text(projectName)
                                    .font(.tasker(.caption1))
                                    .foregroundStyle(Color.tasker(.textTertiary))
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer(minLength: TaskerTheme.Spacing.sm)

                    if overlay.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        EvaDayStatusChipsView(
                            chips: chips,
                            colorProvider: chipColorProvider
                        )
                    }
                }

                HabitBoardStripView(
                    cells: boardCells,
                    family: family,
                    mode: .compact,
                    cellSizeOverride: 13,
                    cellWidthOverride: 13,
                    cellHeightOverride: 13
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(card.title)
        .accessibilityValue("\(streakLabel). Last \(boardCells.count) days shown.")
        .accessibilityHint("Opens habit details.")
        .accessibilityIdentifier("chat.dayOverview.habitTile.\(card.habitID.uuidString)")
    }
}

private struct EvaDayTaskHeaderView: View {
    let card: EvaDayTaskCard
    let overlay: EvaDayTaskOverlayState
    let chipColorProvider: (String) -> Color

    var body: some View {
        HStack(alignment: .top, spacing: TaskerTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                Text(card.title)
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker(.textPrimary))
                    .multilineTextAlignment(.leading)

                EvaDayTaskMetadataView(card: card)
            }

            Spacer(minLength: TaskerTheme.Spacing.sm)

            if overlay.isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else {
                EvaDayStatusChipsView(
                    chips: card.statusChips,
                    colorProvider: chipColorProvider
                )
            }
        }
    }
}

private struct EvaDayTaskMetadataView: View {
    let card: EvaDayTaskCard

    var body: some View {
        HStack(spacing: TaskerTheme.Spacing.xs) {
            if let dueLabel = card.dueLabel, dueLabel.isEmpty == false {
                Text(dueLabel)
                    .font(.tasker(.caption1))
                    .foregroundStyle(card.isOverdue ? Color.tasker(.statusDanger) : Color.tasker(.textSecondary))
            }
            Text(card.projectName)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textTertiary))
            if let durationLabel = card.durationLabel, durationLabel.isEmpty == false {
                Text(durationLabel)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textTertiary))
            }
        }
    }
}

private struct EvaDayTaskActionsView: View {
    let actions: [EvaDayTaskAction]
    let isProcessing: Bool
    let actionTitle: (EvaDayTaskAction) -> String
    let actionHandler: (EvaDayTaskAction) -> Void

    var body: some View {
        HStack(spacing: TaskerTheme.Spacing.xs) {
            ForEach(actions, id: \.rawValue) { action in
                EvaDayTaskActionButtonView(
                    action: action,
                    title: actionTitle(action),
                    isProcessing: isProcessing,
                    actionHandler: actionHandler
                )
            }
        }
    }
}

private struct EvaDayTaskActionButtonView: View {
    let action: EvaDayTaskAction
    let title: String
    let isProcessing: Bool
    let actionHandler: (EvaDayTaskAction) -> Void

    var body: some View {
        if action == .done {
            Button(title) {
                actionHandler(action)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.tasker(.accentPrimary))
            .disabled(isProcessing)
        } else {
            Button(title) {
                actionHandler(action)
            }
            .buttonStyle(.bordered)
            .tint(Color.tasker(.accentMuted))
            .disabled(isProcessing)
        }
    }
}

private struct EvaDayHabitHeaderView: View {
    let card: EvaDayHabitCard
    let overlay: EvaDayHabitOverlayState
    let chips: [EvaDayStatusChip]
    let chipColorProvider: (String) -> Color

    var body: some View {
        HStack(alignment: .top, spacing: TaskerTheme.Spacing.sm) {
            Image(systemName: card.iconSymbolName ?? "repeat.circle")
                .font(.tasker(.title3))
                .foregroundStyle(Color.tasker(.accentPrimary))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                Text(card.title)
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker(.textPrimary))
                    .multilineTextAlignment(.leading)

                EvaDayHabitMetadataView(card: card)
            }

            Spacer(minLength: TaskerTheme.Spacing.sm)

            if overlay.isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else {
                EvaDayStatusChipsView(
                    chips: chips,
                    colorProvider: chipColorProvider
                )
            }
        }
    }
}

private struct EvaDayHabitMetadataView: View {
    let card: EvaDayHabitCard

    var body: some View {
        HStack(spacing: TaskerTheme.Spacing.xs) {
            Text(card.cadenceLabel)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
            if let dueLabel = card.dueLabel, dueLabel.isEmpty == false {
                Text(dueLabel)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textTertiary))
            }
            if card.currentStreak > 0 {
                Text("\(card.currentStreak) day streak")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textTertiary))
            }
        }
    }
}

private struct EvaDayHabitActionsView: View {
    let actions: [EvaDayHabitAction]
    let isProcessing: Bool
    let actionTitle: (EvaDayHabitAction) -> String
    let actionHandler: (EvaDayHabitAction) -> Void

    var body: some View {
        HStack(spacing: TaskerTheme.Spacing.xs) {
            ForEach(actions, id: \.rawValue) { action in
                EvaDayHabitActionButtonView(
                    action: action,
                    title: actionTitle(action),
                    isProcessing: isProcessing,
                    actionHandler: actionHandler
                )
            }
        }
    }
}

private struct EvaDayHabitActionButtonView: View {
    let action: EvaDayHabitAction
    let title: String
    let isProcessing: Bool
    let actionHandler: (EvaDayHabitAction) -> Void

    var body: some View {
        if action == .done || action == .stayedClean {
            Button(title) {
                actionHandler(action)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.tasker(.accentPrimary))
            .disabled(isProcessing)
        } else {
            Button(title) {
                actionHandler(action)
            }
            .buttonStyle(.bordered)
            .tint(Color.tasker(.accentMuted))
            .disabled(isProcessing)
        }
    }
}

struct MessageView: View {
    @State private var collapsed = true
    @State private var undoExpiredLogged = false
    @State private var selectedEvaCardIDs: Set<UUID> = []
    @State private var expandedEvaCardID: UUID?
    @State private var evaApplyMessage: String?
    @State private var isApplyingEvaProposal = false
    @State private var appliedEvaRunIDs: Set<UUID> = []
    @State private var appliedEvaRunIDByPayloadRunID: [UUID: UUID] = [:]
    @State private var pendingEvaApplyConfirmationIDs: Set<UUID>?
    @State private var isUndoingEvaRun = false
    @State private var dayTaskOverlayStates: [UUID: EvaDayTaskOverlayState] = [:]
    @State private var dayHabitOverlayStates: [UUID: EvaDayHabitOverlayState] = [:]
    @State private var dayOverviewNotices: [String] = []

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

    private var runtimeRunning: Bool {
        runtime?.running ?? false
    }

    private var runtimeElapsedTime: TimeInterval? {
        runtime?.elapsedTime
    }

    private var isThinking: Bool {
        renderModel.isThinkingOpenEnded
    }

    private var answerIsEmpty: Bool {
        renderModel.answerText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    private var thinkingIsEmpty: Bool {
        renderModel.thinkingText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    private var isPendingResponse: Bool {
        pendingPhase.isActive
    }

    private var activeWorkingStatuses: [String] {
        if runtimeRunning {
            return workingStatuses
        }
        if let pendingStatusText, pendingStatusText.isEmpty == false {
            return [pendingStatusText]
        }
        return workingStatuses
    }

    private var time: String {
        if isThinking, runtimeRunning, let elapsedTime = runtimeElapsedTime {
            return "(\(elapsedTime.formatted))"
        }
        if let generatingTime = renderModel.generatingTime {
            return generatingTime.formatted
        }
        return "0s"
    }

    private var thinkingLabel: some View {
        HStack(spacing: TaskerTheme.Spacing.sm) {
            Button {
                collapsed.toggle()
            } label: {
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.tasker(.caption2))
                    .fontWeight(.medium)
                    .foregroundStyle(Color.tasker(.textTertiary))
            }

            Text("\(isThinking ? "thinking..." : "thought for") \(time)")
                .font(.tasker(.caption1))
                .italic()
                .foregroundStyle(Color.tasker(.textTertiary))
        }
        .padding(.horizontal, TaskerTheme.Spacing.md)
        .padding(.vertical, TaskerTheme.Spacing.xs)
        .taskerChromeSurface(
            cornerRadius: 16,
            accentColor: Color.tasker(.accentSecondary),
            level: .e1
        )
        .buttonStyle(.borderless)
    }

    private var shouldShowLiveWorkingStatus: Bool {
        isLiveOutput &&
        (runtimeRunning || isPendingResponse) &&
        answerIsEmpty &&
        thinkingIsEmpty
    }

    private var shouldShowTypingIndicator: Bool {
        isLiveOutput && (runtimeRunning || isPendingResponse)
    }

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

    @ViewBuilder
    private var assistantBody: some View {
        if let payload = renderModel.cardPayload {
            assistantCardView(payload: payload)
                .padding(TaskerTheme.Spacing.lg)
                .taskerPremiumSurface(
                    cornerRadius: TaskerTheme.CornerRadius.lg,
                    fillColor: Color.tasker(.surfacePrimary),
                    strokeColor: Color.tasker(.strokeHairline),
                    accentColor: Color.tasker(.accentSecondary),
                    level: .e2
                )
                .padding(.trailing, 48)
        } else {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.lg) {
                if shouldShowLiveWorkingStatus {
                    EvaLiveWorkingStatusView(statuses: activeWorkingStatuses)
                }

                if EvaThinkingVisibilityPolicy.showsVisibleThinking,
                   let thinking = renderModel.thinkingText {
                    VStack(alignment: .leading, spacing: TaskerTheme.Spacing.md) {
                        thinkingLabel
                        if !collapsed, !thinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(spacing: TaskerTheme.Spacing.md) {
                                Capsule()
                                    .frame(width: 2)
                                    .padding(.vertical, 1)
                                    .foregroundStyle(Color.tasker(.accentMuted))
                                markdownText(
                                    thinking,
                                    color: Color.tasker(.textSecondary)
                                )
                            }
                            .padding(.leading, 5)
                        }
                    }
                    .contentShape(.rect)
                    .onTapGesture {
                        collapsed.toggle()
                        if isThinking, isLiveOutput {
                            runtime?.collapsed = collapsed
                        }
                    }
                }

                if let answer = renderModel.answerText {
                    markdownText(
                        answer,
                        color: Color.tasker(.textPrimary)
                    )
                }

                if shouldShowTypingIndicator {
                    TypingIndicator()
                }
            }
            .padding(TaskerTheme.Spacing.lg)
            .taskerPremiumSurface(
                cornerRadius: TaskerTheme.CornerRadius.lg,
                fillColor: Color.tasker(.surfacePrimary),
                strokeColor: Color.tasker(.strokeHairline),
                accentColor: Color.tasker(.accentSecondary),
                level: .e2
            )
            .padding(.trailing, 48)
        }
    }

    private var userBody: some View {
        Markdown(renderModel.displayContent)
            .textSelection(.enabled)
            .markdownTextStyle {
                ForegroundColor(Color.tasker(.accentOnPrimary))
            }
        #if os(iOS) || os(visionOS)
            .padding(.horizontal, TaskerTheme.Spacing.lg)
            .padding(.vertical, TaskerTheme.Spacing.md)
        #else
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        #endif
            .background(Color.tasker(.accentPrimary))
        #if os(iOS) || os(visionOS)
            .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
        #elseif os(macOS)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        #endif
            .overlay(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                    .stroke(Color.tasker(.accentPrimary).opacity(0.18), lineWidth: 1)
            )
            .padding(.leading, 48)
    }

    @ViewBuilder
    private func markdownText(_ text: String, color: Color) -> some View {
        if isLiveOutput && runtimeRunning {
            Text(text)
                .font(.tasker(.body))
                .foregroundStyle(color)
                .textSelection(.enabled)
        } else {
            Markdown(text)
                .textSelection(.enabled)
                .markdownTextStyle {
                    ForegroundColor(color)
                }
                .id(renderModel.markdownSourceHash)
        }
    }

    @ViewBuilder
    private func assistantCardView(payload: AssistantCardPayload) -> some View {
        if let evaProposal = payload.evaProposal {
            evaProposalCardView(payload: payload, proposal: evaProposal)
        } else if let dayOverview = payload.dayOverview {
            dayOverviewCardView(payload: payload, overview: dayOverview)
        } else if payload.cardType == .commandResult, let commandResult = payload.commandResult {
            commandResultCardView(commandResult)
        } else {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                HStack {
                    Text(payload.cardType == .undo ? "Changes applied" : "Eva's Plan")
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker(.textPrimary))
                    Spacer()
                    if payload.cardType == .proposal {
                        Text("Affects \(payload.affectedTaskCount) tasks")
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker(.textTertiary))
                    }
                }

                if let rationale = payload.rationale, !rationale.isEmpty {
                    Text("Rationale: \"\(rationale)\"")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textSecondary))
                }

                if !payload.diffLines.isEmpty {
                    VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                        ForEach(Array(payload.diffLines.enumerated()), id: \.offset) { _, line in
                            Text("• \(line.text)")
                                .font(.tasker(.callout))
                                .foregroundStyle(
                                    line.isDestructive ? Color.tasker(.statusDanger) : Color.tasker(.textPrimary)
                                )
                        }
                    }
                }

                if payload.cardType == .undo {
                    HStack {
                        Text(undoLabel(payload: payload))
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker(.textSecondary))
                        Spacer()
                        Button("Undo") {
                            if let runID = payload.runID {
                                undoEvaRun(runID, payloadRunID: payload.runID)
                            }
                        }
                            .buttonStyle(.borderedProminent)
                            .disabled(isUndoExpired(payload: payload) || isUndoingEvaRun || payload.runID == nil)
                    }
                } else if payload.cardType == .proposal {
                    if payload.runID == nil {
                        Text("Invalid proposal card (missing run ID).")
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker(.statusDanger))
                    } else if payload.status == .pending || payload.status == .confirmed {
                        HStack(spacing: TaskerTheme.Spacing.sm) {
                            Button("Reject") {}
                                .buttonStyle(.bordered)

                            Button("Apply Changes") {}
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Text(payload.message ?? proposalStatusText(payload.status))
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker(.textTertiary))
                    }
                } else if let status = payload.message {
                    Text(status)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textTertiary))
                }
            }
        }
    }

    private func evaProposalCardView(payload: AssistantCardPayload, proposal: EvaProposalReviewPayload) -> some View {
        let isApplyable = payload.runID != nil && proposal.cards.contains { $0.commandIndexes.isEmpty == false }
        return VStack(alignment: .leading, spacing: TaskerTheme.Spacing.md) {
            evaPromptCard(prompt: proposal.prompt)

            HStack(alignment: .top, spacing: TaskerTheme.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.tasker(.textTertiary))
                Text("The AI may make mistakes or produce inaccurate information. Be sure to check important tasks.")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, TaskerTheme.Spacing.md)
            .padding(.vertical, TaskerTheme.Spacing.sm)
            .background(Color.tasker(.surfaceSecondary))
            .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))

            DisclosureGroup {
                Text(proposal.contextReceipt.sources.joined(separator: "\n"))
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, TaskerTheme.Spacing.xs)
            } label: {
                Label(proposal.contextReceipt.collapsedText, systemImage: "lock.shield")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }

            Text(summaryText(proposal.summary))
                .font(.tasker(.body))
                .foregroundStyle(Color.tasker(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(TaskerTheme.Spacing.md)
                .background(Color.tasker(.surfaceSecondary))
                .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))

            ForEach(EvaProposalCardBuilder.groups(for: proposal.cards)) { group in
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                    Text(group.title)
                        .font(.tasker(.caption1))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.tasker(.textTertiary))
                        .padding(.horizontal, TaskerTheme.Spacing.xs)

                    ForEach(group.cards) { card in
                        evaProposalRow(card)
                    }
                }
            }

            HStack(spacing: TaskerTheme.Spacing.sm) {
                Button {
                    selectedEvaCardIDs = Set(proposal.cards.filter(\.isSelectedByDefault).map(\.id))
                    expandedEvaCardID = nil
                    evaApplyMessage = nil
                    pendingEvaApplyConfirmationIDs = nil
                } label: {
                    Label("Start New", systemImage: "square.and.pencil")
                }
                .buttonStyle(.bordered)
                .tint(Color.tasker(.accentPrimary))

                Spacer()

                Button {
                    evaApplyMessage = "Thanks for the feedback."
                } label: {
                    Image(systemName: "hand.thumbsup")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.tasker(.textTertiary))
                .accessibilityLabel("Helpful")

                Button {
                    evaApplyMessage = "Thanks. EVA will use this feedback later."
                } label: {
                    Image(systemName: "hand.thumbsdown")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.tasker(.textTertiary))
                .accessibilityLabel("Not helpful")
            }

            if let evaApplyMessage {
                Text(evaApplyMessage)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }

            if isApplyable {
                if let payloadRunID = payload.runID,
                   let appliedRunID = appliedEvaRunIDByPayloadRunID[payloadRunID] {
                    HStack(spacing: TaskerTheme.Spacing.sm) {
                        Button {
                            undoEvaRun(appliedRunID, payloadRunID: payloadRunID)
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                                .font(.tasker(.buttonSmall))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.tasker(.accentPrimary))
                        .disabled(isUndoingEvaRun)
                        .accessibilityIdentifier("eva.proposal.undo")
                    }
                } else {
                    if pendingEvaApplyConfirmationIDs == selectedEvaCardIDs {
                        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                            Text("Confirm before EVA changes your tasks.")
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker(.textSecondary))

                            HStack(spacing: TaskerTheme.Spacing.sm) {
                                Button("Cancel") {
                                    pendingEvaApplyConfirmationIDs = nil
                                    evaApplyMessage = nil
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    applyEvaProposal(payload: payload, proposal: proposal)
                                } label: {
                                    Text("Confirm Apply")
                                        .font(.tasker(.buttonSmall))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.tasker(.accentPrimary))
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
                                    .font(.tasker(.buttonSmall))
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.tasker(.accentPrimary))
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

    private func evaPromptCard(prompt: String) -> some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            HStack(spacing: TaskerTheme.Spacing.xs) {
                Image(systemName: "chevron.right")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textTertiary))
                Text("Your plans")
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }
            Text(prompt)
                .font(.tasker(.body))
                .foregroundStyle(Color.tasker(.textPrimary))
        }
        .padding(TaskerTheme.Spacing.md)
        .background(Color.tasker(.surfacePrimary))
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                .stroke(Color.tasker(.accentPrimary), lineWidth: 1.5)
        )
    }

    private func dayOverviewCardView(payload: AssistantCardPayload, overview: EvaDayOverviewPayload) -> some View {
        let sections = visibleDayOverviewSections(for: overview)

        return VStack(alignment: .leading, spacing: TaskerTheme.Spacing.md) {
            evaPromptCard(prompt: overview.prompt)

            if overview.isPartialContext {
                HStack(alignment: .top, spacing: TaskerTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.tasker(.statusWarning))
                    Text("Context is partial. EVA is only showing grounded tasks and habits from the slices that loaded.")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, TaskerTheme.Spacing.md)
                .padding(.vertical, TaskerTheme.Spacing.sm)
                .background(Color.tasker(.surfaceSecondary))
                .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
            }

            DisclosureGroup {
                Text(overview.contextReceipt.sources.joined(separator: "\n"))
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, TaskerTheme.Spacing.xs)
            } label: {
                Label(overview.contextReceipt.collapsedText, systemImage: "lock.shield")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }

            markdownText(overview.summaryMarkdown, color: Color.tasker(.textPrimary))
                .padding(TaskerTheme.Spacing.md)
                .background(Color.tasker(.surfaceSecondary))
                .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))

            if dayOverviewNotices.isEmpty == false {
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                    ForEach(Array(dayOverviewNotices.enumerated()), id: \.offset) { _, notice in
                        Text(notice)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker(.textSecondary))
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.md)
                .padding(.vertical, TaskerTheme.Spacing.sm)
                .background(Color.tasker(.accentWash).opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
            }

            if sections.isEmpty {
                Text("Everything visible in this brief has already been handled.")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textTertiary))
            } else {
                ForEach(sections) { section in
                    dayOverviewSectionView(section)
                }
            }
        }
    }

    private func visibleDayOverviewSections(for overview: EvaDayOverviewPayload) -> [EvaDayOverviewSection] {
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

    private func dayOverviewSectionView(_ section: EvaDayOverviewSection) -> some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.tasker(.caption1))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.tasker(.textTertiary))
                if let subtitle = section.subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.tasker(.caption2))
                        .foregroundStyle(Color.tasker(.textTertiary))
                }
            }
            .padding(.horizontal, TaskerTheme.Spacing.xs)

            if let message = section.message, message.isEmpty == false,
               section.taskCards.isEmpty && section.habitCards.isEmpty {
                Text(message)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .padding(TaskerTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.tasker(.surfaceSecondary))
                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
            }

            ForEach(section.taskCards) { card in
                dayTaskRow(card)
            }

            ForEach(section.habitCards) { card in
                dayHabitRow(card)
            }
        }
    }

    private func dayTaskRow(_ card: EvaDayTaskCard) -> some View {
        let overlay = dayTaskOverlayStates[card.taskID] ?? EvaDayTaskOverlayState()
        return EvaDayTaskRowView(
            card: card,
            overlay: overlay,
            chipColorProvider: dayChipColor,
            actionTitle: taskActionTitle,
            actionHandler: { action in
                handleDayTaskAction(action, card: card)
            }
        )
    }

    private func dayHabitRow(_ card: EvaDayHabitCard) -> some View {
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
    private func dayStatusChips(_ chips: [EvaDayStatusChip]) -> some View {
        EvaDayStatusChipsView(chips: chips, colorProvider: dayChipColor)
    }

    private func handleDayTaskAction(_ action: EvaDayTaskAction, card: EvaDayTaskCard) {
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

    private func handleDayHabitAction(_ action: EvaDayHabitAction, card: EvaDayHabitCard) {
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

    private func appendDayOverviewNotice(_ notice: String) {
        guard dayOverviewNotices.contains(notice) == false else { return }
        dayOverviewNotices.append(notice)
    }

    private func taskActionTitle(_ action: EvaDayTaskAction) -> String {
        switch action {
        case .done: return "Done"
        case .reopen: return "Reopen"
        case .tomorrow: return "Tomorrow"
        case .open: return "Open"
        }
    }

    private func habitActionTitle(_ action: EvaDayHabitAction) -> String {
        switch action {
        case .done: return "Done"
        case .skip: return "Skip"
        case .stayedClean: return "Stayed Clean"
        case .lapsed: return "Lapsed"
        case .logLapse: return "Log Lapse"
        case .open: return "Open"
        }
    }

    private func habitResolvedChipTitle(_ action: EvaDayHabitAction) -> String {
        switch action {
        case .done: return "Done"
        case .skip: return "Skipped"
        case .stayedClean: return "Stayed clean"
        case .lapsed, .logLapse: return "Lapsed"
        case .open: return "Open"
        }
    }

    private func habitActionSuccessMessage(_ action: EvaDayHabitAction) -> String {
        switch action {
        case .done: return "Logged completion for"
        case .skip: return "Skipped"
        case .stayedClean: return "Logged stayed clean for"
        case .lapsed: return "Logged a lapse for"
        case .logLapse: return "Logged a lapse for"
        case .open: return "Opened"
        }
    }

    private func habitActionDayState(_ action: EvaDayHabitAction) -> HabitDayState? {
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

    private func dayChipColor(_ tone: String) -> Color {
        switch tone {
        case "danger":
            return Color.tasker(.statusDanger)
        case "warning":
            return Color.tasker(.statusWarning)
        default:
            return Color.tasker(.accentPrimary)
        }
    }

    private func evaProposalRow(_ card: EvaProposalCard) -> some View {
        let isSelected = selectedEvaCardIDs.contains(card.id)
        let isExpanded = expandedEvaCardID == card.id

        return VStack(spacing: 0) {
            Button {
                if isExpanded {
                    expandedEvaCardID = nil
                } else {
                    expandedEvaCardID = card.id
                }
            } label: {
                HStack(alignment: .center, spacing: TaskerTheme.Spacing.md) {
                    Image(systemName: iconName(for: card))
                        .font(.tasker(.title3))
                        .foregroundStyle(toneColor(card.tone))
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.subtitle)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker(.textTertiary))
                            .lineLimit(2)
                        Text(card.title)
                            .font(.tasker(.headline))
                            .foregroundStyle(Color.tasker(.textPrimary))
                            .lineLimit(2)
                    }

                    Spacer(minLength: TaskerTheme.Spacing.sm)

                    VStack(alignment: .trailing, spacing: TaskerTheme.Spacing.xs) {
                        Text(card.badgeText)
                            .font(.tasker(.caption2))
                            .fontWeight(.semibold)
                            .foregroundStyle(toneColor(card.tone))
                            .padding(.horizontal, TaskerTheme.Spacing.xs)
                            .padding(.vertical, 3)
                            .background(toneColor(card.tone).opacity(0.14))
                            .clipShape(Capsule())

                        Button {
                            toggleEvaSelection(card)
                        } label: {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.tasker(.accentPrimary) : Color.tasker(.accentMuted))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isSelected ? "Deselect \(card.title)" : "Select \(card.title)")
                    }
                }
                .padding(TaskerTheme.Spacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(spacing: TaskerTheme.Spacing.sm) {
                    ForEach(availableEvaActions(for: card), id: \.self) { action in
                        evaCardActionButton(action, card: card)
                    }
                }
                .padding(TaskerTheme.Spacing.sm)
                .background(Color.tasker(.accentWash).opacity(0.48))
            }
        }
        .background(Color.tasker(.surfacePrimary))
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                .stroke(isExpanded || isSelected ? Color.tasker(.accentPrimary) : Color.tasker(.strokeHairline), lineWidth: isExpanded ? 1.5 : 1)
        )
    }

    private func evaCardActionButton(_ action: EvaProposalAction, card: EvaProposalCard) -> some View {
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
            Label(action.rawValue, systemImage: actionIcon(action))
                .font(.tasker(.buttonSmall))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(action == .discard ? Color.tasker(.statusDanger) : Color.tasker(.accentPrimary))
    }

    private func availableEvaActions(for card: EvaProposalCard) -> [EvaProposalAction] {
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

    private func openEvaProposalCard(_ card: EvaProposalCard) {
        guard let task = evaTaskDefinition(for: card) else { return }
        onOpenTaskFromCard?(task)
    }

    private func evaTaskDefinition(for card: EvaProposalCard) -> TaskDefinition? {
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

    private func toggleEvaSelection(_ card: EvaProposalCard) {
        if selectedEvaCardIDs.contains(card.id) {
            selectedEvaCardIDs.remove(card.id)
        } else {
            selectedEvaCardIDs.insert(card.id)
        }
        pendingEvaApplyConfirmationIDs = nil
    }

    private func prepareEvaProposalConfirmation(proposal: EvaProposalReviewPayload) {
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

    private func applyEvaProposal(payload: AssistantCardPayload, proposal: EvaProposalReviewPayload) {
        guard let runID = payload.runID, let pipeline = LLMAssistantPipelineProvider.pipeline else {
            evaApplyMessage = "EVA cannot apply this plan right now."
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
            switch fetchResult {
            case .failure(let error):
                finishEvaApply(message: error.localizedDescription)
            case .success(let run):
                guard
                    let run,
                    let data = run.proposalData,
                    let envelope = try? JSONDecoder().decode(AssistantCommandEnvelope.self, from: data)
                else {
                    finishEvaApply(message: "EVA could not read this proposal.")
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

    private func confirmAndApply(
        pipeline: AssistantActionPipelineUseCase,
        runID: UUID,
        appliedCount: Int,
        payload: AssistantCardPayload,
        proposal: EvaProposalReviewPayload,
        selectedCards: [EvaProposalCard],
        payloadRunID: UUID
    ) {
        pipeline.confirm(runID: runID) { confirmResult in
            switch confirmResult {
            case .failure(let error):
                finishEvaApply(message: error.localizedDescription)
            case .success:
                pipeline.applyConfirmedRun(id: runID) { applyResult in
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
                            message: "EVA updated \(appliedCount) tasks. Undo for 30 min.",
                            appliedRunID: runID,
                            payloadRunID: payloadRunID
                        )
                    }
                }
            }
        }
    }

    private func recordEvaAppliedRunHistory(
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

    private func finishEvaApply(message: String, appliedRunID: UUID? = nil, payloadRunID: UUID? = nil) {
        Task { @MainActor in
            isApplyingEvaProposal = false
            evaApplyMessage = message
            pendingEvaApplyConfirmationIDs = nil
            if let appliedRunID {
                appliedEvaRunIDs.insert(appliedRunID)
                if let payloadRunID {
                    appliedEvaRunIDByPayloadRunID[payloadRunID] = appliedRunID
                }
                selectedEvaCardIDs.removeAll()
            }
        }
    }

    private func undoEvaRun(_ runID: UUID, payloadRunID: UUID?) {
        guard let pipeline = LLMAssistantPipelineProvider.pipeline else {
            evaApplyMessage = "EVA cannot undo this plan right now."
            return
        }
        isUndoingEvaRun = true
        evaApplyMessage = "Undoing EVA changes..."
        pipeline.undoAppliedRun(id: runID) { result in
            Task { @MainActor in
                isUndoingEvaRun = false
                switch result {
                case .success:
                    appliedEvaRunIDs.remove(runID)
                    if let payloadRunID {
                        appliedEvaRunIDByPayloadRunID[payloadRunID] = nil
                    }
                    evaApplyMessage = "EVA reverted those changes."
                case .failure(let error):
                    evaApplyMessage = error.localizedDescription
                }
            }
        }
    }

    private func applyButtonTitle(cards: [EvaProposalCard]) -> String {
        EvaProposalApplyButtonTitleResolver.title(cards: cards, selectedCardIDs: selectedEvaCardIDs)
    }

    private func summaryText(_ summary: String) -> String {
        summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Here's how your day is planned:"
            : summary
    }

    private func toneColor(_ tone: EvaProposalTone) -> Color {
        switch tone {
        case .create:
            return Color.tasker(.accentPrimary)
        case .edit:
            return Color.tasker(.statusWarning)
        case .neutral:
            return Color.tasker(.textTertiary)
        case .warning:
            return Color.tasker(.statusWarning)
        case .destructive:
            return Color.tasker(.statusDanger)
        }
    }

    private func iconName(for card: EvaProposalCard) -> String {
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

    private func actionIcon(_ action: EvaProposalAction) -> String {
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
    private func commandResultCardView(_ result: SlashCommandExecutionResult) -> some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            HStack {
                Label(result.commandLabel, systemImage: result.commandID.icon)
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker(.textPrimary))
                Spacer()
                Text("\(result.totalTaskCount)")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textTertiary))
            }

            Text(result.summary)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))

            if result.sections.isEmpty {
                Text("No tasks to show.")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textTertiary))
            } else {
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                    ForEach(Array(result.sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                            Text("\(section.title) (\(section.totalCount))")
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker(.textTertiary))

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
                                    VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                                        Text(item.title)
                                            .font(.tasker(.callout))
                                            .foregroundStyle(Color.tasker(.textPrimary))
                                            .multilineTextAlignment(.leading)
                                        HStack(spacing: TaskerTheme.Spacing.xs) {
                                            if let dueLabel = item.dueLabel, !dueLabel.isEmpty {
                                                Text(dueLabel)
                                                    .font(.tasker(.caption1))
                                                    .foregroundStyle(dueLabelColor(dueLabel))
                                            }
                                            Text(item.projectName)
                                                .font(.tasker(.caption1))
                                                .foregroundStyle(Color.tasker(.textTertiary))
                                        }
                                    }
                                    .padding(.horizontal, TaskerTheme.Spacing.sm)
                                    .padding(.vertical, TaskerTheme.Spacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.tasker(.surfaceSecondary))
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: TaskerTheme.CornerRadius.md,
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

    private func dueLabelColor(_ dueLabel: String) -> Color {
        dueLabel.localizedCaseInsensitiveContains("late")
            ? Color.tasker(.statusDanger)
            : Color.tasker(.textTertiary)
    }

    private func proposalStatusText(_ status: AssistantCardStatus) -> String {
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

    private func isUndoExpired(payload: AssistantCardPayload) -> Bool {
        guard let expiresAt = payload.expiresAt else { return true }
        return now >= expiresAt
    }

    private func undoLabel(payload: AssistantCardPayload) -> String {
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

struct ConversationView: View {
    @Environment(LLMEvaluator.self) private var llm
    @EnvironmentObject private var appManager: AppManager

    let snapshot: ChatTranscriptSnapshot
    let liveOutput: ChatLiveOutputState
    var onOpenTaskFromCard: ((TaskDefinition) -> Void)?
    var onOpenHabitFromCard: ((UUID) -> Void)?
    var onPerformDayTaskAction: EvaDayTaskActionHandler?
    var onPerformDayHabitAction: EvaDayHabitActionHandler?

    @State private var scrollID: String?
    @State private var scrollInterrupted = false
    @State private var now = Date()

    private var shouldRenderLiveOutput: Bool {
        liveOutput.shouldRender && snapshot.threadID == liveOutput.threadID
    }

    private var liveWorkingStatuses: [String] {
        EvaWorkingStatusLibrary.statuses(for: snapshot.recentUserMessageFragments)
    }

    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(snapshot.messages, id: \.id) { message in
                        MessageView(
                            renderModel: message,
                            now: now,
                            onOpenTaskFromCard: onOpenTaskFromCard,
                            onOpenHabitFromCard: onOpenHabitFromCard,
                            onPerformDayTaskAction: onPerformDayTaskAction,
                            onPerformDayHabitAction: onPerformDayHabitAction
                        )
                        .padding(.horizontal, TaskerTheme.Spacing.lg)
                        .padding(.vertical, TaskerTheme.Spacing.sm)
                        .id(message.id.uuidString)
                    }

                    if shouldRenderLiveOutput {
                        MessageView(
                            renderModel: liveOutput.renderModel,
                            now: now,
                            runtime: llm,
                            isLiveOutput: true,
                            workingStatuses: liveWorkingStatuses,
                            pendingPhase: liveOutput.pendingPhase,
                            pendingStatusText: liveOutput.pendingStatusText,
                            onOpenTaskFromCard: onOpenTaskFromCard,
                            onOpenHabitFromCard: onOpenHabitFromCard,
                            onPerformDayTaskAction: onPerformDayTaskAction,
                            onPerformDayHabitAction: onPerformDayHabitAction
                        )
                        .padding(.horizontal, TaskerTheme.Spacing.lg)
                        .padding(.vertical, TaskerTheme.Spacing.sm)
                        .id("output")
                        .onAppear {
                            scrollInterrupted = false
                        }
                    }

                    Rectangle()
                        .fill(.clear)
                        .frame(height: 1)
                        .id("bottom")
                }
                .scrollTargetLayout()
            }
            .background(Color.tasker(.bgCanvas))
            .scrollPosition(id: $scrollID, anchor: .bottom)
            .onAppear {
                if !scrollInterrupted {
                    scrollView.scrollTo("bottom")
                }
            }
            .onChange(of: snapshot.identityHash) { _, _ in
                if !scrollInterrupted {
                    scrollView.scrollTo("bottom")
                }
            }
            .onChange(of: liveOutput.text) { _, _ in
                if !scrollInterrupted {
                    scrollView.scrollTo("bottom")
                }
            }
            .onChange(of: liveOutput.runtimePhase) { oldPhase, newPhase in
                guard snapshot.threadID == liveOutput.threadID else { return }

                if newPhase == .thinking,
                   oldPhase != .thinking,
                   V2FeatureFlags.llmChatThinkingPhaseHapticsEnabled {
                    appManager.playHaptic()
                }

                if newPhase == .answering,
                   oldPhase != .answering,
                   V2FeatureFlags.llmChatAnswerPhaseHapticsEnabled {
                    appManager.playHaptic()
                }
            }
            .onChange(of: scrollID) { _, _ in
                guard shouldRenderLiveOutput else { return }
                if scrollID == "bottom" || scrollID == "output" {
                    scrollInterrupted = false
                    return
                }
                scrollInterrupted = true
            }
        }
        .task(id: snapshot.containsUndoCard) {
            guard snapshot.containsUndoCard else { return }
            now = Date()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                now = Date()
            }
        }
        .defaultScrollAnchor(.bottom)
        #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
        #endif
    }
}

#Preview {
    ConversationView(snapshot: .empty, liveOutput: .empty)
        .environment(LLMEvaluator())
        .environmentObject(AppManager())
}
