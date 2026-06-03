//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaDayTaskActionsView: View {
    let actions: [EvaDayTaskAction]
    let isProcessing: Bool
    let actionTitle: (EvaDayTaskAction) -> String
    let actionHandler: (EvaDayTaskAction) -> Void

    var body: some View {
        HStack(spacing: LifeBoardTheme.Spacing.xs) {
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
