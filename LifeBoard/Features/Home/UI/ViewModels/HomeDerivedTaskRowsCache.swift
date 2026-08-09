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

struct HomeDerivedTaskRowsCache {
    let revision: UInt64
    let quickView: HomeQuickView
    let rows: [TaskDefinition]
}
