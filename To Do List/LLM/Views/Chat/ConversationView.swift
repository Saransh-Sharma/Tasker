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
    @Environment(LLMEvaluator.self) var llm
    @State private var collapsed = true
    @State private var now = Date()
    @State private var undoExpiredLogged = false

    let message: Message
    var isLiveOutput: Bool = false
    var onApplyProposal: ((Message, AssistantCardPayload) -> Void)?
    var onRejectProposal: ((Message, AssistantCardPayload) -> Void)?
    var onUndoRun: ((Message, AssistantCardPayload) -> Void)?
    var onRefreshContext: ((Message, AssistantCardPayload) -> Void)?

    private let countdownTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var cardPayload: AssistantCardPayload? {
        AssistantCardCodec.decode(from: message.content)
    }

    var isThinking: Bool {
        !message.content.contains("</think>")
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
        if isThinking, llm.running, let elapsedTime = llm.elapsedTime {
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
                                        Markdown(thinking)
                                            .textSelection(.enabled)
                                            .markdownTextStyle {
                                                ForegroundColor(Color.tasker(.textSecondary))
                                            }
                                    }
                                    .padding(.leading, 5)
                                }
                            }
                            .contentShape(.rect)
                            .onTapGesture {
                                collapsed.toggle()
                                if isThinking {
                                    llm.collapsed = collapsed
                                }
                            }
                        }

                        if let afterThink {
                            Markdown(afterThink)
                                .textSelection(.enabled)
                                .markdownTextStyle {
                                    ForegroundColor(Color.tasker(.textPrimary))
                                }
                        }

                        if isLiveOutput && llm.running {
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
            if llm.running {
                collapsed = false
            }
        }
        .onChange(of: llm.elapsedTime) {
            if isThinking {
                llm.thinkingTime = llm.elapsedTime
            }
        }
        .onChange(of: isThinking) {
            if llm.running {
                llm.isThinking = isThinking
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

    @State private var scrollID: String?
    @State private var scrollInterrupted = false

    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(thread.sortedMessages.enumerated()), id: \.element.id) { index, message in
                        MessageView(
                            message: message,
                            onApplyProposal: onApplyProposal,
                            onRejectProposal: onRejectProposal,
                            onUndoRun: onUndoRun,
                            onRefreshContext: onRefreshContext
                        )
                            .padding(.horizontal, TaskerTheme.Spacing.lg)
                            .padding(.vertical, TaskerTheme.Spacing.sm)
                            .staggeredAppearance(index: index)
                            .id(message.id.uuidString)
                    }

                    if (llm.running || isPreparingResponse) && !llm.output.isEmpty && thread.id == generatingThreadID {
                        VStack {
                            MessageView(message: Message(role: .assistant, content: llm.output), isLiveOutput: true)
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
                if !scrollInterrupted {
                    scrollView.scrollTo("bottom")
                }

                if !llm.isThinking {
                    appManager.playHaptic()
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
}

#Preview {
    ConversationView(thread: Thread(), generatingThreadID: nil, isPreparingResponse: false)
        .environment(LLMEvaluator())
        .environmentObject(AppManager())
}
