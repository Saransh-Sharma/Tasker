import SwiftUI

extension ChatScaffoldView {
    var isActivationPresentation: Bool {
        if case .activation = presentationMode {
            return true
        }
        return false
    }

    var activationConfiguration: EvaActivationChatConfiguration? {
        guard case .activation(let config) = presentationMode else { return nil }
        return config
    }

    var hasActivationAssistantReply: Bool {
        transcriptSnapshot.messages.contains { $0.role == .assistant }
    }

    var navigationChromeState: EvaChatNavigationChromeState {
        EvaChatNavigationChromeState(
            title: assistantIdentity.snapshot.displayName,
            subtitle: currentThread == nil ? "Ask or use / commands" : chatTitle,
            showsUtilityActions: activationConfiguration?.hideUtilityActions != true,
            showsHistoryAction: showsHistoryAction && isActivationPresentation == false,
            showsNewChatAction: currentThread != nil && isActivationPresentation == false
        )
    }

    func publishNavigationChromeState() {
        onNavigationChromeChange?(navigationChromeState)
    }
}
