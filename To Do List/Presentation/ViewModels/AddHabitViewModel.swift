import Foundation
import SwiftUI

public enum AddHabitKind: String, CaseIterable, Identifiable {
    case positive
    case negative

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .positive: return "Build"
        case .negative: return "Quit"
        }
    }

    var iconSupportKey: String {
        switch self {
        case .positive: return "positive"
        case .negative: return "negative"
        }
    }
}

public enum AddHabitTrackingMode: String, CaseIterable, Identifiable {
    case dailyCheckIn
    case lapseOnly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .dailyCheckIn: return "Daily check-in"
        case .lapseOnly: return "Log lapse only"
        }
    }
}

@MainActor
public final class AddHabitViewModel: ObservableObject {
    @Published public private(set) var lifeAreas: [LifeArea] = []
    @Published public private(set) var projects: [ProjectWithStats] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSaving = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isHabitCreated = false
    @Published public private(set) var lastCreatedHabitID: UUID?

    @Published public var habitName: String = ""
    @Published public var habitNotes: String = ""
    @Published public var selectedKind: AddHabitKind = .positive
    @Published public var selectedTrackingMode: AddHabitTrackingMode = .dailyCheckIn
    @Published public var selectedCadence: HabitCadenceDraft = .daily()
    @Published public var selectedLifeAreaID: UUID?
    @Published public var selectedProjectID: UUID?
    @Published public var reminderWindowStart: String = ""
    @Published public var reminderWindowEnd: String = ""
    @Published public var iconSearchQuery: String = ""
    @Published public var selectedIconSymbolName: String?

    private let createHabitUseCase: CreateHabitUseCase
    private let manageLifeAreasUseCase: ManageLifeAreasUseCase
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let iconCatalog: HabitIconCatalog
    private var hasLoadedOnce = false
    private var pristineKind: AddHabitKind = .positive
    private var pristineTrackingMode: AddHabitTrackingMode = .dailyCheckIn
    private var pristineCadence: HabitCadenceDraft = .daily()
    private var pristineLifeAreaID: UUID?
    private var pristineProjectID: UUID?
    private var pristineReminderWindowStart: String = ""
    private var pristineReminderWindowEnd: String = ""
    private var pristineIconSymbolName: String?
    private var pristineQuery: String = ""
    private var pristineName: String = ""
    private var pristineNotes: String = ""

    public init(
        createHabitUseCase: CreateHabitUseCase,
        manageLifeAreasUseCase: ManageLifeAreasUseCase,
        manageProjectsUseCase: ManageProjectsUseCase,
        iconCatalog: HabitIconCatalog = .shared
    ) {
        self.createHabitUseCase = createHabitUseCase
        self.manageLifeAreasUseCase = manageLifeAreasUseCase
        self.manageProjectsUseCase = manageProjectsUseCase
        self.iconCatalog = iconCatalog
    }

    public var availableIconOptions: [HabitIconOption] {
        let preferredLifeAreaName: String?
        if let selectedLifeAreaID {
            preferredLifeAreaName = lifeAreas.first(where: { $0.id == selectedLifeAreaID })?.name
        } else {
            preferredLifeAreaName = nil
        }
        return iconCatalog.search(
            query: iconSearchQuery,
            habitKind: selectedKind,
            preferredLifeAreaName: preferredLifeAreaName
        )
    }

    public var selectedIconOption: HabitIconOption? {
        guard let selectedIconSymbolName else { return nil }
        return iconCatalog.all.first(where: { $0.symbolName == selectedIconSymbolName })
    }

    public var canSubmit: Bool {
        habitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && selectedLifeAreaID != nil
            && reminderWindowValidationError == nil
            && isSaving == false
            && isLoading == false
    }

    public var reminderWindowValidationError: String? {
        validateReminderWindows(start: reminderWindowStart.nilIfBlank, end: reminderWindowEnd.nilIfBlank)
    }

    public var hasUnsavedChanges: Bool {
        habitName.trimmingCharacters(in: .whitespacesAndNewlines) != pristineName
            || habitNotes.trimmingCharacters(in: .whitespacesAndNewlines) != pristineNotes
            || selectedKind != pristineKind
            || selectedTrackingMode != pristineTrackingMode
            || selectedCadence != pristineCadence
            || selectedLifeAreaID != pristineLifeAreaID
            || selectedProjectID != pristineProjectID
            || reminderWindowStart.trimmingCharacters(in: .whitespacesAndNewlines) != pristineReminderWindowStart
            || reminderWindowEnd.trimmingCharacters(in: .whitespacesAndNewlines) != pristineReminderWindowEnd
            || selectedIconSymbolName != pristineIconSymbolName
            || iconSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines) != pristineQuery
    }

    public var currentHabitType: String {
        switch (selectedKind, selectedTrackingMode) {
        case (.positive, _):
            return "check_in"
        case (.negative, .dailyCheckIn):
            return "quit"
        case (.negative, .lapseOnly):
            return "quit_lapse_only"
        }
    }

    public func loadIfNeeded() {
        guard hasLoadedOnce == false else { return }
        hasLoadedOnce = true
        isLoading = true
        errorMessage = nil

        let group = DispatchGroup()
        var loadedLifeAreas: [LifeArea] = []
        var loadedProjects: [ProjectWithStats] = []
        var loadedError: Error?

        group.enter()
        manageLifeAreasUseCase.list { result in
            defer { group.leave() }
            switch result {
            case .success(let lifeAreas):
                loadedLifeAreas = lifeAreas
            case .failure(let error):
                loadedError = error
            }
        }

        group.enter()
        manageProjectsUseCase.getAllProjects { result in
            defer { group.leave() }
            switch result {
            case .success(let projects):
                loadedProjects = projects
            case .failure(let error):
                loadedError = error
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.isLoading = false
            self.lifeAreas = loadedLifeAreas
            self.projects = loadedProjects
            if self.selectedLifeAreaID == nil {
                self.selectedLifeAreaID = loadedLifeAreas.first?.id
            }
            if self.selectedIconSymbolName == nil {
                self.selectedIconSymbolName = self.availableIconOptions.first?.symbolName
            }
            if let loadedError {
                self.errorMessage = loadedError.localizedDescription
            }
            self.normalizeSelection()
            self.capturePristineState()
        }
    }

    public func normalizeSelection() {
        if selectedKind == .positive, selectedTrackingMode != .dailyCheckIn {
            selectedTrackingMode = .dailyCheckIn
        }

        if let selectedIconSymbolName,
           availableIconOptions.contains(where: { $0.symbolName == selectedIconSymbolName }) == false {
            self.selectedIconSymbolName = availableIconOptions.first?.symbolName
        }

        if selectedIconSymbolName == nil {
            selectedIconSymbolName = availableIconOptions.first?.symbolName
        }
    }

    public func createHabit(completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) {
        let trimmedName = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            errorMessage = "Habit name cannot be empty."
            return
        }
        guard let lifeAreaID = selectedLifeAreaID else {
            errorMessage = "Select a life area."
            return
        }
        if let reminderWindowValidationError {
            errorMessage = reminderWindowValidationError
            return
        }

        isSaving = true
        errorMessage = nil
        let normalizedStart = reminderWindowStart.nilIfBlank?.normalizedHHmm
        let normalizedEnd = reminderWindowEnd.nilIfBlank?.normalizedHHmm
        let icon = selectedIconOption.map {
            HabitIconMetadata(symbolName: $0.symbolName, categoryKey: $0.categoryKey)
        } ?? HabitIconMetadata(
            symbolName: selectedIconSymbolName ?? "circle.dashed",
            categoryKey: "general"
        )
        let request = CreateHabitRequest(
            title: trimmedName,
            lifeAreaID: lifeAreaID,
            projectID: selectedProjectID,
            kind: selectedKind == .positive ? .positive : .negative,
            trackingMode: selectedTrackingMode == .dailyCheckIn ? .dailyCheckIn : .lapseOnly,
            icon: icon,
            targetConfig: HabitTargetConfig(notes: habitNotes.nilIfBlank, targetCountPerDay: 1),
            metricConfig: HabitMetricConfig(
                unitLabel: nil,
                showNotesOnCompletion: habitNotes.nilIfBlank != nil
            ),
            cadence: selectedCadence,
            reminderWindowStart: normalizedStart,
            reminderWindowEnd: normalizedEnd
        )
        createHabitUseCase.execute(request: request) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success(let habit):
                    self.isHabitCreated = true
                    self.lastCreatedHabitID = habit.id
                    completion(.success(habit))
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    public func resetForm() {
        habitName = ""
        habitNotes = ""
        selectedKind = .positive
        selectedTrackingMode = .dailyCheckIn
        selectedCadence = .daily()
        selectedProjectID = nil
        reminderWindowStart = ""
        reminderWindowEnd = ""
        iconSearchQuery = ""
        selectedIconSymbolName = availableIconOptions.first?.symbolName
        isHabitCreated = false
        lastCreatedHabitID = nil
        errorMessage = nil
        capturePristineState()
    }

    private func capturePristineState() {
        pristineName = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        pristineNotes = habitNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        pristineKind = selectedKind
        pristineTrackingMode = selectedTrackingMode
        pristineCadence = selectedCadence
        pristineLifeAreaID = selectedLifeAreaID
        pristineProjectID = selectedProjectID
        pristineReminderWindowStart = reminderWindowStart.trimmingCharacters(in: .whitespacesAndNewlines)
        pristineReminderWindowEnd = reminderWindowEnd.trimmingCharacters(in: .whitespacesAndNewlines)
        pristineIconSymbolName = selectedIconSymbolName
        pristineQuery = iconSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validateReminderWindows(start: String?, end: String?) -> String? {
        if let start, start.normalizedHHmm == nil {
            return "Reminder start must use HH:mm."
        }
        if let end, end.normalizedHHmm == nil {
            return "Reminder end must use HH:mm."
        }
        return nil
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedHHmm: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return String(format: "%02d:%02d", hour, minute)
    }
}

@MainActor
public final class HabitLibraryViewModel: ObservableObject {
    @Published public private(set) var rows: [HabitLibraryRow] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let getHabitLibraryUseCase: GetHabitLibraryUseCase
    private var hasLoadedOnce = false

    public init(getHabitLibraryUseCase: GetHabitLibraryUseCase) {
        self.getHabitLibraryUseCase = getHabitLibraryUseCase
    }

    public var activeRows: [HabitLibraryRow] {
        rows.filter { !$0.isArchived && !$0.isPaused }
    }

    public var pausedRows: [HabitLibraryRow] {
        rows.filter { !$0.isArchived && $0.isPaused }
    }

    public var archivedRows: [HabitLibraryRow] {
        rows.filter(\.isArchived)
    }

    public func loadIfNeeded() {
        guard hasLoadedOnce == false else { return }
        hasLoadedOnce = true
        refresh()
    }

    public func refresh() {
        isLoading = true
        errorMessage = nil
        getHabitLibraryUseCase.execute(includeArchived: true) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = false
                switch result {
                case .success(let rows):
                    self.rows = rows
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func clearError() {
        errorMessage = nil
    }
}

public struct HabitEditorDraft: Equatable {
    public var title: String
    public var notes: String
    public var kind: AddHabitKind
    public var trackingMode: AddHabitTrackingMode
    public var lifeAreaID: UUID?
    public var projectID: UUID?
    public var iconSearchQuery: String
    public var selectedIconSymbolName: String?

    public init(row: HabitLibraryRow) {
        title = row.title
        notes = row.notes ?? ""
        kind = row.kind == .positive ? .positive : .negative
        trackingMode = row.trackingMode == .dailyCheckIn ? .dailyCheckIn : .lapseOnly
        lifeAreaID = row.lifeAreaID
        projectID = row.projectID
        iconSearchQuery = ""
        selectedIconSymbolName = row.icon?.symbolName
    }
}

@MainActor
public final class HabitDetailViewModel: ObservableObject {
    @Published public private(set) var row: HabitLibraryRow
    @Published public private(set) var historyMarks: [HabitDayMark]
    @Published public private(set) var lifeAreas: [LifeArea] = []
    @Published public private(set) var projects: [ProjectWithStats] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSaving = false
    @Published public private(set) var errorMessage: String?
    @Published public var isEditing = false
    @Published public var draft: HabitEditorDraft

    private let getHabitLibraryUseCase: GetHabitLibraryUseCase
    private let getHabitHistoryUseCase: GetHabitHistoryUseCase
    private let updateHabitUseCase: UpdateHabitUseCase
    private let pauseHabitUseCase: PauseHabitUseCase
    private let archiveHabitUseCase: ArchiveHabitUseCase
    private let resolveHabitOccurrenceUseCase: ResolveHabitOccurrenceUseCase
    private let manageLifeAreasUseCase: ManageLifeAreasUseCase
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let iconCatalog: HabitIconCatalog
    private var hasLoadedOnce = false

    public init(
        row: HabitLibraryRow,
        getHabitLibraryUseCase: GetHabitLibraryUseCase,
        getHabitHistoryUseCase: GetHabitHistoryUseCase,
        updateHabitUseCase: UpdateHabitUseCase,
        pauseHabitUseCase: PauseHabitUseCase,
        archiveHabitUseCase: ArchiveHabitUseCase,
        resolveHabitOccurrenceUseCase: ResolveHabitOccurrenceUseCase,
        manageLifeAreasUseCase: ManageLifeAreasUseCase,
        manageProjectsUseCase: ManageProjectsUseCase,
        iconCatalog: HabitIconCatalog = .shared
    ) {
        self.row = row
        self.historyMarks = row.last14Days
        self.draft = HabitEditorDraft(row: row)
        self.getHabitLibraryUseCase = getHabitLibraryUseCase
        self.getHabitHistoryUseCase = getHabitHistoryUseCase
        self.updateHabitUseCase = updateHabitUseCase
        self.pauseHabitUseCase = pauseHabitUseCase
        self.archiveHabitUseCase = archiveHabitUseCase
        self.resolveHabitOccurrenceUseCase = resolveHabitOccurrenceUseCase
        self.manageLifeAreasUseCase = manageLifeAreasUseCase
        self.manageProjectsUseCase = manageProjectsUseCase
        self.iconCatalog = iconCatalog
    }

    public var availableIconOptions: [HabitIconOption] {
        let preferredLifeAreaName = lifeAreas.first(where: { $0.id == draft.lifeAreaID })?.name
        return iconCatalog.search(
            query: draft.iconSearchQuery,
            habitKind: draft.kind,
            preferredLifeAreaName: preferredLifeAreaName
        )
    }

    public var selectedIconOption: HabitIconOption? {
        guard let selectedIconSymbolName = draft.selectedIconSymbolName else { return nil }
        return iconCatalog.all.first(where: { $0.symbolName == selectedIconSymbolName })
    }

    public var canSave: Bool {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && draft.lifeAreaID != nil
            && isSaving == false
    }

    public func loadIfNeeded() {
        guard hasLoadedOnce == false else { return }
        hasLoadedOnce = true
        refresh()
    }

    public func refresh() {
        isLoading = true
        errorMessage = nil

        let group = DispatchGroup()
        var latestRow: HabitLibraryRow?
        var latestHistory: [HabitDayMark] = historyMarks
        var loadedLifeAreas: [LifeArea] = []
        var loadedProjects: [ProjectWithStats] = []
        var firstError: Error?

        group.enter()
        getHabitLibraryUseCase.execute(includeArchived: true) { result in
            defer { group.leave() }
            switch result {
            case .success(let rows):
                latestRow = rows.first(where: { $0.habitID == self.row.habitID })
            case .failure(let error):
                firstError = firstError ?? error
            }
        }

        group.enter()
        getHabitHistoryUseCase.execute(habitIDs: [row.habitID], endingOn: Date(), dayCount: 14) { result in
            defer { group.leave() }
            switch result {
            case .success(let windows):
                latestHistory = windows.first(where: { $0.habitID == self.row.habitID })?.marks ?? latestHistory
            case .failure(let error):
                firstError = firstError ?? error
            }
        }

        group.enter()
        manageLifeAreasUseCase.list { result in
            defer { group.leave() }
            switch result {
            case .success(let values):
                loadedLifeAreas = values
            case .failure(let error):
                firstError = firstError ?? error
            }
        }

        group.enter()
        manageProjectsUseCase.getAllProjects { result in
            defer { group.leave() }
            switch result {
            case .success(let values):
                loadedProjects = values
            case .failure(let error):
                firstError = firstError ?? error
            }
        }

        group.notify(queue: .main) {
            self.isLoading = false
            if let latestRow {
                self.row = latestRow
                if self.isEditing == false {
                    self.draft = HabitEditorDraft(row: latestRow)
                }
            }
            self.historyMarks = latestHistory
            self.lifeAreas = loadedLifeAreas
            self.projects = loadedProjects
            if self.draft.selectedIconSymbolName == nil {
                self.draft.selectedIconSymbolName = self.availableIconOptions.first?.symbolName
            }
            self.errorMessage = firstError?.localizedDescription
        }
    }

    public func beginEditing() {
        draft = HabitEditorDraft(row: row)
        if draft.selectedIconSymbolName == nil {
            draft.selectedIconSymbolName = availableIconOptions.first?.symbolName
        }
        isEditing = true
        errorMessage = nil
    }

    public func cancelEditing() {
        draft = HabitEditorDraft(row: row)
        isEditing = false
        errorMessage = nil
    }

    public func saveChanges(completion: (() -> Void)? = nil) {
        guard canSave else {
            errorMessage = "Fill in the required habit details."
            return
        }

        isSaving = true
        errorMessage = nil
        let request = UpdateHabitRequest(
            id: row.habitID,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            lifeAreaID: draft.lifeAreaID,
            projectID: draft.projectID,
            clearProject: draft.projectID == nil,
            kind: draft.kind == .positive ? .positive : .negative,
            trackingMode: draft.trackingMode == .dailyCheckIn ? .dailyCheckIn : .lapseOnly,
            icon: selectedIconOption.map { HabitIconMetadata(symbolName: $0.symbolName, categoryKey: $0.categoryKey) },
            targetConfig: HabitTargetConfig(notes: draft.notes.nilIfBlank, targetCountPerDay: 1),
            metricConfig: HabitMetricConfig(unitLabel: nil, showNotesOnCompletion: draft.notes.nilIfBlank != nil),
            notes: draft.notes.nilIfBlank
        )

        updateHabitUseCase.execute(request: request) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success:
                    self.isEditing = false
                    self.refresh()
                    completion?()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func togglePause(completion: (() -> Void)? = nil) {
        isSaving = true
        pauseHabitUseCase.execute(id: row.habitID, isPaused: !row.isPaused) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success:
                    self.refresh()
                    completion?()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func archive(completion: (() -> Void)? = nil) {
        isSaving = true
        archiveHabitUseCase.execute(id: row.habitID) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success:
                    self.refresh()
                    completion?()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func logLapse(completion: (() -> Void)? = nil) {
        guard row.trackingMode == .lapseOnly else { return }
        isSaving = true
        resolveHabitOccurrenceUseCase.execute(
            habitID: row.habitID,
            occurrenceID: nil,
            action: .lapsed,
            on: Date(),
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success:
                    self.refresh()
                    completion?()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func clearError() {
        errorMessage = nil
    }
}
