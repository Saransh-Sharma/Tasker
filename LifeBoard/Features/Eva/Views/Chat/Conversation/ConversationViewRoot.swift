//
//  ConversationView.swift
//

import MarkdownUI
import LifeBoardDomain
import SwiftUI

struct ConversationView: View {


    @Environment(LLMEvaluator.self) var llm

    @EnvironmentObject var appManager: AppManager

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let snapshot: ChatTranscriptSnapshot

    let liveOutput: ChatLiveOutputState

    var onOpenTaskFromCard: ((TaskDefinition) -> Void)?

    var onOpenHabitFromCard: ((UUID) -> Void)?

    var onOpenRecordFromCard: ((EvaRecordReference) -> Void)?

    var onOpenNavigationTargetFromCard: ((EvaNavigationTarget) -> Void)?

    var onPerformDayTaskAction: EvaDayTaskActionHandler?

    var onPerformDayHabitAction: EvaDayHabitActionHandler?

    var onEditResend: ((UUID) -> Void)?

    @State var scrollID: String?

    @State var scrollInterrupted = false

    @State var now = Date()

    @State private var inkRevealProgress = 1.0

    /// Card decisions outlive the lazy stack's message views; see
    /// `EvaProposalCardSession`.
    @State private var cardSessions = EvaProposalCardSessions()

    /// Held as an instance so the pending target is observed.
    @State private var scrollTarget = EvaChatScrollTarget.shared
    @State private var highlightedMessageID: UUID?

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
                            onOpenRecordFromCard: onOpenRecordFromCard,
                            onOpenNavigationTargetFromCard: onOpenNavigationTargetFromCard,
                            onPerformDayTaskAction: onPerformDayTaskAction,
                            onPerformDayHabitAction: onPerformDayHabitAction,
                            onEditResend: onEditResend
                        )
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background {
                            // The message a search opened, lit briefly so the
                            // eye lands on it; a tint fade, not motion.
                            if highlightedMessageID == message.id {
                                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                                    .fill(Color.lifeboard(.accentWash))
                                    .padding(.horizontal, Theme.Spacing.sm)
                                    .transition(.opacity)
                                    .accessibilityHidden(true)
                            }
                        }
                        .id(message.id.uuidString)
                        .transition(messageTransition(for: message))
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
                            onOpenRecordFromCard: onOpenRecordFromCard,
                            onOpenNavigationTargetFromCard: onOpenNavigationTargetFromCard,
                            onPerformDayTaskAction: onPerformDayTaskAction,
                            onPerformDayHabitAction: onPerformDayHabitAction
                        )
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.sm)
                        .lifeboardEvaInkReveal(
                            progress: liveOutput.runtimePhase == .answering ? inkRevealProgress : 1,
                            newContentFraction: newlySettledContentFraction,
                            tint: Color.lifeboard(.accentPrimary)
                        )
                        .id(liveOutput.responseID?.uuidString ?? liveOutput.threadID?.uuidString ?? "output")
                        .transition(liveOutputTransition)
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
                .environment(\.evaProposalCardSessions, cardSessions)
                .animation(messageInsertionAnimation, value: snapshot.identityHash)
                .animation(messageInsertionAnimation, value: shouldRenderLiveOutput)
            }
            .background(Color.clear)
            .scrollPosition(id: $scrollID, anchor: .bottom)
            .overlay(alignment: .bottomTrailing) {
                if scrollInterrupted && shouldRenderLiveOutput {
                    Button {
                        scrollInterrupted = false
                        withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
                            scrollView.scrollTo("bottom", anchor: .bottom)
                        }
                    } label: {
                        Label("New response", systemImage: "arrow.down")
                            .lifeboardFont(.bodyStrong)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.lifeBoardChip)
                    .padding(.trailing, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .accessibilityHint("Scrolls to the latest text")
                }
            }
            .onAppear {
                if revealSearchTarget(with: scrollView) == false, !scrollInterrupted {
                    scrollView.scrollTo("bottom")
                }
            }
            .onChange(of: scrollTarget.messageID) { _, _ in
                _ = revealSearchTarget(with: scrollView)
            }
            .onChange(of: snapshot.identityHash) { _, _ in
                if revealSearchTarget(with: scrollView) == false, !scrollInterrupted {
                    scrollView.scrollTo("bottom")
                }
            }
            .onChange(of: liveOutput.text) { _, _ in
                if !scrollInterrupted {
                    scrollView.scrollTo("bottom")
                }
            }
            .onChange(of: llm.phraseSettlementSequence) { oldSequence, newSequence in
                guard newSequence > oldSequence,
                      liveOutput.runtimePhase == .answering else { return }
                inkRevealProgress = 0
                withAnimation(reduceMotion ? nil : LifeBoardAnimation.roleLocalState) {
                    inkRevealProgress = 1
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

                // A reply that finishes streaming is a state change nothing
                // announced, so VoiceOver users had to keep probing the
                // transcript to find out whether Eva was done.
                if oldPhase == .answering, newPhase != .answering {
                    AccessibilityNotification.Announcement("\(AssistantIdentitySnapshot.current.displayName) finished responding").post()
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

    private var messageInsertionAnimation: Animation? {
        LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.stateChange
    }

    private func messageTransition(for message: ChatMessageRenderModel) -> AnyTransition {
        guard LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false else {
            return .opacity
        }
        if message.role == .user {
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            )
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity
        )
    }

    private var liveOutputTransition: AnyTransition {
        guard LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false else {
            return .opacity
        }
        return .asymmetric(insertion: .opacity, removal: .opacity)
    }

    private var newlySettledContentFraction: Double {
        guard liveOutput.text.isEmpty == false else { return 1 }
        return min(
            1,
            Double(llm.lastSettledPhraseCharacterCount) / Double(liveOutput.text.count)
        )
    }
}

#Preview {
    ConversationView(snapshot: .empty, liveOutput: .empty)
        .environment(LLMEvaluator())
        .environmentObject(AppManager())
}

extension ConversationView {
    /// Scrolls to the message a search hit opened, once, and lights it.
    /// `false` when there is no target in this thread, so the caller keeps
    /// its usual scroll to the bottom.
    func revealSearchTarget(with scrollView: ScrollViewProxy) -> Bool {
        guard let target = scrollTarget.messageID,
              snapshot.messages.contains(where: { $0.id == target }) else { return false }
        _ = scrollTarget.consume()
        // Reading an older message is an interruption of the live tail.
        scrollInterrupted = true
        withAnimation(MotionProfile.route.animation(reduceMotion: reduceMotion)) {
            scrollView.scrollTo(target.uuidString, anchor: .center)
        }
        withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
            highlightedMessageID = target
        }
        AccessibilityNotification.Announcement("Showing the matching message").post()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_400))
            withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
                if highlightedMessageID == target { highlightedMessageID = nil }
            }
        }
        return true
    }
}
