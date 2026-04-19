import Foundation
import Combine
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

public struct AddHabitPrefillTemplate: Equatable {
    public let title: String
    public let notes: String?
    public let lifeAreaID: UUID?
    public let projectID: UUID?
    public let kind: AddHabitKind
    public let trackingMode: AddHabitTrackingMode
    public let cadence: HabitCadenceDraft
    public let iconSymbolName: String?
    public let reminderWindowStart: String?
    public let reminderWindowEnd: String?

    public init(
        title: String,
        notes: String? = nil,
        lifeAreaID: UUID? = nil,
        projectID: UUID? = nil,
        kind: AddHabitKind = .positive,
        trackingMode: AddHabitTrackingMode = .dailyCheckIn,
        cadence: HabitCadenceDraft = .daily(),
        iconSymbolName: String? = nil,
        reminderWindowStart: String? = nil,
        reminderWindowEnd: String? = nil
    ) {
        self.title = title
        self.notes = notes
        self.lifeAreaID = lifeAreaID
        self.projectID = projectID
        self.kind = kind
        self.trackingMode = trackingMode
        self.cadence = cadence
        self.iconSymbolName = iconSymbolName
        self.reminderWindowStart = reminderWindowStart
        self.reminderWindowEnd = reminderWindowEnd
    }
}

@MainActor
public final class AddHabitViewModel: ObservableObject {
    private struct IconSearchCacheKey: Equatable {
        let query: String
        let kind: AddHabitKind
        let lifeAreaID: UUID?
    }

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
    @Published public var selectedColorHex: String = ""

    private let createHabitUseCase: CreateHabitUseCase
    private let manageLifeAreasUseCase: ManageLifeAreasUseCase
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let iconCatalog: HabitIconCatalog
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedOnce = false
    private var iconOptionsCache: (key: IconSearchCacheKey, options: [HabitIconOption])?
    private var pristineKind: AddHabitKind = .positive
    private var pristineTrackingMode: AddHabitTrackingMode = .dailyCheckIn
    private var pristineCadence: HabitCadenceDraft = .daily()
    private var pristineLifeAreaID: UUID?
    private var pristineProjectID: UUID?
    private var pristineReminderWindowStart: String = ""
    private var pristineReminderWindowEnd: String = ""
    private var pristineIconSymbolName: String?
    private var pristineColorHex: String = ""
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
        setupSelectionObservers()
    }

    public var availableIconOptions: [HabitIconOption] {
        let cacheKey = IconSearchCacheKey(
            query: iconSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            kind: selectedKind,
            lifeAreaID: selectedLifeAreaID
        )
        if let iconOptionsCache, iconOptionsCache.key == cacheKey {
            return iconOptionsCache.options
        }

        let preferredLifeAreaName: String?
        if let selectedLifeAreaID {
            preferredLifeAreaName = lifeAreas.first(where: { $0.id == selectedLifeAreaID })?.name
        } else {
            preferredLifeAreaName = nil
        }
        let options = iconCatalog.search(
            query: iconSearchQuery,
            habitKind: selectedKind,
            preferredLifeAreaName: preferredLifeAreaName
        )
        iconOptionsCache = (cacheKey, options)
        return options
    }

    public var selectedIconOption: HabitIconOption? {
        guard let selectedIconSymbolName else { return nil }
        return iconCatalog.all.first(where: { $0.symbolName == selectedIconSymbolName })
    }

    public var filteredProjectsForSelectedLifeArea: [ProjectWithStats] {
        projects.filter { projectWithStats in
            guard let selectedLifeAreaID else { return true }
            return projectWithStats.project.lifeAreaID == selectedLifeAreaID
        }
    }

    public var canSubmit: Bool {
        habitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && selectedLifeAreaID != nil
            && reminderWindowValidationError == nil
            && isSaving == false
            && isLoading == false
    }

    public var reminderWindowValidationError: String? {
        habitReminderWindowValidationError(start: reminderWindowStart.nilIfBlank, end: reminderWindowEnd.nilIfBlank)
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
            || selectedColorHex.trimmingCharacters(in: .whitespacesAndNewlines) != pristineColorHex
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
        loadDependencies(markLoaded: true)
    }

    public func reloadDependencies() {
        loadDependencies(markLoaded: true)
    }

    private func loadDependencies(markLoaded: Bool) {
        if markLoaded {
            hasLoadedOnce = true
        }
        isLoading = true
        errorMessage = nil
        let group = DispatchGroup()
        var loadedLifeAreas: [LifeArea] = []
        var loadedProjects: [ProjectWithStats] = []
        var loadedError: Error?

        group.enter()
        manageLifeAreasUseCase.list { result in
            Task { @MainActor in
                defer { group.leave() }
                switch result {
                case .success(let lifeAreas):
                    loadedLifeAreas = lifeAreas
                case .failure(let error):
                    loadedError = error
                }
            }
        }

        group.enter()
        manageProjectsUseCase.getAllProjects { result in
            Task { @MainActor in
                defer { group.leave() }
                switch result {
                case .success(let projects):
                    loadedProjects = projects
                case .failure(let error):
                    loadedError = error
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.isLoading = false
            self.lifeAreas = loadedLifeAreas
            self.projects = loadedProjects
            if let selectedProjectID = self.selectedProjectID,
               let projectLifeAreaID = loadedProjects.first(where: { $0.project.id == selectedProjectID })?.project.lifeAreaID {
                self.selectedLifeAreaID = projectLifeAreaID
            } else if self.selectedLifeAreaID == nil {
                self.selectedLifeAreaID = loadedLifeAreas.first?.id
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

        normalizeProjectSelection()

        if let selectedIconSymbolName,
           availableIconOptions.contains(where: { $0.symbolName == selectedIconSymbolName }) == false {
            self.selectedIconSymbolName = randomIconOption()?.symbolName
        }

        if selectedIconSymbolName == nil {
            selectedIconSymbolName = randomIconOption()?.symbolName
        }

        if selectedColorHex.nilIfBlank == nil {
            selectedColorHex = randomColorHex()
        }
    }

    public func createHabit(completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void) {
        guard isSaving == false else { return }
        let trimmedName = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            let error = validationError("Habit name cannot be empty.")
            errorMessage = error.localizedDescription
            completion(.failure(error))
            return
        }
        guard let lifeAreaID = selectedLifeAreaID else {
            let error = validationError("Select a life area.")
            errorMessage = error.localizedDescription
            completion(.failure(error))
            return
        }
        if let reminderWindowValidationError {
            let error = validationError(reminderWindowValidationError)
            errorMessage = error.localizedDescription
            completion(.failure(error))
            return
        }

        normalizeSelection()
        normalizeProjectSelection()
        isSaving = true
        errorMessage = nil
        if selectedIconSymbolName == nil {
            selectedIconSymbolName = randomIconOption()?.symbolName
        }
        if selectedColorHex.nilIfBlank == nil {
            selectedColorHex = randomColorHex()
        }
        let normalizedStart = reminderWindowStart.nilIfBlank?.normalizedHHmm
        let normalizedEnd = reminderWindowEnd.nilIfBlank?.normalizedHHmm
        let icon = resolvedCreateIconMetadata()
        let request = CreateHabitRequest(
            title: trimmedName,
            lifeAreaID: lifeAreaID,
            projectID: selectedProjectID,
            kind: selectedKind == .positive ? .positive : .negative,
            trackingMode: selectedTrackingMode == .dailyCheckIn ? .dailyCheckIn : .lapseOnly,
            icon: icon,
            colorHex: TaskerHexColor.normalized(selectedColorHex.nilIfBlank),
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

    public func applyPrefill(_ template: AddHabitPrefillTemplate) {
        habitName = template.title
        habitNotes = template.notes ?? ""
        selectedLifeAreaID = template.lifeAreaID
        selectedProjectID = template.projectID
        selectedKind = template.kind
        selectedTrackingMode = template.trackingMode
        selectedCadence = template.cadence
        reminderWindowStart = template.reminderWindowStart ?? ""
        reminderWindowEnd = template.reminderWindowEnd ?? ""
        selectedColorHex = ""
        selectedIconSymbolName = nil
        if let iconSymbolName = template.iconSymbolName {
            selectedIconSymbolName = iconSymbolName
        }
        normalizeSelection()
        errorMessage = nil
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
        selectedIconSymbolName = nil
        selectedColorHex = randomColorHex()
        normalizeSelection()
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
        pristineColorHex = selectedColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        pristineQuery = iconSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func randomIconOption() -> HabitIconOption? {
        availableIconOptions.randomElement()
    }

    private func randomColorHex() -> String {
        HabitColorFamily.allCases.randomElement()?.canonicalHex ?? HabitColorFamily.green.canonicalHex
    }

    private func resolvedCreateIconMetadata() -> HabitIconMetadata {
        if let selectedIconOption {
            return HabitIconMetadata(
                symbolName: selectedIconOption.symbolName,
                categoryKey: selectedIconOption.categoryKey
            )
        }

        if let symbolName = selectedIconSymbolName,
           let matchingOption = iconCatalog.all.first(where: { $0.symbolName == symbolName }) {
            return HabitIconMetadata(
                symbolName: matchingOption.symbolName,
                categoryKey: matchingOption.categoryKey
            )
        }

        if let randomOption = randomIconOption() {
            selectedIconSymbolName = randomOption.symbolName
            return HabitIconMetadata(
                symbolName: randomOption.symbolName,
                categoryKey: randomOption.categoryKey
            )
        }

        return HabitIconMetadata(
            symbolName: selectedIconSymbolName ?? "circle.dashed",
            categoryKey: "general"
        )
    }

    private func setupSelectionObservers() {
        $selectedLifeAreaID
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] _ in
                self?.normalizeProjectSelection()
            }
            .store(in: &cancellables)

        $selectedProjectID
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] selectedProjectID in
                guard let self,
                      let selectedProjectID,
                      let projectLifeAreaID = self.projects.first(where: { $0.project.id == selectedProjectID })?.project.lifeAreaID,
                      self.selectedLifeAreaID != projectLifeAreaID else {
                    return
                }
                self.selectedLifeAreaID = projectLifeAreaID
            }
            .store(in: &cancellables)
    }

    private func normalizeProjectSelection() {
        guard let selectedProjectID else { return }
        let isProjectValid = projects.contains { projectWithStats in
            guard projectWithStats.project.id == selectedProjectID else { return false }
            guard let selectedLifeAreaID else { return true }
            return projectWithStats.project.lifeAreaID == selectedLifeAreaID
        }
        if isProjectValid == false {
            self.selectedProjectID = nil
        }
    }

    private func validationError(_ message: String) -> NSError {
        NSError(
            domain: "AddHabitViewModel",
            code: 422,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

}

fileprivate func habitReminderWindowValidationError(start: String?, end: String?) -> String? {
    let normalizedStart = start?.normalizedHHmm
    let normalizedEnd = end?.normalizedHHmm
    if let start, normalizedStart == nil {
        return "Reminder start must use HH:mm."
    }
    if let end, normalizedEnd == nil {
        return "Reminder end must use HH:mm."
    }
    if let startMinutes = normalizedStart?.minutesSinceMidnight,
       let endMinutes = normalizedEnd?.minutesSinceMidnight,
       endMinutes <= startMinutes {
        return "Reminder end must be after the start on the same day."
    }
    return nil
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

    var minutesSinceMidnight: Int? {
        guard let normalizedHHmm else { return nil }
        let parts = normalizedHHmm.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return (hour * 60) + minute
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
    public var cadence: HabitCadenceDraft
    public var lifeAreaID: UUID?
    public var projectID: UUID?
    public var reminderWindowStart: String
    public var reminderWindowEnd: String
    public var iconSearchQuery: String
    public var selectedIconSymbolName: String?
    public var colorHex: String

    public init(row: HabitLibraryRow) {
        title = row.title
        notes = row.notes ?? ""
        kind = row.kind == .positive ? .positive : .negative
        trackingMode = row.trackingMode == .dailyCheckIn ? .dailyCheckIn : .lapseOnly
        cadence = row.cadence
        lifeAreaID = row.lifeAreaID
        projectID = row.projectID
        reminderWindowStart = row.reminderWindowStart ?? ""
        reminderWindowEnd = row.reminderWindowEnd ?? ""
        iconSearchQuery = ""
        selectedIconSymbolName = row.icon?.symbolName
        colorHex = row.colorHex ?? ""
    }
}

public enum HabitDetailDayCellState: Equatable {
    case empty
    case success
    case skipped
    case lapsed
    case notScheduled
    case future
}

public struct HabitDetailDayCell: Identifiable, Equatable {
    public let date: Date
    public let state: HabitDetailDayCellState
    public let isToday: Bool
    public let isInteractive: Bool

    public var id: Date { date }

    public var dayNumber: String {
        String(Calendar.current.component(.day, from: date))
    }
}

public struct HabitDetailCalendarWeek: Identifiable, Equatable {
    public let startDate: Date
    public let monthLabel: String?
    public let cells: [HabitDetailDayCell]

    public var id: Date { startDate }
}

public struct HabitDetailCalendarCellViewState: Identifiable, Equatable {
    public let cell: HabitDetailDayCell
    public let streakDepth: Int?
    public let dayNumber: String
    public let accessibilityLabel: String
    public let accessibilityValue: String
    public let accessibilityHint: String
    public let accessibilityIdentifier: String

    public var id: Date { cell.id }
}

public struct HabitDetailCalendarWeekViewState: Identifiable, Equatable {
    public let startDate: Date
    public let monthLabel: String?
    public let cells: [HabitDetailCalendarCellViewState]

    public var id: Date { startDate }
}

public struct HabitDetailCalendarViewState: Equatable {
    public let helperText: String
    public let weeks: [HabitDetailCalendarWeekViewState]
}

enum HabitDetailDayMutationRequest: Equatable {
    case resolve(HabitOccurrenceAction)
    case reset
}

enum HabitDetailCalendarBuilder {
    static let historyDayCount = 84

    static func buildWeeks(
        row: HabitLibraryRow,
        marks: [HabitDayMark],
        referenceDate: Date,
        dayCount: Int = historyDayCount,
        calendar: Calendar = .current
    ) -> [HabitDetailCalendarWeek] {
        let endDay = calendar.startOfDay(for: referenceDate)
        let requestedStart = calendar.date(byAdding: .day, value: -(max(dayCount, 1) - 1), to: endDay) ?? endDay
        let startDay = calendar.dateInterval(of: .weekOfYear, for: requestedStart)?.start ?? requestedStart
        let endWeek = calendar.dateInterval(of: .weekOfYear, for: endDay)
        let endGridDay = calendar.date(byAdding: .day, value: 6, to: endWeek?.start ?? endDay) ?? endDay
        let totalDays = max(calendar.dateComponents([.day], from: startDay, to: endGridDay).day ?? 0, 0) + 1
        let marksByDay = Dictionary(uniqueKeysWithValues: marks.map { mark in
            (calendar.startOfDay(for: mark.date), mark)
        })

        let days = (0..<totalDays).compactMap { offset -> HabitDetailDayCell? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { return nil }
            let dayStart = calendar.startOfDay(for: day)
            let scheduled = occurs(on: dayStart, cadence: row.cadence, trackingMode: row.trackingMode, calendar: calendar)
            let mark = marksByDay[dayStart]
            let state = resolveState(
                mark: mark,
                day: dayStart,
                referenceDay: endDay,
                scheduled: scheduled
            )
            let hasRecordedMark: Bool = {
                switch mark?.state {
                case .some(.success), .some(.skipped), .some(.failure):
                    return true
                case .some(.none), .some(.future), .none:
                    return false
                }
            }()

            return HabitDetailDayCell(
                date: dayStart,
                state: state,
                isToday: calendar.isDate(dayStart, inSameDayAs: endDay),
                isInteractive: (scheduled || hasRecordedMark) && dayStart <= endDay && !row.isPaused && !row.isArchived
            )
        }

        let formatter = monthFormatter
        var previousMonthAnchor: Date?

        return stride(from: 0, to: days.count, by: 7).compactMap { index in
            let cells = Array(days[index..<min(index + 7, days.count)])
            guard let firstDay = cells.first?.date else { return nil }
            let monthAnchor = cells.first(where: {
                calendar.component(.day, from: $0.date) == 1
            })?.date ?? (index == 0 ? firstDay : nil)
            let monthLabel: String?
            if let monthAnchor {
                if let previousMonthAnchor, calendar.isDate(monthAnchor, equalTo: previousMonthAnchor, toGranularity: .month) {
                    monthLabel = nil
                } else {
                    monthLabel = formatter.string(from: monthAnchor)
                    previousMonthAnchor = monthAnchor
                }
            } else {
                monthLabel = nil
            }

            return HabitDetailCalendarWeek(
                startDate: firstDay,
                monthLabel: monthLabel,
                cells: cells
            )
        }
    }

    static func buildViewState(
        row: HabitLibraryRow,
        marks: [HabitDayMark],
        referenceDate: Date,
        dayCount: Int = historyDayCount,
        calendar: Calendar = .current
    ) -> HabitDetailCalendarViewState {
        let weeks = buildWeeks(
            row: row,
            marks: marks,
            referenceDate: referenceDate,
            dayCount: dayCount,
            calendar: calendar
        )
        let flattenedCells = weeks.flatMap(\.cells)
        let streakDepthByDate = streakDepthMap(for: flattenedCells, calendar: calendar)

        return HabitDetailCalendarViewState(
            helperText: helperText(for: row),
            weeks: weeks.map { week in
                HabitDetailCalendarWeekViewState(
                    startDate: week.startDate,
                    monthLabel: week.monthLabel,
                    cells: week.cells.map { cell in
                        let dayStart = calendar.startOfDay(for: cell.date)
                        return HabitDetailCalendarCellViewState(
                            cell: cell,
                            streakDepth: streakDepthByDate[dayStart],
                            dayNumber: String(calendar.component(.day, from: cell.date)),
                            accessibilityLabel: fullDateFormatter.string(from: cell.date),
                            accessibilityValue: accessibilityValue(for: cell, row: row),
                            accessibilityHint: accessibilityHint(for: cell, row: row),
                            accessibilityIdentifier: accessibilityIdentifier(for: cell.date)
                        )
                    }
                )
            }
        )
    }

    static func helperText(for row: HabitLibraryRow) -> String {
        if row.isArchived {
            return "Archived habits are read-only."
        }
        if row.isPaused {
            return "Resume this habit to update days."
        }

        switch (row.kind, row.trackingMode) {
        case (.positive, .dailyCheckIn):
            return "Tap a day to mark it done or skipped."
        case (.negative, .dailyCheckIn):
            return "Tap a day to mark stayed clean or lapsed."
        case (.negative, .lapseOnly):
            return "Tap a day to log or clear a lapse."
        case (.positive, .lapseOnly):
            return "Tap a day to update it."
        }
    }

    static func accessibilityIdentifier(for date: Date) -> String {
        "habitDetail.cell.\(accessibilityStampFormatter.string(from: date))"
    }

    static func nextMutation(
        for row: HabitLibraryRow,
        state: HabitDetailDayCellState
    ) -> HabitDetailDayMutationRequest? {
        guard !row.isPaused, !row.isArchived else { return nil }

        switch (row.kind, row.trackingMode, state) {
        case (_, _, .future), (_, _, .notScheduled):
            return nil

        case (.positive, .dailyCheckIn, .empty):
            return .resolve(.complete)
        case (.positive, .dailyCheckIn, .success):
            return .resolve(.skip)
        case (.positive, .dailyCheckIn, .skipped), (.positive, .dailyCheckIn, .lapsed):
            return .reset

        case (.negative, .dailyCheckIn, .empty):
            return .resolve(.abstained)
        case (.negative, .dailyCheckIn, .success):
            return .resolve(.lapsed)
        case (.negative, .dailyCheckIn, .skipped):
            return .reset
        case (.negative, .dailyCheckIn, .lapsed):
            return .reset

        case (.negative, .lapseOnly, .empty):
            return .resolve(.lapsed)
        case (.negative, .lapseOnly, .lapsed):
            return .reset
        case (.negative, .lapseOnly, .success), (.negative, .lapseOnly, .skipped):
            return .reset

        case (.positive, .lapseOnly, .empty):
            return .resolve(.complete)
        case (.positive, .lapseOnly, .success), (.positive, .lapseOnly, .skipped), (.positive, .lapseOnly, .lapsed):
            return .reset
        }
    }

    static func accessibilityValue(for cell: HabitDetailDayCell, row: HabitLibraryRow) -> String {
        switch cell.state {
        case .empty:
            return row.kind == .negative && row.trackingMode == .dailyCheckIn ? "Open day" : "Empty"
        case .success:
            return row.kind == .negative ? "Stayed clean" : "Done"
        case .skipped:
            return "Skipped"
        case .lapsed:
            return row.kind == .negative ? "Lapsed" : "Missed"
        case .notScheduled:
            return "Not scheduled"
        case .future:
            return "Future day"
        }
    }

    static func accessibilityHint(for cell: HabitDetailDayCell, row: HabitLibraryRow) -> String {
        guard cell.isInteractive,
              let mutation = nextMutation(for: row, state: cell.state) else { return "" }

        switch mutation {
        case .resolve(let action):
            switch action {
            case .complete:
                return "Double-tap to mark done."
            case .skip:
                return "Double-tap to mark skipped."
            case .abstained:
                return "Double-tap to mark stayed clean."
            case .lapsed:
                return "Double-tap to mark lapsed."
            }
        case .reset:
            return "Double-tap to clear this day."
        }
    }

    private static func resolveState(
        mark: HabitDayMark?,
        day: Date,
        referenceDay: Date,
        scheduled: Bool
    ) -> HabitDetailDayCellState {
        guard day <= referenceDay else { return .future }

        if let mark {
            switch mark.state {
            case .success:
                return .success
            case .skipped:
                return .skipped
            case .failure:
                return .lapsed
            case .future:
                return .future
            case .none:
                break
            }
        }

        return scheduled ? .empty : .notScheduled
    }

    private static func occurs(
        on date: Date,
        cadence: HabitCadenceDraft,
        trackingMode: HabitTrackingMode,
        calendar: Calendar
    ) -> Bool {
        switch cadence {
        case .daily:
            return true
        case .weekly(let daysOfWeek, _, _):
            let weekday = calendar.component(.weekday, from: date)
            if trackingMode == .lapseOnly && daysOfWeek.isEmpty {
                return true
            }
            return daysOfWeek.contains(weekday)
        }
    }

    private static func streakDepthMap(
        for cells: [HabitDetailDayCell],
        calendar: Calendar
    ) -> [Date: Int] {
        var streakDepthByDate: [Date: Int] = [:]
        var streakDepth = 0

        for cell in cells.sorted(by: { $0.date < $1.date }) {
            switch cell.state {
            case .success:
                streakDepth = min(streakDepth + 1, 8)
                streakDepthByDate[calendar.startOfDay(for: cell.date)] = streakDepth
            case .skipped, .notScheduled:
                continue
            case .empty, .lapsed:
                streakDepth = 0
            case .future:
                continue
            }
        }

        return streakDepthByDate
    }

    private static var monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    private static let accessibilityStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

@MainActor
public final class HabitDetailViewModel: ObservableObject {
    private enum TestHooks {
        private static let editorSupportDelayPrefix = "-TASKER_TEST_HABIT_DETAIL_EDITOR_SUPPORT_DELAY_MS:"

        static var editorSupportDelay: TimeInterval {
            guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(editorSupportDelayPrefix) }) else {
                return 0
            }

            let rawValue = argument.dropFirst(editorSupportDelayPrefix.count)
            guard let milliseconds = Double(rawValue), milliseconds > 0 else {
                return 0
            }

            return milliseconds / 1_000
        }
    }

    private struct IconSearchCacheKey: Equatable {
        let query: String
        let kind: AddHabitKind
        let lifeAreaID: UUID?
    }

    @Published public private(set) var row: HabitLibraryRow
    @Published public private(set) var historyMarks: [HabitDayMark]
    @Published public private(set) var calendarViewState: HabitDetailCalendarViewState
    @Published public private(set) var lifeAreas: [LifeArea] = []
    @Published public private(set) var projects: [ProjectWithStats] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isCalendarMounted = false
    @Published public private(set) var isCalendarLoading = false
    @Published public private(set) var isPreparingEditorData = false
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
    private let resetHabitOccurrenceUseCase: ResetHabitOccurrenceUseCase
    private let manageLifeAreasUseCase: ManageLifeAreasUseCase
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let iconCatalog: HabitIconCatalog
    private var hasLoadedOnce = false
    private var hasLoadedEditorSupport = false
    private var iconOptionsCache: (key: IconSearchCacheKey, options: [HabitIconOption])?
    private var pendingEditorSupportCompletions: [(Bool) -> Void] = []

    public init(
        row: HabitLibraryRow,
        getHabitLibraryUseCase: GetHabitLibraryUseCase,
        getHabitHistoryUseCase: GetHabitHistoryUseCase,
        updateHabitUseCase: UpdateHabitUseCase,
        pauseHabitUseCase: PauseHabitUseCase,
        archiveHabitUseCase: ArchiveHabitUseCase,
        resolveHabitOccurrenceUseCase: ResolveHabitOccurrenceUseCase,
        resetHabitOccurrenceUseCase: ResetHabitOccurrenceUseCase,
        manageLifeAreasUseCase: ManageLifeAreasUseCase,
        manageProjectsUseCase: ManageProjectsUseCase,
        iconCatalog: HabitIconCatalog = .shared
    ) {
        self.row = row
        self.historyMarks = row.last14Days
        self.calendarViewState = HabitDetailCalendarBuilder.buildViewState(
            row: row,
            marks: row.last14Days,
            referenceDate: Date(),
            dayCount: max(row.last14Days.count, 14)
        )
        self.draft = HabitEditorDraft(row: row)
        self.getHabitLibraryUseCase = getHabitLibraryUseCase
        self.getHabitHistoryUseCase = getHabitHistoryUseCase
        self.updateHabitUseCase = updateHabitUseCase
        self.pauseHabitUseCase = pauseHabitUseCase
        self.archiveHabitUseCase = archiveHabitUseCase
        self.resolveHabitOccurrenceUseCase = resolveHabitOccurrenceUseCase
        self.resetHabitOccurrenceUseCase = resetHabitOccurrenceUseCase
        self.manageLifeAreasUseCase = manageLifeAreasUseCase
        self.manageProjectsUseCase = manageProjectsUseCase
        self.iconCatalog = iconCatalog
        TaskerPerformanceTrace.event("HabitDetailViewModelInit")
    }

    public var detailCalendarWeeks: [HabitDetailCalendarWeek] {
        calendarViewState.weeks.map { week in
            HabitDetailCalendarWeek(
                startDate: week.startDate,
                monthLabel: week.monthLabel,
                cells: week.cells.map(\.cell)
            )
        }
    }

    public var detailCalendarHelperText: String {
        calendarViewState.helperText
    }

    public var availableIconOptions: [HabitIconOption] {
        let cacheKey = IconSearchCacheKey(
            query: draft.iconSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            kind: draft.kind,
            lifeAreaID: draft.lifeAreaID
        )
        if let iconOptionsCache, iconOptionsCache.key == cacheKey {
            return iconOptionsCache.options
        }

        let preferredLifeAreaName = lifeAreas.first(where: { $0.id == draft.lifeAreaID })?.name
        let options = iconCatalog.search(
            query: draft.iconSearchQuery,
            habitKind: draft.kind,
            preferredLifeAreaName: preferredLifeAreaName
        )
        iconOptionsCache = (cacheKey, options)
        return options
    }

    public var selectedIconOption: HabitIconOption? {
        guard let selectedIconSymbolName = draft.selectedIconSymbolName else { return nil }
        return iconCatalog.all.first(where: { $0.symbolName == selectedIconSymbolName })
    }

    public var canSave: Bool {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && draft.lifeAreaID != nil
            && editorReminderWindowValidationError == nil
            && isSaving == false
    }

    public var editorReminderWindowValidationError: String? {
        habitReminderWindowValidationError(
            start: draft.reminderWindowStart.nilIfBlank,
            end: draft.reminderWindowEnd.nilIfBlank
        )
    }

    public func loadIfNeeded() {
        guard hasLoadedOnce == false else { return }
        hasLoadedOnce = true
        isCalendarLoading = true
        TaskerPerformanceTrace.event("HabitDetailSheetLoadRequested")

        DispatchQueue.main.async {
            self.isCalendarMounted = true
            TaskerPerformanceTrace.event("HabitDetailCalendarMounted")

            DispatchQueue.main.async {
                self.refreshReadOnlyData()
            }
        }
    }

    public func refresh() {
        refreshReadOnlyData()
    }

    public func refreshReadOnlyData(completion: (() -> Void)? = nil) {
        isLoading = true
        isCalendarLoading = true
        errorMessage = nil
        TaskerPerformanceTrace.event("HabitDetailReadOnlyRefreshStarted")

        let group = DispatchGroup()
        var latestRow: HabitLibraryRow?
        var latestHistory: [HabitDayMark] = historyMarks
        var firstError: Error?

        group.enter()
        getHabitLibraryUseCase.execute(habitID: row.habitID, includeArchived: true) { result in
            Task { @MainActor in
                defer { group.leave() }
                switch result {
                case .success(let refreshedRow):
                    latestRow = refreshedRow
                case .failure(let error):
                    firstError = firstError ?? error
                }
            }
        }

        group.enter()
        getHabitHistoryUseCase.execute(
            habitIDs: [row.habitID],
            endingOn: Date(),
            dayCount: HabitDetailCalendarBuilder.historyDayCount
        ) { result in
            Task { @MainActor in
                defer { group.leave() }
                switch result {
                case .success(let windows):
                    latestHistory = windows.first(where: { $0.habitID == self.row.habitID })?.marks ?? latestHistory
                case .failure(let error):
                    firstError = firstError ?? error
                }
            }
        }

        group.notify(queue: .main) {
            self.isLoading = false
            self.isCalendarLoading = false
            if let latestRow {
                let preservedLast14Days = latestRow.last14Days.isEmpty ? self.row.last14Days : latestRow.last14Days
                self.row = latestRow
                if latestRow.last14Days.isEmpty {
                    self.row = HabitLibraryRow(
                        habitID: latestRow.habitID,
                        title: latestRow.title,
                        kind: latestRow.kind,
                        trackingMode: latestRow.trackingMode,
                        cadence: latestRow.cadence,
                        lifeAreaID: latestRow.lifeAreaID,
                        lifeAreaName: latestRow.lifeAreaName,
                        projectID: latestRow.projectID,
                        projectName: latestRow.projectName,
                        icon: latestRow.icon,
                        colorHex: latestRow.colorHex,
                        isPaused: latestRow.isPaused,
                        isArchived: latestRow.isArchived,
                        currentStreak: latestRow.currentStreak,
                        bestStreak: latestRow.bestStreak,
                        last14Days: preservedLast14Days,
                        nextDueAt: latestRow.nextDueAt,
                        lastCompletedAt: latestRow.lastCompletedAt,
                        reminderWindowStart: latestRow.reminderWindowStart,
                        reminderWindowEnd: latestRow.reminderWindowEnd,
                        notes: latestRow.notes
                    )
                }
                if self.isEditing == false {
                    self.draft = HabitEditorDraft(row: self.row)
                }
            }
            self.historyMarks = latestHistory
            self.updateCalendarViewState()
            if self.draft.selectedIconSymbolName == nil {
                self.draft.selectedIconSymbolName = self.availableIconOptions.first?.symbolName
            }
            self.errorMessage = firstError?.localizedDescription
            TaskerPerformanceTrace.event("HabitDetailHydrationCompleted")
            completion?()
        }
    }

    public func beginEditing() {
        guard isSaving == false, isPreparingEditorData == false else { return }
        errorMessage = nil
        loadEditorSupportDataIfNeeded { [weak self] didLoad in
            guard let self else { return }
            guard didLoad else { return }
            self.draft = HabitEditorDraft(row: self.row)
            self.normalizeDraftSelection()
            self.isEditing = true
            self.errorMessage = nil
        }
    }

    public func cancelEditing() {
        draft = HabitEditorDraft(row: row)
        normalizeDraftSelection()
        isEditing = false
        errorMessage = nil
    }

    public func normalizeDraftSelection() {
        if draft.kind == .positive, draft.trackingMode != .dailyCheckIn {
            draft.trackingMode = .dailyCheckIn
        }
        normalizeDraftProjectSelection()
        if let selectedIconSymbolName = draft.selectedIconSymbolName,
           availableIconOptions.contains(where: { $0.symbolName == selectedIconSymbolName }) == false {
            draft.selectedIconSymbolName = availableIconOptions.first?.symbolName
        }
        if draft.selectedIconSymbolName == nil {
            draft.selectedIconSymbolName = availableIconOptions.first?.symbolName
        }
    }

    public func saveChanges(completion: (() -> Void)? = nil) {
        normalizeDraftSelection()
        guard canSave else {
            errorMessage = editorReminderWindowValidationError ?? "Fill in the required habit details."
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
            colorHex: TaskerHexColor.normalized(draft.colorHex.nilIfBlank),
            targetConfig: HabitTargetConfig(notes: draft.notes.nilIfBlank, targetCountPerDay: 1),
            metricConfig: HabitMetricConfig(unitLabel: nil, showNotesOnCompletion: draft.notes.nilIfBlank != nil),
            cadence: draft.cadence,
            reminderWindowStart: draft.reminderWindowStart.nilIfBlank?.normalizedHHmm,
            reminderWindowEnd: draft.reminderWindowEnd.nilIfBlank?.normalizedHHmm,
            notes: draft.notes.nilIfBlank
        )

        updateHabitUseCase.execute(request: request) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success:
                    self.isEditing = false
                    self.refreshReadOnlyData {
                        completion?()
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func togglePause(completion: (() -> Void)? = nil) {
        guard isSaving == false else { return }
        isSaving = true
        pauseHabitUseCase.execute(id: row.habitID, isPaused: !row.isPaused) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success:
                    self.refreshReadOnlyData {
                        completion?()
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func archive(completion: (() -> Void)? = nil) {
        guard isSaving == false else { return }
        isSaving = true
        archiveHabitUseCase.execute(id: row.habitID) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success:
                    self.refreshReadOnlyData {
                        completion?()
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func logLapse(completion: (() -> Void)? = nil) {
        guard row.trackingMode == .lapseOnly else { return }
        guard isSaving == false else { return }
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
                    self.refreshReadOnlyData {
                        completion?()
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func mutateDay(
        _ cell: HabitDetailDayCell,
        completion: (() -> Void)? = nil
    ) {
        guard cell.isInteractive,
              isSaving == false,
              let request = HabitDetailCalendarBuilder.nextMutation(for: row, state: cell.state) else { return }

        isSaving = true
        errorMessage = nil

        let handleResult: (Result<Void, Error>) -> Void = { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success:
                    self.refreshReadOnlyData {
                        completion?()
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        switch request {
        case .resolve(let action):
            resolveHabitOccurrenceUseCase.execute(
                habitID: row.habitID,
                occurrenceID: nil,
                action: action,
                on: cell.date
            ) { result in
                handleResult(result)
            }
        case .reset:
            resetHabitOccurrenceUseCase.execute(
                habitID: row.habitID,
                occurrenceID: nil,
                on: cell.date
            ) { result in
                handleResult(result)
            }
        }
    }

    public func clearError() {
        errorMessage = nil
    }

    private func updateCalendarViewState(referenceDate: Date = Date()) {
        calendarViewState = HabitDetailCalendarBuilder.buildViewState(
            row: row,
            marks: historyMarks,
            referenceDate: referenceDate
        )
    }

    private func loadEditorSupportDataIfNeeded(completion: @escaping (Bool) -> Void) {
        if hasLoadedEditorSupport {
            completion(true)
            return
        }

        pendingEditorSupportCompletions.append(completion)
        guard isPreparingEditorData == false else { return }

        isPreparingEditorData = true

        let group = DispatchGroup()
        var loadedLifeAreas: [LifeArea] = lifeAreas
        var loadedProjects: [ProjectWithStats] = projects
        var firstError: Error?

        group.enter()
        manageLifeAreasUseCase.list { result in
            Task { @MainActor in
                defer { group.leave() }
                switch result {
                case .success(let values):
                    loadedLifeAreas = values
                case .failure(let error):
                    firstError = firstError ?? error
                }
            }
        }

        group.enter()
        manageProjectsUseCase.getAllProjects { result in
            Task { @MainActor in
                defer { group.leave() }
                switch result {
                case .success(let values):
                    loadedProjects = values
                case .failure(let error):
                    firstError = firstError ?? error
                }
            }
        }

        group.notify(queue: .main) {
            let finalize = {
                self.isPreparingEditorData = false
                self.lifeAreas = loadedLifeAreas
                self.projects = loadedProjects
                self.hasLoadedEditorSupport = firstError == nil
                if self.hasLoadedEditorSupport {
                    self.normalizeDraftSelection()
                    self.errorMessage = nil
                } else {
                    self.errorMessage = firstError?.localizedDescription
                }

                let completions = self.pendingEditorSupportCompletions
                self.pendingEditorSupportCompletions.removeAll()
                completions.forEach { $0(firstError == nil) }
            }

            let delay = TestHooks.editorSupportDelay
            guard delay > 0 else {
                finalize()
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                finalize()
            }
        }
    }

    private func normalizeDraftProjectSelection() {
        guard let projectID = draft.projectID else { return }
        let isProjectValid = projects.contains { projectWithStats in
            guard projectWithStats.project.id == projectID else { return false }
            guard let lifeAreaID = draft.lifeAreaID else { return true }
            return projectWithStats.project.lifeAreaID == lifeAreaID
        }
        if isProjectValid == false {
            draft.projectID = nil
        }
    }
}
