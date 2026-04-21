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

struct MessageView: View {
    @State private var collapsed = true
    @State private var undoExpiredLogged = false

    let renderModel: ChatMessageRenderModel
    let now: Date
    var runtime: LLMEvaluator? = nil
    var isLiveOutput: Bool = false
    var workingStatuses: [String] = []
    var pendingPhase: ChatPendingResponsePhase = .idle
    var pendingStatusText: String? = nil
    var onOpenTaskFromCard: ((TaskDefinition) -> Void)?

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
        if payload.cardType == .commandResult, let commandResult = payload.commandResult {
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
                        Button("Undo") {}
                            .buttonStyle(.borderedProminent)
                            .disabled(isUndoExpired(payload: payload))
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
                            onOpenTaskFromCard: onOpenTaskFromCard
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
                            pendingStatusText: liveOutput.pendingStatusText
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
