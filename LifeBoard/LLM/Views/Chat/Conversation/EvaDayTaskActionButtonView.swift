//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaDayTaskActionButtonView: View {
    let action: EvaDayTaskAction
    let title: String
    let isProcessing: Bool
    let actionHandler: (EvaDayTaskAction) -> Void

    var body: some View {
        if action == .done {
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
