import Foundation

public final class CoreSchedulingEngine: SchedulingEngineProtocol {
    private struct TemplateMetadata {
        let rulesByTemplate: [UUID: [ScheduleRuleDefinition]]
        let exceptionsByTemplate: [UUID: [ScheduleExceptionDefinition]]
    }

    private let scheduleRepository: ScheduleRepositoryProtocol
    private let occurrenceRepository: OccurrenceRepositoryProtocol

    /// Initializes a new instance.
    public init(
        scheduleRepository: ScheduleRepositoryProtocol,
        occurrenceRepository: OccurrenceRepositoryProtocol
    ) {
        self.scheduleRepository = scheduleRepository
        self.occurrenceRepository = occurrenceRepository
    }

    /// Executes generateOccurrences.
    public func generateOccurrences(
        windowStart: Date,
        windowEnd: Date,
        sourceFilter: ScheduleSourceType?,
        completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void
    ) {
        scheduleRepository.fetchTemplates { result in
            switch result {
            case .success(let templates):
                let filtered = templates.filter { sourceFilter == nil || $0.sourceType == sourceFilter }
                self.fetchTemplateMetadata(for: filtered) { metadataResult in
                    switch metadataResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let metadata):
                        self.occurrenceRepository.fetchInRange(start: windowStart, end: windowEnd) { existingResult in
                            switch existingResult {
                            case .success(let existing):
                                let existingKeys = Set(existing.map(\.occurrenceKey))
                                let generated = self.buildOccurrences(
                                    templates: filtered,
                                    rulesByTemplate: metadata.rulesByTemplate,
                                    exceptionsByTemplate: metadata.exceptionsByTemplate,
                                    windowStart: windowStart,
                                    windowEnd: windowEnd,
                                    existingKeys: existingKeys
                                )
                                self.occurrenceRepository.saveOccurrences(generated) { saveResult in
                                    switch saveResult {
                                    case .success:
                                        completion(.success(generated))
                                    case .failure(let error):
                                        completion(.failure(error))
                                    }
                                }
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Executes resolveOccurrence.
    public func resolveOccurrence(
        id: UUID,
        resolution: OccurrenceResolutionType,
        actor: OccurrenceActor,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let resolutionRecord = OccurrenceResolutionDefinition(
            id: UUID(),
            occurrenceID: id,
            resolutionType: resolution,
            resolvedAt: Date(),
            actor: actor.rawValue,
            reason: nil,
            createdAt: Date()
        )
        occurrenceRepository.resolve(resolutionRecord, completion: completion)
    }

    /// Executes rebuildFutureOccurrences.
    public func rebuildFutureOccurrences(templateID: UUID, effectiveFrom: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        let rebuildEnd = Calendar.current.date(byAdding: .day, value: 14, to: effectiveFrom) ?? effectiveFrom
        occurrenceRepository.fetchInRange(start: effectiveFrom, end: rebuildEnd) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let existing):
                let unresolvedFutureIDs = existing
                    .filter { $0.scheduleTemplateID == templateID && $0.state == .pending }
                    .map(\.id)

                let regenerate: () -> Void = {
                    self.generateOccurrences(windowStart: effectiveFrom, windowEnd: rebuildEnd, sourceFilter: nil) { generateResult in
                        switch generateResult {
                        case .success:
                            completion(.success(()))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                }

                guard unresolvedFutureIDs.isEmpty == false else {
                    regenerate()
                    return
                }

                self.occurrenceRepository.deleteOccurrences(ids: unresolvedFutureIDs) { deleteResult in
                    switch deleteResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success:
                        regenerate()
                    }
                }
            }
        }
    }

    /// Executes applyScheduleException.
    public func applyScheduleException(templateID: UUID, occurrenceKey: String, action: ScheduleExceptionAction, completion: @escaping (Result<Void, Error>) -> Void) {
        let normalizedOccurrenceKey = OccurrenceKeyCodec.canonicalize(
            occurrenceKey,
            fallbackTemplateID: templateID,
            fallbackSourceID: nil
        ) ?? occurrenceKey
        let exception = ScheduleExceptionDefinition(
            id: UUID(),
            scheduleTemplateID: templateID,
            occurrenceKey: normalizedOccurrenceKey,
            action: action,
            movedToAt: nil,
            payloadData: nil,
            createdAt: Date()
        )
        let effectiveDate: Date
        if let parsed = Self.occurrenceDate(from: normalizedOccurrenceKey) {
            effectiveDate = parsed
        } else {
            effectiveDate = Date()
        }
        scheduleRepository.saveException(exception) { saveResult in
            switch saveResult {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.rebuildFutureOccurrences(templateID: templateID, effectiveFrom: effectiveDate, completion: completion)
            }
        }
    }

    /// Executes fetchTemplateMetadata.
    private func fetchTemplateMetadata(
        for templates: [ScheduleTemplateDefinition],
        completion: @escaping (Result<TemplateMetadata, Error>) -> Void
    ) {
        let group = DispatchGroup()
        var rulesByTemplate: [UUID: [ScheduleRuleDefinition]] = [:]
        var exceptionsByTemplate: [UUID: [ScheduleExceptionDefinition]] = [:]
        var firstError: Error?

        for template in templates {
            group.enter()
            scheduleRepository.fetchRules(templateID: template.id) { result in
                switch result {
                case .success(let rules):
                    rulesByTemplate[template.id] = rules
                case .failure(let error):
                    firstError = firstError ?? error
                }
                group.leave()
            }

            group.enter()
            scheduleRepository.fetchExceptions(templateID: template.id) { result in
                switch result {
                case .success(let exceptions):
                    exceptionsByTemplate[template.id] = exceptions
                case .failure(let error):
                    firstError = firstError ?? error
                }
                group.leave()
            }
        }

        group.notify(queue: .global()) {
            if let firstError {
                completion(.failure(firstError))
            } else {
                completion(.success(TemplateMetadata(
                    rulesByTemplate: rulesByTemplate,
                    exceptionsByTemplate: exceptionsByTemplate
                )))
            }
        }
    }

    /// Executes buildOccurrences.
    private func buildOccurrences(
        templates: [ScheduleTemplateDefinition],
        rulesByTemplate: [UUID: [ScheduleRuleDefinition]],
        exceptionsByTemplate: [UUID: [ScheduleExceptionDefinition]],
        windowStart: Date,
        windowEnd: Date,
        existingKeys: Set<String>
    ) -> [OccurrenceDefinition] {
        var generated: [OccurrenceDefinition] = []
        var generatedKeys = Set<String>()
        let generationWindow = "rolling_\(Self.dayKey(for: windowStart))_\(Self.dayKey(for: windowEnd))"

        for template in templates where template.isActive {
            let timezone = resolveTimeZone(for: template)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timezone
            let rules = rulesByTemplate[template.id].flatMap { $0.isEmpty ? nil : $0 } ?? [Self.defaultRule(templateID: template.id)]
            let exceptionsByKey = latestExceptionsByOccurrenceKey(
                exceptionsByTemplate[template.id] ?? []
            )

            var cursor = calendar.startOfDay(for: windowStart)
            let end = calendar.startOfDay(for: windowEnd)
            while cursor <= end {
                for rule in rules where matches(day: cursor, rule: rule, template: template, calendar: calendar) {
                    guard let scheduledAt = scheduledDate(for: cursor, template: template, rule: rule, calendar: calendar) else {
                        continue
                    }
                    let key = occurrenceKey(
                        templateID: template.id,
                        scheduledAt: scheduledAt,
                        sourceID: template.sourceID
                    )
                    let dueAt = dueDate(for: cursor, template: template, defaultDate: scheduledAt, calendar: calendar)
                    let final = apply(
                        exception: exceptionsByKey[key],
                        template: template,
                        scheduledAt: scheduledAt,
                        sourceID: template.sourceID,
                        dueAt: dueAt,
                        calendar: calendar,
                        windowStart: windowStart,
                        windowEnd: windowEnd
                    )
                    guard let final else {
                        continue
                    }
                    guard existingKeys.contains(final.key) == false, generatedKeys.contains(final.key) == false else {
                        continue
                    }
                    generated.append(
                        OccurrenceDefinition(
                            id: UUID(),
                            occurrenceKey: final.key,
                            scheduleTemplateID: template.id,
                            sourceType: template.sourceType,
                            sourceID: template.sourceID,
                            scheduledAt: final.scheduledAt,
                            dueAt: final.dueAt,
                            state: .pending,
                            isGenerated: true,
                            generationWindow: generationWindow,
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                    )
                    generatedKeys.insert(final.key)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
        }

        return generated
    }

    /// Executes matches.
    private func matches(
        day: Date,
        rule: ScheduleRuleDefinition,
        template: ScheduleTemplateDefinition,
        calendar: Calendar
    ) -> Bool {
        let anchor = calendar.startOfDay(for: template.anchorAt ?? day)
        let current = calendar.startOfDay(for: day)
        let interval = max(rule.interval, 1)
        let ruleType = rule.ruleType.lowercased()

        switch ruleType {
        case "weekly":
            let weeks = calendar.dateComponents([.weekOfYear], from: anchor, to: current).weekOfYear ?? 0
            guard weeks % interval == 0 else { return false }
            let weekday = calendar.component(.weekday, from: current)
            let mask = Self.weekdayMask(for: weekday)
            let byDayMask = rule.byDayMask ?? 0
            if byDayMask == 0 {
                return weekday == calendar.component(.weekday, from: anchor)
            }
            return (byDayMask & mask) != 0
        case "monthly":
            let months = calendar.dateComponents([.month], from: anchor, to: current).month ?? 0
            guard months % interval == 0 else { return false }
            let targetDay = rule.byMonthDay ?? calendar.component(.day, from: anchor)
            return calendar.component(.day, from: current) == targetDay
        case "yearly":
            let years = calendar.dateComponents([.year], from: anchor, to: current).year ?? 0
            guard years % interval == 0 else { return false }
            let anchorComponents = calendar.dateComponents([.month, .day], from: anchor)
            let currentComponents = calendar.dateComponents([.month, .day], from: current)
            return anchorComponents.month == currentComponents.month && anchorComponents.day == currentComponents.day
        default:
            let days = calendar.dateComponents([.day], from: anchor, to: current).day ?? 0
            return days % interval == 0
        }
    }

    /// Executes scheduledDate.
    private func scheduledDate(
        for day: Date,
        template: ScheduleTemplateDefinition,
        rule: ScheduleRuleDefinition,
        calendar: Calendar
    ) -> Date? {
        let defaultTime = parsedTime(from: template.windowStart)
            ?? template.anchorAt.flatMap { calendar.dateComponents([.hour, .minute], from: $0) }
            ?? DateComponents(hour: 9, minute: 0)

        let hour = Self.validHour(rule.byHour) ?? defaultTime.hour ?? 9
        let minute = Self.validMinute(rule.byMinute) ?? defaultTime.minute ?? 0
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    /// Executes dueDate.
    private func dueDate(
        for day: Date,
        template: ScheduleTemplateDefinition,
        defaultDate: Date,
        calendar: Calendar
    ) -> Date {
        guard let endTime = parsedTime(from: template.windowEnd) else {
            return defaultDate
        }
        return calendar.date(bySettingHour: endTime.hour ?? 23, minute: endTime.minute ?? 59, second: 0, of: day) ?? defaultDate
    }

    /// Executes resolveTimeZone.
    private func resolveTimeZone(for template: ScheduleTemplateDefinition) -> TimeZone {
        switch template.temporalReference {
        case .floating:
            return TimeZone.current
        case .anchored:
            return template.timezoneID.flatMap(TimeZone.init(identifier:)) ?? TimeZone.current
        }
    }

    /// Executes occurrenceKey.
    private func occurrenceKey(
        templateID: UUID,
        scheduledAt: Date,
        sourceID: UUID
    ) -> String {
        OccurrenceKeyCodec.encode(
            scheduleTemplateID: templateID,
            scheduledAt: scheduledAt,
            sourceID: sourceID
        )
    }

    /// Executes defaultRule.
    private static func defaultRule(templateID: UUID) -> ScheduleRuleDefinition {
        ScheduleRuleDefinition(
            id: UUID(),
            scheduleTemplateID: templateID,
            ruleType: "daily",
            interval: 1,
            byDayMask: nil,
            byMonthDay: nil,
            byHour: nil,
            byMinute: nil,
            rawRuleData: nil,
            createdAt: Date()
        )
    }

    /// Executes parsedTime.
    private func parsedTime(from value: String?) -> DateComponents? {
        guard let value else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return nil
        }
        return DateComponents(hour: max(0, min(23, hour)), minute: max(0, min(59, minute)))
    }

    /// Executes validHour.
    private static func validHour(_ hour: Int?) -> Int? {
        guard let hour else { return nil }
        return (0...23).contains(hour) ? hour : nil
    }

    /// Executes validMinute.
    private static func validMinute(_ minute: Int?) -> Int? {
        guard let minute else { return nil }
        return (0...59).contains(minute) ? minute : nil
    }

    /// Executes weekdayMask.
    private static func weekdayMask(for weekday: Int) -> Int {
        // Foundation weekday: Sunday=1 ... Saturday=7
        switch weekday {
        case 1: return 1
        case 2: return 2
        case 3: return 4
        case 4: return 8
        case 5: return 16
        case 6: return 32
        case 7: return 64
        default: return 0
        }
    }

    /// Executes occurrenceDate.
    private static func occurrenceDate(from key: String) -> Date? {
        OccurrenceKeyCodec.parse(key)?.scheduledAt
    }

    /// Executes dayKey.
    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Executes latestExceptionsByOccurrenceKey.
    private func latestExceptionsByOccurrenceKey(
        _ exceptions: [ScheduleExceptionDefinition]
    ) -> [String: ScheduleExceptionDefinition] {
        var indexed: [String: ScheduleExceptionDefinition] = [:]
        for exception in exceptions where exception.occurrenceKey.isEmpty == false {
            if let existing = indexed[exception.occurrenceKey] {
                if exception.createdAt >= existing.createdAt {
                    indexed[exception.occurrenceKey] = exception
                }
            } else {
                indexed[exception.occurrenceKey] = exception
            }
        }
        return indexed
    }

    /// Executes apply.
    private func apply(
        exception: ScheduleExceptionDefinition?,
        template: ScheduleTemplateDefinition,
        scheduledAt: Date,
        sourceID: UUID,
        dueAt: Date?,
        calendar: Calendar,
        windowStart: Date,
        windowEnd: Date
    ) -> (key: String, scheduledAt: Date, dueAt: Date?)? {
        guard let exception else {
            return (
                key: occurrenceKey(
                    templateID: template.id,
                    scheduledAt: scheduledAt,
                    sourceID: sourceID
                ),
                scheduledAt: scheduledAt,
                dueAt: dueAt
            )
        }

        switch exception.action {
        case .skip:
            return nil
        case .move:
            guard let movedAt = exception.movedToAt else { return nil }
            guard movedAt >= windowStart, movedAt <= windowEnd else { return nil }
            let movedDueAt = dueDate(
                for: movedAt,
                template: template,
                defaultDate: movedAt,
                calendar: calendar
            )
            let key = occurrenceKey(
                templateID: template.id,
                scheduledAt: movedAt,
                sourceID: sourceID
            )
            return (key: key, scheduledAt: movedAt, dueAt: movedDueAt)
        case .modify:
            let modifiedScheduledAt = dateFromPayload(field: "scheduledAt", data: exception.payloadData) ?? scheduledAt
            guard modifiedScheduledAt >= windowStart, modifiedScheduledAt <= windowEnd else { return nil }
            let modifiedDueAt = dateFromPayload(field: "dueAt", data: exception.payloadData) ?? dueAt
            let key = occurrenceKey(
                templateID: template.id,
                scheduledAt: modifiedScheduledAt,
                sourceID: sourceID
            )
            return (key: key, scheduledAt: modifiedScheduledAt, dueAt: modifiedDueAt)
        }
    }

    /// Executes dateFromPayload.
    private func dateFromPayload(field: String, data: Data?) -> Date? {
        guard
            let data,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let value = object[field] as? String
        else {
            return nil
        }
        return ISO8601DateFormatter().date(from: value)
    }
}
