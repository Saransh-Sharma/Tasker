//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

struct HomeCalendarEventDetailSelection: Identifiable, Equatable {
    let eventID: String
    let selectedDate: Date
    let allowsTimelineHide: Bool

    var id: String {
        "\(eventID):\(HomeTimelineHiddenCalendarEventKey.dayStamp(for: selectedDate)):\(allowsTimelineHide)"
    }
}
