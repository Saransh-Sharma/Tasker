//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaDayHabitActionsView: View {
    let actions: [EvaDayHabitAction]
    let isProcessing: Bool
    let actionTitle: (EvaDayHabitAction) -> String
    let actionHandler: (EvaDayHabitAction) -> Void

    var body: some View {
        HStack(spacing: LifeBoardTheme.Spacing.xs) {
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
