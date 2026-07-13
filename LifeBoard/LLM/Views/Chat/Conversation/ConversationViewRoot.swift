//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct ConversationView: View {


    @Environment(LLMEvaluator.self) var llm

    @EnvironmentObject var appManager: AppManager

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let snapshot: ChatTranscriptSnapshot

    let liveOutput: ChatLiveOutputState

    var onOpenTaskFromCard: ((TaskDefinition) -> Void)?

    var onOpenHabitFromCard: ((UUID) -> Void)?

    var onPerformDayTaskAction: EvaDayTaskActionHandler?

    var onPerformDayHabitAction: EvaDayHabitActionHandler?

    @State var scrollID: String?

    @State var scrollInterrupted = false

    @State var now = Date()

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
                        .padding(.horizontal, LifeBoardTheme.Spacing.lg)
                        .padding(.vertical, LifeBoardTheme.Spacing.sm)
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
                            onPerformDayTaskAction: onPerformDayTaskAction,
                            onPerformDayHabitAction: onPerformDayHabitAction
                        )
                        .padding(.horizontal, LifeBoardTheme.Spacing.lg)
                        .padding(.vertical, LifeBoardTheme.Spacing.sm)
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
                .animation(messageInsertionAnimation, value: snapshot.identityHash)
                .animation(messageInsertionAnimation, value: shouldRenderLiveOutput)
            }
            .background(Color.clear)
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
}

#Preview {
    ConversationView(snapshot: .empty, liveOutput: .empty)
        .environment(LLMEvaluator())
        .environmentObject(AppManager())
}
