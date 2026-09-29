//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

extension TimeInterval {
    var formatted: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return seconds > 0
                ? String(localized: "\(minutes) min \(seconds) sec")
                : String(localized: "\(minutes) min")
        }
        return String(localized: "\(seconds) sec")
    }
}
