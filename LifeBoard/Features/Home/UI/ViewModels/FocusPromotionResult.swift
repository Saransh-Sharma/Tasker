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

public enum FocusPromotionResult: Equatable {
    case promoted
    case alreadyPinned
    case alreadyVisible
    case replacementRequired(currentFocusTaskIDs: [UUID])
    case taskIneligible
}
