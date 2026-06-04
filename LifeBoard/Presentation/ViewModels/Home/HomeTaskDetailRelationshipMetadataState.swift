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

struct HomeTaskDetailRelationshipMetadataState: Sendable {
    var lifeAreas: [LifeArea] = []
    var tags: [TagDefinition] = []
    var availableTasks: [TaskDefinition] = []
    var recentReflectionNotes: [ReflectionNote] = []
}
