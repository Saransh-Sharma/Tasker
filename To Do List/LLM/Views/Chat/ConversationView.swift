//
//  ConversationView.swift
//
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
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.tasker(.accentPrimary))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.top, TaskerTheme.Spacing.xs)
        .onAppear { animating = true }
    }
}

struct MessageView: View {
    @State private var collapsed = true
    @State private var now = Date()
    @State private var undoExpiredLogged = false

    let message: Message
    var runtime: LLMEvaluator? = nil
    var isLiveOutput: Bool = false
    var onApplyProposal: ((Message, AssistantCardPayload) -> Void)?
    var onRejectProposal: ((Message, AssistantCardPayload) -> Void)?
    var onUndoRun: ((Message, AssistantCardPayload) -> Void)?
    var onRefreshContext: ((Message, AssistantCardPayload) -> Void)?
    var onOpenTaskFromCard: ((TaskDefinition) -> Void)?

    private let countdownTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var cardPayload: AssistantCardPayload? {
        AssistantCardCodec.decode(from: message.content)
    }

    private var runtimeRunning: Bool {
        runtime?.running ?? false
    }

    private var runtimeElapsedTime: TimeInterval? {
        runtime?.elapsedTime
    }

    var isThinking: Bool {
        message.content.contains("<think>") && !message.content.contains("</think>")
    }

    func processThinkingContent(_ content: String) -> (String?, String?) {
        guard let startRange = content.range(of: "<think>") else {
            return (nil, content.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let endRange = content.range(of: "</think>") else {
            let thinking = String(content[startRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (thinking, nil)
        }

        let thinking = String(content[startRange.upperBound ..< endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let afterThink = String(content[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (thinking, afterThink.isEmpty ? nil : afterThink)
    }

    var time: String {
        if isThinking, runtimeRunning, let elapsedTime = runtimeElapsedTime {
            return "(\(elapsedTime.formatted))"
        }
        if let generatingTime = message.generatingTime {
            return "\(generatingTime.formatted)"
        }
        return "0s"
    }

    var thinkingLabel: some View {
        HStack(spacing: TaskerTheme.Spacing.sm) {
            Button {
                collapsed.toggle()
            } label: {
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.tasker(.caption2))
                    .fontWeight(.medium)
                    .foregroundColor(Color.tasker(.textTertiary))
            }

            Text("\(isThinking ? "thinking..." : "thought for") \(time)")
                .font(.tasker(.caption1))
                .italic()
                .foregroundColor(Color.tasker(.textTertiary))
        }
        .padding(.horizontal, TaskerTheme.Spacing.md)
        .padding(.vertical, TaskerTheme.Spacing.xs)
        .background(Color.tasker(.surfaceSecondary))
        .clipShape(Capsule())
        .buttonStyle(.borderless)
    }

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            if message.role == .assistant {
                if let cardPayload {
                    assistantCardView(payload: cardPayload)
                        .padding(TaskerTheme.Spacing.lg)
                        .background(Color.tasker(.surfacePrimary))
                        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
                        .taskerElevation(.e1, cornerRadius: TaskerTheme.CornerRadius.lg)
                        .padding(.trailing, 48)
                } else {
                    let (thinking, afterThink) = processThinkingContent(message.content)
                    VStack(alignment: .leading, spacing: TaskerTheme.Spacing.lg) {
                        if let thinking {
                            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.md) {
                                thinkingLabel
                                if !collapsed, !thinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    HStack(spacing: TaskerTheme.Spacing.md) {
                                        Capsule()
                                            .frame(width: 2)
                                            .padding(.vertical, 1)
                                            .foregroundStyle(Color.tasker(.accentMuted))
                                        if isLiveOutput && runtimeRunning {
                                            Text(thinking)
                                                .font(.tasker(.body))
                                                .foregroundColor(Color.tasker(.textSecondary))
                                                .textSelection(.enabled)
                                        } else {
                                            Markdown(thinking)
                                                .textSelection(.enabled)
                                                .markdownTextStyle {
                                                    ForegroundColor(Color.tasker(.textSecondary))
                                                }
                                        }
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

                        if let afterThink {
                            if isLiveOutput && runtimeRunning {
                                Text(afterThink)
                                    .font(.tasker(.body))
                                    .foregroundColor(Color.tasker(.textPrimary))
                                    .textSelection(.enabled)
                            } else {
                                Markdown(afterThink)
                                    .textSelection(.enabled)
                                    .markdownTextStyle {
                                        ForegroundColor(Color.tasker(.textPrimary))
                                    }
                            }
                        }

                        if isLiveOutput && runtimeRunning {
                            TypingIndicator()
                        }
                    }
                    .padding(TaskerTheme.Spacing.lg)
                    .background(Color.tasker(.surfacePrimary))
                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
                    .taskerElevation(.e1, cornerRadius: TaskerTheme.CornerRadius.lg)
                    .padding(.trailing, 48)
                }
            } else {
                Markdown(message.content)
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
                    .padding(.leading, 48)
            }

            if message.role == .assistant { Spacer() }
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
        .onChange(of: isThinking) { _, isThinkingNow in
            if isLiveOutput, runtimeRunning {
                runtime?.isThinking = isThinkingNow
            }
        }
        .onReceive(countdownTimer) { _ in
            now = Date()
            if let payload = cardPayload,
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
    private func assistantCardView(payload: AssistantCardPayload) -> some View {
        if payload.cardType == .commandResult, let commandResult = payload.commandResult {
            commandResultCardView(commandResult)
        } else {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            HStack {
                Text(payload.cardType == .undo ? "Changes applied" : "Eva's Plan")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker(.textPrimary))
                Spacer()
                if payload.cardType == .proposal {
                    Text("Affects \(payload.affectedTaskCount) tasks")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker(.textTertiary))
                }
            }

            if let rationale = payload.rationale, rationale.isEmpty == false {
                Text("Rationale: \"\(rationale)\"")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker(.textSecondary))
            }

            if !payload.diffLines.isEmpty {
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                    ForEach(Array(payload.diffLines.enumerated()), id: \.offset) { _, line in
                        Text("• \(line.text)")
                            .font(.tasker(.callout))
                            .foregroundColor(line.isDestructive ? Color.tasker(.statusDanger) : Color.tasker(.textPrimary))
                    }
                }
            }

            if payload.cardType == .undo {
                HStack {
                    Text(undoLabel(payload: payload))
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker(.textSecondary))
                    Spacer()
                    Button("Undo") {
                        onUndoRun?(message, payload)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUndoExpired(payload: payload))
                }
            } else if payload.cardType == .proposal {
                if payload.runID == nil {
                    Text("Invalid proposal card (missing run ID).")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker(.statusDanger))
                } else if payload.status == .pending || payload.status == .confirmed {
                    HStack(spacing: TaskerTheme.Spacing.sm) {
                        Button("Reject") {
                            onRejectProposal?(message, payload)
                        }
                        .buttonStyle(.bordered)

                        Button("Apply Changes") {
                            onApplyProposal?(message, payload)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Text(payload.message ?? proposalStatusText(payload.status))
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker(.textTertiary))
                    if (payload.message ?? "").localizedCaseInsensitiveContains("refresh context") {
                        Button("Refresh context") {
                            onRefreshContext?(message, payload)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else if let status = payload.message {
                Text(status)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker(.textTertiary))
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
                    .foregroundColor(Color.tasker(.textPrimary))
                Spacer()
                Text("\(result.totalTaskCount)")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker(.textTertiary))
            }

            Text(result.summary)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker(.textSecondary))

            if result.sections.isEmpty {
                Text("No tasks to show.")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker(.textTertiary))
            } else {
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                    ForEach(Array(result.sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                            Text("\(section.title) (\(section.totalCount))")
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker(.textTertiary))

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
                                            .foregroundColor(Color.tasker(.textPrimary))
                                            .multilineTextAlignment(.leading)
                                        HStack(spacing: TaskerTheme.Spacing.xs) {
                                            if let dueLabel = item.dueLabel, dueLabel.isEmpty == false {
                                                Text(dueLabel)
                                                    .font(.tasker(.caption1))
                                                    .foregroundColor(dueLabelColor(dueLabel))
                                            }
                                            Text(item.projectName)
                                                .font(.tasker(.caption1))
                                                .foregroundColor(Color.tasker(.textTertiary))
                                        }
                                    }
                                    .padding(.horizontal, TaskerTheme.Spacing.sm)
                                    .padding(.vertical, TaskerTheme.Spacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.tasker(.surfaceSecondary))
                                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous))
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

    /// Executes proposalStatusText.
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
    @Environment(LLMEvaluator.self) var llm
    @EnvironmentObject var appManager: AppManager

    let thread: Thread
    let generatingThreadID: UUID?
    let isPreparingResponse: Bool
    var onApplyProposal: ((Message, AssistantCardPayload) -> Void)?
    var onRejectProposal: ((Message, AssistantCardPayload) -> Void)?
    var onUndoRun: ((Message, AssistantCardPayload) -> Void)?
    var onRefreshContext: ((Message, AssistantCardPayload) -> Void)?
    var onOpenTaskFromCard: ((TaskDefinition) -> Void)?

    @State private var scrollID: String?
    @State private var scrollInterrupted = false
    @State private var cachedSortedMessages: [Message] = []
    @State private var lastAnswerHapticAt: Date = .distantPast
    @State private var liveOutputMessage = Message(role: .assistant, content: "")

    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(cachedSortedMessages.enumerated()), id: \.element.id) { index, message in
                        MessageView(
                            message: message,
                            runtime: nil,
                            onApplyProposal: onApplyProposal,
                            onRejectProposal: onRejectProposal,
                            onUndoRun: onUndoRun,
                            onRefreshContext: onRefreshContext,
                            onOpenTaskFromCard: onOpenTaskFromCard
                        )
                            .padding(.horizontal, TaskerTheme.Spacing.lg)
                            .padding(.vertical, TaskerTheme.Spacing.sm)
                            .staggeredAppearance(index: index)
                            .id(message.id.uuidString)
                    }

                    if (llm.running || isPreparingResponse) && !llm.output.isEmpty && thread.id == generatingThreadID {
                        VStack {
                            MessageView(message: liveOutputMessage, runtime: llm, isLiveOutput: true)
                        }
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
            .onChange(of: llm.output) { _, _ in
                liveOutputMessage.content = llm.output
                if !scrollInterrupted {
                    scrollView.scrollTo("bottom")
                }

                guard thread.id == generatingThreadID else { return }
                guard V2FeatureFlags.llmChatAnswerPhaseHapticsEnabled else { return }
                guard llm.runtimePhase == .answering else { return }
                let now = Date()
                guard now.timeIntervalSince(lastAnswerHapticAt) >= 0.35 else { return }
                lastAnswerHapticAt = now
                appManager.playHaptic()
            }
            .onChange(of: llm.runtimePhase) { _, phase in
                guard thread.id == generatingThreadID else { return }
                guard phase == .thinking else { return }
                guard V2FeatureFlags.llmChatThinkingPhaseHapticsEnabled else { return }
                appManager.playHaptic()
            }
            .onAppear {
                liveOutputMessage.content = llm.output
                refreshCachedMessages()
            }
            .onChange(of: messageSetFingerprint) { _, _ in
                refreshCachedMessages()
                if !scrollInterrupted {
                    scrollView.scrollTo("bottom")
                }
            }
            .onChange(of: scrollID) { _, _ in
                if llm.running {
                    scrollInterrupted = true
                }
            }
        }
        .defaultScrollAnchor(.bottom)
        #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
        #endif
    }

    private var messageSetFingerprint: Int {
        var hasher = Hasher()
        hasher.combine(thread.messages.count)
        for message in thread.messages {
            hasher.combine(message.id)
            hasher.combine(message.role.rawValue)
            hasher.combine(message.content)
            hasher.combine(message.timestamp.timeIntervalSinceReferenceDate.bitPattern)
            hasher.combine(message.generatingTime?.bitPattern ?? 0)
        }
        return hasher.finalize()
    }

    private func refreshCachedMessages() {
        cachedSortedMessages = thread.sortedMessagesSnapshot()
    }
}

#Preview {
    ConversationView(thread: Thread(), generatingThreadID: nil, isPreparingResponse: false)
        .environment(LLMEvaluator())
        .environmentObject(AppManager())
}
