//
//  HomeViewModel.swift
//  LifeBoard
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

public enum HomeDateNavigationSource: String {
    case datePicker
    case weekStrip
    case swipe
    case backToToday
    case replan
    case dailyReflection
    /// Triggered by the universal input composer (e.g. "check my meetings").
    case universalInput
}
