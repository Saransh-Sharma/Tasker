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

public struct LifeAreaIconOption: Identifiable, Equatable, Hashable {
    public let symbolName: String
    public let keywords: [String]

    public var id: String { symbolName }

    /// Initializes a new instance.
    public init(symbolName: String, keywords: [String]) {
        self.symbolName = symbolName
        self.keywords = keywords
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

public struct LifeManagementArchivedProjectGroup: Identifiable, Equatable {
    public let lifeArea: LifeArea
    public var projects: [LifeManagementProjectRow]

    public var id: UUID { lifeArea.id }
}

public struct LifeAreaEditDraft: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var colorHex: String
}

public struct ProjectEditDraft: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var description: String
}

public struct LifeAreaArchivePreview: Identifiable, Equatable {
    public let id: UUID
    public let lifeAreaName: String
    public let projectCount: Int
    public let taskCount: Int
}

public struct ProjectArchivePreview: Identifiable, Equatable {
    public let id: UUID
    public let projectName: String
    public let taskCount: Int
}

public struct LifeAreaIconPickerContext: Identifiable, Equatable {
    public let id: UUID
    public let lifeAreaName: String
    public let currentIcon: String?
}

public final class LifeManagementViewModel: ObservableObject {
    @Published public private(set) var sections: [LifeManagementLifeAreaSection] = []
    @Published public private(set) var archivedLifeAreaSections: [LifeManagementLifeAreaSection] = []
    @Published public private(set) var archivedProjectGroups: [LifeManagementArchivedProjectGroup] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isMutating = false
    @Published public private(set) var isCreatingLifeArea = false
    @Published public private(set) var isCreatingProject = false
    @Published public private(set) var errorMessage: String?
    @Published public var draftLifeAreaName = ""
    @Published public var draftProjectName = ""
    @Published public var draftProjectDescription = ""
    @Published public var draftProjectLifeAreaID: UUID?
    @Published public private(set) var draggingProjectID: UUID?
    @Published public private(set) var activeDropLifeAreaID: UUID?
    @Published public var isArchivedLifeAreasExpanded = false
    @Published public var isArchivedProjectsExpanded = false

    @Published public private(set) var lifeAreaEditDraft: LifeAreaEditDraft?
    @Published public private(set) var projectEditDraft: ProjectEditDraft?
    @Published public private(set) var lifeAreaArchivePreview: LifeAreaArchivePreview?
    @Published public private(set) var projectArchivePreview: ProjectArchivePreview?
    @Published public private(set) var iconPickerContext: LifeAreaIconPickerContext?

    public let suggestedLifeAreasCatalog: [LifeAreaSuggestion] = StarterWorkspaceCatalog.allLifeAreas.map {
        LifeAreaSuggestion(name: $0.name, icon: $0.icon, colorHex: $0.colorHex)
    }

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
        LifeAreaIconOption(symbolName: "figure.2.and.child.holdinghands", keywords: ["family", "kids", "parents"]),
        LifeAreaIconOption(symbolName: "paintpalette.fill", keywords: ["creative", "art", "design"]),
        LifeAreaIconOption(symbolName: "music.note", keywords: ["music", "hobby", "play"]),
        LifeAreaIconOption(symbolName: "camera.fill", keywords: ["photo", "camera", "media"]),
        LifeAreaIconOption(symbolName: "chart.line.uptrend.xyaxis", keywords: ["growth", "progress", "improvement"]),
        LifeAreaIconOption(symbolName: "dollarsign.circle.fill", keywords: ["finance", "money", "budget"]),
        LifeAreaIconOption(symbolName: "creditcard.fill", keywords: ["expenses", "payments", "billing"]),
        LifeAreaIconOption(symbolName: "airplane", keywords: ["travel", "trip", "vacation"]),
        LifeAreaIconOption(symbolName: "globe.americas.fill", keywords: ["global", "travel", "world"]),
        LifeAreaIconOption(symbolName: "sparkles", keywords: ["personal", "self", "improvement"]),
        LifeAreaIconOption(symbolName: "flag.fill", keywords: ["goals", "milestones", "targets"]),
        LifeAreaIconOption(symbolName: "star.fill", keywords: ["priorities", "important", "highlight"]),
        LifeAreaIconOption(symbolName: "sun.max.fill", keywords: ["morning", "energy", "routine"]),
        LifeAreaIconOption(symbolName: "bolt.fill", keywords: ["execution", "action", "momentum"]),
        LifeAreaIconOption(symbolName: "tray.full.fill", keywords: ["inbox", "capture", "intake"]),
        LifeAreaIconOption(symbolName: "wrench.and.screwdriver.fill", keywords: ["maintenance", "ops", "repairs"])
    ]

    public var visibleSuggestions: [LifeAreaSuggestion] {
        let existing = Set(allLifeAreasByID.values.map { normalizedLifeAreaName($0.name) })
        return suggestedLifeAreasCatalog.filter { existing.contains(normalizedLifeAreaName($0.name)) == false }
    }

    public var projectCreationLifeAreas: [LifeArea] {
        sections.map(\.lifeArea)
    }

    public var selectedDraftProjectLifeAreaName: String {
        if let draftProjectLifeAreaID,
           let lifeArea = allLifeAreasByID[draftProjectLifeAreaID] {
            return lifeArea.name
        }
        return "Select Life Area"
    }

    public var hasArchivedContent: Bool {
        archivedLifeAreaSections.isEmpty == false || archivedProjectGroups.isEmpty == false
    }

    private let manageLifeAreasUseCase: ManageLifeAreasUseCase
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let projectRepository: ProjectRepositoryProtocol?

    private var hasLoadedOnce = false
    private var hasPerformedBackfill = false
    private var generalLifeAreaID: UUID?
    private var allLifeAreasByID: [UUID: LifeArea] = [:]
    private var allRowsByLifeAreaID: [UUID: [LifeManagementProjectRow]] = [:]

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

    /// Executes createProjectFromDraft.
    public func createProjectFromDraft() {
        let trimmedName = draftProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { return }

        guard let lifeAreaID = draftProjectLifeAreaID else {
            errorMessage = "Select a life area for the new project."
            return
        }

        let trimmedDescription = draftProjectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDescription = trimmedDescription.isEmpty ? nil : trimmedDescription

        isCreatingProject = true
        errorMessage = nil
        manageProjectsUseCase.createProject(
            request: CreateProjectRequest(
                name: trimmedName,
                description: normalizedDescription,
                lifeAreaID: lifeAreaID
            )
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isCreatingProject = false
                switch result {
                case .success:
                    self.draftProjectName = ""
                    self.draftProjectDescription = ""
                    self.reload()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes beginEditLifeArea.
    public func beginEditLifeArea(_ lifeAreaID: UUID) {
        guard let lifeArea = allLifeAreasByID[lifeAreaID] else { return }
        lifeAreaEditDraft = LifeAreaEditDraft(
            id: lifeArea.id,
            name: lifeArea.name,
            colorHex: lifeArea.color ?? ""
        )
    }

    /// Executes dismissLifeAreaEdit.
    public func dismissLifeAreaEdit() {
        lifeAreaEditDraft = nil
    }

    /// Executes saveLifeAreaEdit.
    public func saveLifeAreaEdit(name: String, colorHex: String) {
        guard let draft = lifeAreaEditDraft,
              let source = allLifeAreasByID[draft.id] else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            errorMessage = "Life area name cannot be empty."
            return
        }

        let trimmedColor = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedColor = trimmedColor.isEmpty ? nil : trimmedColor

        isMutating = true
        errorMessage = nil
        manageLifeAreasUseCase.update(
            id: draft.id,
            name: trimmedName,
            color: normalizedColor,
            icon: source.icon
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isMutating = false
                switch result {
                case .success:
                    self.lifeAreaEditDraft = nil
                    self.reload()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes showIconPicker.
    public func showIconPicker(for lifeAreaID: UUID) {
        guard let lifeArea = allLifeAreasByID[lifeAreaID] else { return }
        iconPickerContext = LifeAreaIconPickerContext(
            id: lifeArea.id,
            lifeAreaName: lifeArea.name,
            currentIcon: lifeArea.icon
        )
    }

    /// Executes dismissIconPicker.
    public func dismissIconPicker() {
        iconPickerContext = nil
    }

    /// Executes filteredIconOptions.
    public func filteredIconOptions(query: String) -> [LifeAreaIconOption] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return lifeAreaIconCatalog }
        let normalized = trimmed.lowercased()
        return lifeAreaIconCatalog.filter { option in
            if option.symbolName.lowercased().contains(normalized) {
                return true
            }
            return option.keywords.contains(where: { $0.contains(normalized) })
        }
    }

    /// Executes applyIconSelection.
    public func applyIconSelection(_ symbol: String) {
        guard let context = iconPickerContext,
              let source = allLifeAreasByID[context.id] else { return }

        isMutating = true
        errorMessage = nil
        manageLifeAreasUseCase.update(
            id: source.id,
            name: source.name,
            color: source.color,
            icon: symbol
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isMutating = false
                switch result {
                case .success:
                    self.iconPickerContext = nil
                    self.reload()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes beginEditProject.
    public func beginEditProject(_ projectID: UUID) {
        guard let project = findProject(by: projectID) else { return }
        projectEditDraft = ProjectEditDraft(
            id: project.id,
            name: project.name,
            description: project.projectDescription ?? ""
        )
    }

    /// Executes dismissProjectEdit.
    public func dismissProjectEdit() {
        projectEditDraft = nil
    }

    /// Executes saveProjectEdit.
    public func saveProjectEdit(name: String, description: String) {
        guard let draft = projectEditDraft else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            errorMessage = "Project name cannot be empty."
            return
        }

        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDescription = trimmedDescription.isEmpty ? nil : trimmedDescription

        isMutating = true
        errorMessage = nil
        manageProjectsUseCase.updateProject(
            projectId: draft.id,
            request: UpdateProjectRequest(name: trimmedName, description: normalizedDescription)
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isMutating = false
                switch result {
                case .success:
                    self.projectEditDraft = nil
                    self.reload()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes requestArchiveLifeArea.
    public func requestArchiveLifeArea(_ lifeAreaID: UUID) {
        guard let lifeArea = allLifeAreasByID[lifeAreaID] else { return }
        guard isGeneralLifeArea(lifeAreaID) == false else {
            errorMessage = "General is pinned and cannot be archived."
            return
        }

        let rows = allRowsByLifeAreaID[lifeAreaID] ?? []
        let preview = LifeAreaArchivePreview(
            id: lifeAreaID,
            lifeAreaName: lifeArea.name,
            projectCount: rows.count,
            taskCount: rows.reduce(0) { $0 + $1.taskCount }
        )
        lifeAreaArchivePreview = preview
    }

    /// Executes cancelLifeAreaArchive.
    public func cancelLifeAreaArchive() {
        lifeAreaArchivePreview = nil
    }

    /// Executes confirmLifeAreaArchive.
    public func confirmLifeAreaArchive() {
        guard let preview = lifeAreaArchivePreview else { return }
        isMutating = true
        errorMessage = nil
        manageLifeAreasUseCase.archive(id: preview.id) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isMutating = false
                self.lifeAreaArchivePreview = nil
                switch result {
                case .success:
                    self.reload()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes unarchiveLifeArea.
    public func unarchiveLifeArea(_ lifeAreaID: UUID) {
        isMutating = true
        errorMessage = nil
        manageLifeAreasUseCase.unarchive(id: lifeAreaID) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isMutating = false
                switch result {
                case .success:
                    self.reload()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes requestArchiveProject.
    public func requestArchiveProject(_ projectID: UUID) {
        guard let row = findProjectRow(by: projectID) else { return }
        guard row.isMoveLocked == false else {
            errorMessage = "Inbox is pinned and cannot be archived."
            return
        }
        projectArchivePreview = ProjectArchivePreview(
            id: row.project.id,
            projectName: row.project.name,
            taskCount: row.taskCount
        )
    }

    /// Executes cancelProjectArchive.
    public func cancelProjectArchive() {
        projectArchivePreview = nil
    }

    /// Executes confirmProjectArchive.
    public func confirmProjectArchive() {
        guard let preview = projectArchivePreview else { return }
        isMutating = true
        errorMessage = nil
        manageProjectsUseCase.archiveProject(projectId: preview.id) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isMutating = false
                self.projectArchivePreview = nil
                switch result {
                case .success:
                    self.reload()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes unarchiveProject.
    public func unarchiveProject(_ projectID: UUID) {
        isMutating = true
        errorMessage = nil
        manageProjectsUseCase.unarchiveProject(projectId: projectID) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isMutating = false
                switch result {
                case .success:
                    self.reload()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes isGeneralLifeArea.
    public func isGeneralLifeArea(_ lifeAreaID: UUID) -> Bool {
        if let generalLifeAreaID, generalLifeAreaID == lifeAreaID {
            return true
        }
        if let area = allLifeAreasByID[lifeAreaID] {
            return normalizedLifeAreaName(area.name) == Self.generalNormalizedName
        }
        return false
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
        guard sections.contains(where: { $0.lifeArea.id == targetLifeAreaID }) else {
            return false
        }
        guard let draggingProjectID,
              let row = activeProjectRow(for: draggingProjectID) else {
            return false
        }
        guard row.isMoveLocked == false else { return false }
        guard row.project.isArchived == false else { return false }
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
        guard let row = activeProjectRow(for: projectID) else {
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
                let dedupedAll = self.dedupeLifeAreasByNormalizedName(areas)
                let activeAreas = dedupedAll.filter { !$0.isArchived }
                self.resolveGeneralLifeArea(from: activeAreas) { [weak self] resolution in
                    guard let self else { return }
                    switch resolution {
                    case .failure(let error):
                        Task { @MainActor [weak self] in
                            self?.isLoading = false
                            self?.errorMessage = error.localizedDescription
                        }
                    case .success(let payload):
                        var mergedAllAreas = dedupedAll
                        if mergedAllAreas.contains(where: { $0.id == payload.generalArea.id }) == false {
                            mergedAllAreas.append(payload.generalArea)
                        }

                        let shouldRunBackfill = runBackfill || !self.hasPerformedBackfill
                        if shouldRunBackfill {
                            self.manageProjectsUseCase.backfillUnassignedProjectsToGeneral(
                                generalLifeAreaID: payload.generalArea.id
                            ) { [weak self] backfillResult in
                                guard let self else { return }
                                switch backfillResult {
                                case .success:
                                    self.hasPerformedBackfill = true
                                    self.loadSections(lifeAreas: mergedAllAreas, generalLifeAreaID: payload.generalArea.id)
                                case .failure(let error):
                                    Task { @MainActor [weak self] in
                                        self?.errorMessage = error.localizedDescription
                                    }
                                    self.loadSections(lifeAreas: mergedAllAreas, generalLifeAreaID: payload.generalArea.id)
                                }
                            }
                        } else {
                            self.loadSections(lifeAreas: mergedAllAreas, generalLifeAreaID: payload.generalArea.id)
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
                self.generalLifeAreaID = generalLifeAreaID

                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                case .success(let projectStats):
                    let output = self.buildSections(
                        lifeAreas: lifeAreas,
                        projects: projectStats,
                        generalLifeAreaID: generalLifeAreaID
                    )
                    self.sections = output.activeSections
                    self.archivedLifeAreaSections = output.archivedLifeAreaSections
                    self.archivedProjectGroups = output.archivedProjectGroups
                    self.allRowsByLifeAreaID = output.rowsByLifeAreaID
                    self.allLifeAreasByID = Dictionary(uniqueKeysWithValues: lifeAreas.map { ($0.id, $0) })

                    if self.draftProjectLifeAreaID == nil ||
                        self.sections.contains(where: { $0.lifeArea.id == self.draftProjectLifeAreaID }) == false {
                        self.draftProjectLifeAreaID = self.sections.first?.lifeArea.id ?? generalLifeAreaID
                    }

                    if let draggingProjectID = self.draggingProjectID,
                       self.activeProjectRow(for: draggingProjectID) == nil {
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
            color: "#9E5F0A",
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

    private struct BuildOutput {
        let activeSections: [LifeManagementLifeAreaSection]
        let archivedLifeAreaSections: [LifeManagementLifeAreaSection]
        let archivedProjectGroups: [LifeManagementArchivedProjectGroup]
        let rowsByLifeAreaID: [UUID: [LifeManagementProjectRow]]
    }

    /// Executes buildSections.
    private func buildSections(
        lifeAreas: [LifeArea],
        projects: [ProjectWithStats],
        generalLifeAreaID: UUID
    ) -> BuildOutput {
        let activeAreas = sortLifeAreas(lifeAreas.filter { !$0.isArchived })
        let archivedAreas = sortLifeAreas(lifeAreas.filter(\.isArchived))

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

        let activeSections = activeAreas.map { area in
            let rows = rowsByLifeAreaID[area.id] ?? []
            let activeRows = sortRows(rows.filter { $0.project.isArchived == false })
            return LifeManagementLifeAreaSection(lifeArea: area, projects: activeRows)
        }

        let archivedLifeAreaSections = archivedAreas.map { area in
            let rows = sortRows(rowsByLifeAreaID[area.id] ?? [])
            return LifeManagementLifeAreaSection(lifeArea: area, projects: rows)
        }

        var archivedProjectGroups: [LifeManagementArchivedProjectGroup] = activeAreas.compactMap { area in
            let rows = rowsByLifeAreaID[area.id] ?? []
            let archivedRows = sortRows(rows.filter(\.project.isArchived))
            guard archivedRows.isEmpty == false else { return nil }
            return LifeManagementArchivedProjectGroup(lifeArea: area, projects: archivedRows)
        }
        archivedProjectGroups.sort { lhs, rhs in
            lhs.lifeArea.name.localizedCaseInsensitiveCompare(rhs.lifeArea.name) == .orderedAscending
        }

        return BuildOutput(
            activeSections: activeSections,
            archivedLifeAreaSections: archivedLifeAreaSections,
            archivedProjectGroups: archivedProjectGroups,
            rowsByLifeAreaID: rowsByLifeAreaID
        )
    }

    /// Executes sortLifeAreas.
    private func sortLifeAreas(_ lifeAreas: [LifeArea]) -> [LifeArea] {
        lifeAreas.sorted { lhs, rhs in
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
    }

    /// Executes sortRows.
    private func sortRows(_ rows: [LifeManagementProjectRow]) -> [LifeManagementProjectRow] {
        rows.sorted { lhs, rhs in
            if lhs.isInbox != rhs.isInbox {
                return lhs.isInbox
            }
            return lhs.project.name.localizedCaseInsensitiveCompare(rhs.project.name) == .orderedAscending
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
        targetSection.projects = sortRows(targetSection.projects)

        sections[sourceSectionIndex] = sourceSection
        sections[targetSectionIndex] = targetSection
    }

    /// Executes findProject.
    private func findProject(by projectID: UUID) -> Project? {
        findProjectRow(by: projectID)?.project
    }

    /// Executes findProjectRow.
    private func findProjectRow(by projectID: UUID) -> LifeManagementProjectRow? {
        if let active = activeProjectRow(for: projectID) {
            return active
        }
        for section in archivedLifeAreaSections {
            if let row = section.projects.first(where: { $0.project.id == projectID }) {
                return row
            }
        }
        for group in archivedProjectGroups {
            if let row = group.projects.first(where: { $0.project.id == projectID }) {
                return row
            }
        }
        return nil
    }

    /// Executes activeProjectRow.
    private func activeProjectRow(for projectID: UUID) -> LifeManagementProjectRow? {
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
