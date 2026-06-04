//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaDayHabitActionButtonView: View {
    let action: EvaDayHabitAction
    let title: String
    let isProcessing: Bool
    let actionHandler: (EvaDayHabitAction) -> Void

    var body: some View {
        if action == .done || action == .stayedClean {
            Button(title) {
                actionHandler(action)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.lifeboard(.accentPrimary))
            .disabled(isProcessing)
        } else {
            Button(title) {
                actionHandler(action)
            }
            .buttonStyle(.bordered)
            .tint(Color.lifeboard(.accentMuted))
            .disabled(isProcessing)
        }
    }
}
