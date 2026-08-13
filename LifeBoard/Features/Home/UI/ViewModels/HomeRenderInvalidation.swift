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

struct HomeRenderInvalidation: OptionSet {
    let rawValue: Int

    static let chrome = HomeRenderInvalidation(rawValue: 1 << 0)
    static let tasks = HomeRenderInvalidation(rawValue: 1 << 1)
    static let habits = HomeRenderInvalidation(rawValue: 1 << 2)
    static let calendar = HomeRenderInvalidation(rawValue: 1 << 3)
    static let overlay = HomeRenderInvalidation(rawValue: 1 << 4)
    static let timeline = HomeRenderInvalidation(rawValue: 1 << 5)

    static let all: HomeRenderInvalidation = [.chrome, .tasks, .habits, .calendar, .overlay, .timeline]

    func includes(_ other: HomeRenderInvalidation) -> Bool {
        intersection(other).isEmpty == false
    }
}
