//
//  HomeTaskTintResolver.swift
//  Tasker
//
//  Shared helpers for resolving the tint used by home task rows.
//

import Foundation

enum HomeTaskTintResolver {
    static func sectionAccentHex(
        for anchor: HomeSectionAnchor,
        projectsByID: [UUID: Project],
        lifeAreasByID: [UUID: LifeArea]
    ) -> String? {
        switch anchor {
        case .project(let id, _, _, _):
            return projectsByID[id]?.color.hexString

        case .lifeArea(let id, _, _):
            guard let id, let lifeArea = lifeAreasByID[id] else { return nil }
            return LifeAreaColorPalette.normalizeOrMap(hex: lifeArea.color, for: lifeArea.id)

        case .dueTodaySummary, .focusNow, .plainList:
            return nil
        }
    }

    static func taskAccentHex(
        for task: TaskDefinition,
        projectsByID: [UUID: Project],
        lifeAreasByID: [UUID: LifeArea]
    ) -> String? {
        if let lifeAreaID = task.lifeAreaID,
           let lifeArea = lifeAreasByID[lifeAreaID] {
            return LifeAreaColorPalette.normalizeOrMap(hex: lifeArea.color, for: lifeArea.id)
        }

        if let project = projectsByID[task.projectID] {
            if let projectLifeAreaID = project.lifeAreaID,
               let lifeArea = lifeAreasByID[projectLifeAreaID] {
                return LifeAreaColorPalette.normalizeOrMap(hex: lifeArea.color, for: lifeArea.id)
            }
            return project.color.hexString
        }

        if task.projectID == ProjectConstants.inboxProjectID {
            return Project.createInbox().color.hexString
        }

        return nil
    }
}
