import Foundation
import Combine
import SwiftUI

public enum AddHabitKind: String, CaseIterable, Identifiable, Sendable {
    case positive
    case negative

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .positive: return String(localized: "Build")
        case .negative: return String(localized: "Quit")
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
        case .dailyCheckIn: return String(localized: "Daily check-in")
        case .lapseOnly: return String(localized: "Log slips only")
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
    /// A colour seed; `nil` keeps whatever the form has (or draws one).
    public let colorHex: String?
    /// The real target ("8 glasses", "20 min"); `nil` falls back to the
    /// kind's default, a check-in for build habits and avoidance for quit ones.
    public let target: HabitTarget?

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
        reminderWindowEnd: String? = nil,
        colorHex: String? = nil,
        target: HabitTarget? = nil
    ) {
        self.title = title
        self.notes = notes
        self.lifeAreaID = lifeAreaID
        self.projectID = projectID
        self.kind = kind
        self.trackingMode = trackingMode
        self.cadence = cadence
        self.colorHex = colorHex
        self.target = target
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
    @Published public var targetConfig = HabitTargetConfig(target: .binary)
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
    private var pristineTargetConfig = HabitTargetConfig(target: .binary)
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

    public var hasReminderWindow: Bool {
        reminderWindowStart.nilIfBlank != nil || reminderWindowEnd.nilIfBlank != nil
    }

    public var reminderWindowStartPickerDate: Date {
        get {
            HabitReminderWindowPickerCodec.date(fromHHmm: reminderWindowStart, fallbackMinutes: 9 * 60)
        }
        set {
            reminderWindowStart = HabitReminderWindowPickerCodec.hhmm(from: newValue)
            repairReminderWindowEndIfNeeded()
        }
    }

    public var reminderWindowEndPickerDate: Date {
        get {
            HabitReminderWindowPickerCodec.date(fromHHmm: reminderWindowEnd, fallbackMinutes: 17 * 60)
        }
        set {
            reminderWindowEnd = HabitReminderWindowPickerCodec.hhmm(from: newValue)
        }
    }

    public func ensureReminderWindowDefaults() {
        if reminderWindowStart.nilIfBlank == nil {
            reminderWindowStart = "09:00"
        }
        if reminderWindowEnd.nilIfBlank == nil {
            reminderWindowEnd = "17:00"
        }
        repairReminderWindowEndIfNeeded()
    }

    public func clearReminderWindow() {
        reminderWindowStart = ""
        reminderWindowEnd = ""
    }

    public var hasUnsavedChanges: Bool {
        habitName.trimmingCharacters(in: .whitespacesAndNewlines) != pristineName
            || habitNotes.trimmingCharacters(in: .whitespacesAndNewlines) != pristineNotes
            || selectedKind != pristineKind
            || selectedTrackingMode != pristineTrackingMode
            || selectedCadence != pristineCadence
            || targetConfig != pristineTargetConfig
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
        // Writes are serialized by the DispatchGroup before the notify read; the region
        // isolation checker can't prove this, so opt out explicitly.
        nonisolated(unsafe) var loadedLifeAreas: [LifeArea] = []
        nonisolated(unsafe) var loadedProjects: [ProjectWithStats] = []
        nonisolated(unsafe) var loadedError: Error?

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
        if selectedKind == .negative, targetConfig.effectiveTarget == .binary {
            targetConfig.target = .avoidance
            targetConfig.minimumTarget = nil
        } else if selectedKind == .positive, targetConfig.effectiveTarget == .avoidance {
            targetConfig.target = .binary
            targetConfig.minimumTarget = nil
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

    public func createHabit(completion: @escaping @Sendable (Result<HabitDefinitionRecord, Error>) -> Void) {
        guard isSaving == false else { return }
        let trimmedName = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            let error = validationError(String(localized: "Add a name."))
            errorMessage = error.localizedDescription
            completion(.failure(error))
            return
        }
        guard let lifeAreaID = selectedLifeAreaID else {
            let error = validationError(String(localized: "Choose an area."))
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
        var reviewedTargetConfig = targetConfig
        reviewedTargetConfig.notes = habitNotes.nilIfBlank
        let request = CreateHabitRequest(
            title: trimmedName,
            lifeAreaID: lifeAreaID,
            projectID: selectedProjectID,
            kind: selectedKind == .positive ? .positive : .negative,
            trackingMode: selectedTrackingMode == .dailyCheckIn ? .dailyCheckIn : .lapseOnly,
            icon: icon,
            colorHex: HexColor.normalized(selectedColorHex.nilIfBlank),
            targetConfig: reviewedTargetConfig,
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
        targetConfig = HabitTargetConfig(
            notes: template.notes,
            target: template.target ?? (template.kind == .negative ? .avoidance : .binary)
        )
        reminderWindowStart = template.reminderWindowStart ?? ""
        reminderWindowEnd = template.reminderWindowEnd ?? ""
        selectedColorHex = template.colorHex ?? ""
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
        targetConfig = HabitTargetConfig(target: .binary)
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
        pristineTargetConfig = targetConfig
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

    private func repairReminderWindowEndIfNeeded() {
        guard let startMinutes = reminderWindowStart.nilIfBlank?.normalizedHHmm?.minutesSinceMidnight else { return }
        let endMinutes = reminderWindowEnd.nilIfBlank?.normalizedHHmm?.minutesSinceMidnight
        guard endMinutes == nil || (endMinutes ?? 0) <= startMinutes else { return }
        reminderWindowEnd = HabitReminderWindowPickerCodec.hhmm(minutesSinceMidnight: min(startMinutes + 60, (23 * 60) + 59))
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
    if start != nil, normalizedStart == nil {
        return String(localized: "Choose a start time.")
    }
    if end != nil, normalizedEnd == nil {
        return String(localized: "Choose an end time.")
    }
    if let startMinutes = normalizedStart?.minutesSinceMidnight,
       let endMinutes = normalizedEnd?.minutesSinceMidnight,
       endMinutes <= startMinutes {
        return String(localized: "End time must be after start.")
    }
    return nil
}

fileprivate enum HabitReminderWindowPickerCodec {
    static func date(fromHHmm value: String, fallbackMinutes: Int) -> Date {
        let minutes = value.nilIfBlank?.normalizedHHmm?.minutesSinceMidnight ?? fallbackMinutes
        let clampedMinutes = max(0, min(minutes, (23 * 60) + 59))
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: clampedMinutes / 60,
            minute: clampedMinutes % 60,
            second: 0,
            of: calendar.startOfDay(for: Date())
        ) ?? Date()
    }

    static func hhmm(from date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }

    static func hhmm(minutesSinceMidnight minutes: Int) -> String {
        let clampedMinutes = max(0, min(minutes, (23 * 60) + 59))
        return String(format: "%02d:%02d", clampedMinutes / 60, clampedMinutes % 60)
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
    public var targetConfig: HabitTargetConfig
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
        targetConfig = row.targetConfig ?? HabitTargetConfig(
            notes: row.notes,
            target: row.kind == .negative ? .avoidance : .binary
        )
        lifeAreaID = row.lifeAreaID
        projectID = row.projectID
        reminderWindowStart = row.reminderWindowStart ?? ""
        reminderWindowEnd = row.reminderWindowEnd ?? ""
        iconSearchQuery = ""
        selectedIconSymbolName = row.icon?.symbolName
        colorHex = row.colorHex ?? ""
    }

    public var hasReminderWindow: Bool {
        reminderWindowStart.nilIfBlank != nil || reminderWindowEnd.nilIfBlank != nil
    }

    public var reminderWindowStartPickerDate: Date {
        get {
            HabitReminderWindowPickerCodec.date(fromHHmm: reminderWindowStart, fallbackMinutes: 9 * 60)
        }
        set {
            reminderWindowStart = HabitReminderWindowPickerCodec.hhmm(from: newValue)
            repairReminderWindowEndIfNeeded()
        }
    }

    public var reminderWindowEndPickerDate: Date {
        get {
            HabitReminderWindowPickerCodec.date(fromHHmm: reminderWindowEnd, fallbackMinutes: 17 * 60)
        }
        set {
            reminderWindowEnd = HabitReminderWindowPickerCodec.hhmm(from: newValue)
        }
    }

    public mutating func ensureReminderWindowDefaults() {
        if reminderWindowStart.nilIfBlank == nil {
            reminderWindowStart = "09:00"
        }
        if reminderWindowEnd.nilIfBlank == nil {
            reminderWindowEnd = "17:00"
        }
        repairReminderWindowEndIfNeeded()
    }

    public mutating func clearReminderWindow() {
        reminderWindowStart = ""
        reminderWindowEnd = ""
    }

    private mutating func repairReminderWindowEndIfNeeded() {
        guard let startMinutes = reminderWindowStart.nilIfBlank?.normalizedHHmm?.minutesSinceMidnight else { return }
        let endMinutes = reminderWindowEnd.nilIfBlank?.normalizedHHmm?.minutesSinceMidnight
        guard endMinutes == nil || (endMinutes ?? 0) <= startMinutes else { return }
        reminderWindowEnd = HabitReminderWindowPickerCodec.hhmm(minutesSinceMidnight: min(startMinutes + 60, (23 * 60) + 59))
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
    public let summaryMetrics: HabitDetailCalendarSummaryMetrics
}

public struct HabitDetailCalendarSummaryMetrics: Equatable {
    public let currentStreak: Int
    public let bestStreak: Int
    public let totalCount: Int
    public let scheduledElapsedCount: Int
    public let completionRate: Double

    public var currentStreakDisplay: String {
        "\(currentStreak)"
    }

    public var bestStreakDisplay: String {
        "\(bestStreak)"
    }

    public var totalCountDisplay: String {
        "\(totalCount)"
    }

    public var completionRateDisplay: String {
        guard scheduledElapsedCount > 0 else { return "0%" }
        return "\(Int((completionRate * 100).rounded()))%"
    }
}

enum HabitDetailDayMutationRequest: Equatable {
    case resolve(HabitOccurrenceAction)
    case reset
}

public enum HabitDetailMutationFeedbackHaptic: Equatable, Sendable {
    case selection
    case success
    case warning
}

public struct HabitDetailMutationFeedback: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let message: String
    public let haptic: HabitDetailMutationFeedbackHaptic

    public init(
        id: UUID = UUID(),
        message: String,
        haptic: HabitDetailMutationFeedbackHaptic
    ) {
        self.id = id
        self.message = message
        self.haptic = haptic
    }
}

@MainActor
public final class HabitDetailViewModel: ObservableObject {
    private enum TestHooks {
        private static let editorSupportDelayPrefix = "-LIFEBOARD_TEST_HABIT_DETAIL_EDITOR_SUPPORT_DELAY_MS:"

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

    struct IconSearchCacheKey: Equatable {
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
    @Published public private(set) var mutationFeedback: HabitDetailMutationFeedback?
    @Published public var autosaveState: TaskDetailAutosaveState = .idle
    @Published public var isEditing = false
    @Published public var draft: HabitEditorDraft

    private let getHabitLibraryUseCase: GetHabitLibraryUseCase
    private let getHabitHistoryUseCase: GetHabitHistoryUseCase
    private let updateHabitUseCase: UpdateHabitUseCase
    private let pauseHabitUseCase: PauseHabitUseCase
    private let archiveHabitUseCase: ArchiveHabitUseCase
    private let setHabitArchivedUseCase: SetHabitArchivedUseCase?
    private let resolveHabitOccurrenceUseCase: ResolveHabitOccurrenceUseCase
    private let resetHabitOccurrenceUseCase: ResetHabitOccurrenceUseCase
    private let manageLifeAreasUseCase: ManageLifeAreasUseCase
    private let manageProjectsUseCase: ManageProjectsUseCase
    let iconCatalog: HabitIconCatalog
    private var hasLoadedOnce = false
    private var hasLoadedEditorSupport = false
    var iconOptionsCache: (key: IconSearchCacheKey, options: [HabitIconOption])?
    private var pendingLoadIfNeededCompletions: [@MainActor @Sendable () -> Void] = []
    private var pendingEditorSupportCompletions: [(Bool) -> Void] = []
    private var autosaveWorkItem: DispatchWorkItem?
    private var autosaveGeneration = 0
    private var draftRevision = 0
    private var savedDraftRevision = 0
    private var savingDraftRevision: Int?
    private var autosaveRequestedAfterCurrentOperation = false
    private var pendingAutosaveFlushCompletions: [(Bool) -> Void] = []
    private let textAutosaveDebounceSeconds: TimeInterval = 0.6

    public init(
        row: HabitLibraryRow,
        getHabitLibraryUseCase: GetHabitLibraryUseCase,
        getHabitHistoryUseCase: GetHabitHistoryUseCase,
        updateHabitUseCase: UpdateHabitUseCase,
        pauseHabitUseCase: PauseHabitUseCase,
        archiveHabitUseCase: ArchiveHabitUseCase,
        setHabitArchivedUseCase: SetHabitArchivedUseCase? = nil,
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
        self.setHabitArchivedUseCase = setHabitArchivedUseCase
        self.resolveHabitOccurrenceUseCase = resolveHabitOccurrenceUseCase
        self.resetHabitOccurrenceUseCase = resetHabitOccurrenceUseCase
        self.manageLifeAreasUseCase = manageLifeAreasUseCase
        self.manageProjectsUseCase = manageProjectsUseCase
        self.iconCatalog = iconCatalog
        PerformanceTrace.event("HabitDetailViewModelInit")
    }

    public var editorReminderWindowValidationError: String? {
        habitReminderWindowValidationError(
            start: draft.reminderWindowStart.nilIfBlank,
            end: draft.reminderWindowEnd.nilIfBlank
        )
    }

    public func loadIfNeeded(completion: (@MainActor @Sendable () -> Void)? = nil) {
        if let completion {
            pendingLoadIfNeededCompletions.append(completion)
        }
        guard hasLoadedOnce == false else {
            if isLoading == false && isCalendarLoading == false {
                completeLoadIfNeededCompletions()
            }
            return
        }
        hasLoadedOnce = true
        isLoading = true
        isCalendarLoading = true
        PerformanceTrace.event("HabitDetailSheetLoadRequested")

        DispatchQueue.main.async {
            self.isCalendarMounted = true
            PerformanceTrace.event("HabitDetailCalendarMounted")

            DispatchQueue.main.async {
                self.refreshReadOnlyData {
                    self.completeLoadIfNeededCompletions()
                }
            }
        }
    }

    public func refresh() {
        refreshReadOnlyData()
    }

    public func refreshReadOnlyData(completion: (@MainActor @Sendable () -> Void)? = nil) {
        isLoading = true
        isCalendarLoading = true
        errorMessage = nil
        PerformanceTrace.event("HabitDetailReadOnlyRefreshStarted")

        let group = DispatchGroup()
        // Serialized by the DispatchGroup before the notify read; opt out of region isolation.
        nonisolated(unsafe) var latestRow: HabitLibraryRow?
        nonisolated(unsafe) var latestHistory: [HabitDayMark] = historyMarks
        nonisolated(unsafe) var firstError: Error?

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
                        notes: latestRow.notes,
                        targetConfig: latestRow.targetConfig
                    )
                }
                if self.draftRevision == self.savedDraftRevision {
                    self.draft = HabitEditorDraft(row: self.row)
                }
            }
            self.historyMarks = latestHistory
            self.updateCalendarViewState()
            if self.draft.selectedIconSymbolName == nil {
                self.draft.selectedIconSymbolName = self.availableIconOptions.first?.symbolName
            }
            self.errorMessage = firstError?.localizedDescription
            PerformanceTrace.event("HabitDetailHydrationCompleted")
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

    public func prepareAlwaysEditableSupport(completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard hasLoadedOnce, isLoading == false, isCalendarLoading == false else {
            loadIfNeeded { [weak self] in
                self?.prepareAlwaysEditableSupport(completion: completion)
            }
            return
        }

        loadEditorSupportDataIfNeeded { [weak self] didLoad in
            guard let self else {
                completion?()
                return
            }
            if didLoad {
                self.isEditing = true
                self.errorMessage = nil
            }
            completion?()
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
        if draft.kind == .negative, draft.targetConfig.effectiveTarget == .binary {
            draft.targetConfig.target = .avoidance
            draft.targetConfig.minimumTarget = nil
        } else if draft.kind == .positive, draft.targetConfig.effectiveTarget == .avoidance {
            draft.targetConfig.target = .binary
            draft.targetConfig.minimumTarget = nil
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

    public func saveChanges(completion: (@MainActor @Sendable () -> Void)? = nil) {
        normalizeDraftSelection()
        guard canSave else {
            errorMessage = editorReminderWindowValidationError ?? String(localized: "Add a name and area.")
            return
        }

        isSaving = true
        errorMessage = nil
        let request = makeUpdateRequest()

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

    /// Flushes any dirty draft without allowing a running save to be duplicated.
    public func flushPendingAutosave(completion: ((Bool) -> Void)? = nil) {
        autosaveWorkItem?.cancel()
        autosaveWorkItem = nil
        autosaveGeneration += 1

        if let completion {
            pendingAutosaveFlushCompletions.append(completion)
        }

        guard draftRevision > savedDraftRevision else {
            completeAutosaveFlushes(success: true)
            return
        }

        guard isSaving == false else {
            if draftRevision > (savingDraftRevision ?? savedDraftRevision) {
                autosaveRequestedAfterCurrentOperation = true
            }
            return
        }

        performAutosave()
    }

    public func scheduleAutosave(debounced: Bool) {
        autosaveWorkItem?.cancel()
        autosaveWorkItem = nil
        autosaveGeneration += 1
        draftRevision += 1

        if isSaving {
            autosaveRequestedAfterCurrentOperation = true
            return
        }

        let generation = autosaveGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, generation == self.autosaveGeneration else { return }
            self.autosaveWorkItem = nil
            self.performAutosave()
        }
        autosaveWorkItem = workItem

        if debounced {
            autosaveState = .debouncing
            DispatchQueue.main.asyncAfter(deadline: .now() + textAutosaveDebounceSeconds, execute: workItem)
        } else {
            DispatchQueue.main.async(execute: workItem)
        }
    }

    public func retryAutosave() {
        guard draftRevision > savedDraftRevision, isSaving == false else { return }
        performAutosave()
    }

    public func togglePause(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        flushPendingAutosave { [weak self] didFlush in
            guard let self, didFlush else {
                completion?(false)
                return
            }
            self.performTogglePause(completion: completion)
        }
    }

    private func performTogglePause(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        guard isSaving == false else {
            completion?(false)
            return
        }
        isSaving = true
        errorMessage = nil
        pauseHabitUseCase.execute(id: row.habitID, isPaused: !row.isPaused) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success:
                    self.refreshReadOnlyData {
                        self.finishExplicitMutation()
                        completion?(true)
                    }
                case .failure(let error):
                    self.isSaving = false
                    self.errorMessage = error.localizedDescription
                    completion?(false)
                }
            }
        }
    }

    public func archive(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        flushPendingAutosave { [weak self] didFlush in
            guard let self, didFlush else {
                completion?(false)
                return
            }
            self.performArchive(completion: completion)
        }
    }

    private func performArchive(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        guard isSaving == false else {
            completion?(false)
            return
        }
        isSaving = true
        errorMessage = nil
        archiveHabitUseCase.execute(id: row.habitID) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success:
                    self.refreshReadOnlyData {
                        self.finishExplicitMutation()
                        completion?(true)
                    }
                case .failure(let error):
                    self.isSaving = false
                    self.errorMessage = error.localizedDescription
                    completion?(false)
                }
            }
        }
    }

    /// Whether an archived habit can be brought back from this screen.
    public var canRestoreFromArchive: Bool {
        row.isArchived && setHabitArchivedUseCase != nil
    }

    /// Brings an archived habit back as active; `SetHabitArchivedUseCase`
    /// clears the pause that archiving applied.
    public func restoreFromArchive(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        guard let setHabitArchivedUseCase, isSaving == false else {
            completion?(false)
            return
        }
        isSaving = true
        errorMessage = nil
        setHabitArchivedUseCase.execute(id: row.habitID, isArchived: false) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success:
                    self.refreshReadOnlyData {
                        self.finishExplicitMutation()
                        completion?(true)
                    }
                case .failure(let error):
                    self.isSaving = false
                    self.errorMessage = error.localizedDescription
                    completion?(false)
                }
            }
        }
    }

    public func logLapse(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        guard row.trackingMode == .lapseOnly else {
            completion?(false)
            return
        }
        flushPendingAutosave { [weak self] didFlush in
            guard let self, didFlush else {
                completion?(false)
                return
            }
            self.performLogLapse(completion: completion)
        }
    }

    private func performLogLapse(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        guard isSaving == false else {
            completion?(false)
            return
        }
        isSaving = true
        errorMessage = nil
        resolveHabitOccurrenceUseCase.execute(
            habitID: row.habitID,
            occurrenceID: nil,
            action: .lapsed,
            on: Date(),
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success:
                    self.refreshReadOnlyData {
                        self.finishExplicitMutation()
                        completion?(true)
                    }
                case .failure(let error):
                    self.isSaving = false
                    self.errorMessage = error.localizedDescription
                    completion?(false)
                }
            }
        }
    }

    /// Undo for `logLapse`: today goes back to having no record.
    public func undoTodayLapse(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        guard isSaving == false else {
            completion?(false)
            return
        }
        isSaving = true
        errorMessage = nil
        resetHabitOccurrenceUseCase.execute(
            habitID: row.habitID,
            occurrenceID: nil,
            on: Date()
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success:
                    self.refreshReadOnlyData {
                        self.finishExplicitMutation()
                        completion?(true)
                    }
                case .failure(let error):
                    self.isSaving = false
                    self.errorMessage = error.localizedDescription
                    completion?(false)
                }
            }
        }
    }

    public func mutateDay(
        _ cell: HabitDetailDayCell,
        completion: (@MainActor @Sendable (Bool) -> Void)? = nil
    ) {
        guard cell.isInteractive,
              let request = HabitDetailCalendarBuilder.nextMutation(for: row, state: cell.state) else {
            completion?(false)
            return
        }

        flushPendingAutosave { [weak self] didFlush in
            guard let self, didFlush else {
                completion?(false)
                return
            }
            self.performDayMutation(cell: cell, request: request, completion: completion)
        }
    }

    private func performDayMutation(
        cell: HabitDetailDayCell,
        request: HabitDetailDayMutationRequest,
        completion: (@MainActor @Sendable (Bool) -> Void)?
    ) {
        guard isSaving == false else {
            completion?(false)
            return
        }

        let mutationFeedback = HabitDetailCalendarBuilder.mutationFeedback(
            for: request,
            row: row,
            date: cell.date
        )
        // A day that had no record and was just resolved can be put back as it
        // was. `DESIGN.md` asks for Undo wherever reversal is supported, and
        // marking the wrong day complete is the mistake this screen invites.
        if case .resolve = request, cell.state == .empty || cell.state == .notScheduled {
            undoableDayCell = cell
        } else {
            undoableDayCell = nil
        }
        isSaving = true
        errorMessage = nil

        let handleResult: @Sendable (Result<Void, Error>) -> Void = { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success:
                    self.mutationFeedback = mutationFeedback
                    self.refreshReadOnlyData {
                        self.finishExplicitMutation()
                        completion?(true)
                    }
                case .failure(let error):
                    self.isSaving = false
                    self.errorMessage = error.localizedDescription
                    completion?(false)
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

    public func clearMutationFeedback() {
        mutationFeedback = nil
    }

    /// The day a resolve just filled in, if putting it back is possible.
    @Published public private(set) var undoableDayCell: HabitDetailDayCell?

    /// Clears the day the last mutation recorded, restoring "no record".
    public func undoLastDayMutation(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        guard let cell = undoableDayCell else {
            completion?(false)
            return
        }
        undoableDayCell = nil
        performDayMutation(cell: cell, request: .reset, completion: completion)
    }

    private func updateCalendarViewState(referenceDate: Date = Date()) {
        calendarViewState = HabitDetailCalendarBuilder.buildViewState(
            row: row,
            marks: historyMarks,
            referenceDate: referenceDate
        )
    }

    private func completeLoadIfNeededCompletions() {
        let completions = pendingLoadIfNeededCompletions
        pendingLoadIfNeededCompletions.removeAll()
        completions.forEach { $0() }
    }

    private func performAutosave() {
        guard isSaving == false else {
            autosaveRequestedAfterCurrentOperation = true
            return
        }

        normalizeDraftSelection()

        guard draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            autosaveState = .failed(String(localized: "Add a name."))
            completeAutosaveFlushes(success: false)
            return
        }

        guard draft.lifeAreaID != nil else {
            autosaveState = .failed(String(localized: "Choose an area."))
            completeAutosaveFlushes(success: false)
            return
        }

        guard editorReminderWindowValidationError == nil else {
            autosaveState = .failed(String(localized: "Check the reminder time."))
            completeAutosaveFlushes(success: false)
            return
        }

        autosaveState = .saving
        isSaving = true
        errorMessage = nil
        autosaveRequestedAfterCurrentOperation = false
        let savingRevision = draftRevision
        savingDraftRevision = savingRevision
        let request = makeUpdateRequest()

        updateHabitUseCase.execute(request: request) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success:
                    self.savedDraftRevision = max(self.savedDraftRevision, savingRevision)
                    self.autosaveState = .saved
                    self.refreshReadOnlyData {
                        self.savingDraftRevision = nil
                        self.isSaving = false
                        if self.draftRevision > self.savedDraftRevision || self.autosaveRequestedAfterCurrentOperation {
                            self.performAutosave()
                        } else {
                            self.completeAutosaveFlushes(success: true)
                        }
                    }
                case .failure(let error):
                    self.savingDraftRevision = nil
                    self.isSaving = false
                    self.autosaveState = .failed(error.localizedDescription)
                    self.completeAutosaveFlushes(success: false)
                }
            }
        }
    }

    private func completeAutosaveFlushes(success: Bool) {
        let completions = pendingAutosaveFlushCompletions
        pendingAutosaveFlushCompletions.removeAll()
        completions.forEach { $0(success) }
    }

    private func finishExplicitMutation() {
        isSaving = false
        guard draftRevision > savedDraftRevision || autosaveRequestedAfterCurrentOperation else { return }
        performAutosave()
    }
}

extension HabitDetailViewModel {
    private func makeUpdateRequest() -> UpdateHabitRequest {
        var reviewedTargetConfig = draft.targetConfig
        reviewedTargetConfig.notes = draft.notes.nilIfBlank
        return UpdateHabitRequest(
            id: row.habitID,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            lifeAreaID: draft.lifeAreaID,
            projectID: draft.projectID,
            clearProject: draft.projectID == nil,
            kind: draft.kind == .positive ? .positive : .negative,
            trackingMode: draft.trackingMode == .dailyCheckIn ? .dailyCheckIn : .lapseOnly,
            icon: selectedIconOption.map { HabitIconMetadata(symbolName: $0.symbolName, categoryKey: $0.categoryKey) },
            colorHex: HexColor.normalized(draft.colorHex.nilIfBlank),
            targetConfig: reviewedTargetConfig,
            metricConfig: HabitMetricConfig(unitLabel: nil, showNotesOnCompletion: draft.notes.nilIfBlank != nil),
            cadence: draft.cadence,
            reminderWindowStart: draft.reminderWindowStart.nilIfBlank?.normalizedHHmm,
            reminderWindowEnd: draft.reminderWindowEnd.nilIfBlank?.normalizedHHmm,
            notes: draft.notes.nilIfBlank
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
        // Serialized by the DispatchGroup before the notify read; opt out of region isolation.
        nonisolated(unsafe) var loadedLifeAreas: [LifeArea] = lifeAreas
        nonisolated(unsafe) var loadedProjects: [ProjectWithStats] = projects
        nonisolated(unsafe) var firstError: Error?

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
