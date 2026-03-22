import Foundation

public extension Notification.Name {
    static let homeHabitMutation = Notification.Name("HomeHabitMutationEvent")
}

public enum HabitRuntimeError: LocalizedError {
    case invalidLifeArea
    case invalidProject
    case habitNotFound
    case scheduleTemplateNotFound
    case occurrenceNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidLifeArea:
            return "The selected life area no longer exists."
        case .invalidProject:
            return "The selected project no longer exists."
        case .habitNotFound:
            return "The habit could not be found."
        case .scheduleTemplateNotFound:
            return "The habit schedule template could not be found."
        case .occurrenceNotFound:
            return "The habit occurrence could not be found."
        }
    }
}

public struct CreateHabitRequest: Codable, Equatable, Hashable {
    public let id: UUID
    public var title: String
    public var lifeAreaID: UUID
    public var projectID: UUID?
    public var kind: HabitKind
    public var trackingMode: HabitTrackingMode
    public var icon: HabitIconMetadata
    public var targetConfig: HabitTargetConfig
    public var metricConfig: HabitMetricConfig
    public var cadence: HabitCadenceDraft
    public var reminderWindowStart: String?
    public var reminderWindowEnd: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        lifeAreaID: UUID,
        projectID: UUID? = nil,
        kind: HabitKind,
        trackingMode: HabitTrackingMode,
        icon: HabitIconMetadata,
        targetConfig: HabitTargetConfig = .init(),
        metricConfig: HabitMetricConfig = .init(),
        cadence: HabitCadenceDraft = .daily(),
        reminderWindowStart: String? = nil,
        reminderWindowEnd: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.lifeAreaID = lifeAreaID
        self.projectID = projectID
        self.kind = kind
        self.trackingMode = trackingMode
        self.icon = icon
        self.targetConfig = targetConfig
        self.metricConfig = metricConfig
        self.cadence = cadence
        self.reminderWindowStart = reminderWindowStart
        self.reminderWindowEnd = reminderWindowEnd
        self.createdAt = createdAt
    }
}

public struct UpdateHabitRequest: Codable, Equatable, Hashable {
    public let id: UUID
    public var title: String?
    public var lifeAreaID: UUID?
    public var projectID: UUID?
    public var clearProject: Bool
    public var kind: HabitKind?
    public var trackingMode: HabitTrackingMode?
    public var icon: HabitIconMetadata?
    public var targetConfig: HabitTargetConfig?
    public var metricConfig: HabitMetricConfig?
    public var cadence: HabitCadenceDraft?
    public var reminderWindowStart: String?
    public var reminderWindowEnd: String?
    public var notes: String?
    public var updatedAt: Date

    public init(
        id: UUID,
        title: String? = nil,
        lifeAreaID: UUID? = nil,
        projectID: UUID? = nil,
        clearProject: Bool = false,
        kind: HabitKind? = nil,
        trackingMode: HabitTrackingMode? = nil,
        icon: HabitIconMetadata? = nil,
        targetConfig: HabitTargetConfig? = nil,
        metricConfig: HabitMetricConfig? = nil,
        cadence: HabitCadenceDraft? = nil,
        reminderWindowStart: String? = nil,
        reminderWindowEnd: String? = nil,
        notes: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.lifeAreaID = lifeAreaID
        self.projectID = projectID
        self.clearProject = clearProject
        self.kind = kind
        self.trackingMode = trackingMode
        self.icon = icon
        self.targetConfig = targetConfig
        self.metricConfig = metricConfig
        self.cadence = cadence
        self.reminderWindowStart = reminderWindowStart
        self.reminderWindowEnd = reminderWindowEnd
        self.notes = notes
        self.updatedAt = updatedAt
    }
}

enum HabitRuntimeSupport {
    static func normalizedTrackingMode(
        kind: HabitKind,
        trackingMode: HabitTrackingMode
    ) -> HabitTrackingMode {
        kind == .positive ? .dailyCheckIn : trackingMode
    }

    static func normalizedReminderWindow(
        start: String?,
        end: String?
    ) -> (start: String?, end: String?) {
        let normalizedStart = normalizeHHmm(start)
        let normalizedEnd = normalizeHHmm(end)
        guard let startMinutes = minutesSinceMidnight(normalizedStart),
              let endMinutes = minutesSinceMidnight(normalizedEnd) else {
            return (normalizedStart, normalizedEnd)
        }
        guard endMinutes >= startMinutes else {
            return (normalizedStart, normalizedStart)
        }
        return (normalizedStart, normalizedEnd)
    }

    static func buildScheduleTemplate(
        templateID: UUID = UUID(),
        habitID: UUID,
        cadence: HabitCadenceDraft,
        windowStart: String?,
        windowEnd: String?,
        anchorAt: Date,
        isActive: Bool
    ) -> ScheduleTemplateDefinition {
        ScheduleTemplateDefinition(
            id: templateID,
            sourceType: .habit,
            sourceID: habitID,
            timezoneID: TimeZone.current.identifier,
            temporalReference: .anchored,
            anchorAt: anchorAt,
            windowStart: windowStart,
            windowEnd: windowEnd,
            isActive: isActive,
            createdAt: anchorAt,
            updatedAt: Date()
        )
    }

    static func buildScheduleRules(
        templateID: UUID,
        cadence: HabitCadenceDraft,
        createdAt: Date
    ) -> [ScheduleRuleDefinition] {
        switch cadence {
        case .daily(let hour, let minute):
            return [
                ScheduleRuleDefinition(
                    id: UUID(),
                    scheduleTemplateID: templateID,
                    ruleType: "daily",
                    interval: 1,
                    byDayMask: nil,
                    byMonthDay: nil,
                    byHour: hour,
                    byMinute: minute,
                    rawRuleData: nil,
                    createdAt: createdAt
                )
            ]
        case .weekly(let daysOfWeek, let hour, let minute):
            return [
                ScheduleRuleDefinition(
                    id: UUID(),
                    scheduleTemplateID: templateID,
                    ruleType: "weekly",
                    interval: 1,
                    byDayMask: weekdayMask(for: daysOfWeek),
                    byMonthDay: nil,
                    byHour: hour,
                    byMinute: minute,
                    rawRuleData: nil,
                    createdAt: createdAt
                )
            ]
        }
    }

    static func weekdayMask(for weekdays: [Int]) -> Int? {
        guard weekdays.isEmpty == false else { return nil }
        return weekdays.reduce(into: 0) { partial, weekday in
            guard (1...7).contains(weekday) else { return }
            partial |= (1 << (weekday - 1))
        }
    }

    static func weekdays(from mask: Int?) -> [Int] {
        guard let mask else { return [] }
        return (1...7).filter { weekday in
            (mask & (1 << (weekday - 1))) != 0
        }
    }

    static func cadence(
        from template: ScheduleTemplateDefinition?,
        rules: [ScheduleRuleDefinition]
    ) -> HabitCadenceDraft {
        let primaryRule = rules.sorted {
            ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
        }.first
        let hour = primaryRule?.byHour
        let minute = primaryRule?.byMinute
        let fallbackMinutes = normalizeHHmm(template?.windowStart).flatMap(minutesSinceMidnight(_:))

        switch primaryRule?.ruleType {
        case "weekly":
            let days = weekdays(from: primaryRule?.byDayMask)
            return .weekly(
                daysOfWeek: days.isEmpty ? [2, 3, 4, 5, 6] : days,
                hour: hour,
                minute: minute
            )
        default:
            return .daily(
                hour: hour ?? fallbackMinutes.map { $0 / 60 },
                minute: minute ?? fallbackMinutes.map { $0 % 60 }
            )
        }
    }

    static func normalizeHHmm(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
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

    static func minutesSinceMidnight(_ value: String?) -> Int? {
        guard let value = normalizeHHmm(value) else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return (hour * 60) + minute
    }

    static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    static func occurrenceDate(_ occurrence: OccurrenceDefinition) -> Date {
        occurrence.dueAt ?? occurrence.scheduledAt
    }

    static func dayMarks(
        from occurrences: [OccurrenceDefinition],
        endingOn date: Date,
        dayCount: Int,
        calendar: Calendar = .current
    ) -> [HabitDayMark] {
        guard dayCount > 0 else { return [] }
        let endDay = calendar.startOfDay(for: date)
        let startDay = calendar.date(byAdding: .day, value: -(dayCount - 1), to: endDay) ?? endDay
        let grouped = Dictionary(grouping: occurrences) { occurrence in
            calendar.startOfDay(for: occurrenceDate(occurrence))
        }

        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { return nil }
            let state: HabitDayState
            if day > endDay {
                state = .future
            } else if let latest = grouped[day]?.sorted(by: { occurrenceDate($0) < occurrenceDate($1) }).last {
                state = dayState(for: latest, day: day, referenceDay: endDay, calendar: calendar)
            } else {
                state = .none
            }
            return HabitDayMark(date: day, state: state)
        }
    }

    static func dayState(
        for occurrence: OccurrenceDefinition,
        day: Date,
        referenceDay: Date,
        calendar: Calendar = .current
    ) -> HabitDayState {
        switch occurrence.state {
        case .completed:
            return .success
        case .failed, .missed:
            return .failure
        case .skipped:
            return .skipped
        case .pending:
            return day < referenceDay ? .failure : .none
        }
    }

    static func masks(from marks: [HabitDayMark]) -> (UInt16, UInt16) {
        var success: UInt16 = 0
        var failure: UInt16 = 0
        for (index, mark) in marks.prefix(14).enumerated() {
            let bit = UInt16(1 << index)
            switch mark.state {
            case .success:
                success |= bit
            case .failure:
                failure |= bit
            case .skipped, .none, .future:
                break
            }
        }
        return (success, failure)
    }

    static func riskState(
        for marks: [HabitDayMark],
        dueAt: Date?,
        occurrenceState: OccurrenceState,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> HabitRiskState {
        if occurrenceState == .failed || occurrenceState == .missed {
            return .broken
        }
        if occurrenceState == .pending,
           let dueAt,
           dueAt < calendar.startOfDay(for: referenceDate) {
            return .atRisk
        }
        let recentFailures = marks.suffix(3).filter { $0.state == .failure }.count
        if recentFailures > 0 {
            return .atRisk
        }
        return .stable
    }

    static func streaks(
        from occurrences: [OccurrenceDefinition],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> (current: Int, best: Int) {
        let latestByDay = Dictionary(grouping: occurrences.filter {
            occurrenceDate($0) <= referenceDate
        }) { occurrence in
            calendar.startOfDay(for: occurrenceDate(occurrence))
        }
        .compactMapValues { entries in
            entries.sorted(by: { occurrenceDate($0) < occurrenceDate($1) }).last
        }
        let ordered = latestByDay.values.sorted(by: { occurrenceDate($0) < occurrenceDate($1) })

        var best = 0
        var run = 0
        for occurrence in ordered {
            let isSuccess = occurrence.state == .completed
            if isSuccess {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }

        var current = 0
        for occurrence in ordered.reversed() {
            if occurrence.state == .pending,
               calendar.isDate(occurrenceDate(occurrence), inSameDayAs: referenceDate) {
                continue
            }
            if occurrence.state == .completed {
                current += 1
            } else {
                break
            }
        }
        return (current, best)
    }

    static func homeState(
        for summary: HabitOccurrenceSummary,
        on date: Date,
        calendar: Calendar = .current
    ) -> HomeHabitRowState {
        let startOfDay = calendar.startOfDay(for: date)
        switch summary.state {
        case .completed:
            return .completedToday
        case .failed:
            return .lapsedToday
        case .pending:
            if let dueAt = summary.dueAt, dueAt < startOfDay {
                return .overdue
            }
            return .due
        case .missed:
            return .overdue
        case .skipped:
            return .skippedToday
        }
    }
}

public final class CreateHabitUseCase {
    private let habitRepository: HabitRepositoryProtocol
    private let lifeAreaRepository: LifeAreaRepositoryProtocol
    private let projectRepository: ProjectRepositoryProtocol
    private let scheduleRepository: ScheduleRepositoryProtocol
    private let maintainHabitRuntimeUseCase: MaintainHabitRuntimeUseCase

    public init(
        habitRepository: HabitRepositoryProtocol,
        lifeAreaRepository: LifeAreaRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        scheduleRepository: ScheduleRepositoryProtocol,
        maintainHabitRuntimeUseCase: MaintainHabitRuntimeUseCase
    ) {
        self.habitRepository = habitRepository
        self.lifeAreaRepository = lifeAreaRepository
        self.projectRepository = projectRepository
        self.scheduleRepository = scheduleRepository
        self.maintainHabitRuntimeUseCase = maintainHabitRuntimeUseCase
    }

    public func execute(
        request: CreateHabitRequest,
        completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void
    ) {
        validate(lifeAreaID: request.lifeAreaID, projectID: request.projectID) { validationResult in
            switch validationResult {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                let trackingMode = HabitRuntimeSupport.normalizedTrackingMode(
                    kind: request.kind,
                    trackingMode: request.trackingMode
                )
                let reminderWindow = HabitRuntimeSupport.normalizedReminderWindow(
                    start: request.reminderWindowStart,
                    end: request.reminderWindowEnd
                )
                var habit = HabitDefinitionRecord(
                    id: request.id,
                    lifeAreaID: request.lifeAreaID,
                    projectID: request.projectID,
                    title: request.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    habitType: Self.habitTypeString(kind: request.kind, trackingMode: trackingMode),
                    kindRaw: request.kind.rawValue,
                    trackingModeRaw: trackingMode.rawValue,
                    iconSymbolName: request.icon.symbolName,
                    iconCategoryKey: request.icon.categoryKey,
                    targetConfigData: HabitRuntimeSupport.encode(request.targetConfig),
                    metricConfigData: HabitRuntimeSupport.encode(request.metricConfig),
                    notes: request.targetConfig.notes,
                    isPaused: false,
                    archivedAt: nil,
                    lastGeneratedDate: nil,
                    streakCurrent: 0,
                    streakBest: 0,
                    successMask14Raw: 0,
                    failureMask14Raw: 0,
                    lastHistoryRollDate: Calendar.current.startOfDay(for: request.createdAt),
                    createdAt: request.createdAt,
                    updatedAt: request.createdAt
                )
                habit.targetConfig = request.targetConfig
                habit.metricConfig = request.metricConfig

                let template = HabitRuntimeSupport.buildScheduleTemplate(
                    habitID: habit.id,
                    cadence: request.cadence,
                    windowStart: reminderWindow.start,
                    windowEnd: reminderWindow.end,
                    anchorAt: request.createdAt,
                    isActive: true
                )
                let rules = HabitRuntimeSupport.buildScheduleRules(
                    templateID: template.id,
                    cadence: request.cadence,
                    createdAt: request.createdAt
                )

                self.habitRepository.create(habit) { createResult in
                    switch createResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let createdHabit):
                        self.scheduleRepository.saveTemplate(template) { templateResult in
                            switch templateResult {
                            case .failure(let error):
                                self.habitRepository.delete(id: createdHabit.id) { _ in
                                    completion(.failure(error))
                                }
                            case .success:
                                self.scheduleRepository.replaceRules(templateID: template.id, rules: rules) { rulesResult in
                                    switch rulesResult {
                                    case .failure(let error):
                                        self.habitRepository.delete(id: createdHabit.id) { _ in
                                            self.scheduleRepository.replaceRules(templateID: template.id, rules: []) { _ in
                                                completion(.failure(error))
                                            }
                                        }
                                    case .success:
                                        self.maintainHabitRuntimeUseCase.execute(anchorDate: request.createdAt) { syncResult in
                                            switch syncResult {
                                            case .failure(let error):
                                                self.habitRepository.delete(id: createdHabit.id) { _ in
                                                    self.scheduleRepository.replaceRules(templateID: template.id, rules: []) { _ in
                                                        completion(.failure(error))
                                                    }
                                                }
                                            case .success:
                                                TaskNotificationDispatcher.postOnMain(
                                                    name: .homeHabitMutation,
                                                    object: createdHabit
                                                )
                                                completion(.success(createdHabit))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func validate(
        lifeAreaID: UUID,
        projectID: UUID?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        lifeAreaRepository.fetchAll { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let areas):
                guard areas.contains(where: { $0.id == lifeAreaID }) else {
                    completion(.failure(HabitRuntimeError.invalidLifeArea))
                    return
                }
                guard let projectID else {
                    completion(.success(()))
                    return
                }
                self.projectRepository.fetchProject(withId: projectID) { projectResult in
                    switch projectResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let project):
                        if project == nil {
                            completion(.failure(HabitRuntimeError.invalidProject))
                        } else {
                            completion(.success(()))
                        }
                    }
                }
            }
        }
    }

    static func habitTypeString(kind: HabitKind, trackingMode: HabitTrackingMode) -> String {
        switch (kind, trackingMode) {
        case (.positive, _):
            return "check_in"
        case (.negative, .dailyCheckIn):
            return "quit"
        case (.negative, .lapseOnly):
            return "quit_lapse_only"
        }
    }
}

public final class UpdateHabitUseCase {
    private let habitRepository: HabitRepositoryProtocol
    private let scheduleRepository: ScheduleRepositoryProtocol
    private let scheduleEngine: SchedulingEngineProtocol
    private let projectRepository: ProjectRepositoryProtocol
    private let lifeAreaRepository: LifeAreaRepositoryProtocol
    private let maintainHabitRuntimeUseCase: MaintainHabitRuntimeUseCase

    public init(
        habitRepository: HabitRepositoryProtocol,
        scheduleRepository: ScheduleRepositoryProtocol,
        scheduleEngine: SchedulingEngineProtocol,
        projectRepository: ProjectRepositoryProtocol,
        lifeAreaRepository: LifeAreaRepositoryProtocol,
        maintainHabitRuntimeUseCase: MaintainHabitRuntimeUseCase
    ) {
        self.habitRepository = habitRepository
        self.scheduleRepository = scheduleRepository
        self.scheduleEngine = scheduleEngine
        self.projectRepository = projectRepository
        self.lifeAreaRepository = lifeAreaRepository
        self.maintainHabitRuntimeUseCase = maintainHabitRuntimeUseCase
    }

    public func execute(
        request: UpdateHabitRequest,
        completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void
    ) {
        habitRepository.fetchAll { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let habits):
                guard let existingHabit = habits.first(where: { $0.id == request.id }) else {
                    completion(.failure(HabitRuntimeError.habitNotFound))
                    return
                }
                var habit = existingHabit

                self.validate(lifeAreaID: request.lifeAreaID ?? habit.lifeAreaID, projectID: request.clearProject ? nil : (request.projectID ?? habit.projectID)) { validationResult in
                    switch validationResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success:
                        if let title = request.title?.trimmingCharacters(in: .whitespacesAndNewlines), title.isEmpty == false {
                            habit.title = title
                        }
                        if let lifeAreaID = request.lifeAreaID {
                            habit.lifeAreaID = lifeAreaID
                        }
                        if request.clearProject {
                            habit.projectID = nil
                        } else if let projectID = request.projectID {
                            habit.projectID = projectID
                        }
                        let resolvedKind = request.kind ?? habit.kind
                        let resolvedTrackingMode = HabitRuntimeSupport.normalizedTrackingMode(
                            kind: resolvedKind,
                            trackingMode: request.trackingMode ?? habit.trackingMode
                        )
                        habit.kind = resolvedKind
                        habit.trackingMode = resolvedTrackingMode
                        if let icon = request.icon {
                            habit.icon = icon
                        }
                        if let targetConfig = request.targetConfig {
                            habit.targetConfig = targetConfig
                            if request.notes == nil {
                                habit.notes = targetConfig.notes
                            }
                        }
                        if let metricConfig = request.metricConfig {
                            habit.metricConfig = metricConfig
                        }
                        if let notes = request.notes {
                            habit.notes = notes
                        }
                        habit.habitType = CreateHabitUseCase.habitTypeString(
                            kind: habit.kind,
                            trackingMode: habit.trackingMode
                        )
                        habit.updatedAt = request.updatedAt

                        self.habitRepository.update(habit) { updateResult in
                            switch updateResult {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success(let updatedHabit):
                                self.updateSchedule(
                                    for: updatedHabit,
                                    cadence: request.cadence,
                                    reminderWindowStart: request.reminderWindowStart,
                                    reminderWindowEnd: request.reminderWindowEnd,
                                    updatedAt: request.updatedAt
                                ) { scheduleResult in
                                    switch scheduleResult {
                                    case .failure(let error):
                                        self.habitRepository.update(existingHabit) { _ in
                                            completion(.failure(error))
                                        }
                                    case .success:
                                        TaskNotificationDispatcher.postOnMain(
                                            name: .homeHabitMutation,
                                            object: updatedHabit
                                        )
                                        completion(.success(updatedHabit))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func validate(
        lifeAreaID: UUID?,
        projectID: UUID?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let lifeAreaID else {
            completion(.failure(HabitRuntimeError.invalidLifeArea))
            return
        }
        lifeAreaRepository.fetchAll { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let areas):
                guard areas.contains(where: { $0.id == lifeAreaID }) else {
                    completion(.failure(HabitRuntimeError.invalidLifeArea))
                    return
                }
                self.validateProject(projectID, completion: completion)
            }
        }
    }

    private func validateProject(
        _ projectID: UUID?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let projectID else {
            completion(.success(()))
            return
        }
        projectRepository.fetchProject(withId: projectID) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let project):
                completion(project == nil ? .failure(HabitRuntimeError.invalidProject) : .success(()))
            }
        }
    }

    private func updateSchedule(
        for habit: HabitDefinitionRecord,
        cadence: HabitCadenceDraft?,
        reminderWindowStart: String?,
        reminderWindowEnd: String?,
        updatedAt: Date,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let reminderWindow = HabitRuntimeSupport.normalizedReminderWindow(
            start: reminderWindowStart,
            end: reminderWindowEnd
        )
        guard cadence != nil || reminderWindow.start != nil || reminderWindow.end != nil else {
            maintainHabitRuntimeUseCase.execute(anchorDate: updatedAt) { result in
                completion(result.map { _ in () })
            }
            return
        }

        scheduleRepository.fetchTemplates { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let templates):
                let existing = templates.first { $0.sourceType == .habit && $0.sourceID == habit.id }
                let templateID = existing?.id ?? UUID()
                let template = HabitRuntimeSupport.buildScheduleTemplate(
                    templateID: templateID,
                    habitID: habit.id,
                    cadence: cadence ?? .daily(),
                    windowStart: reminderWindow.start ?? existing?.windowStart,
                    windowEnd: reminderWindow.end ?? existing?.windowEnd,
                    anchorAt: existing?.anchorAt ?? updatedAt,
                    isActive: habit.isPaused == false && habit.isArchived == false
                )
                self.scheduleRepository.saveTemplate(template) { templateResult in
                    switch templateResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success:
                        let updateRules: (@escaping (Result<Void, Error>) -> Void) -> Void = { finish in
                            guard let cadence else {
                                finish(.success(()))
                                return
                            }
                            let rules = HabitRuntimeSupport.buildScheduleRules(
                                templateID: templateID,
                                cadence: cadence,
                                createdAt: updatedAt
                            )
                            self.scheduleRepository.replaceRules(templateID: template.id, rules: rules) { rulesResult in
                                finish(rulesResult.map { _ in () })
                            }
                        }
                        updateRules { rulesResult in
                            switch rulesResult {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success:
                                self.scheduleEngine.rebuildFutureOccurrences(templateID: template.id, effectiveFrom: updatedAt) { rebuildResult in
                                    switch rebuildResult {
                                    case .failure(let error):
                                        completion(.failure(error))
                                    case .success:
                                        self.maintainHabitRuntimeUseCase.execute(anchorDate: updatedAt) { syncResult in
                                            completion(syncResult.map { _ in () })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

public final class PauseHabitUseCase {
    private let habitRepository: HabitRepositoryProtocol
    private let scheduleRepository: ScheduleRepositoryProtocol
    private let maintainHabitRuntimeUseCase: MaintainHabitRuntimeUseCase

    public init(
        habitRepository: HabitRepositoryProtocol,
        scheduleRepository: ScheduleRepositoryProtocol,
        maintainHabitRuntimeUseCase: MaintainHabitRuntimeUseCase
    ) {
        self.habitRepository = habitRepository
        self.scheduleRepository = scheduleRepository
        self.maintainHabitRuntimeUseCase = maintainHabitRuntimeUseCase
    }

    public func execute(
        id: UUID,
        isPaused: Bool,
        completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void
    ) {
        habitRepository.fetchAll { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let habits):
                guard let existingHabit = habits.first(where: { $0.id == id }) else {
                    completion(.failure(HabitRuntimeError.habitNotFound))
                    return
                }
                var habit = existingHabit
                habit.isPaused = isPaused
                habit.updatedAt = Date()
                self.habitRepository.update(habit) { updateResult in
                    switch updateResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let updatedHabit):
                        self.syncTemplateActiveState(for: updatedHabit) { syncResult in
                            switch syncResult {
                            case .failure(let error):
                                self.habitRepository.update(existingHabit) { _ in
                                    completion(.failure(error))
                                }
                            case .success:
                                self.maintainHabitRuntimeUseCase.execute(anchorDate: Date()) { maintainResult in
                                    switch maintainResult {
                                    case .failure(let error):
                                        self.syncTemplateActiveState(for: existingHabit) { _ in
                                            self.habitRepository.update(existingHabit) { _ in
                                                completion(.failure(error))
                                            }
                                        }
                                    case .success:
                                        TaskNotificationDispatcher.postOnMain(name: .homeHabitMutation, object: updatedHabit)
                                        completion(.success(updatedHabit))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func syncTemplateActiveState(
        for habit: HabitDefinitionRecord,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        scheduleRepository.fetchTemplates { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let templates):
                guard var template = templates.first(where: { $0.sourceType == .habit && $0.sourceID == habit.id }) else {
                    completion(.success(()))
                    return
                }
                template.isActive = habit.isPaused == false && habit.isArchived == false
                template.updatedAt = Date()
                self.scheduleRepository.saveTemplate(template) { saveResult in
                    completion(saveResult.map { _ in () })
                }
            }
        }
    }
}

public final class ArchiveHabitUseCase {
    private let habitRepository: HabitRepositoryProtocol
    private let pauseHabitUseCase: PauseHabitUseCase
    private let maintainHabitRuntimeUseCase: MaintainHabitRuntimeUseCase

    public init(
        habitRepository: HabitRepositoryProtocol,
        pauseHabitUseCase: PauseHabitUseCase,
        maintainHabitRuntimeUseCase: MaintainHabitRuntimeUseCase
    ) {
        self.habitRepository = habitRepository
        self.pauseHabitUseCase = pauseHabitUseCase
        self.maintainHabitRuntimeUseCase = maintainHabitRuntimeUseCase
    }

    public func execute(
        id: UUID,
        completion: @escaping (Result<HabitDefinitionRecord, Error>) -> Void
    ) {
        habitRepository.fetchAll { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let habits):
                guard var habit = habits.first(where: { $0.id == id }) else {
                    completion(.failure(HabitRuntimeError.habitNotFound))
                    return
                }
                habit.archivedAt = Date()
                habit.isPaused = true
                habit.updatedAt = Date()
                self.habitRepository.update(habit) { updateResult in
                    switch updateResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let archivedHabit):
                        self.pauseHabitUseCase.execute(id: id, isPaused: true) { pauseResult in
                            switch pauseResult {
                            case .failure(let error):
                                self.habitRepository.update(habits.first(where: { $0.id == id }) ?? archivedHabit) { _ in
                                    completion(.failure(error))
                                }
                            case .success:
                                completion(.success(archivedHabit))
                            }
                        }
                    }
                }
            }
        }
    }
}

public final class RecomputeHabitStreaksUseCase {
    private let habitRepository: HabitRepositoryProtocol
    private let occurrenceRepository: OccurrenceRepositoryProtocol

    public init(
        habitRepository: HabitRepositoryProtocol,
        occurrenceRepository: OccurrenceRepositoryProtocol
    ) {
        self.habitRepository = habitRepository
        self.occurrenceRepository = occurrenceRepository
    }

    public func execute(
        habitIDs: [UUID]? = nil,
        referenceDate: Date = Date(),
        completion: @escaping (Result<[HabitDefinitionRecord], Error>) -> Void
    ) {
        habitRepository.fetchAll { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let habits):
                let filteredHabits = habits.filter { habit in
                    guard let habitIDs else { return true }
                    return habitIDs.contains(habit.id)
                }
                guard filteredHabits.isEmpty == false else {
                    completion(.success([]))
                    return
                }
                let calendar = Calendar.current
                let earliest = filteredHabits
                    .map { calendar.startOfDay(for: $0.createdAt) }
                    .min() ?? calendar.startOfDay(for: referenceDate)
                let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
                self.occurrenceRepository.fetchInRange(start: earliest, end: end) { occurrencesResult in
                    switch occurrencesResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let occurrences):
                        let habitOccurrences = Dictionary(grouping: occurrences.filter { $0.sourceType == .habit }) { $0.sourceID }
                        let group = DispatchGroup()
                        let lock = NSLock()
                        var firstError: Error?
                        var updatedHabits: [HabitDefinitionRecord] = []

                        for habit in filteredHabits {
                            var updated = habit
                            let history = habitOccurrences[habit.id] ?? []
                            let marks = HabitRuntimeSupport.dayMarks(
                                from: history,
                                endingOn: referenceDate,
                                dayCount: 14,
                                calendar: calendar
                            )
                            let masks = HabitRuntimeSupport.masks(from: marks)
                            let streaks = HabitRuntimeSupport.streaks(from: history, referenceDate: referenceDate, calendar: calendar)
                            updated.streakCurrent = streaks.current
                            updated.streakBest = streaks.best
                            updated.successMask14 = masks.0
                            updated.failureMask14 = masks.1
                            updated.lastHistoryRollDate = calendar.startOfDay(for: referenceDate)

                            group.enter()
                            self.habitRepository.update(updated) { updateResult in
                                lock.lock()
                                defer {
                                    lock.unlock()
                                    group.leave()
                                }
                                switch updateResult {
                                case .failure(let error):
                                    if firstError == nil {
                                        firstError = error
                                    }
                                case .success(let saved):
                                    updatedHabits.append(saved)
                                }
                            }
                        }

                        group.notify(queue: .main) {
                            if let firstError {
                                completion(.failure(firstError))
                            } else {
                                completion(.success(updatedHabits.sorted { $0.createdAt < $1.createdAt }))
                            }
                        }
                    }
                }
            }
        }
    }
}

public final class SyncHabitScheduleUseCase {
    private let habitRepository: HabitRepositoryProtocol
    private let scheduleRepository: ScheduleRepositoryProtocol
    private let scheduleEngine: SchedulingEngineProtocol
    private let occurrenceRepository: OccurrenceRepositoryProtocol
    private let recomputeHabitStreaksUseCase: RecomputeHabitStreaksUseCase

    public init(
        habitRepository: HabitRepositoryProtocol,
        scheduleRepository: ScheduleRepositoryProtocol,
        scheduleEngine: SchedulingEngineProtocol,
        occurrenceRepository: OccurrenceRepositoryProtocol,
        recomputeHabitStreaksUseCase: RecomputeHabitStreaksUseCase
    ) {
        self.habitRepository = habitRepository
        self.scheduleRepository = scheduleRepository
        self.scheduleEngine = scheduleEngine
        self.occurrenceRepository = occurrenceRepository
        self.recomputeHabitStreaksUseCase = recomputeHabitStreaksUseCase
    }

    public func execute(
        anchorDate: Date = Date(),
        completion: @escaping (Result<HabitRuntimeSyncResult, Error>) -> Void
    ) {
        habitRepository.fetchAll { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let habits):
                self.scheduleRepository.fetchTemplates { templateResult in
                    switch templateResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let templates):
                        self.alignTemplateStates(habits: habits, templates: templates) { alignmentResult in
                            switch alignmentResult {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success(let templatesRebuilt):
                                let calendar = Calendar.current
                                let start = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: anchorDate)) ?? anchorDate
                                let end = calendar.date(byAdding: .day, value: 30, to: calendar.startOfDay(for: anchorDate)) ?? anchorDate
                                self.scheduleEngine.generateOccurrences(
                                    windowStart: start,
                                    windowEnd: end,
                                    sourceFilter: .habit
                                ) { generateResult in
                                    switch generateResult {
                                    case .failure(let error):
                                        completion(.failure(error))
                                    case .success(let generated):
                                        self.finalizeLapseOnlySuccesses(habits: habits, anchorDate: anchorDate) { finalizeResult in
                                            switch finalizeResult {
                                            case .failure(let error):
                                                completion(.failure(error))
                                            case .success(let rolloverCount):
                                                self.recomputeHabitStreaksUseCase.execute(referenceDate: anchorDate) { recomputeResult in
                                                    switch recomputeResult {
                                                    case .failure(let error):
                                                        completion(.failure(error))
                                                    case .success(let updatedHabits):
                                                        self.updateGenerationDates(habits: updatedHabits, anchorDate: anchorDate) { updateResult in
                                                            switch updateResult {
                                                            case .failure(let error):
                                                                completion(.failure(error))
                                                            case .success:
                                                                completion(.success(HabitRuntimeSyncResult(
                                                                    templatesRebuilt: templatesRebuilt,
                                                                    occurrencesGenerated: generated.count,
                                                                    rolloverUpdates: rolloverCount
                                                                )))
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func alignTemplateStates(
        habits: [HabitDefinitionRecord],
        templates: [ScheduleTemplateDefinition],
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        let habitTemplates = templates.filter { $0.sourceType == .habit }
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?
        var savedCount = 0

        for habit in habits {
            guard var template = habitTemplates.first(where: { $0.sourceID == habit.id }) else { continue }
            let desiredActive = habit.isPaused == false && habit.isArchived == false
            guard template.isActive != desiredActive else { continue }
            template.isActive = desiredActive
            template.updatedAt = Date()
            group.enter()
            scheduleRepository.saveTemplate(template) { result in
                lock.lock()
                defer {
                    lock.unlock()
                    group.leave()
                }
                switch result {
                case .failure(let error):
                    if firstError == nil {
                        firstError = error
                    }
                case .success:
                    savedCount += 1
                }
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
            } else {
                completion(.success(savedCount))
            }
        }
    }

    private func finalizeLapseOnlySuccesses(
        habits: [HabitDefinitionRecord],
        anchorDate: Date,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        let lapseOnlyHabitIDs = Set(habits.filter {
            $0.trackingMode == .lapseOnly && $0.isPaused == false && $0.isArchived == false
        }.map(\.id))
        guard lapseOnlyHabitIDs.isEmpty == false else {
            completion(.success(0))
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: anchorDate)
        let start = habits
            .filter { lapseOnlyHabitIDs.contains($0.id) }
            .compactMap { habit in
                let anchor = habit.lastHistoryRollDate ?? habit.createdAt
                return calendar.startOfDay(for: anchor)
            }
            .min() ?? today
        guard start < today else {
            completion(.success(0))
            return
        }
        occurrenceRepository.fetchInRange(start: start, end: today) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let occurrences):
                let pending = occurrences.filter {
                    $0.sourceType == .habit &&
                    lapseOnlyHabitIDs.contains($0.sourceID) &&
                    $0.state == .pending &&
                    HabitRuntimeSupport.occurrenceDate($0) < today
                }
                guard pending.isEmpty == false else {
                    completion(.success(0))
                    return
                }

                let group = DispatchGroup()
                let lock = NSLock()
                var firstError: Error?
                var resolvedCount = 0

                for occurrence in pending {
                    group.enter()
                    self.scheduleEngine.resolveOccurrence(
                        id: occurrence.id,
                        resolution: .completed,
                        actor: .system
                    ) { result in
                        lock.lock()
                        defer {
                            lock.unlock()
                            group.leave()
                        }
                        switch result {
                        case .failure(let error):
                            if firstError == nil {
                                firstError = error
                            }
                        case .success:
                            resolvedCount += 1
                        }
                    }
                }

                group.notify(queue: .main) {
                    if let firstError {
                        completion(.failure(firstError))
                    } else {
                        completion(.success(resolvedCount))
                    }
                }
            }
        }
    }

    private func updateGenerationDates(
        habits: [HabitDefinitionRecord],
        anchorDate: Date,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for var habit in habits {
            guard habit.isArchived == false else { continue }
            habit.lastGeneratedDate = anchorDate
            habit.updatedAt = Date()
            group.enter()
            habitRepository.update(habit) { result in
                lock.lock()
                defer {
                    lock.unlock()
                    group.leave()
                }
                if case .failure(let error) = result, firstError == nil {
                    firstError = error
                }
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
            } else {
                completion(.success(()))
            }
        }
    }
}

public final class MaintainHabitRuntimeUseCase {
    private let syncHabitScheduleUseCase: SyncHabitScheduleUseCase

    public init(syncHabitScheduleUseCase: SyncHabitScheduleUseCase) {
        self.syncHabitScheduleUseCase = syncHabitScheduleUseCase
    }

    public func execute(
        anchorDate: Date = Date(),
        completion: @escaping (Result<HabitRuntimeSyncResult, Error>) -> Void
    ) {
        syncHabitScheduleUseCase.execute(anchorDate: anchorDate, completion: completion)
    }
}

public final class ResolveHabitOccurrenceUseCase {
    private let habitRepository: HabitRepositoryProtocol
    private let scheduleRepository: ScheduleRepositoryProtocol
    private let occurrenceRepository: OccurrenceRepositoryProtocol
    private let scheduleEngine: SchedulingEngineProtocol
    private let maintainHabitRuntimeUseCase: MaintainHabitRuntimeUseCase
    private let recomputeHabitStreaksUseCase: RecomputeHabitStreaksUseCase
    private let gamificationEngine: GamificationEngine

    public init(
        habitRepository: HabitRepositoryProtocol,
        scheduleRepository: ScheduleRepositoryProtocol,
        occurrenceRepository: OccurrenceRepositoryProtocol,
        scheduleEngine: SchedulingEngineProtocol,
        maintainHabitRuntimeUseCase: MaintainHabitRuntimeUseCase,
        recomputeHabitStreaksUseCase: RecomputeHabitStreaksUseCase,
        gamificationEngine: GamificationEngine
    ) {
        self.habitRepository = habitRepository
        self.scheduleRepository = scheduleRepository
        self.occurrenceRepository = occurrenceRepository
        self.scheduleEngine = scheduleEngine
        self.maintainHabitRuntimeUseCase = maintainHabitRuntimeUseCase
        self.recomputeHabitStreaksUseCase = recomputeHabitStreaksUseCase
        self.gamificationEngine = gamificationEngine
    }

    public func execute(
        habitID: UUID,
        occurrenceID: UUID? = nil,
        action: HabitOccurrenceAction,
        on date: Date = Date(),
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        habitRepository.fetchAll { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let habits):
                guard let habit = habits.first(where: { $0.id == habitID }) else {
                    completion(.failure(HabitRuntimeError.habitNotFound))
                    return
                }
                self.resolveOccurrenceID(habit: habit, occurrenceID: occurrenceID, date: date, action: action) { occurrenceResult in
                    switch occurrenceResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let resolvedOccurrenceID):
                        let resolution = Self.mapResolution(for: action)
                        self.scheduleEngine.resolveOccurrence(
                            id: resolvedOccurrenceID,
                            resolution: resolution,
                            actor: .user
                        ) { resolveResult in
                            switch resolveResult {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success:
                                self.maintainHabitRuntimeUseCase.execute(anchorDate: date) { maintainResult in
                                    switch maintainResult {
                                    case .failure(let error):
                                        completion(.failure(error))
                                    case .success:
                                        self.recordGamificationEvent(
                                            habit: habit,
                                            occurrenceID: resolvedOccurrenceID,
                                            action: action,
                                            completion: { _ in
                                                TaskNotificationDispatcher.postOnMain(
                                                    name: .homeHabitMutation,
                                                    object: habitID
                                                )
                                                completion(.success(()))
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func resolveOccurrenceID(
        habit: HabitDefinitionRecord,
        occurrenceID: UUID?,
        date: Date,
        action: HabitOccurrenceAction,
        completion: @escaping (Result<UUID, Error>) -> Void
    ) {
        if let occurrenceID {
            completion(.success(occurrenceID))
            return
        }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        occurrenceRepository.fetchInRange(start: startOfDay, end: endOfDay) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let occurrences):
                let matches = occurrences
                    .filter { $0.sourceType == .habit && $0.sourceID == habit.id }
                    .sorted { HabitRuntimeSupport.occurrenceDate($0) < HabitRuntimeSupport.occurrenceDate($1) }
                if let occurrence = matches.last {
                    completion(.success(occurrence.id))
                    return
                }
                guard habit.trackingMode == .lapseOnly && action == .lapsed else {
                    completion(.failure(HabitRuntimeError.occurrenceNotFound))
                    return
                }
                self.materializeOccurrence(for: habit, date: date, completion: completion)
            }
        }
    }

    private func materializeOccurrence(
        for habit: HabitDefinitionRecord,
        date: Date,
        completion: @escaping (Result<UUID, Error>) -> Void
    ) {
        scheduleRepository.fetchTemplates { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let templates):
                guard let template = templates.first(where: { $0.sourceType == .habit && $0.sourceID == habit.id }) else {
                    completion(.failure(HabitRuntimeError.scheduleTemplateNotFound))
                    return
                }
                self.scheduleRepository.fetchRules(templateID: template.id) { rulesResult in
                    switch rulesResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let rules):
                        let occurrence = Self.makeMaterializedOccurrence(
                            habitID: habit.id,
                            template: template,
                            rules: rules,
                            date: date
                        )
                        self.occurrenceRepository.saveOccurrences([occurrence]) { saveResult in
                            switch saveResult {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success:
                                completion(.success(occurrence.id))
                            }
                        }
                    }
                }
            }
        }
    }

    private static func makeMaterializedOccurrence(
        habitID: UUID,
        template: ScheduleTemplateDefinition,
        rules: [ScheduleRuleDefinition],
        date: Date
    ) -> OccurrenceDefinition {
        var calendar = Calendar(identifier: .gregorian)
        let timezone = template.timezoneID.flatMap(TimeZone.init(identifier:)) ?? .current
        calendar.timeZone = timezone

        let day = calendar.startOfDay(for: date)
        let primaryRule = rules.first
        let defaultTime = parseTime(template.windowStart)
            ?? template.anchorAt.flatMap { calendar.dateComponents([.hour, .minute], from: $0) }
            ?? DateComponents(hour: 9, minute: 0)
        let hour = validHour(primaryRule?.byHour) ?? defaultTime.hour ?? 9
        let minute = validMinute(primaryRule?.byMinute) ?? defaultTime.minute ?? 0
        let scheduledAt = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? date
        let dueAt: Date
        if let endTime = parseTime(template.windowEnd) {
            let requestedDueAt = calendar.date(
                bySettingHour: endTime.hour ?? hour,
                minute: endTime.minute ?? minute,
                second: 0,
                of: day
            ) ?? scheduledAt
            dueAt = max(requestedDueAt, scheduledAt)
        } else {
            dueAt = scheduledAt
        }

        return OccurrenceDefinition(
            id: UUID(),
            occurrenceKey: OccurrenceKeyCodec.encode(
                scheduleTemplateID: template.id,
                scheduledAt: scheduledAt,
                sourceID: habitID
            ),
            scheduleTemplateID: template.id,
            sourceType: .habit,
            sourceID: habitID,
            scheduledAt: scheduledAt,
            dueAt: dueAt,
            state: .pending,
            isGenerated: true,
            generationWindow: "ad_hoc_habit_lapse",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private static func parseTime(_ value: String?) -> DateComponents? {
        guard let value else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return nil
        }
        return DateComponents(hour: max(0, min(23, hour)), minute: max(0, min(59, minute)))
    }

    private static func validHour(_ hour: Int?) -> Int? {
        guard let hour, (0...23).contains(hour) else { return nil }
        return hour
    }

    private static func validMinute(_ minute: Int?) -> Int? {
        guard let minute, (0...59).contains(minute) else { return nil }
        return minute
    }

    private static func mapResolution(for action: HabitOccurrenceAction) -> OccurrenceResolutionType {
        switch action {
        case .complete, .abstained:
            return .completed
        case .skip:
            return .skipped
        case .lapsed:
            return .lapsed
        }
    }

    private func recordGamificationEvent(
        habit: HabitDefinitionRecord,
        occurrenceID: UUID,
        action: HabitOccurrenceAction,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let category: XPActionCategory
        switch (habit.kind, action) {
        case (.positive, .complete):
            category = .habitPositiveComplete
        case (.negative, .abstained):
            category = .habitNegativeSuccess
        case (.negative, .lapsed):
            category = .habitNegativeLapse
        default:
            completion(.success(()))
            return
        }

        gamificationEngine.recordEvent(
            context: XPEventContext(
                category: category,
                source: .habit,
                habitID: habit.id,
                occurrenceID: occurrenceID,
                completedAt: Date()
            )
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                completion(.success(()))
            }
        }
    }
}

public final class GetDueHabitsForDateUseCase {
    private let readRepository: HabitRuntimeReadRepositoryProtocol

    public init(readRepository: HabitRuntimeReadRepositoryProtocol) {
        self.readRepository = readRepository
    }

    public func execute(
        date: Date,
        completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        readRepository.fetchAgendaHabits(for: date, completion: completion)
    }
}

public final class GetHabitHistoryUseCase {
    private let readRepository: HabitRuntimeReadRepositoryProtocol

    public init(readRepository: HabitRuntimeReadRepositoryProtocol) {
        self.readRepository = readRepository
    }

    public func execute(
        habitIDs: [UUID],
        endingOn date: Date = Date(),
        dayCount: Int = 14,
        completion: @escaping (Result<[HabitHistoryWindow], Error>) -> Void
    ) {
        readRepository.fetchHistory(habitIDs: habitIDs, endingOn: date, dayCount: dayCount, completion: completion)
    }
}

public final class GetHabitSignalsInRangeUseCase {
    private let readRepository: HabitRuntimeReadRepositoryProtocol

    public init(readRepository: HabitRuntimeReadRepositoryProtocol) {
        self.readRepository = readRepository
    }

    public func execute(
        start: Date,
        end: Date,
        completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        readRepository.fetchSignals(start: start, end: end, completion: completion)
    }
}

public final class GetHabitLibraryUseCase {
    private let readRepository: HabitRuntimeReadRepositoryProtocol

    public init(readRepository: HabitRuntimeReadRepositoryProtocol) {
        self.readRepository = readRepository
    }

    public func execute(
        includeArchived: Bool = true,
        completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void
    ) {
        readRepository.fetchHabitLibrary(includeArchived: includeArchived, completion: completion)
    }
}

public final class BuildHabitHomeProjectionUseCase {
    private let getDueHabitsForDateUseCase: GetDueHabitsForDateUseCase

    public init(
        getDueHabitsForDateUseCase: GetDueHabitsForDateUseCase
    ) {
        self.getDueHabitsForDateUseCase = getDueHabitsForDateUseCase
    }

    public func execute(
        date: Date,
        completion: @escaping (Result<[HomeHabitRow], Error>) -> Void
    ) {
        getDueHabitsForDateUseCase.execute(date: date) { fetchResult in
            switch fetchResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let summaries):
                let rows = summaries.map { summary in
                    HomeHabitRow(
                        habitID: summary.habitID,
                        occurrenceID: summary.occurrenceID,
                        title: summary.title,
                        kind: summary.kind,
                        trackingMode: summary.trackingMode,
                        lifeAreaID: summary.lifeAreaID,
                        lifeAreaName: summary.lifeAreaName,
                        projectID: summary.projectID,
                        projectName: summary.projectName,
                        iconSymbolName: summary.icon?.symbolName ?? "circle.dashed",
                        dueAt: summary.dueAt,
                        state: HabitRuntimeSupport.homeState(for: summary, on: date),
                        currentStreak: summary.currentStreak,
                        bestStreak: summary.bestStreak,
                        last14Days: summary.last14Days,
                        riskState: summary.riskState
                    )
                }
                completion(.success(rows))
            }
        }
    }
}
