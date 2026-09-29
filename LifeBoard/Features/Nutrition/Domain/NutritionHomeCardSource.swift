import Foundation

public struct NutritionHomeCardSource: HomeCardSource {
    public let definition: HomeCardDefinition
    public let primaryDestination = Destination.track
    public let privacyClassification = DataSensitivity.privateSensitive
    private let repository: any NutritionRepository
    private let focus: NutritionHomeCardFocus
    private let healthMetrics: (any HealthMetricsReading)?

    public init(
        definition: HomeCardDefinition,
        focus: NutritionHomeCardFocus,
        repository: any NutritionRepository,
        healthMetrics: (any HealthMetricsReading)? = nil
    ) {
        self.definition = definition
        self.focus = focus
        self.repository = repository
        self.healthMetrics = healthMetrics
    }

    public func snapshot(configuration: HomeCardConfiguration, size: HomeCardSize, at date: Date) async -> HomeCardSnapshot {
        do {
            switch focus {
            case .logMeal:
                return .init(availability: .ready, title: definition.title, value: String(localized: "Log meal"), detail: nil, actions: inlineActions, updatedAt: date)
            case .recentMeal:
                guard let entry = try await repository.logs(from: nil, to: nil).first else {
                    return .init(availability: .empty, title: definition.title, detail: String(localized: "Nothing logged"), actions: inlineActions, updatedAt: date)
                }
                let mealPreview = HomeMomentPreview(
                    excerpt: entry.foodNameSnapshot,
                    moodLabel: entry.mealSlot.displayName,
                    capturedAt: entry.loggedAt
                )
                return .init(availability: .ready, title: definition.title, value: entry.foodNameSnapshot, detail: size == .compact ? nil : "\(Int(entry.resolvedMacrosSnapshot.calories.rounded())) kcal · \(entry.mealSlot.displayName)", payload: .moment(mealPreview), actions: inlineActions, updatedAt: entry.updatedAt)
            case .dailySummary:
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = .autoupdatingCurrent
                let entries = try await repository.logs(from: calendar.startOfDay(for: date), to: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)))
                let total = entries.reduce(NutritionMacros.zero) { $0.adding($1.resolvedMacrosSnapshot) }
                let healthSnapshot = await healthMetrics?.currentSnapshot(now: date)
                let summary = HealthFirstNutritionSummaryResolver.resolve(
                    health: healthSnapshot,
                    local: total,
                    localUpdatedAt: entries.map(\.updatedAt).max()
                )
                let baseDetail: String? = switch size {
                case .compact: nil
                case .standard, .wide: Self.macroDetail(summary)
                case .tall, .expanded: summary.source == .appleHealth
                    ? (entries.count == 1
                        ? String(localized: "Apple Health totals · 1 meal logged here")
                        : String(localized: "Apple Health totals · \(entries.count) meals logged here"))
                    : (entries.count == 1
                        ? String(localized: "1 meal logged")
                        : String(localized: "\(entries.count) meals logged"))
                }
                let detail = summary.source == .appleHealth
                    ? Self.appendingHealthStatus(
                        to: baseDetail,
                        status: healthSnapshot?.statuses[.nutrition]
                    )
                    : baseDetail
                // A hero numeral for the day's energy, with the last week's
                // daily totals behind it. Factual, never a target or a score.
                let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: date))
                let weekEntries = try await repository.logs(from: weekStart, to: date)
                var byDay: [Date: Double] = [:]
                for entry in weekEntries {
                    let day = calendar.startOfDay(for: entry.loggedAt)
                    byDay[day, default: 0] += entry.resolvedMacrosSnapshot.calories
                }
                let history: [HomeSeriesPoint]
                if summary.source == .appleHealth, let healthMetrics {
                    let healthHistory = await healthMetrics.cachedHistory(
                        domain: .nutrition,
                        range: .sevenDays,
                        now: date
                    )
                    history = (healthHistory[.dietaryEnergy] ?? []).map {
                        HomeSeriesPoint(date: $0.start, value: $0.value)
                    }
                } else {
                    history = byDay
                        .map { HomeSeriesPoint(date: $0.key, value: $0.value) }
                        .sorted { $0.date < $1.date }
                }

                var energyPayload = HomeCardPayload.none
                if let calories = summary.calories {
                    energyPayload = .metric(
                        HomeMetricValue(
                            amount: calories.rounded(),
                            unit: "kcal",
                            history: history
                        )
                    )
                }
                let hasSummary = summary.calories != nil
                    || summary.proteinGrams != nil
                    || summary.carbohydrateGrams != nil
                    || summary.fatGrams != nil
                return .init(
                    availability: hasSummary ? .ready : .empty,
                    title: definition.title,
                    value: summary.calories.map { "\(Int($0.rounded())) kcal" },
                    detail: hasSummary ? detail : nil,
                    payload: energyPayload,
                    actions: inlineActions,
                    updatedAt: summary.updatedAt ?? date
                )
            }
        } catch {
            return .init(availability: .degraded, title: definition.title, detail: String(localized: "Couldn’t load nutrition."), updatedAt: date)
        }
    }

    private static func macroDetail(_ summary: NutritionSummaryProjection) -> String {
        func value(_ amount: Double?, unit: String) -> String {
            amount.map { "\(Int($0.rounded()))\(unit)" } ?? "—"
        }
        return "P \(value(summary.proteinGrams, unit: "g")) · C \(value(summary.carbohydrateGrams, unit: "g")) · F \(value(summary.fatGrams, unit: "g"))"
    }

    private static func appendingHealthStatus(
        to detail: String?,
        status: HealthDomainStatus?
    ) -> String? {
        guard let status else { return detail }
        let suffix: String? = switch status.signal {
        case .stale: String(localized: "May be out of date")
        case .partial, .offline: String(localized: "Some values missing")
        case .protectedDataLocked: String(localized: "Unlock to refresh")
        case .unavailable: String(localized: "Last synced Health data")
        case .writeDenied: String(localized: "Saving to Health is off")
        case .loading, .setupRequired, .noRecord, .explicitZero, .recorded: nil
        }
        return [detail, suffix].compactMap { $0 }.joined(separator: " · ").nutritionTrimmed
    }
}
