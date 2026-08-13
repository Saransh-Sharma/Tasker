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

struct HomeReplanUndoEntry: Equatable {
    let runID: UUID
    let action: HomeReplanResolutionKind
    let candidate: HomeReplanCandidate
}
