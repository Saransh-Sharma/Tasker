import Foundation
import SwiftUI
import UniformTypeIdentifiers

private enum LifeManagementConstants {
    static let generalDisplayName = "General"
    static let generalNormalizedName = "general"
}

private func lifeManagementTreeAreaAccentHex(_ area: LifeArea?) -> String {
    guard let area else { return HabitColorFamily.green.canonicalHex }
    return LifeAreaColorPalette.normalizeOrMap(hex: area.color, for: area.id)
}

private func lifeManagementTreeHabitStatusText(_ row: HabitLibraryRow) -> String {
    if row.isArchived { return "Archived" }
    if row.isPaused { return "Paused" }
    if row.currentStreak > 0 { return "\(row.currentStreak)d streak" }

    switch row.cadence {
    case .daily:
        return "Daily"
    case .weekly(let days, _, _):
        return days.count == 1 ? "Weekly" : "\(days.count)x weekly"
    }
}

public struct LifeAreaIconOption: Identifiable, Equatable, Hashable {
    public let symbolName: String
    public let keywords: [String]

    public var id: String { symbolName }

    public init(symbolName: String, keywords: [String]) {
        self.symbolName = symbolName
        self.keywords = keywords
    }
}

public struct LifeManagementAreaRow: Identifiable, Equatable {
    public let lifeArea: LifeArea
    public let projectCount: Int
    public let habitCount: Int
    public let taskCount: Int
    public let isGeneral: Bool

    public var id: UUID { lifeArea.id }
}

public struct LifeManagementProjectRow: Identifiable, Equatable {
    public let project: Project
    public let taskCount: Int
    public let lifeArea: LifeArea?
    public let linkedHabitCount: Int

    public var id: UUID { project.id }
    public var isInbox: Bool { project.isInbox || project.id == ProjectConstants.inboxProjectID }
    public var isMoveLocked: Bool { isInbox || project.isDefault }
}

public struct LifeManagementHabitRow: Identifiable, Equatable {
    public let row: HabitLibraryRow
    public let lifeArea: LifeArea?
    public let project: Project?

    public var id: UUID { row.habitID }
}

public enum LifeManagementSelection: Hashable, Identifiable {
    case area(UUID)
    case project(UUID)
    case habit(UUID)

    public var id: String {
        switch self {
        case .area(let id):
            return "area:\(id.uuidString)"
        case .project(let id):
            return "project:\(id.uuidString)"
        case .habit(let id):
            return "habit:\(id.uuidString)"
        }
    }
}

public enum LifeManagementTreeSectionKind: String, Hashable, Identifiable {
    case active
    case archived

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .active:
            return "Life Areas"
        case .archived:
            return "Archived"
        }
    }
}

public enum LifeManagementTreeNodePayload: Equatable {
    case area(LifeManagementAreaRow)
    case project(LifeManagementProjectRow)
    case habit(LifeManagementHabitRow)
}

public struct LifeManagementTreeNode: Identifiable, Equatable {
    public let payload: LifeManagementTreeNodePayload
    public let children: [LifeManagementTreeNode]
    public let isArchived: Bool

    public init(
        payload: LifeManagementTreeNodePayload,
        children: [LifeManagementTreeNode] = [],
        isArchived: Bool
    ) {
        self.payload = payload
        self.children = children
        self.isArchived = isArchived
    }

    public var selection: LifeManagementSelection {
        switch payload {
        case .area(let row):
            return .area(row.id)
        case .project(let row):
            return .project(row.id)
        case .habit(let row):
            return .habit(row.id)
        }
    }

    public var id: String { selection.id }

    public var accessibilityIdentifier: String {
        switch selection {
        case .area(let id):
            return "settings.lifeManagement.node.area.\(id.uuidString)"
        case .project(let id):
            return "settings.lifeManagement.node.project.\(id.uuidString)"
        case .habit(let id):
            return "settings.lifeManagement.node.habit.\(id.uuidString)"
        }
    }

    public var title: String {
        switch payload {
        case .area(let row):
            return row.lifeArea.name
        case .project(let row):
            return row.project.name
        case .habit(let row):
            return row.row.title
        }
    }

    public var subtitle: String {
        switch payload {
        case .area(let row):
            return "\(row.projectCount) projects · \(row.habitCount) habits"
        case .project(let row):
            var parts: [String] = [row.lifeArea?.name ?? LifeManagementConstants.generalDisplayName]
            parts.append(row.taskCount == 0 ? "Empty" : "\(row.taskCount) open tasks")
            if row.linkedHabitCount > 0 {
                parts.append("\(row.linkedHabitCount) habits")
            }
            return parts.joined(separator: " · ")
        case .habit(let row):
            var parts: [String] = [row.row.kind == .positive ? "Build" : "Quit"]
            if let projectName = row.row.projectName?.nilIfBlank {
                parts.append(projectName)
            } else if let lifeAreaName = row.lifeArea?.name.nilIfBlank {
                parts.append(lifeAreaName)
            }
            parts.append(lifeManagementTreeHabitStatusText(row.row))
            return parts.joined(separator: " · ")
        }
    }

    public var symbolName: String {
        switch payload {
        case .area(let row):
            return row.lifeArea.icon ?? "square.grid.2x2"
        case .project(let row):
            return row.project.icon.systemImageName
        case .habit(let row):
            return row.row.icon?.symbolName ?? "circle.dashed"
        }
    }

    public var accentHex: String {
        switch payload {
        case .area(let row):
            return LifeAreaColorPalette.normalizeOrMap(hex: row.lifeArea.color, for: row.id)
        case .project(let row):
            return row.project.color.hexString
        case .habit(let row):
            return row.row.colorHex ?? lifeManagementTreeAreaAccentHex(row.lifeArea)
        }
    }

    public var isExpandable: Bool {
        children.isEmpty == false
    }
}

public struct LifeManagementTreeSection: Identifiable, Equatable {
    public let kind: LifeManagementTreeSectionKind
    public let title: String
    public let nodes: [LifeManagementTreeNode]

    public init(kind: LifeManagementTreeSectionKind, title: String, nodes: [LifeManagementTreeNode]) {
        self.kind = kind
        self.title = title
        self.nodes = nodes
    }

    public var id: String { kind.rawValue }

    public var accessibilityIdentifier: String {
        "settings.lifeManagement.section.\(kind.rawValue)"
    }
}

public struct LifeManagementLifeAreaDraft: Identifiable, Equatable {
    public let id: UUID
    public let existingID: UUID?
    public var name: String
    public var colorHex: String
    public var iconSymbolName: String

    public var isNew: Bool { existingID == nil }

    public init(
        id: UUID = UUID(),
        existingID: UUID? = nil,
        name: String,
        colorHex: String,
        iconSymbolName: String
    ) {
        self.id = id
        self.existingID = existingID
        self.name = name
        self.colorHex = colorHex
        self.iconSymbolName = iconSymbolName
    }
}

public struct LifeManagementProjectDraft: Identifiable, Equatable {
    public let id: UUID
    public let existingID: UUID?
    public var name: String
    public var description: String
    public var lifeAreaID: UUID?
    public var color: ProjectColor
    public var icon: ProjectIcon

    public var isNew: Bool { existingID == nil }

    public init(
        id: UUID = UUID(),
        existingID: UUID? = nil,
        name: String,
        description: String,
        lifeAreaID: UUID?,
        color: ProjectColor,
        icon: ProjectIcon
    ) {
        self.id = id
        self.existingID = existingID
        self.name = name
        self.description = description
        self.lifeAreaID = lifeAreaID
        self.color = color
        self.icon = icon
    }
}

public struct LifeManagementProjectMoveDraft: Identifiable, Equatable {
    public let id: UUID
    public let projectID: UUID
    public let projectName: String
    public var targetLifeAreaID: UUID?
}

public struct LifeManagementDeleteAreaDraft: Identifiable, Equatable {
    public let id: UUID
    public let areaID: UUID
    public let areaName: String
    public let projectCount: Int
    public let habitCount: Int
    public var destinationLifeAreaID: UUID?
}

public struct LifeManagementDeleteProjectDraft: Identifiable, Equatable {
    public let id: UUID
    public let projectID: UUID
    public let projectName: String
    public let taskCount: Int
    public let linkedHabitCount: Int
    public var destinationProjectID: UUID?
}

public struct LifeManagementDeleteHabitDraft: Identifiable, Equatable {
    public let id: UUID
    public let habitID: UUID
    public let habitTitle: String
}

private enum LifeManagementUndoAction {
    case lifeArea(UUID)
    case project(UUID)
    case habit(UUID)
}

struct LifeManagementAreaDetailSnapshot: Equatable {
    let row: LifeManagementAreaRow
    let projectRows: [LifeManagementProjectRow]
    let habitRows: [LifeManagementHabitRow]
}

struct LifeManagementProjectDetailSnapshot: Equatable {
    let row: LifeManagementProjectRow
    let linkedHabits: [LifeManagementHabitRow]
}

struct LifeManagementProjection {
    struct Snapshot: Equatable {
        let treeSections: [LifeManagementTreeSection]
        let searchExpandedAncestorNodeIDs: Set<String>
    }

    struct Context: Equatable {
        let sections: [LifeManagementTreeSection]
        let areaRowsByID: [UUID: LifeManagementAreaRow]
        let projectRowsByID: [UUID: LifeManagementProjectRow]
        let habitRowsByID: [UUID: LifeManagementHabitRow]
        let areaDetailByID: [UUID: LifeManagementAreaDetailSnapshot]
        let projectDetailByID: [UUID: LifeManagementProjectDetailSnapshot]
        let allProjectCountByAreaID: [UUID: Int]
        let allHabitCountByAreaID: [UUID: Int]
        let allLinkedHabitCountByProjectID: [UUID: Int]
        let ancestorNodeIDsBySelection: [LifeManagementSelection: Set<String>]

        static let empty = Context(
            sections: [],
            areaRowsByID: [:],
            projectRowsByID: [:],
            habitRowsByID: [:],
            areaDetailByID: [:],
            projectDetailByID: [:],
            allProjectCountByAreaID: [:],
            allHabitCountByAreaID: [:],
            allLinkedHabitCountByProjectID: [:],
            ancestorNodeIDsBySelection: [:]
        )

        func snapshot(searchQuery: String) -> Snapshot {
            let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedQuery.isEmpty == false else {
                return Snapshot(treeSections: sections, searchExpandedAncestorNodeIDs: [])
            }

            var expandedAncestors = Set<String>()
            let filteredSections = sections.compactMap { section -> LifeManagementTreeSection? in
                let filteredNodes = section.nodes.compactMap { LifeManagementProjection.filteredNode($0, query: normalizedQuery, expandedAncestors: &expandedAncestors) }
                guard filteredNodes.isEmpty == false else { return nil }
                return LifeManagementTreeSection(kind: section.kind, title: section.title, nodes: filteredNodes)
            }
            return Snapshot(treeSections: filteredSections, searchExpandedAncestorNodeIDs: expandedAncestors)
        }
    }

    static func prepare(
        lifeAreas: [LifeArea],
        projectStats: [ProjectWithStats],
        habitRows: [HabitLibraryRow],
        generalLifeAreaID: UUID?
    ) -> Context {
        let areasByID = Dictionary(uniqueKeysWithValues: lifeAreas.map { ($0.id, $0) })

        let projectRows = projectStats.map { entry in
            let resolvedAreaID = entry.project.lifeAreaID ?? generalLifeAreaID
            return LifeManagementProjectRow(
                project: entry.project,
                taskCount: entry.taskCount,
                lifeArea: resolvedAreaID.flatMap { areasByID[$0] },
                linkedHabitCount: 0
            )
        }
        let projectsByID = Dictionary(uniqueKeysWithValues: projectRows.map { ($0.project.id, $0.project) })

        let habitViewRows = habitRows.map { row in
            let resolvedLifeAreaID = row.lifeAreaID ?? generalLifeAreaID
            return LifeManagementHabitRow(
                row: row,
                lifeArea: resolvedLifeAreaID.flatMap { areasByID[$0] },
                project: row.projectID.flatMap { projectsByID[$0] }
            )
        }

        let allHabitRowsByProjectID = groupedHabitRowsByProjectID(habitViewRows)
        let linkedHabitCountByProjectID = Dictionary(
            uniqueKeysWithValues: projectRows.map { ($0.id, (allHabitRowsByProjectID[$0.id] ?? []).count) }
        )
        let resolvedProjectRows = projectRows.map { row in
            LifeManagementProjectRow(
                project: row.project,
                taskCount: row.taskCount,
                lifeArea: row.lifeArea,
                linkedHabitCount: linkedHabitCountByProjectID[row.id] ?? 0
            )
        }
        let projectRowsByID = Dictionary(uniqueKeysWithValues: resolvedProjectRows.map { ($0.id, $0) })
        let resolvedProjectsByID = Dictionary(uniqueKeysWithValues: resolvedProjectRows.map { ($0.id, $0.project) })

        let resolvedHabitRows = habitRows.map { row in
            let resolvedLifeAreaID = row.lifeAreaID ?? generalLifeAreaID
            return LifeManagementHabitRow(
                row: row,
                lifeArea: resolvedLifeAreaID.flatMap { areasByID[$0] },
                project: row.projectID.flatMap { resolvedProjectsByID[$0] }
            )
        }
        let habitRowsByID = Dictionary(uniqueKeysWithValues: resolvedHabitRows.map { ($0.id, $0) })

        let activeAreas = sortAreas(lifeAreas.filter { $0.isArchived == false })
        let allAreas = sortAreas(lifeAreas)

        let activeProjects = sortProjectRows(resolvedProjectRows.filter { isArchived(projectRow: $0) == false })
        let archivedProjects = sortProjectRows(resolvedProjectRows.filter { isArchived(projectRow: $0) })
        let activeHabits = sortHabitRows(resolvedHabitRows.filter { isArchived(habitRow: $0) == false })
        let archivedHabits = sortHabitRows(resolvedHabitRows.filter { isArchived(habitRow: $0) })

        let activeProjectsByAreaID = groupedProjectRowsByAreaID(activeProjects)
        let archivedProjectsByAreaID = groupedProjectRowsByAreaID(archivedProjects)
        let activeDirectHabitsByAreaID = groupedDirectHabitRowsByAreaID(activeHabits)
        let archivedDirectHabitsByAreaID = groupedDirectHabitRowsByAreaID(archivedHabits)
        let activeHabitsByAreaID = groupedHabitRowsByAreaID(activeHabits)
        let archivedHabitsByAreaID = groupedHabitRowsByAreaID(archivedHabits)
        let activeHabitsByProjectID = groupedHabitRowsByProjectID(activeHabits)
        let archivedHabitsByProjectID = groupedHabitRowsByProjectID(archivedHabits)

        let activeAreaRows = activeAreas.map { area in
            buildAreaRow(
                area: area,
                projectRows: activeProjectsByAreaID[area.id] ?? [],
                habitRows: activeHabitsByAreaID[area.id] ?? []
            )
        }
        let activeAreaRowsByID = Dictionary(uniqueKeysWithValues: activeAreaRows.map { ($0.id, $0) })

        let archivedAreaRows = allAreas.compactMap { area -> LifeManagementAreaRow? in
            let projectRows = archivedProjectsByAreaID[area.id] ?? []
            let areaHabitRows = archivedHabitsByAreaID[area.id] ?? []
            guard area.isArchived || projectRows.isEmpty == false || areaHabitRows.isEmpty == false else {
                return nil
            }
            return buildAreaRow(area: area, projectRows: projectRows, habitRows: areaHabitRows)
        }
        let archivedAreaRowsByID = Dictionary(uniqueKeysWithValues: archivedAreaRows.map { ($0.id, $0) })

        let activeNodes = activeAreaRows.map { areaRow in
            areaNode(
                row: areaRow,
                projectRows: activeProjectsByAreaID[areaRow.id] ?? [],
                directHabitRows: activeDirectHabitsByAreaID[areaRow.id] ?? [],
                habitsByProjectID: activeHabitsByProjectID,
                isArchivedSection: false
            )
        }
        let archivedNodes = archivedAreaRows.map { areaRow in
            areaNode(
                row: areaRow,
                projectRows: archivedProjectsByAreaID[areaRow.id] ?? [],
                directHabitRows: archivedDirectHabitsByAreaID[areaRow.id] ?? [],
                habitsByProjectID: archivedHabitsByProjectID,
                isArchivedSection: true
            )
        }

        let sections = [
            LifeManagementTreeSection(kind: .active, title: LifeManagementTreeSectionKind.active.title, nodes: activeNodes),
            LifeManagementTreeSection(kind: .archived, title: LifeManagementTreeSectionKind.archived.title, nodes: archivedNodes)
        ].filter { $0.nodes.isEmpty == false }

        let areaRowsByID = activeAreaRows.reduce(into: archivedAreaRowsByID) { partialResult, row in
            partialResult[row.id] = row
        }
        let areaDetailByID = Dictionary(uniqueKeysWithValues: allAreas.compactMap { area -> (UUID, LifeManagementAreaDetailSnapshot)? in
            let row = activeAreaRowsByID[area.id] ?? archivedAreaRowsByID[area.id]
            guard let row else { return nil }
            let projectRows = area.isArchived
                ? sortProjectRows(archivedProjectsByAreaID[area.id] ?? [])
                : sortProjectRows(activeProjectsByAreaID[area.id] ?? [])
            let habitRows = area.isArchived
                ? sortHabitRows(archivedHabitsByAreaID[area.id] ?? [])
                : sortHabitRows(activeHabitsByAreaID[area.id] ?? [])
            return (
                area.id,
                LifeManagementAreaDetailSnapshot(
                    row: row,
                    projectRows: projectRows,
                    habitRows: habitRows
                )
            )
        })
        let projectDetailByID = Dictionary(uniqueKeysWithValues: resolvedProjectRows.map { row in
            let linkedHabits = isArchived(projectRow: row)
                ? sortHabitRows(archivedHabitsByProjectID[row.id] ?? [])
                : sortHabitRows(activeHabitsByProjectID[row.id] ?? [])
            return (
                row.id,
                LifeManagementProjectDetailSnapshot(
                    row: row,
                    linkedHabits: linkedHabits
                )
            )
        })

        let allProjectCountByAreaID = Dictionary(
            uniqueKeysWithValues: allAreas.map { area in
                let count = resolvedProjectRows.filter { $0.lifeArea?.id == area.id }.count
                return (area.id, count)
            }
        )
        let allHabitCountByAreaID = Dictionary(
            uniqueKeysWithValues: allAreas.map { area in
                let count = resolvedHabitRows.filter { $0.lifeArea?.id == area.id }.count
                return (area.id, count)
            }
        )
        let allLinkedHabitCountByProjectID = Dictionary(
            uniqueKeysWithValues: resolvedProjectRows.map { ($0.id, (allHabitRowsByProjectID[$0.id] ?? []).count) }
        )

        var ancestorNodeIDsBySelection: [LifeManagementSelection: Set<String>] = [:]
        for section in sections {
            populateAncestorMap(nodes: section.nodes, ancestors: [], result: &ancestorNodeIDsBySelection)
        }

        return Context(
            sections: sections,
            areaRowsByID: areaRowsByID,
            projectRowsByID: projectRowsByID,
            habitRowsByID: habitRowsByID,
            areaDetailByID: areaDetailByID,
            projectDetailByID: projectDetailByID,
            allProjectCountByAreaID: allProjectCountByAreaID,
            allHabitCountByAreaID: allHabitCountByAreaID,
            allLinkedHabitCountByProjectID: allLinkedHabitCountByProjectID,
            ancestorNodeIDsBySelection: ancestorNodeIDsBySelection
        )
    }

    private static func areaNode(
        row: LifeManagementAreaRow,
        projectRows: [LifeManagementProjectRow],
        directHabitRows: [LifeManagementHabitRow],
        habitsByProjectID: [UUID: [LifeManagementHabitRow]],
        isArchivedSection: Bool
    ) -> LifeManagementTreeNode {
        let projectNodes = sortProjectRows(projectRows).map { projectRow in
            projectNode(
                row: projectRow,
                habitRows: habitsByProjectID[projectRow.id] ?? [],
                isArchivedSection: isArchivedSection
            )
        }
        let directHabitNodes = sortHabitRows(directHabitRows).map { habitRow in
            habitNode(row: habitRow, isArchivedSection: isArchivedSection)
        }
        return LifeManagementTreeNode(
            payload: .area(row),
            children: projectNodes + directHabitNodes,
            isArchived: isArchivedSection || row.lifeArea.isArchived
        )
    }

    private static func projectNode(
        row: LifeManagementProjectRow,
        habitRows: [LifeManagementHabitRow],
        isArchivedSection: Bool
    ) -> LifeManagementTreeNode {
        let childNodes = sortHabitRows(habitRows).map { habitNode(row: $0, isArchivedSection: isArchivedSection) }
        return LifeManagementTreeNode(
            payload: .project(row),
            children: childNodes,
            isArchived: isArchivedSection || isArchived(projectRow: row)
        )
    }

    private static func habitNode(
        row: LifeManagementHabitRow,
        isArchivedSection: Bool
    ) -> LifeManagementTreeNode {
        LifeManagementTreeNode(
            payload: .habit(row),
            children: [],
            isArchived: isArchivedSection || isArchived(habitRow: row)
        )
    }

    private static func filteredNode(
        _ node: LifeManagementTreeNode,
        query: String,
        expandedAncestors: inout Set<String>
    ) -> LifeManagementTreeNode? {
        let filteredChildren = node.children.compactMap { filteredNode($0, query: query, expandedAncestors: &expandedAncestors) }
        let matchesSelf = matchesSearch(node: node, query: query)
        guard matchesSelf || filteredChildren.isEmpty == false else {
            return nil
        }
        if filteredChildren.isEmpty == false {
            expandedAncestors.insert(node.id)
        }
        return LifeManagementTreeNode(payload: node.payload, children: filteredChildren, isArchived: node.isArchived)
    }

    private static func groupedProjectRowsByAreaID(_ rows: [LifeManagementProjectRow]) -> [UUID: [LifeManagementProjectRow]] {
        Dictionary(grouping: rows.compactMap { row -> (UUID, LifeManagementProjectRow)? in
            guard let lifeAreaID = row.lifeArea?.id else { return nil }
            return (lifeAreaID, row)
        }, by: \.0)
        .mapValues { $0.map(\.1) }
    }

    private static func groupedHabitRowsByAreaID(_ rows: [LifeManagementHabitRow]) -> [UUID: [LifeManagementHabitRow]] {
        Dictionary(grouping: rows.compactMap { row -> (UUID, LifeManagementHabitRow)? in
            guard let lifeAreaID = row.lifeArea?.id else { return nil }
            return (lifeAreaID, row)
        }, by: \.0)
        .mapValues { $0.map(\.1) }
    }

    private static func groupedDirectHabitRowsByAreaID(_ rows: [LifeManagementHabitRow]) -> [UUID: [LifeManagementHabitRow]] {
        Dictionary(grouping: rows.compactMap { row -> (UUID, LifeManagementHabitRow)? in
            guard row.project == nil, let lifeAreaID = row.lifeArea?.id else { return nil }
            return (lifeAreaID, row)
        }, by: \.0)
        .mapValues { $0.map(\.1) }
    }

    private static func groupedHabitRowsByProjectID(_ rows: [LifeManagementHabitRow]) -> [UUID: [LifeManagementHabitRow]] {
        Dictionary(grouping: rows.compactMap { row -> (UUID, LifeManagementHabitRow)? in
            guard let projectID = row.project?.id else { return nil }
            return (projectID, row)
        }, by: \.0)
        .mapValues { $0.map(\.1) }
    }

    private static func buildAreaRow(
        area: LifeArea,
        projectRows: [LifeManagementProjectRow],
        habitRows: [LifeManagementHabitRow]
    ) -> LifeManagementAreaRow {
        LifeManagementAreaRow(
            lifeArea: area,
            projectCount: projectRows.count,
            habitCount: habitRows.count,
            taskCount: projectRows.reduce(0) { $0 + $1.taskCount },
            isGeneral: normalizedAreaName(area.name) == LifeManagementConstants.generalNormalizedName
        )
    }

    private static func populateAncestorMap(
        nodes: [LifeManagementTreeNode],
        ancestors: Set<String>,
        result: inout [LifeManagementSelection: Set<String>]
    ) {
        for node in nodes {
            result[node.selection] = ancestors
            populateAncestorMap(nodes: node.children, ancestors: ancestors.union([node.id]), result: &result)
        }
    }

    private static func isArchived(projectRow: LifeManagementProjectRow) -> Bool {
        projectRow.project.isArchived || projectRow.lifeArea?.isArchived == true
    }

    private static func isArchived(habitRow: LifeManagementHabitRow) -> Bool {
        habitRow.row.isArchived || habitRow.lifeArea?.isArchived == true || habitRow.project?.isArchived == true
    }

    private static func matchesSearch(node: LifeManagementTreeNode, query: String) -> Bool {
        switch node.payload {
        case .area(let row):
            return matchesSearch(areaRow: row, query: query)
        case .project(let row):
            return matchesSearch(projectRow: row, query: query)
        case .habit(let row):
            return matchesSearch(habitRow: row, query: query)
        }
    }

    private static func sortAreas(_ areas: [LifeArea]) -> [LifeArea] {
        areas.sorted { lhs, rhs in
            let lhsIsGeneral = normalizedAreaName(lhs.name) == LifeManagementConstants.generalNormalizedName
            let rhsIsGeneral = normalizedAreaName(rhs.name) == LifeManagementConstants.generalNormalizedName
            if lhsIsGeneral != rhsIsGeneral {
                return lhsIsGeneral
            }
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func sortProjectRows(_ rows: [LifeManagementProjectRow]) -> [LifeManagementProjectRow] {
        rows.sorted { lhs, rhs in
            if lhs.isInbox != rhs.isInbox { return lhs.isInbox }
            if lhs.taskCount != rhs.taskCount { return lhs.taskCount > rhs.taskCount }
            return lhs.project.name.localizedCaseInsensitiveCompare(rhs.project.name) == .orderedAscending
        }
    }

    private static func sortHabitRows(_ rows: [LifeManagementHabitRow]) -> [LifeManagementHabitRow] {
        rows.sorted { lhs, rhs in
            if lhs.row.isPaused != rhs.row.isPaused { return rhs.row.isPaused == false }
            if lhs.row.currentStreak != rhs.row.currentStreak { return lhs.row.currentStreak > rhs.row.currentStreak }
            return lhs.row.title.localizedCaseInsensitiveCompare(rhs.row.title) == .orderedAscending
        }
    }

    private static func matchesSearch(areaRow: LifeManagementAreaRow, query: String) -> Bool {
        let searchable = [
            areaRow.lifeArea.name,
            areaRow.lifeArea.color ?? "",
            areaRow.lifeArea.icon ?? "",
            "\(areaRow.projectCount) projects",
            "\(areaRow.habitCount) habits"
        ]
        return matchesSearch(searchable: searchable, query: query)
    }

    private static func matchesSearch(projectRow: LifeManagementProjectRow, query: String) -> Bool {
        let searchable = [
            projectRow.project.name,
            projectRow.project.projectDescription ?? "",
            projectRow.lifeArea?.name ?? "",
            projectRow.project.color.displayName,
            projectRow.project.icon.displayName,
            "\(projectRow.taskCount) tasks"
        ]
        return matchesSearch(searchable: searchable, query: query)
    }

    private static func matchesSearch(habitRow: LifeManagementHabitRow, query: String) -> Bool {
        let searchable = [
            habitRow.row.title,
            habitRow.row.lifeAreaName,
            habitRow.row.projectName ?? "",
            habitRow.row.notes ?? "",
            habitRow.row.icon?.symbolName ?? "",
            habitRow.row.kind == .positive ? "build" : "quit",
            habitRow.row.isPaused ? "paused" : "active"
        ]
        return matchesSearch(searchable: searchable, query: query)
    }

    private static func matchesSearch(searchable: [String], query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedQuery.isEmpty == false else { return true }
        return searchable.contains { $0.lowercased().contains(normalizedQuery) }
    }

    private static func normalizedAreaName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? LifeManagementConstants.generalDisplayName : trimmed).lowercased()
    }
}

@MainActor
public final class LifeManagementViewModel: ObservableObject {
    @Published public var searchQuery = "" {
        didSet { rebuildDerivedState() }
    }
    @Published public var selectedNode: LifeManagementSelection? {
        didSet {
            guard selectedNode != oldValue else { return }
            expandAncestors(for: selectedNode)
        }
    }
    @Published public var expandedNodeIDs: Set<String> = []
    @Published public var expandedSectionKinds: Set<LifeManagementTreeSectionKind> = [.active]
    @Published public private(set) var treeSections: [LifeManagementTreeSection] = []
    @Published public private(set) var searchExpandedNodeIDs: Set<String> = []
    @Published public private(set) var areaRows: [LifeManagementAreaRow] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isMutating = false
    @Published public private(set) var errorMessage: String?
    @Published var snackbar: SnackbarData?
    @Published public var lifeAreaDraft: LifeManagementLifeAreaDraft?
    @Published public var projectDraft: LifeManagementProjectDraft?
    @Published public var moveProjectDraft: LifeManagementProjectMoveDraft?
    @Published public var deleteAreaDraft: LifeManagementDeleteAreaDraft?
    @Published public var deleteProjectDraft: LifeManagementDeleteProjectDraft?
    @Published public var deleteHabitDraft: LifeManagementDeleteHabitDraft?

    public let lifeAreaIconCatalog: [LifeAreaIconOption] = [
        LifeAreaIconOption(symbolName: "square.grid.2x2", keywords: ["general", "default", "grid"]),
        LifeAreaIconOption(symbolName: "heart.fill", keywords: ["health", "fitness", "wellness"]),
        LifeAreaIconOption(symbolName: "briefcase.fill", keywords: ["career", "work", "job"]),
        LifeAreaIconOption(symbolName: "book.fill", keywords: ["learning", "study", "education"]),
        LifeAreaIconOption(symbolName: "dumbbell.fill", keywords: ["gym", "exercise", "fitness"]),
        LifeAreaIconOption(symbolName: "leaf.fill", keywords: ["mindfulness", "nature", "calm"]),
        LifeAreaIconOption(symbolName: "brain.head.profile", keywords: ["focus", "thinking", "mind"]),
        LifeAreaIconOption(symbolName: "figure.run", keywords: ["running", "sports", "cardio"]),
        LifeAreaIconOption(symbolName: "fork.knife", keywords: ["nutrition", "food", "diet"]),
        LifeAreaIconOption(symbolName: "moon.stars.fill", keywords: ["sleep", "rest", "night"]),
        LifeAreaIconOption(symbolName: "house.fill", keywords: ["home", "family", "household"]),
        LifeAreaIconOption(symbolName: "person.2.fill", keywords: ["relationships", "friends", "social"]),
        LifeAreaIconOption(symbolName: "paintpalette.fill", keywords: ["creative", "art", "design"]),
        LifeAreaIconOption(symbolName: "chart.line.uptrend.xyaxis", keywords: ["growth", "progress", "improvement"]),
        LifeAreaIconOption(symbolName: "dollarsign.circle.fill", keywords: ["finance", "money", "budget"]),
        LifeAreaIconOption(symbolName: "airplane", keywords: ["travel", "trip", "vacation"]),
        LifeAreaIconOption(symbolName: "sparkles", keywords: ["personal", "self", "improvement"]),
        LifeAreaIconOption(symbolName: "flag.fill", keywords: ["goals", "milestones", "targets"]),
        LifeAreaIconOption(symbolName: "star.fill", keywords: ["priorities", "important", "highlight"]),
        LifeAreaIconOption(symbolName: "bolt.fill", keywords: ["execution", "action", "momentum"]),
        LifeAreaIconOption(symbolName: "tray.full.fill", keywords: ["inbox", "capture", "intake"]),
        LifeAreaIconOption(symbolName: "wrench.and.screwdriver.fill", keywords: ["maintenance", "ops", "repairs"])
    ]

    private let useCaseCoordinator: UseCaseCoordinator
    private let manageLifeAreasUseCase: ManageLifeAreasUseCase
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let destructiveFlowCoordinator: LifeManagementDestructiveFlowCoordinator
    private let projectRepository: ProjectRepositoryProtocol
    private let lifeAreaRepository: LifeAreaRepositoryProtocol

    private var sourceLifeAreas: [LifeArea] = []
    private var projectionContext: LifeManagementProjection.Context = .empty
    private var generalLifeAreaID: UUID?
    private var hasLoadedOnce = false
    private var hasPerformedBackfill = false
    private var pendingUndoAction: LifeManagementUndoAction?

    public init(
        useCaseCoordinator: UseCaseCoordinator,
        projectRepository: ProjectRepositoryProtocol? = nil
    ) {
        self.useCaseCoordinator = useCaseCoordinator
        self.manageLifeAreasUseCase = useCaseCoordinator.manageLifeAreas
        self.manageProjectsUseCase = useCaseCoordinator.manageProjects
        self.destructiveFlowCoordinator = useCaseCoordinator.lifeManagementDestructiveFlow
        self.projectRepository = projectRepository ?? useCaseCoordinator.projectRepository
        self.lifeAreaRepository = useCaseCoordinator.lifeAreaRepository
    }

    public func loadIfNeeded() {
        guard hasLoadedOnce == false else { return }
        hasLoadedOnce = true
        Task {
            await load(runBackfill: true, showsLoading: true)
        }
    }

    public func reload() {
        Task {
            await load(runBackfill: hasPerformedBackfill == false, showsLoading: true)
        }
    }

    public func clearError() {
        errorMessage = nil
    }

    public func filteredIconOptions(query: String) -> [LifeAreaIconOption] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.isEmpty == false else { return lifeAreaIconCatalog }
        return lifeAreaIconCatalog.filter { option in
            option.symbolName.lowercased().contains(normalized) ||
            option.keywords.contains(where: { $0.lowercased().contains(normalized) })
        }
    }

    public func selectNode(_ selection: LifeManagementSelection?) {
        selectedNode = selection
    }

    public func toggleNodeExpansion(_ selection: LifeManagementSelection) {
        let nodeID = selection.id
        if expandedNodeIDs.contains(nodeID) {
            expandedNodeIDs.remove(nodeID)
        } else {
            expandedNodeIDs.insert(nodeID)
        }
    }

    public func isNodeExpanded(_ selection: LifeManagementSelection) -> Bool {
        let nodeID = selection.id
        return expandedNodeIDs.contains(nodeID) || searchExpandedNodeIDs.contains(nodeID)
    }

    public func toggleSectionExpansion(_ kind: LifeManagementTreeSectionKind) {
        if expandedSectionKinds.contains(kind) {
            expandedSectionKinds.remove(kind)
        } else {
            expandedSectionKinds.insert(kind)
        }
    }

    public func isSectionExpanded(_ kind: LifeManagementTreeSectionKind) -> Bool {
        expandedSectionKinds.contains(kind)
    }

    public func beginCreateLifeArea(prefillName: String = "") {
        let draftID = UUID()
        lifeAreaDraft = LifeManagementLifeAreaDraft(
            id: draftID,
            existingID: nil,
            name: prefillName,
            colorHex: LifeAreaColorPalette.defaultHex(for: draftID),
            iconSymbolName: "square.grid.2x2"
        )
    }

    public func beginEditLifeArea(_ lifeAreaID: UUID) {
        guard let area = sourceLifeAreas.first(where: { $0.id == lifeAreaID }) else { return }
        lifeAreaDraft = LifeManagementLifeAreaDraft(
            existingID: area.id,
            name: area.name,
            colorHex: LifeAreaColorPalette.normalizeOrMap(hex: area.color, for: area.id),
            iconSymbolName: area.icon ?? "square.grid.2x2"
        )
    }

    public func dismissLifeAreaDraft() {
        lifeAreaDraft = nil
    }

    public func saveLifeAreaDraft() {
        guard let draft = lifeAreaDraft else { return }
        performMutation {
            let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.isEmpty == false else {
                throw NSError(
                    domain: "LifeManagementViewModel",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Enter a name for the life area."]
                )
            }

            if let existingID = draft.existingID {
                _ = try await self.awaitResult { completion in
                    self.manageLifeAreasUseCase.update(
                        id: existingID,
                        name: trimmedName,
                        color: draft.colorHex.nilIfBlank,
                        icon: draft.iconSymbolName.nilIfBlank,
                        completion: completion
                    )
                }
            } else {
                _ = try await self.awaitResult { completion in
                    self.manageLifeAreasUseCase.create(
                        name: trimmedName,
                        color: draft.colorHex.nilIfBlank,
                        icon: draft.iconSymbolName.nilIfBlank,
                        completion: completion
                    )
                }
            }
            self.lifeAreaDraft = nil
            self.snackbar = SnackbarData(message: draft.isNew ? "Area added" : "Area updated")
        }
    }

    public func beginCreateProject(prefillLifeAreaID: UUID? = nil) {
        projectDraft = LifeManagementProjectDraft(
            existingID: nil,
            name: "",
            description: "",
            lifeAreaID: prefillLifeAreaID ?? selectedAreaID ?? generalLifeAreaID ?? areaRows.first?.id,
            color: .blue,
            icon: .folder
        )
    }

    public func beginEditProject(_ projectID: UUID) {
        guard let row = projectRow(for: projectID) else { return }
        projectDraft = LifeManagementProjectDraft(
            existingID: row.project.id,
            name: row.project.name,
            description: row.project.projectDescription ?? "",
            lifeAreaID: row.project.lifeAreaID ?? generalLifeAreaID,
            color: row.project.color,
            icon: row.project.icon
        )
    }

    public func dismissProjectDraft() {
        projectDraft = nil
    }

    public func saveProjectDraft() {
        guard let draft = projectDraft else { return }
        performMutation {
            let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.isEmpty == false else {
                throw NSError(
                    domain: "LifeManagementViewModel",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Enter a name for the project."]
                )
            }

            let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
            if let existingID = draft.existingID {
                let originalProject = try await self.awaitResult { completion in
                    self.projectRepository.fetchProject(withId: existingID) { result in
                        completion(result)
                    }
                }
                guard let originalProject else {
                    throw NSError(
                        domain: "LifeManagementViewModel",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "The project could not be found."]
                    )
                }

                _ = try await self.awaitProjectResult { completion in
                    self.manageProjectsUseCase.updateProject(
                        projectId: existingID,
                        request: UpdateProjectRequest(
                            name: trimmedName,
                            description: description,
                            color: draft.color,
                            icon: draft.icon
                        ),
                        completion: completion
                    )
                }

                let currentLifeAreaID = originalProject.lifeAreaID ?? self.generalLifeAreaID
                if draft.lifeAreaID != currentLifeAreaID, let targetAreaID = draft.lifeAreaID {
                    do {
                        _ = try await self.awaitProjectResult { completion in
                            self.manageProjectsUseCase.moveProjectToLifeArea(
                                projectId: existingID,
                                lifeAreaID: targetAreaID,
                                completion: completion
                            )
                        }
                    } catch {
                        do {
                            _ = try await self.awaitProjectResult { completion in
                                self.manageProjectsUseCase.updateProject(
                                    projectId: existingID,
                                    request: UpdateProjectRequest(
                                        name: originalProject.name,
                                        description: originalProject.projectDescription,
                                        color: originalProject.color,
                                        icon: originalProject.icon
                                    ),
                                    completion: completion
                                )
                            }

                            let currentProject = try await self.awaitResult { completion in
                                self.projectRepository.fetchProject(withId: existingID) { result in
                                    completion(result)
                                }
                            }
                            if let originalLifeAreaID = originalProject.lifeAreaID,
                               currentProject?.lifeAreaID != originalLifeAreaID {
                                _ = try await self.awaitProjectResult { completion in
                                    self.manageProjectsUseCase.moveProjectToLifeArea(
                                        projectId: existingID,
                                        lifeAreaID: originalLifeAreaID,
                                        completion: completion
                                    )
                                }
                            }
                        } catch let rollbackError {
                            throw LifeManagementMutationError.projectMoveRollbackFailed(
                                moveError: error,
                                rollbackError: rollbackError
                            )
                        }

                        throw LifeManagementMutationError.projectMoveRolledBack(moveError: error)
                    }
                }
            } else {
                _ = try await self.awaitProjectResult { completion in
                    self.manageProjectsUseCase.createProject(
                        request: CreateProjectRequest(
                            name: trimmedName,
                            description: description,
                            lifeAreaID: draft.lifeAreaID,
                            color: draft.color,
                            icon: draft.icon
                        ),
                        completion: completion
                    )
                }
            }
            self.projectDraft = nil
            self.snackbar = SnackbarData(message: draft.isNew ? "Project added" : "Project updated")
        }
    }

    public func beginMoveProject(_ projectID: UUID) {
        guard let row = projectRow(for: projectID), row.isMoveLocked == false else { return }
        let fallbackTarget = availableAreaTargets(excluding: row.lifeArea?.id).first?.id
        moveProjectDraft = LifeManagementProjectMoveDraft(
            id: UUID(),
            projectID: projectID,
            projectName: row.project.name,
            targetLifeAreaID: fallbackTarget
        )
    }

    public func dismissMoveProjectDraft() {
        moveProjectDraft = nil
    }

    public func moveProjectFromDraft() {
        guard let draft = moveProjectDraft, let targetLifeAreaID = draft.targetLifeAreaID else { return }
        performMutation {
            _ = try await self.awaitProjectResult { completion in
                self.manageProjectsUseCase.moveProjectToLifeArea(
                    projectId: draft.projectID,
                    lifeAreaID: targetLifeAreaID,
                    completion: completion
                )
            }
            self.moveProjectDraft = nil
        }
    }

    public func beginDeleteArea(_ lifeAreaID: UUID) {
        guard let area = sourceLifeAreas.first(where: { $0.id == lifeAreaID }), isGeneralArea(area) == false else { return }
        let defaultTarget = availableAreaTargets(excluding: lifeAreaID).first?.id
        deleteAreaDraft = LifeManagementDeleteAreaDraft(
            id: UUID(),
            areaID: area.id,
            areaName: area.name,
            projectCount: projectionContext.allProjectCountByAreaID[area.id] ?? 0,
            habitCount: projectionContext.allHabitCountByAreaID[area.id] ?? 0,
            destinationLifeAreaID: defaultTarget
        )
    }

    public func dismissDeleteAreaDraft() {
        deleteAreaDraft = nil
    }

    public func confirmDeleteArea() {
        guard let draft = deleteAreaDraft else { return }
        performMutation {
            guard let destinationLifeAreaID = draft.destinationLifeAreaID, destinationLifeAreaID != draft.areaID else {
                throw NSError(
                    domain: "LifeManagementViewModel",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Choose a destination area before deleting this area."]
                )
            }

            _ = try await self.awaitVoid { completion in
                self.destructiveFlowCoordinator.deleteLifeArea(
                    request: DeleteLifeAreaRequest(
                        areaID: draft.areaID,
                        destinationLifeAreaID: destinationLifeAreaID
                    ),
                    completion: completion
                )
            }

            self.deleteAreaDraft = nil
        }
    }

    public func beginDeleteProject(_ projectID: UUID) {
        guard let row = projectRow(for: projectID), row.project.isDefault == false else { return }
        let fallbackProjectID = availableProjectDeleteTargets(excluding: projectID).first?.id
        deleteProjectDraft = LifeManagementDeleteProjectDraft(
            id: UUID(),
            projectID: projectID,
            projectName: row.project.name,
            taskCount: row.taskCount,
            linkedHabitCount: projectionContext.allLinkedHabitCountByProjectID[projectID] ?? 0,
            destinationProjectID: fallbackProjectID
        )
    }

    public func dismissDeleteProjectDraft() {
        deleteProjectDraft = nil
    }

    public func confirmDeleteProject() {
        guard let draft = deleteProjectDraft else { return }
        performMutation {
            guard let destinationProjectID = draft.destinationProjectID, destinationProjectID != draft.projectID else {
                throw NSError(
                    domain: "LifeManagementViewModel",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Choose a destination project before deleting this project."]
                )
            }

            _ = try await self.awaitVoid { completion in
                self.destructiveFlowCoordinator.deleteProject(
                    request: DeleteProjectRequest(
                        projectID: draft.projectID,
                        destinationProjectID: destinationProjectID
                    ),
                    completion: completion
                )
            }

            self.deleteProjectDraft = nil
        }
    }

    public func beginDeleteHabit(_ habitID: UUID) {
        guard let row = habitRow(for: habitID) else { return }
        deleteHabitDraft = LifeManagementDeleteHabitDraft(
            id: UUID(),
            habitID: habitID,
            habitTitle: row.row.title
        )
    }

    public func dismissDeleteHabitDraft() {
        deleteHabitDraft = nil
    }

    public func confirmDeleteHabit() {
        guard let draft = deleteHabitDraft else { return }
        performMutation {
            _ = try await self.awaitVoid { completion in
                self.useCaseCoordinator.deleteHabit.execute(id: draft.habitID, completion: completion)
            }
            self.deleteHabitDraft = nil
        }
    }

    public func archiveLifeArea(_ lifeAreaID: UUID) {
        guard let row = areaRow(for: lifeAreaID), row.isGeneral == false else { return }
        performMutation {
            _ = try await self.awaitResult { completion in
                self.manageLifeAreasUseCase.archive(id: lifeAreaID, completion: completion)
            }
            self.presentArchiveUndo(message: "\(row.lifeArea.name) archived", action: .lifeArea(lifeAreaID))
        }
    }

    public func restoreLifeArea(_ lifeAreaID: UUID) {
        performMutation {
            _ = try await self.awaitResult { completion in
                self.manageLifeAreasUseCase.unarchive(id: lifeAreaID, completion: completion)
            }
        }
    }

    public func archiveProject(_ projectID: UUID) {
        guard let row = projectRow(for: projectID), row.isInbox == false else { return }
        performMutation {
            _ = try await self.awaitProjectResult { completion in
                self.manageProjectsUseCase.archiveProject(projectId: projectID, completion: completion)
            }
            self.presentArchiveUndo(message: "\(row.project.name) archived", action: .project(projectID))
        }
    }

    public func restoreProject(_ projectID: UUID) {
        performMutation {
            _ = try await self.awaitProjectResult { completion in
                self.manageProjectsUseCase.unarchiveProject(projectId: projectID, completion: completion)
            }
        }
    }

    public func archiveHabit(_ habitID: UUID) {
        guard let row = habitRow(for: habitID) else { return }
        performMutation {
            _ = try await self.awaitResult { completion in
                self.useCaseCoordinator.setHabitArchived.execute(id: habitID, isArchived: true, completion: completion)
            }
            self.presentArchiveUndo(message: "\(row.row.title) archived", action: .habit(habitID))
        }
    }

    public func restoreHabit(_ habitID: UUID) {
        performMutation {
            _ = try await self.awaitResult { completion in
                self.useCaseCoordinator.setHabitArchived.execute(id: habitID, isArchived: false, completion: completion)
            }
        }
    }

    public func toggleHabitPause(_ habitID: UUID) {
        guard let row = habitRow(for: habitID) else { return }
        performMutation {
            _ = try await self.awaitResult { completion in
                self.useCaseCoordinator.pauseHabit.execute(
                    id: habitID,
                    isPaused: row.row.isPaused == false,
                    completion: completion
                )
            }
        }
    }

    public func undoArchive() {
        guard let pendingUndoAction else { return }
        self.pendingUndoAction = nil
        snackbar = nil
        switch pendingUndoAction {
        case .lifeArea(let id):
            restoreLifeArea(id)
        case .project(let id):
            restoreProject(id)
        case .habit(let id):
            restoreHabit(id)
        }
    }

    public func areaRow(for lifeAreaID: UUID) -> LifeManagementAreaRow? {
        projectionContext.areaRowsByID[lifeAreaID]
    }

    public func projectRow(for projectID: UUID) -> LifeManagementProjectRow? {
        projectionContext.projectRowsByID[projectID]
    }

    public func habitRow(for habitID: UUID) -> LifeManagementHabitRow? {
        projectionContext.habitRowsByID[habitID]
    }

    func areaDetailSnapshot(for lifeAreaID: UUID) -> LifeManagementAreaDetailSnapshot? {
        projectionContext.areaDetailByID[lifeAreaID]
    }

    func projectDetailSnapshot(for projectID: UUID) -> LifeManagementProjectDetailSnapshot? {
        projectionContext.projectDetailByID[projectID]
    }

    public func availableAreaTargets(excluding lifeAreaID: UUID?) -> [LifeManagementAreaRow] {
        areaRows.filter { row in
            row.id != lifeAreaID && row.lifeArea.isArchived == false
        }
    }

    public func availableProjectDeleteTargets(excluding projectID: UUID?) -> [LifeManagementProjectRow] {
        projectionContext.projectRowsByID.values
            .filter { row in
                row.id != projectID && row.project.isArchived == false
            }
            .sorted { lhs, rhs in
                if lhs.isInbox != rhs.isInbox { return lhs.isInbox }
                return lhs.project.name.localizedCaseInsensitiveCompare(rhs.project.name) == .orderedAscending
            }
    }

    private var selectedAreaID: UUID? {
        switch selectedNode {
        case .area(let id):
            return id
        case .project(let id):
            return projectRow(for: id)?.lifeArea?.id
        case .habit(let id):
            return habitRow(for: id)?.lifeArea?.id
        case nil:
            return nil
        }
    }

    private func expandAncestors(for selection: LifeManagementSelection?) {
        guard let selection, let ancestors = projectionContext.ancestorNodeIDsBySelection[selection] else { return }
        expandedNodeIDs.formUnion(ancestors)
    }

    private func rebuildDerivedState() {
        let snapshot = projectionContext.snapshot(searchQuery: searchQuery)
        treeSections = snapshot.treeSections
        searchExpandedNodeIDs = snapshot.searchExpandedAncestorNodeIDs
        areaRows = treeSections
            .first(where: { $0.kind == .active })?
            .nodes
            .compactMap { node in
                if case .area(let row) = node.payload {
                    return row
                }
                return nil
            } ?? []

        if let selectedNode, rowExists(for: selectedNode) == false {
            self.selectedNode = nil
        }
    }

    private func rowExists(for selection: LifeManagementSelection) -> Bool {
        switch selection {
        case .area(let id):
            return projectionContext.areaRowsByID[id] != nil
        case .project(let id):
            return projectionContext.projectRowsByID[id] != nil
        case .habit(let id):
            return projectionContext.habitRowsByID[id] != nil
        }
    }

    private func presentArchiveUndo(message: String, action: LifeManagementUndoAction) {
        pendingUndoAction = action
        snackbar = SnackbarData(
            message: message,
            actions: [
                SnackbarAction(title: "Undo") { [weak self] in
                    self?.undoArchive()
                }
            ]
        )
    }

    @discardableResult
    private func performMutation(_ operation: @escaping () async throws -> Void) -> Bool {
        guard isMutating == false else { return false }
        isMutating = true
        errorMessage = nil

        Task { [weak self] in
            guard let self else { return }
            defer { self.isMutating = false }

            do {
                try await operation()
                await self.load(runBackfill: false, showsLoading: false)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }

        return true
    }

    private func load(runBackfill: Bool, showsLoading: Bool) async {
        if showsLoading {
            isLoading = true
        }
        errorMessage = nil

        do {
            let listedAreas = try await awaitResult { completion in
                self.manageLifeAreasUseCase.list(completion: completion)
            }
            let generalArea = try await resolveGeneralLifeArea(from: listedAreas.filter { $0.isArchived == false })

            if runBackfill || hasPerformedBackfill == false {
                _ = try? await awaitProjectResult { completion in
                    self.manageProjectsUseCase.backfillUnassignedProjectsToGeneral(
                        generalLifeAreaID: generalArea.id,
                        completion: completion
                    )
                }
                hasPerformedBackfill = true
            }

            let projectStats = try await awaitProjectResult { completion in
                self.manageProjectsUseCase.getAllProjects(completion: completion)
            }
            let habitRows = try await awaitResult { completion in
                self.useCaseCoordinator.getHabitLibrary.execute(includeArchived: true, completion: completion)
            }

            let mergedAreas = Self.mergeLifeAreas(listedAreas, generalArea: generalArea)

            sourceLifeAreas = mergedAreas
            generalLifeAreaID = generalArea.id
            projectionContext = LifeManagementProjection.prepare(
                lifeAreas: mergedAreas,
                projectStats: projectStats,
                habitRows: habitRows,
                generalLifeAreaID: generalArea.id
            )
            rebuildDerivedState()
            expandAncestors(for: selectedNode)
        } catch {
            errorMessage = error.localizedDescription
        }

        if showsLoading {
            isLoading = false
        }
    }

    private func resolveGeneralLifeArea(from activeAreas: [LifeArea]) async throws -> LifeArea {
        if let general = activeAreas.first(where: { normalizedLifeAreaName($0.name) == LifeManagementConstants.generalNormalizedName }) {
            return general
        }

        do {
            return try await awaitResult { completion in
                self.manageLifeAreasUseCase.create(
                    name: LifeManagementConstants.generalDisplayName,
                    color: nil,
                    icon: "square.grid.2x2",
                    completion: completion
                )
            }
        } catch {
            let refreshedAreas = try await awaitResult { completion in
                self.manageLifeAreasUseCase.list(completion: completion)
            }
            if let general = refreshedAreas.first(where: { normalizedLifeAreaName($0.name) == LifeManagementConstants.generalNormalizedName }) {
                return general
            }
            throw error
        }
    }

    static func mergeLifeAreas(_ lifeAreas: [LifeArea], generalArea: LifeArea) -> [LifeArea] {
        dedupeLifeAreasByNormalizedName(
            lifeAreas.contains(where: { $0.id == generalArea.id }) ? lifeAreas : lifeAreas + [generalArea],
            preferredGeneralID: generalArea.id
        )
    }

    private static func dedupeLifeAreasByNormalizedName(
        _ lifeAreas: [LifeArea],
        preferredGeneralID: UUID?
    ) -> [LifeArea] {
        var chosenByName: [String: LifeArea] = [:]
        for lifeArea in lifeAreas {
            let normalizedName = normalizedLifeAreaName(lifeArea.name)
            if let existing = chosenByName[normalizedName] {
                chosenByName[normalizedName] = preferredLifeArea(
                    between: existing,
                    and: lifeArea,
                    preferredGeneralID: preferredGeneralID
                )
            } else {
                chosenByName[normalizedName] = lifeArea
            }
        }

        var emitted = Set<String>()
        var deduped: [LifeArea] = []
        for lifeArea in lifeAreas {
            let normalizedName = normalizedLifeAreaName(lifeArea.name)
            guard chosenByName[normalizedName]?.id == lifeArea.id else { continue }
            guard emitted.insert(normalizedName).inserted else { continue }
            deduped.append(lifeArea)
        }
        return deduped
    }

    private static func preferredLifeArea(
        between existing: LifeArea,
        and candidate: LifeArea,
        preferredGeneralID: UUID?
    ) -> LifeArea {
        if let preferredGeneralID {
            let existingIsPreferredGeneral = existing.id == preferredGeneralID
            let candidateIsPreferredGeneral = candidate.id == preferredGeneralID
            if existingIsPreferredGeneral != candidateIsPreferredGeneral {
                return existingIsPreferredGeneral ? existing : candidate
            }
        }

        if existing.isArchived != candidate.isArchived {
            return existing.isArchived ? candidate : existing
        }

        if existing.createdAt != candidate.createdAt {
            return existing.createdAt <= candidate.createdAt ? existing : candidate
        }

        return existing.updatedAt <= candidate.updatedAt ? existing : candidate
    }

    private static func normalizedLifeAreaName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? LifeManagementConstants.generalDisplayName : trimmed).lowercased()
    }

    private func normalizedLifeAreaName(_ name: String) -> String {
        Self.normalizedLifeAreaName(name)
    }

    private func isGeneralArea(_ area: LifeArea) -> Bool {
        normalizedLifeAreaName(area.name) == LifeManagementConstants.generalNormalizedName
    }

    private func awaitResult<T>(
        _ body: (@escaping (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            body { result in
                continuation.resume(with: result)
            }
        }
    }

    private func awaitProjectResult<T>(
        _ body: (@escaping (Result<T, ProjectError>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            body { result in
                continuation.resume(with: result.mapError { $0 as Error })
            }
        }
    }

    private func awaitVoid(
        _ body: (@escaping (Result<Void, Error>) -> Void) -> Void
    ) async throws {
        _ = try await awaitResult(body)
    }
}

private enum LifeManagementMutationError: LocalizedError {
    case projectMoveRolledBack(moveError: Error)
    case projectMoveRollbackFailed(moveError: Error, rollbackError: Error)

    var errorDescription: String? {
        switch self {
        case .projectMoveRolledBack:
            return "Project details were restored because moving the project to the selected area failed."
        case .projectMoveRollbackFailed:
            return "Project updates could not be safely rolled back after the move failed."
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
