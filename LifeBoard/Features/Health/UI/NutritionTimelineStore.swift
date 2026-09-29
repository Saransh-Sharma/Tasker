import Foundation
import Observation
import SwiftUI

@MainActor @Observable
final class NutritionTimelineStore {
    private(set) var foods: [FoodItem] = []
    /// Foods logged most recently, for one-tap "Log again".
    private(set) var recentFoods: [FoodItem] = []
    private(set) var entries: [NutritionLogEntry] = []
    private(set) var weekEntries: [NutritionLogEntry] = []
    private(set) var goals: [NutritionGoal] = []
    private(set) var recentlyDeleted: NutritionLogEntry?
    private(set) var healthSnapshot: HealthMetricsSnapshot?
    private(set) var healthHistory: [HealthMetric: [HealthAggregateValue]] = [:]
    private(set) var isUpdatingAppleHealth = false
    var errorMessage: String?
    let repository: any NutritionRepository
    let healthMetrics: (any HealthMetricsReading)?
    private let barcodeReviewService: NutritionBarcodeReviewService

    init(
        repository: any NutritionRepository,
        healthMetrics: (any HealthMetricsReading)? = nil
    ) {
        self.repository = repository
        self.healthMetrics = healthMetrics
        barcodeReviewService = NutritionBarcodeReviewService(repository: repository)
    }

    func prepareHealth(now: Date = Date()) async {
        guard let healthMetrics else { return }
        await healthMetrics.requestAutomaticRefresh()
        await loadHealth(now: now)
    }

    func loadHealth(now: Date = Date()) async {
        guard let healthMetrics else { return }
        async let snapshot = healthMetrics.currentSnapshot(now: now)
        async let history = healthMetrics.cachedHistory(
            domain: .nutrition,
            range: .sevenDays,
            now: now
        )
        let values = await (snapshot, history)
        healthSnapshot = values.0
        healthHistory = values.1
    }

    func healthUpdates() async -> AsyncStream<HealthSyncEvent>? {
        await healthMetrics?.updates()
    }

    func applyHealthUpdate(_ event: HealthSyncEvent) async {
        guard event.metrics.contains(where: { $0.domain == .nutrition }) else { return }
        await loadHealth(now: event.completedAt)
        isUpdatingAppleHealth = false
    }

    func load() async {
        do {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
            async let foods = repository.foods(query: "")
            async let entries = repository.logs(from: todayStart, to: nil)
            async let weekEntries = repository.logs(from: weekStart, to: nil)
            async let goals = repository.goals()
            self.foods = try await foods
            self.entries = try await entries
            self.weekEntries = try await weekEntries
            self.goals = try await goals
            // Optional: a failure here only hides the shortcut row.
            recentFoods = (try? await repository.recentFoods(limit: 8)) ?? []
            errorMessage = nil
        } catch { errorMessage = String(localized: "Couldn’t load nutrition") }
    }

    /// Writes the daily target. The entity and repository write already existed;
    /// nothing in the app could reach them.
    func saveGoal(_ macros: NutritionMacros) async {
        do {
            let goal = NutritionGoal(id: goals.first?.id ?? UUID(), targetMacros: macros)
            try await repository.save(goal)
            goals = try await repository.goals()
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn’t save target")
        }
    }

    func log(
        food: FoodItem,
        serving: FoodServingDefinition,
        quantity: Double,
        slot: NutritionMealSlot,
        provenance: NutritionLogProvenance,
        sourceReference: String?
    ) async {
        do {
            try await repository.save(food)
            try await repository.save(NutritionLogEntry(
                food: food,
                mealSlot: slot,
                quantity: quantity,
                serving: serving,
                provenance: provenance,
                sourceReference: sourceReference
            ))
            isUpdatingAppleHealth = healthSnapshot?.statuses[.nutrition]?.writeEnabled == true
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = String(localized: "Couldn’t save meal") }
    }

    func delete(_ entry: NutritionLogEntry) async {
        do {
            try await repository.deleteLog(id: entry.id)
            recentlyDeleted = entry
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
        }
        catch { errorMessage = String(localized: "Couldn’t remove meal") }
    }

    /// Historical entries are immutable snapshots, so undo is a faithful
    /// re-save of the exact removed record under its original identity.
    func undoDelete() async {
        guard let entry = recentlyDeleted else { return }
        do {
            try await repository.save(entry)
            recentlyDeleted = nil
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = String(localized: "Couldn’t restore meal") }
    }

    func dismissUndo() { recentlyDeleted = nil }

    func entries(for slot: NutritionMealSlot) -> [NutritionLogEntry] {
        entries.filter { $0.mealSlot == slot }
    }

    struct DailyEnergy: Identifiable {
        let day: Date
        /// `nil` for a day with nothing logged — never `0`, which would claim
        /// the person ate nothing.
        let calories: Double?
        var id: Date { day }
    }

    /// Per-day energy totals over the trailing week for the report chart.
    var weeklyReport: [DailyEnergy] {
        if summary.source == .appleHealth,
           let values = healthHistory[.dietaryEnergy],
           values.isEmpty == false {
            return values
                .map { DailyEnergy(day: $0.start, calories: $0.value) }
                .sorted { $0.day < $1.day }
        }
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let grouped = Dictionary(grouping: weekEntries) { calendar.startOfDay(for: $0.loggedAt) }
        var report: [DailyEnergy] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let entries = grouped[day] ?? []
            let total: Double? = entries.isEmpty
                ? nil
                : entries.reduce(0) { $0 + $1.resolvedMacrosSnapshot.calories }
            report.append(DailyEnergy(day: day, calories: total))
        }
        return report.reversed()
    }

    func food(barcode: String) async -> FoodItem? {
        do { return try await repository.food(barcode: barcode) }
        catch { errorMessage = String(localized: "Couldn’t check food library"); return nil }
    }

    func review(barcode: String) async -> NutritionBarcodeReview? {
        do {
            return try await barcodeReviewService.review(barcode: barcode, scope: .localOnly)
        } catch {
            errorMessage = String(localized: "Couldn’t read barcode")
            return nil
        }
    }

    func selection(
        from review: NutritionBarcodeReview,
        resolution: NutritionBarcodeResolution
    ) -> NutritionBarcodeSelection? {
        barcodeReviewService.selection(from: review, resolution: resolution)
    }

    var total: NutritionMacros { entries.reduce(.zero) { $0.adding($1.resolvedMacrosSnapshot) } }

    var summary: NutritionSummaryProjection {
        HealthFirstNutritionSummaryResolver.resolve(
            health: healthSnapshot,
            local: total,
            localUpdatedAt: entries.map(\.updatedAt).max()
        )
    }
}
