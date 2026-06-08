//
//  HomeTaskTintResolver.swift
//  LifeBoard
//
//  Shared helpers for resolving the tint used by home task rows.
//

import Foundation

enum HomeTaskTintResolver {
    static func owningSectionAccentHex(
        for task: TaskDefinition,
        projectsByID: [UUID: Project],
        lifeAreasByID: [UUID: LifeArea]
    ) -> String? {
        if let directLifeAreaAccent = lifeAreaAccentHex(
            for: task.lifeAreaID,
            lifeAreasByID: lifeAreasByID
        ) {
            return directLifeAreaAccent
        }

        return projectAccentHex(
            for: task.projectID,
            projectsByID: projectsByID,
            lifeAreasByID: lifeAreasByID
        )
    }

    static func sectionAccentHex(
        for anchor: HomeSectionAnchor,
        projectsByID: [UUID: Project],
        lifeAreasByID: [UUID: LifeArea]
    ) -> String? {
        switch anchor {
        case .project(let id, _, _, _):
            return projectAccentHex(
                for: id,
                projectsByID: projectsByID,
                lifeAreasByID: lifeAreasByID
            )

        case .lifeArea(let id, _, _):
            return lifeAreaAccentHex(for: id, lifeAreasByID: lifeAreasByID)

        case .dueTodaySummary, .focusNow, .plainList:
            return nil
        }
    }

    static func taskAccentHex(
        for task: TaskDefinition,
        projectsByID: [UUID: Project],
        lifeAreasByID: [UUID: LifeArea]
    ) -> String? {
        owningSectionAccentHex(
            for: task,
            projectsByID: projectsByID,
            lifeAreasByID: lifeAreasByID
        )
    }

    static func lifeAreaIconSymbolName(
        for task: TaskDefinition,
        projectsByID: [UUID: Project],
        lifeAreasByID: [UUID: LifeArea]
    ) -> String? {
        if let taskLifeAreaID = task.lifeAreaID {
            return normalizedIconSymbolName(for: taskLifeAreaID, lifeAreasByID: lifeAreasByID)
        }

        guard let projectLifeAreaID = projectsByID[task.projectID]?.lifeAreaID else { return nil }
        return normalizedIconSymbolName(for: projectLifeAreaID, lifeAreasByID: lifeAreasByID)
    }

    static func rowAccentHex(
        for row: HomeTodayRow,
        projectsByID: [UUID: Project],
        lifeAreasByID: [UUID: LifeArea]
    ) -> String? {
        switch row {
        case .task(let task):
            return owningSectionAccentHex(
                for: task,
                projectsByID: projectsByID,
                lifeAreasByID: lifeAreasByID
            )
        case .habit(let habit):
            if let accentHex = habit.accentHex {
                return accentHex
            }
            return lifeAreaAccentHex(
                for: habit.lifeAreaID,
                lifeAreasByID: lifeAreasByID
            )
        }
    }

    private static func lifeAreaAccentHex(
        for lifeAreaID: UUID?,
        lifeAreasByID: [UUID: LifeArea]
    ) -> String? {
        guard let lifeAreaID, let lifeArea = lifeAreasByID[lifeAreaID] else { return nil }
        return LifeAreaColorPalette.normalizeOrMap(hex: lifeArea.color, for: lifeArea.id)
    }

    private static func projectAccentHex(
        for projectID: UUID,
        projectsByID: [UUID: Project],
        lifeAreasByID: [UUID: LifeArea]
    ) -> String? {
        if let project = projectsByID[projectID] {
            if let inheritedLifeAreaAccent = lifeAreaAccentHex(
                for: project.lifeAreaID,
                lifeAreasByID: lifeAreasByID
            ) {
                return inheritedLifeAreaAccent
            }
            return project.color.hexString
        }

        if projectID == ProjectConstants.inboxProjectID {
            return Project.createInbox().color.hexString
        }

        return nil
    }

    private static func normalizedIconSymbolName(
        for lifeAreaID: UUID,
        lifeAreasByID: [UUID: LifeArea]
    ) -> String? {
        guard let icon = lifeAreasByID[lifeAreaID]?.icon?.trimmingCharacters(in: .whitespacesAndNewlines),
              icon.isEmpty == false
        else {
            return nil
        }
        return icon
    }
}
