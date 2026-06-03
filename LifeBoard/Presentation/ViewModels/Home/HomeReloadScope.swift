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

public enum HomeReloadScope: String, CaseIterable, Hashable, Sendable {
    case visibleTasks
    case habits
    case facets
    case analytics
    case insightss
    case savedViews
}
