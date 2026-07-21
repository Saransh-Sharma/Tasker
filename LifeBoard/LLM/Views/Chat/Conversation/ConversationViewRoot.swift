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

    @State private var inkRevealProgress = 1.0

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
                .animation(messageInsertionAnimation, value: snapshot.identityHash)
                .animation(messageInsertionAnimation, value: shouldRenderLiveOutput)
            }
            .background(Color.clear)
            .scrollPosition(id: $scrollID, anchor: .bottom)
            .overlay(alignment: .bottomTrailing) {
                if scrollInterrupted && shouldRenderLiveOutput {
                    Button {
                        scrollInterrupted = false
                        if reduceMotion {
                            scrollView.scrollTo("bottom", anchor: .bottom)
                        } else {
                            withAnimation(.snappy(duration: 0.24)) {
                                scrollView.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    } label: {
                        Label("New response", systemImage: "arrow.down")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.trailing, LifeBoardTheme.Spacing.lg)
                    .padding(.bottom, LifeBoardTheme.Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .accessibilityHint("Moves to the newest settled part of Eva's response")
                }
            }
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
            .onChange(of: llm.phraseSettlementSequence) { oldSequence, newSequence in
                guard newSequence > oldSequence,
                      liveOutput.runtimePhase == .answering else { return }
                inkRevealProgress = 0
                withAnimation(.linear(duration: reduceMotion ? 0.14 : 0.22)) {
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
