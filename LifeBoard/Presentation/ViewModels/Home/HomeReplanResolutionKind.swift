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

enum HomeReplanResolutionKind: Equatable {
    case rescheduled
    case movedToInbox
    case completed
    case deleted
}
