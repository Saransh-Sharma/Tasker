import Foundation
import SwiftUI

public struct LifeAreaSuggestion: Identifiable, Equatable {
    public let name: String
    public let icon: String
    public let colorHex: String

    public var id: String { name.lowercased() }

    /// Initializes a new instance.
    public init(name: String, icon: String, colorHex: String) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
}

public struct LifeManagementProjectRow: Identifiable, Equatable {
    public let project: Project
    public let taskCount: Int
    public let sourceLifeAreaID: UUID

    public var id: UUID { project.id }
    public var isInbox: Bool { project.isInbox || project.id == ProjectConstants.inboxProjectID }
    public var isMoveLocked: Bool { isInbox || project.isDefault }
}

public struct LifeManagementLifeAreaSection: Identifiable, Equatable {
    public let lifeArea: LifeArea
    public var projects: [LifeManagementProjectRow]

    public var id: UUID { lifeArea.id }
    public var projectCount: Int { projects.count }
    public var taskCount: Int { projects.reduce(0) { $0 + $1.taskCount } }
}

public final class LifeManagementViewModel: ObservableObject {
    @Published public private(set) var sections: [LifeManagementLifeAreaSection] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isMutating = false
    @Published public private(set) var isCreatingLifeArea = false
    @Published public private(set) var errorMessage: String?
    @Published public var draftLifeAreaName: String = ""
    @Published public private(set) var draggingProjectID: UUID?
    @Published public private(set) var activeDropLifeAreaID: UUID?

    public let suggestedLifeAreasCatalog: [LifeAreaSuggestion] = [
        LifeAreaSuggestion(name: "Health", icon: "heart.fill", colorHex: "#22C55E"),
        LifeAreaSuggestion(name: "Career", icon: "briefcase.fill", colorHex: "#3B82F6")
    ]

    public var visibleSuggestions: [LifeAreaSuggestion] {
        let existing = Set(sections.map { normalizedLifeAreaName($0.lifeArea.name) })
        return suggestedLifeAreasCatalog.filter { existing.contains(normalizedLifeAreaName($0.name)) == false }
    }

    private let manageLifeAreasUseCase: ManageLifeAreasUseCase
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let projectRepository: ProjectRepositoryProtocol?

    private var hasLoadedOnce = false
    private var hasPerformedBackfill = false

    /// Initializes a new instance.
    public init(
        manageLifeAreasUseCase: ManageLifeAreasUseCase,
        manageProjectsUseCase: ManageProjectsUseCase,
        projectRepository: ProjectRepositoryProtocol? = nil
    ) {
        self.manageLifeAreasUseCase = manageLifeAreasUseCase
        self.manageProjectsUseCase = manageProjectsUseCase
        self.projectRepository = projectRepository
    }

    /// Executes loadIfNeeded.
    public func loadIfNeeded() {
        guard hasLoadedOnce == false else { return }
        hasLoadedOnce = true
        load(runBackfill: true)
    }

    /// Executes reload.
    public func reload() {
        load(runBackfill: hasPerformedBackfill == false)
    }

    /// Executes createLifeAreaFromDraft.
    public func createLifeAreaFromDraft() {
        let trimmed = draftLifeAreaName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        createLifeArea(name: trimmed, colorHex: nil, icon: nil) { [weak self] in
            self?.draftLifeAreaName = ""
        }
    }

    /// Executes createSuggestedLifeArea.
    public func createSuggestedLifeArea(_ suggestion: LifeAreaSuggestion) {
        createLifeArea(name: suggestion.name, colorHex: suggestion.colorHex, icon: suggestion.icon, completion: nil)
    }

    /// Executes beginDrag.
    public func beginDrag(projectID: UUID) {
        draggingProjectID = projectID
    }

    /// Executes clearDropTarget.
    public func clearDropTarget(_ lifeAreaID: UUID? = nil) {
        guard let lifeAreaID else {
            activeDropLifeAreaID = nil
            return
        }
        if activeDropLifeAreaID == lifeAreaID {
            activeDropLifeAreaID = nil
        }
    }

    /// Executes dropEntered.
    public func dropEntered(targetLifeAreaID: UUID) {
        guard canDropProject(on: targetLifeAreaID) else { return }
        activeDropLifeAreaID = targetLifeAreaID
    }

    /// Executes canDropProject.
    public func canDropProject(on targetLifeAreaID: UUID) -> Bool {
        guard let draggingProjectID,
              let row = projectRow(for: draggingProjectID) else {
            return false
        }
        guard row.isMoveLocked == false else { return false }
        return row.sourceLifeAreaID != targetLifeAreaID
    }

    /// Executes performDrop.
    @discardableResult
    public func performDrop(providers: [NSItemProvider], targetLifeAreaID: UUID) -> Bool {
        if let draggingProjectID {
            moveProject(projectID: draggingProjectID, targetLifeAreaID: targetLifeAreaID)
            return true
        }

        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            resetDragState()
            return false
        }

        provider.loadObject(ofClass: NSString.self) { [weak self] object, _ in
            guard let self else { return }
            guard let payload = object as? String,
                  let projectID = UUID(uuidString: payload) else {
                Task { @MainActor in
                    self.resetDragState()
                }
                return
            }
            Task { @MainActor in
                self.beginDrag(projectID: projectID)
                self.moveProject(projectID: projectID, targetLifeAreaID: targetLifeAreaID)
            }
        }
        return true
    }

    /// Executes moveProject.
    public func moveProject(projectID: UUID, targetLifeAreaID: UUID) {
        guard isMutating == false else { return }
        guard let row = projectRow(for: projectID) else {
            resetDragState()
            return
        }
        guard row.isMoveLocked == false else {
            resetDragState()
            errorMessage = "Inbox is pinned to General and cannot be moved."
            return
        }
        guard row.sourceLifeAreaID != targetLifeAreaID else {
            resetDragState()
            return
        }

        isMutating = true
        errorMessage = nil

        manageProjectsUseCase.moveProjectToLifeArea(projectId: projectID, lifeAreaID: targetLifeAreaID) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isMutating = false
                self.resetDragState()

                switch result {
                case .success:
                    self.applyLocalProjectMove(projectID: projectID, targetLifeAreaID: targetLifeAreaID)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.load(runBackfill: false)
                }
            }
        }
    }

    /// Executes clearError.
    public func clearError() {
        errorMessage = nil
    }

    /// Executes load.
    private func load(runBackfill: Bool) {
        isLoading = true
        errorMessage = nil

        manageLifeAreasUseCase.list { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                Task { @MainActor [weak self] in
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
            case .success(let areas):
                let activeAreas = areas.filter { !$0.isArchived }
                self.resolveGeneralLifeArea(from: activeAreas) { [weak self] resolution in
                    guard let self else { return }
                    switch resolution {
                    case .failure(let error):
                        Task { @MainActor [weak self] in
                            self?.isLoading = false
                            self?.errorMessage = error.localizedDescription
                        }
                    case .success(let payload):
                        let shouldRunBackfill = runBackfill || !self.hasPerformedBackfill
                        if shouldRunBackfill {
                            self.manageProjectsUseCase.backfillUnassignedProjectsToGeneral(
                                generalLifeAreaID: payload.generalArea.id
                            ) { [weak self] backfillResult in
                                guard let self else { return }
                                switch backfillResult {
                                case .success:
                                    self.hasPerformedBackfill = true
                                    self.loadSections(lifeAreas: payload.lifeAreas, generalLifeAreaID: payload.generalArea.id)
                                case .failure(let error):
                                    Task { @MainActor [weak self] in
                                        self?.errorMessage = error.localizedDescription
                                    }
                                    self.loadSections(lifeAreas: payload.lifeAreas, generalLifeAreaID: payload.generalArea.id)
                                }
                            }
                        } else {
                            self.loadSections(lifeAreas: payload.lifeAreas, generalLifeAreaID: payload.generalArea.id)
                        }
                    }
                }
            }
        }
    }

    /// Executes loadSections.
    private func loadSections(lifeAreas: [LifeArea], generalLifeAreaID: UUID) {
        manageProjectsUseCase.getAllProjects { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                case .success(let projectStats):
                    self.sections = self.buildSections(
                        lifeAreas: lifeAreas,
                        projects: projectStats,
                        generalLifeAreaID: generalLifeAreaID
                    )

                    if let draggingProjectID = self.draggingProjectID,
                       self.projectRow(for: draggingProjectID) == nil {
                        self.resetDragState()
                    }
                }
            }
        }
    }

    /// Executes resolveGeneralLifeArea.
    private func resolveGeneralLifeArea(
        from lifeAreas: [LifeArea],
        completion: @escaping (Result<(generalArea: LifeArea, lifeAreas: [LifeArea]), Error>) -> Void
    ) {
        let deduped = dedupeLifeAreasByNormalizedName(lifeAreas)
        if let general = deduped.first(where: { normalizedLifeAreaName($0.name) == Self.generalNormalizedName }) {
            completion(.success((generalArea: general, lifeAreas: deduped)))
            return
        }

        manageLifeAreasUseCase.create(
            name: Self.generalDisplayName,
            color: "#4A6FA5",
            icon: "square.grid.2x2"
        ) { [weak self] createResult in
            guard let self else { return }
            switch createResult {
            case .success(let created):
                var merged = deduped
                merged.append(created)
                completion(.success((generalArea: created, lifeAreas: self.dedupeLifeAreasByNormalizedName(merged))))
            case .failure:
                self.manageLifeAreasUseCase.list { retryResult in
                    switch retryResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let refreshed):
                        let active = refreshed.filter { !$0.isArchived }
                        let dedupedActive = self.dedupeLifeAreasByNormalizedName(active)
                        if let general = dedupedActive.first(where: { self.normalizedLifeAreaName($0.name) == Self.generalNormalizedName }) {
                            completion(.success((generalArea: general, lifeAreas: dedupedActive)))
                        } else {
                            completion(.failure(NSError(
                                domain: "LifeManagementViewModel",
                                code: 404,
                                userInfo: [NSLocalizedDescriptionKey: "Unable to resolve General life area."]
                            )))
                        }
                    }
                }
            }
        }
    }

    /// Executes createLifeArea.
    private func createLifeArea(
        name: String,
        colorHex: String?,
        icon: String?,
        completion: (() -> Void)?
    ) {
        guard isCreatingLifeArea == false else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        isCreatingLifeArea = true
        errorMessage = nil

        manageLifeAreasUseCase.create(name: trimmed, color: colorHex, icon: icon) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isCreatingLifeArea = false
                completion?()
                switch result {
                case .success:
                    self.reload()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes buildSections.
    private func buildSections(
        lifeAreas: [LifeArea],
        projects: [ProjectWithStats],
        generalLifeAreaID: UUID
    ) -> [LifeManagementLifeAreaSection] {
        let sortedAreas = lifeAreas.sorted { lhs, rhs in
            let lhsIsGeneral = normalizedLifeAreaName(lhs.name) == Self.generalNormalizedName
            let rhsIsGeneral = normalizedLifeAreaName(rhs.name) == Self.generalNormalizedName
            if lhsIsGeneral != rhsIsGeneral {
                return lhsIsGeneral
            }
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        var rowsByLifeAreaID: [UUID: [LifeManagementProjectRow]] = [:]

        for entry in projects {
            let project = entry.project
            let sourceLifeAreaID = project.lifeAreaID ?? generalLifeAreaID
            let row = LifeManagementProjectRow(
                project: project,
                taskCount: entry.taskCount,
                sourceLifeAreaID: sourceLifeAreaID
            )
            rowsByLifeAreaID[sourceLifeAreaID, default: []].append(row)
        }

        return sortedAreas.map { area in
            let rows = (rowsByLifeAreaID[area.id] ?? []).sorted { lhs, rhs in
                if lhs.isInbox != rhs.isInbox {
                    return lhs.isInbox
                }
                return lhs.project.name.localizedCaseInsensitiveCompare(rhs.project.name) == .orderedAscending
            }
            return LifeManagementLifeAreaSection(lifeArea: area, projects: rows)
        }
    }

    /// Executes applyLocalProjectMove.
    private func applyLocalProjectMove(projectID: UUID, targetLifeAreaID: UUID) {
        guard let sourceSectionIndex = sections.firstIndex(where: { section in
            section.projects.contains(where: { $0.project.id == projectID })
        }),
        let sourceRowIndex = sections[sourceSectionIndex].projects.firstIndex(where: { $0.project.id == projectID }) else {
            load(runBackfill: false)
            return
        }

        guard let targetSectionIndex = sections.firstIndex(where: { $0.lifeArea.id == targetLifeAreaID }) else {
            load(runBackfill: false)
            return
        }

        var sourceSection = sections[sourceSectionIndex]
        var targetSection = sections[targetSectionIndex]
        var moved = sourceSection.projects.remove(at: sourceRowIndex)

        var movedProject = moved.project
        movedProject.lifeAreaID = targetLifeAreaID
        moved = LifeManagementProjectRow(
            project: movedProject,
            taskCount: moved.taskCount,
            sourceLifeAreaID: targetLifeAreaID
        )

        targetSection.projects.append(moved)
        targetSection.projects.sort { lhs, rhs in
            if lhs.isInbox != rhs.isInbox {
                return lhs.isInbox
            }
            return lhs.project.name.localizedCaseInsensitiveCompare(rhs.project.name) == .orderedAscending
        }

        sections[sourceSectionIndex] = sourceSection
        sections[targetSectionIndex] = targetSection
    }

    /// Executes projectRow.
    private func projectRow(for projectID: UUID) -> LifeManagementProjectRow? {
        for section in sections {
            if let row = section.projects.first(where: { $0.project.id == projectID }) {
                return row
            }
        }
        return nil
    }

    /// Executes resetDragState.
    private func resetDragState() {
        draggingProjectID = nil
        activeDropLifeAreaID = nil
    }

    /// Executes dedupeLifeAreasByNormalizedName.
    private func dedupeLifeAreasByNormalizedName(_ lifeAreas: [LifeArea]) -> [LifeArea] {
        var chosenByName: [String: LifeArea] = [:]
        for lifeArea in lifeAreas {
            let normalizedName = normalizedLifeAreaName(lifeArea.name)
            if let existing = chosenByName[normalizedName] {
                let keepExisting = existing.createdAt <= lifeArea.createdAt
                chosenByName[normalizedName] = keepExisting ? existing : lifeArea
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

    /// Executes normalizedLifeAreaName.
    private func normalizedLifeAreaName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? Self.generalDisplayName : trimmed).lowercased()
    }

    private static let generalDisplayName = "General"
    private static let generalNormalizedName = "general"
}
