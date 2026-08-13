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

public enum HomeOverdueRescueLauncherState: Equatable {
    case idle
    case loading
    case ready
    case failed(String)
}

/// ViewModel for the Home screen
/// Manages all business logic and state for the home view
