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

public enum FocusPinResult: Equatable {
    case pinned
    case alreadyPinned
    case capacityReached(limit: Int)
    case taskIneligible
}
