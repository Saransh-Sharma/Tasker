//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

extension ConversationView {
    var shouldRenderLiveOutput: Bool {
        liveOutput.shouldRender && snapshot.threadID == liveOutput.threadID
    }

    var liveWorkingStatuses: [String] {
        EvaWorkingStatusLibrary.statuses(for: snapshot.recentUserMessageFragments)
    }
}
