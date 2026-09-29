import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

extension ChatView {
    @MainActor
    func scheduleContextInvalidationForCurrentThread() {
        guard let threadID = currentThread?.id else { return }
        contextInvalidationTask?.cancel()
        contextInvalidationTask = Task {
            let interval = PerformanceTrace.begin("ChatContextInvalidation")
            do {
                try await _Concurrency.Task.sleep(nanoseconds: 150_000_000)
            } catch {
                PerformanceTrace.end(interval)
                return
            }
            await ChatContextAssembly.contextInjectionTracker.clear(threadID: threadID)
            await EvaExecutiveContextService.invalidateCache()
            PerformanceTrace.end(interval)
        }
    }

    @MainActor
    func refreshTranscriptSnapshot(for thread: Thread? = nil) {
        let snapshot = ChatTranscriptSnapshot(thread: thread ?? currentThread)
        guard transcriptSnapshot != snapshot else {
            if hasCompletedInitialTranscriptRender == false {
                hasCompletedInitialTranscriptRender = true
                if let chatOpenTraceInterval {
                    PerformanceTrace.end(chatOpenTraceInterval)
                    self.chatOpenTraceInterval = nil
                    PerformanceTrace.event("ChatTranscriptFirstRender")
                }
                EvaNavigationPerformanceTrace.markInteractive()
            }
            return
        }

        transcriptSnapshot = snapshot
        if hasCompletedInitialTranscriptRender == false {
            hasCompletedInitialTranscriptRender = true
            if let chatOpenTraceInterval {
                PerformanceTrace.end(chatOpenTraceInterval)
                self.chatOpenTraceInterval = nil
                PerformanceTrace.event("ChatTranscriptFirstRender")
            }
            EvaNavigationPerformanceTrace.markInteractive()
        }
    }

    #if os(macOS)
    /// Executes handleShiftReturn.
    func handleShiftReturn() {
        if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
            prompt.append("\n")
            isPromptFocused = true
        } else {
            generate()
        }
    }
    #endif
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatView(
        currentThread: .constant(nil),
        isPromptFocused: $isPromptFocused,
        showChats: .constant(false),
        showSettings: .constant(false)
    )
}
