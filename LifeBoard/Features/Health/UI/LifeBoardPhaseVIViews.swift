import Charts
import Observation
import SwiftUI

@MainActor @Observable
final class NutritionTimelineStore {
    private(set) var foods: [FoodItem] = []
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
            errorMessage = nil
        } catch { errorMessage = "Nutrition is unavailable right now. Your saved meals are unchanged." }
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
            errorMessage = "Could not save that target. Try again."
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
        } catch { errorMessage = "That meal could not be saved. Review the serving and try again." }
    }

    func delete(_ entry: NutritionLogEntry) async {
        do {
            try await repository.deleteLog(id: entry.id)
            recentlyDeleted = entry
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
        }
        catch { errorMessage = "That meal could not be removed." }
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
        } catch { errorMessage = "That meal could not be restored." }
    }

    func dismissUndo() { recentlyDeleted = nil }

    func entries(for slot: NutritionMealSlot) -> [NutritionLogEntry] {
        entries.filter { $0.mealSlot == slot }
    }

    struct DailyEnergy: Identifiable {
        let day: Date
        let calories: Double
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
            var total = 0.0
            for entry in grouped[day] ?? [] {
                total += entry.resolvedMacrosSnapshot.calories
            }
            report.append(DailyEnergy(day: day, calories: total))
        }
        return report.reversed()
    }

    func food(barcode: String) async -> FoodItem? {
        do { return try await repository.food(barcode: barcode) }
        catch { errorMessage = "The local food library could not be checked right now."; return nil }
    }

    func review(barcode: String) async -> NutritionBarcodeReview? {
        do {
            return try await barcodeReviewService.review(barcode: barcode, scope: .localOnly)
        } catch {
            errorMessage = "That barcode could not be reviewed."
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

struct NutritionInitialFocusPresentationState: Equatable {
    private(set) var didApply = false

    mutating func consume(_ focus: NutritionHomeCardFocus) -> Bool {
        guard didApply == false else { return false }
        didApply = true
        return focus == .logMeal
    }
}

/// Today's nourishment, as the screen's one hero.
///
/// A `View` struct rather than a computed property on `NutritionView`: the same
/// `-Onone` stack budget that governs the Track tree applies here, and this file
/// is the second-largest view tree in the app.
///
/// The target is deliberately optional and deliberately quiet. `DESIGN.md`
/// forbids inferring wellbeing from a recorded number, so when a target exists
/// this reports distance from it as a fact and never as a grade, and when none
/// exists the energy figure stands alone rather than inventing a denominator.
struct NutritionView: View {
    @State private var store: NutritionTimelineStore
    @State private var showsComposer = false
    @State private var initialFocusPresentation = NutritionInitialFocusPresentationState()
    @State private var pendingDeletion: NutritionLogEntry?
    @State private var scannedFood: FoodItem?
    @State private var scannedProvenance: NutritionLogProvenance = .manual
    @State private var scannedSourceReference: String?
    @State private var barcodeReview: NutritionBarcodeReview?
    @State private var showsBarcodeScanner = false
    @State private var scanMessage: String?
    @State private var showsVoiceCapture = false
    @State private var voiceFoodName: String?
    @State private var showsGoalComposer = false
    @State private var healthEducationDomain: HealthDomain?
    private let initialFocus: NutritionHomeCardFocus
    private let scanDeduplicator = NutritionScanDeduplicator()

    init(
        repository: any NutritionRepository,
        healthMetrics: any HealthMetricsReading = HealthCoordinator.shared.metricsReader,
        initialFocus: NutritionHomeCardFocus = .dailySummary
    ) {
        _store = State(initialValue: NutritionTimelineStore(
            repository: repository,
            healthMetrics: healthMetrics
        ))
        self.initialFocus = initialFocus
    }

    var body: some View {
        ScrollView {
            timelineContent
                .padding(20)
        }
        // Paper grain, like every sibling feature root. Nutrition was the only
        // one of the three still on a flat canvas fill.
        .background { GrainedCanvas() }
        .navigationTitle("Nutrition")
        .toolbar { nutritionToolbar }
        .task {
            async let localLoad: Void = store.load()
            async let healthLoad: Void = store.prepareHealth()
            _ = await (localLoad, healthLoad)
            if initialFocusPresentation.consume(initialFocus) {
                scannedFood = nil
                scannedProvenance = .manual
                scannedSourceReference = nil
                voiceFoodName = nil
                showsComposer = true
            }
        }
        .task {
            guard let updates = await store.healthUpdates() else { return }
            for await event in updates {
                guard Task.isCancelled == false else { return }
                await store.applyHealthUpdate(event)
            }
        }
        .refreshable {
            async let localLoad: Void = store.load()
            async let healthLoad: Void = store.loadHealth()
            _ = await (localLoad, healthLoad)
        }
        .sheet(isPresented: $showsComposer) {
            NutritionLogComposer(
                prefilledFood: scannedFood,
                prefilledName: voiceFoodName,
                provenance: scannedProvenance,
                sourceReference: scannedSourceReference,
                onSave: logMeal
            )
        }
        .sheet(item: $barcodeReview) { review in
            NutritionBarcodeReviewSheet(review: review) { resolution in
                guard let selection = store.selection(from: review, resolution: resolution) else {
                    barcodeReview = nil
                    return
                }
                scannedFood = selection.food
                scannedProvenance = selection.provenance
                scannedSourceReference = selection.sourceReference
                barcodeReview = nil
                showsComposer = true
            }
        }
        .sheet(isPresented: $showsVoiceCapture) {
            voiceCaptureSheet
        }
        .sheet(isPresented: $showsGoalComposer) {
            NutritionGoalComposer(existing: store.goals.first) { macros in
                Task { await store.saveGoal(macros) }
            }
        }
        .sheet(item: $healthEducationDomain) { domain in
            HealthConnectPromptSheet(
                leadDomain: domain,
                onConnect: { domains in
                    healthEducationDomain = nil
                    Task {
                        await HealthCoordinator.shared.connectionStore.connect(domains: domains)
                        await store.prepareHealth()
                    }
                },
                onDecline: { healthEducationDomain = nil }
            )
        }
        .fullScreenCover(isPresented: $showsBarcodeScanner) {
            barcodeScannerCover
        }
        .confirmationDialog("Remove this meal?", isPresented: Binding(
            get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Remove meal", role: .destructive) {
                guard let value = pendingDeletion else { return }; pendingDeletion = nil
                Task { await store.delete(value) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The food remains in your library. Only this historical entry is removed.") }
        .alert("Nutrition needs attention", isPresented: Binding(
            get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(store.errorMessage ?? "") }
        .alert("Barcode review", isPresented: Binding(
            get: { scanMessage != nil }, set: { if !$0 { scanMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(scanMessage ?? "") }
    }

    @ToolbarContentBuilder
    private var nutritionToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Daily target", systemImage: "target") { showsGoalComposer = true }
                .accessibilityIdentifier("nutrition.goal.open")
            Button("Scan barcode", systemImage: "barcode.viewfinder", action: beginBarcodeScan)
            Button("Log by voice", systemImage: "waveform") { showsVoiceCapture = true }
            Button("Log meal", systemImage: "plus") {
                scannedFood = nil
                scannedProvenance = .manual
                scannedSourceReference = nil
                voiceFoodName = nil
                showsComposer = true
            }
        }
    }

    private func beginBarcodeScan() {
        guard BarcodeScannerCapability.isAvailable else {
            scanMessage = BarcodeScanError.unavailable.localizedDescription
            return
        }
        showsBarcodeScanner = true
    }

    private func logMeal(
        food: FoodItem,
        serving: FoodServingDefinition,
        quantity: Double,
        slot: NutritionMealSlot,
        provenance: NutritionLogProvenance,
        sourceReference: String?
    ) {
        Task {
            await store.log(
                food: food,
                serving: serving,
                quantity: quantity,
                slot: slot,
                provenance: provenance,
                sourceReference: sourceReference
            )
            await HealthCoordinator.shared.jitCoordinator.offerConnectAfterReward(
                leadDomain: .nutrition,
                trigger: "nutrition_log_meal"
            )
        }
    }

    private var barcodeScannerCover: some View {
        BarcodeScannerView(completion: handleBarcodeResult)
            .ignoresSafeArea()
    }

    private func handleBarcodeResult(_ result: Result<String, Error>) {
        showsBarcodeScanner = false
        switch result {
        case .success(let barcode):
            Task {
                guard await scanDeduplicator.shouldAccept(barcode: barcode) else { return }
                guard let review = await store.review(barcode: barcode) else { return }
                switch review.kind {
                case .noMatchRemoteDisabled:
                    // Remote lookup stays an explicit future opt-in; today the
                    // library is local-first only, and we say so plainly.
                    scanMessage = "No local match. You can enter the food manually; online lookup is currently off."
                case .local, .remote, .duplicate:
                    barcodeReview = review
                }
            }
        case .failure(let error):
            scanMessage = error.localizedDescription
        }
    }

    private var timelineHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today’s nourishment").font(Typography.screenTitle())
            Text("A factual record of what you choose to log—never a grade.")
                .font(.subheadline).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
    }

    @ViewBuilder
    private var timelineContent: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            timelineHeader
            NutritionTodayHero(
                calories: store.summary.calories,
                targetCalories: store.goals.first?.targetMacros.calories,
                isPartial: store.summary.isPartial,
                source: store.summary.source,
                onLogMeal: {
                    scannedFood = nil
                    scannedProvenance = .manual
                    scannedSourceReference = nil
                    voiceFoodName = nil
                    showsComposer = true
                }
            )
            nutritionHealthStatus
            if let deleted = store.recentlyDeleted {
                undoBanner(deleted)
            }
            macroSummary
            ForEach(NutritionMealSlot.allCases, id: \.self) { (slot: NutritionMealSlot) in
                NutritionMealSectionView(
                    slot: slot,
                    entries: store.entries(for: slot),
                    onDelete: { (entry: NutritionLogEntry) in pendingDeletion = entry }
                )
            }
            weeklyReportSection
        }
    }

    /// Voice logging reuses the save-first journal transcription control in
    /// its ephemeral search mode: audio is transcribed on-device, the
    /// temporary file is removed, and the text lands in the same reviewable
    /// composer as every other flow.
    private var voiceCaptureSheet: some View {
        let onSave: (String, TimeInterval, String?) async -> Bool = { path, _, transcription in
            defer { try? JournalAudioFiles.delete(relativePath: path) }
            let trimmed = transcription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard trimmed.isEmpty == false else { return false }
            voiceFoodName = trimmed
            scannedFood = nil
            scannedProvenance = .manual
            scannedSourceReference = nil
            showsVoiceCapture = false
            showsComposer = true
            return true
        }
        return NavigationStack {
            JournalAudioCapture(purpose: .search, onSave: onSave)
                .navigationTitle("Say the food")
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private func undoBanner(_ deleted: NutritionLogEntry) -> some View {
        HStack(spacing: 10) {
            Text("Removed “\(deleted.foodNameSnapshot)”")
                .font(.caption)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            Spacer(minLength: 8)
            Button("Undo") { Task { await store.undoDelete() } }
                .font(.caption.weight(.semibold))
            Button {
                store.dismissUndo()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss undo")
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .lifeBoardClaySurface(.well, fill: Color(SemanticColorTokens.foundationSurfaceSelected))
    }

    /// The macros supporting the hero's energy figure.
    ///
    /// Energy itself moved into the hero, and the provenance line moved with it.
    /// Both used to appear twice on this screen — `DESIGN.md` calls duplicated
    /// counts and repeated headings out by name, and a person reading two
    /// identical "Totals from Apple Health" lines has to check whether they mean
    /// different things.
    private var macroSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Macros")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { macroCells }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    macroCells
                }
                VStack(spacing: 8) { macroCells }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var macroCells: some View {
        macro("Protein", value: store.summary.proteinGrams, unit: "g")
        macro("Carbs", value: store.summary.carbohydrateGrams, unit: "g")
        macro("Fat", value: store.summary.fatGrams, unit: "g")
    }

    /// An absent macro is `noRecord`, not an em dash and not zero. The dash read
    /// as a value in exactly the way `0` does — "Fat —" and "Fat 0 g" were
    /// indistinguishable to anyone scanning the row.
    private func macroReading(_ value: Double?, unit: String) -> MetricReading {
        guard let value else { return .noRecord }
        return value == 0
            ? .explicitZero(unit: unit)
            : .recorded(value: Int(value.rounded()).formatted(), unit: unit)
    }

    @ViewBuilder
    private var nutritionHealthStatus: some View {
        if store.isUpdatingAppleHealth {
            healthStatusCard(
                title: "Updating Apple Health",
                detail: "Your meal is saved in LifeBoard. Supported nutrients will update automatically.",
                symbol: "arrow.triangle.2.circlepath"
            )
        } else if let status = store.healthSnapshot?.statuses[.nutrition] {
            switch status.signal {
            case .setupRequired:
                healthStatusCard(
                    title: "Connect Apple Health",
                    detail: "Use Apple Health totals for calories and macros while named meals stay private in LifeBoard.",
                    symbol: "heart.text.clipboard",
                    actionTitle: "Connect Health",
                    action: { healthEducationDomain = .nutrition }
                )
            case .writeDenied:
                healthStatusCard(
                    title: "Meals stay in LifeBoard",
                    detail: "Writing nutrition to Apple Health is off. Existing Health totals still refresh automatically when available.",
                    symbol: "hand.raised"
                )
            case .stale, .partial, .offline:
                healthStatusCard(
                    title: "Showing the latest available Health totals",
                    detail: "LifeBoard refreshes automatically in the foreground and when Apple Health reports changes.",
                    symbol: "clock.arrow.circlepath"
                )
            case .unavailable:
                healthStatusCard(
                    title: "Apple Health is unavailable",
                    detail: "Named meals and local totals remain available in LifeBoard.",
                    symbol: "heart.slash"
                )
            case .protectedDataLocked:
                healthStatusCard(
                    title: "Health data is locked",
                    detail: "Unlock this device and LifeBoard will refresh automatically.",
                    symbol: "lock"
                )
            case .noRecord:
                healthStatusCard(
                    title: "No Apple Health nutrition totals yet",
                    detail: "LifeBoard meals remain below. Health totals appear automatically when available.",
                    symbol: "fork.knife"
                )
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Updating Apple Health automatically…").font(.subheadline)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            case .explicitZero, .recorded:
                EmptyView()
            }
        }
    }

    private func healthStatusCard(
        title: String,
        detail: String,
        symbol: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .lifeBoardClaySurface(.resting)
        .accessibilityElement(children: .contain)
    }

    private func macro(_ title: String, value: Double?, unit: String) -> some View {
        MetricHero(
            label: title,
            reading: macroReading(value, unit: unit),
            accessibilityID: "nutrition.macro.\(title.lowercased())"
        )
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(12)
        .lifeBoardClaySurface(.well, fill: Color(SemanticColorTokens.foundationSurfaceSelected))
    }

    /// Honest trailing-week report: recorded energy per day, no goals or
    /// grades implied. Days without logs stay visibly empty.
    private var weeklyReportSection: some View {
        let report = store.weeklyReport
        return VStack(alignment: .leading, spacing: 10) {
            Text("Past 7 days").font(Typography.sectionTitle())
            Text(store.summary.source == .appleHealth ? "Daily energy totals from Apple Health" : "Energy from named LifeBoard meals")
                .font(.caption)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            if report.allSatisfy({ $0.calories == 0 }) {
                Text("Logged meals will build this picture over the week.")
                    .font(.subheadline).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            } else {
                Chart(report) { item in
                    BarMark(
                        x: .value("Day", item.day, unit: .day),
                        y: .value("Energy", item.calories)
                    )
                    .foregroundStyle(Color(SemanticColorTokens.foundationSunAccent))
                    .cornerRadius(5)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
                .frame(height: 132)
                .padding(14)
                // The clay surface already draws the hairline; the previous
                // explicit stroke doubled it.
                .lifeBoardClaySurface(.raised)
                .accessibilityLabel("Energy logged per day over the past week")
                .accessibilityValue(report.map { "\($0.day.formatted(.dateTime.weekday(.abbreviated))): \(Int($0.calories.rounded())) kilocalories" }.joined(separator: ", "))
            }
        }
    }

}

private struct NutritionBarcodeReviewSheet: View {
    let review: NutritionBarcodeReview
    let onResolve: (NutritionBarcodeResolution) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Barcode", value: review.barcode)
                    LabeledContent(
                        "Online lookup",
                        value: review.remoteLookupWasExplicit ? "Explicitly requested" : "Off"
                    )
                }
                switch review.kind {
                case .local(let food):
                    Section("Local match") {
                        foodRow(food, provenance: "Saved in your LifeBoard library")
                        Button("Use local match") {
                            onResolve(.useLocal)
                            dismiss()
                        }
                        .frame(minHeight: 44)
                    }
                case .remote(let food):
                    Section("Online match") {
                        foodRow(food, provenance: "Returned by the named online source")
                        Button("Use online match") {
                            onResolve(.useRemote)
                            dismiss()
                        }
                        .frame(minHeight: 44)
                    }
                case .duplicate(let local, let remote):
                    Section("Saved locally") {
                        foodRow(local, provenance: "Your existing library value")
                        Button("Use saved value") {
                            onResolve(.useLocal)
                            dismiss()
                        }
                        .frame(minHeight: 44)
                    }
                    Section("Online candidate") {
                        foodRow(remote, provenance: remote.externalReference ?? "Online source")
                        Button("Use online candidate") {
                            onResolve(.useRemote)
                            dismiss()
                        }
                        .frame(minHeight: 44)
                    }
                    Section {
                        Text("Nothing is merged or replaced automatically. Review the name, brand, serving, and nutrition values before choosing.")
                            .font(.caption)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                case .noMatchRemoteDisabled:
                    ContentUnavailableView(
                        "No local match",
                        systemImage: "barcode",
                        description: Text("Enter this food manually.")
                    )
                }
            }
            .navigationTitle("Review barcode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onResolve(.cancel)
                        dismiss()
                    }
                }
            }
        }
    }

    private func foodRow(_ food: FoodItem, provenance: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(food.name).font(.headline)
            if let brand = food.brand { Text(brand).font(.subheadline) }
            Text(provenance)
                .font(.caption)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            Text(
                "\(food.macrosPer100Grams.calories.formatted()) kcal · "
                    + "\(food.macrosPer100Grams.proteinGrams.formatted()) g protein per 100 g"
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    }
}

private struct NutritionMealSectionView: View {
    let slot: NutritionMealSlot
    let entries: [NutritionLogEntry]
    let onDelete: (NutritionLogEntry) -> Void

    /// One clay card per meal slot, with its entries as rows inside.
    ///
    /// Previously the slot name was a bare heading on the page and each entry
    /// carried its own card, so an empty day rendered as four headings and four
    /// identical sentences floating on a flat background with no structure at
    /// all. Grouping gives the day a shape and lets the header carry the slot's
    /// running total.
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(slot.rawValue.capitalized)
                    .font(Typography.sectionTitle())
                Spacer(minLength: 0)
                if entries.isEmpty == false {
                    Text("\(loggedCalories) kcal")
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
            }
            if entries.isEmpty {
                // The reassurance that nothing is required is made once, in the
                // screen's subtitle. Repeating it under all four slots turned a
                // kind sentence into wallpaper.
                Text("Nothing logged")
                    .font(.subheadline)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            Divider().overlay(Color(SemanticColorTokens.foundationHairline))
                        }
                        row(entry)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
    }

    private var loggedCalories: Int {
        Int(entries.reduce(0) { $0 + $1.resolvedMacrosSnapshot.calories }.rounded())
    }

    private func row(_ entry: NutritionLogEntry) -> some View {
        let quantityText = entry.quantity.formatted()
        let calorieCount = Int(entry.resolvedMacrosSnapshot.calories.rounded())
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.foodNameSnapshot).font(.headline)
                Text("\(quantityText) × \(entry.servingNameSnapshot) · \(calorieCount) kcal")
                    .font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            Spacer()
            Menu {
                Button("Remove", systemImage: "trash", role: .destructive) { onDelete(entry) }
            } label: {
                Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct NutritionLogComposer: View {
    let onSave: (
        FoodItem,
        FoodServingDefinition,
        Double,
        NutritionMealSlot,
        NutritionLogProvenance,
        String?
    ) -> Void
    private let prefilledFood: FoodItem?
    private let provenance: NutritionLogProvenance
    private let sourceReference: String?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbohydrates = ""
    @State private var fat = ""
    @State private var servingGrams = "100"
    @State private var quantity = 1.0
    @State private var slot: NutritionMealSlot = .snack
    @State private var errorMessage: String?
    @State private var revealTrigger = 0

    init(
        prefilledFood: FoodItem? = nil,
        prefilledName: String? = nil,
        provenance: NutritionLogProvenance = .manual,
        sourceReference: String? = nil,
        onSave: @escaping (
            FoodItem,
            FoodServingDefinition,
            Double,
            NutritionMealSlot,
            NutritionLogProvenance,
            String?
        ) -> Void
    ) {
        self.prefilledFood = prefilledFood
        self.provenance = provenance
        self.sourceReference = sourceReference
        self.onSave = onSave
        _name = State(initialValue: prefilledFood?.name ?? prefilledName ?? "")
        _calories = State(initialValue: prefilledFood.map { String($0.macrosPer100Grams.calories) } ?? "")
        _protein = State(initialValue: prefilledFood.map { String($0.macrosPer100Grams.proteinGrams) } ?? "")
        _carbohydrates = State(initialValue: prefilledFood.map { String($0.macrosPer100Grams.carbohydrateGrams) } ?? "")
        _fat = State(initialValue: prefilledFood.map { String($0.macrosPer100Grams.fatGrams) } ?? "")
        _servingGrams = State(initialValue: prefilledFood?.servings.first.map { String($0.grams) } ?? "100")
    }

    var body: some View {
        ComposerScaffold(
            title: "Review meal",
            subtitle: "A factual record of what you choose to log.",
            confirmTitle: "Log",
            isConfirmEnabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            identifier: "nutrition.log.composer",
            onConfirm: save
        ) {
            NutritionFoodSection(name: $name, slot: $slot)
            NutritionProvenanceSection(provenance: provenance, sourceReference: sourceReference)
            NutritionMacroSection(
                calories: $calories,
                protein: $protein,
                carbohydrates: $carbohydrates,
                fat: $fat
            )
            NutritionServingSection(servingGrams: $servingGrams, quantity: $quantity)
            NutritionErrorSection(message: errorMessage)
        }
        // The composer arrives as a mode handoff, not a plain sheet — the same
        // lens the capture composer uses. It inherited ComposerScaffold's CTA
        // bezel and first light and added nothing of its own.
        .lifeboardContextLens(trigger: revealTrigger)
        .onAppear { revealTrigger &+= 1 }
        .lifeBoardMotion(.contentInsertion, value: errorMessage)
    }

    private func save() {
        do {
            let macros = try NutritionMacros(
                calories: try number(calories), proteinGrams: try number(protein),
                carbohydrateGrams: try number(carbohydrates), fatGrams: try number(fat)
            )
            let serving = try FoodServingDefinition(name: "serving", grams: try number(servingGrams))
            let food = try FoodItem(
                id: prefilledFood?.id ?? UUID(),
                name: name,
                brand: prefilledFood?.brand,
                barcode: prefilledFood?.barcode,
                macrosPer100Grams: macros,
                servings: [serving],
                source: prefilledFood?.source ?? .userCreated,
                externalReference: prefilledFood?.externalReference,
                isFavorite: prefilledFood?.isFavorite ?? false,
                createdAt: prefilledFood?.createdAt ?? Date(),
                updatedAt: Date()
            )
            onSave(food, serving, quantity, slot, provenance, sourceReference)
            dismiss()
        } catch { errorMessage = "Check the name, macros, and serving before logging." }
    }

    private func number(_ text: String) throws -> Double {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value >= 0 else { throw NutritionError.invalidMacros }
        return value
    }
}

private struct NutritionFoodSection: View {
    @Binding var name: String
    @Binding var slot: NutritionMealSlot

    var body: some View {
        ComposerSection("Food") {
            ComposerField(
                "Name",
                prompt: "What you ate",
                text: $name,
                showsLabel: false,
                identifier: "nutrition.log.name"
            )
            OptionRail(
                "Meal",
                selection: $slot,
                values: NutritionMealSlot.allCases,
                identifierPrefix: "nutrition.log.slot",
                title: { $0.rawValue.capitalized }
            )
        }
    }
}

private struct NutritionProvenanceSection: View {
    let provenance: NutritionLogProvenance
    let sourceReference: String?

    var body: some View {
        if provenance == .barcodeLocal || provenance == .barcodeRemote {
            ComposerSection("Source", detail: sourceReference) {
                Label(
                    provenance == .barcodeLocal ? "Saved local barcode match" : "Explicit online barcode match",
                    systemImage: provenance == .barcodeLocal ? "internaldrive" : "network"
                )
                .font(.lifeboard(.body))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            }
        }
    }
}

private struct NutritionMacroSection: View {
    @Binding var calories: String
    @Binding var protein: String
    @Binding var carbohydrates: String
    @Binding var fat: String

    var body: some View {
        ComposerSection(
            "Per 100 grams",
            detail: "Leave anything you do not know blank rather than guessing."
        ) {
            ComposerField("Calories", prompt: "kcal", text: $calories, keyboard: .decimalPad)
            ComposerField("Protein", prompt: "grams", text: $protein, keyboard: .decimalPad)
            ComposerField("Carbohydrates", prompt: "grams", text: $carbohydrates, keyboard: .decimalPad)
            ComposerField("Fat", prompt: "grams", text: $fat, keyboard: .decimalPad)
        }
    }
}

private struct NutritionServingSection: View {
    @Binding var servingGrams: String
    @Binding var quantity: Double

    var body: some View {
        ComposerSection("Serving") {
            ComposerField("Serving grams", prompt: "100", text: $servingGrams, keyboard: .decimalPad)
            ValueDrum(
                "Quantity",
                value: $quantity,
                in: 0.25...20,
                step: 0.25,
                coarseStep: 1,
                unit: "servings",
                fractionDigits: 2,
                identifier: "nutrition.log.quantity"
            )
        }
    }
}

private struct NutritionErrorSection: View {
    let message: String?

    var body: some View {
        if let message {
            ComposerSection {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

@MainActor @Observable
final class WellnessHistoryStore {
    private(set) var samples: [BodyMetricSample] = []
    private(set) var workouts: [WorkoutRecord] = []
    private(set) var sleepNotes: [SleepNote] = []
    private(set) var movements: [MovementContextRecord] = []
    private(set) var state: WellnessDataState = .notRequested
    private(set) var conflicts: [WellnessSourceConflict] = []
    private(set) var preferences: WellnessDisplayPreferences
    var errorMessage: String?
    let repository: any WellnessRepository
    let preferenceStore: any WellnessPreferenceStore
    init(
        repository: any WellnessRepository,
        preferenceStore: any WellnessPreferenceStore = UserDefaultsWellnessPreferenceStore()
    ) {
        self.repository = repository
        self.preferenceStore = preferenceStore
        preferences = preferenceStore.load()
    }
    func load(kind: BodyMetricKind) async {
        state = .loading
        do {
            async let sampleValues = repository.bodyMetricSamples(kind: kind)
            async let workoutValues = repository.workoutRecords()
            async let sleepValues = repository.sleepNotes()
            async let movementValues = repository.movementRecords()
            let values = try await (sampleValues, workoutValues, sleepValues, movementValues)
            samples = values.0
            workouts = values.1
            sleepNotes = values.2
            movements = values.3
            conflicts = WellnessSourceConflictDetector().conflicts(in: samples)
            errorMessage = nil
            state = samples.isEmpty && workouts.isEmpty && sleepNotes.isEmpty && movements.isEmpty
                ? .noSamples
                : .fresh(lastSyncAt: Date())
        } catch {
            errorMessage = "Wellness history is unavailable right now."
            state = .failed(message: errorMessage ?? "Wellness history is unavailable right now.")
        }
    }
    func save(_ sample: BodyMetricSample, kind: BodyMetricKind) async { do { try await repository.save(sample); await load(kind: kind); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = "That measurement could not be saved." } }
    func delete(_ sample: BodyMetricSample, kind: BodyMetricKind) async { do { try await repository.delete(kind: .bodyMetric, id: sample.id); await load(kind: kind); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = "That measurement could not be removed." } }
    func save(_ value: WorkoutRecord, kind: BodyMetricKind) async { do { try await repository.save(value); await load(kind: kind); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = "That workout could not be saved." } }
    func save(_ value: SleepNote, kind: BodyMetricKind) async { do { try await repository.save(value); await load(kind: kind); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = "That sleep note could not be saved." } }
    func save(_ value: MovementContextRecord, kind: BodyMetricKind) async { do { try await repository.save(value); await load(kind: kind); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = "That movement record could not be saved." } }
    func delete(kind recordKind: WellnessRecordKind, id: UUID, selectedKind: BodyMetricKind) async { do { try await repository.delete(kind: recordKind, id: id); await load(kind: selectedKind); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = "That wellness record could not be removed." } }

    func savePreferences(_ value: WellnessDisplayPreferences) {
        var normalized = value
        normalized.updatedAt = Date()
        preferences = normalized
        preferenceStore.save(normalized)
    }

    func prefer(sampleID: UUID, for conflictID: String) {
        var updated = preferences
        updated.preferredSampleIDsByConflict[conflictID] = sampleID
        savePreferences(updated)
    }
}

private enum WellnessSection: String, CaseIterable, Identifiable {
    case body, workouts, sleep, movement

    var id: String { rawValue }
    var title: String {
        switch self {
        case .body: "Body"
        case .workouts: "Workouts"
        case .sleep: "Sleep"
        case .movement: "Movement"
        }
    }
    var addTitle: String {
        switch self {
        case .body: "Add value"
        case .workouts: "Add workout"
        case .sleep: "Add sleep note"
        case .movement: "Add movement"
        }
    }
    var healthDomain: HealthDomain {
        switch self {
        case .body: .body
        case .workouts: .workouts
        case .sleep: .sleep
        case .movement: .activity
        }
    }
}

/// Today's state for whichever wellness area is showing, as the screen's hero.
///
/// This replaces two hand-rolled cards — `summaryCard` and `todayCard` — that
/// had drifted into rendering the most important object on the screen as a
/// `.well`, the *recessed* depth reserved for fields and progress tracks. The
/// screen's answer to "what is my body doing" was the only thing on it carved
/// into the page rather than lifted off it.
///
/// All four areas share this now, so Body, Workouts, Sleep and Movement no
/// longer each describe "today" in a slightly different shape.
struct WellnessView: View {
    @State private var store: WellnessHistoryStore
    @State private var healthStore = HealthCoordinator.shared.connectionStore
    @State private var healthSnapshot: HealthMetricsSnapshot?
    @State private var movementHealthHistory: [HealthMetric: [HealthAggregateValue]] = [:]
    @State private var section: WellnessSection
    @State private var kind: BodyMetricKind = .bodyMass
    @State private var showsCapture = false
    @State private var showsCustomization = false
    @State private var searchText = ""
    @State private var chartRevealProgress: Double = 1
    @State private var editingBodyMetric: BodyMetricSample?
    @State private var editingWorkout: WorkoutRecord?
    @State private var editingSleep: SleepNote?
    @State private var editingMovement: MovementContextRecord?
    @State private var educationDomain: HealthDomain?
    private let healthMetrics: any HealthMetricsReading
    init(
        repository: any WellnessRepository,
        healthMetrics: any HealthMetricsReading = HealthCoordinator.shared.metricsReader,
        preferenceStore: any WellnessPreferenceStore = UserDefaultsWellnessPreferenceStore(),
        initialFocus: WellnessHomeCardFocus = .bodyMetric(.bodyMass)
    ) {
        _store = State(initialValue: WellnessHistoryStore(
            repository: repository,
            preferenceStore: preferenceStore
        ))
        self.healthMetrics = healthMetrics
        switch initialFocus {
        case .bodyMetric(let metric):
            _section = State(initialValue: .body)
            _kind = State(initialValue: metric)
        case .workouts: _section = State(initialValue: .workouts)
        case .sleep: _section = State(initialValue: .sleep)
        case .movement: _section = State(initialValue: .movement)
        }
    }

    private var todaySamples: [BodyMetricSample] {
        store.samples.filter { Calendar.current.isDateInToday($0.observedAt) }
    }

    private var filteredSamples: [BodyMetricSample] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard query.isEmpty == false else { return store.samples }
        return store.samples.filter { sample in
            display(sample).lowercased().contains(query)
                || sample.observedAt.formatted(date: .complete, time: .shortened).lowercased().contains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LensPicker(
                    "Wellness area",
                    selection: $section,
                    values: WellnessSection.allCases,
                    identifierPrefix: "wellness.section",
                    title: \.title,
                    identifier: \.rawValue
                )
                focusedContent
            }.padding(20)
        }
        .background {
            GrainedCanvas()
        }
        .navigationTitle(section.title)
        .searchable(text: $searchText, prompt: "Search \(section.title.lowercased())")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if section == .body {
                    Button("Customize", systemImage: "slider.horizontal.3") { showsCustomization = true }
                }
                Button(section.addTitle, systemImage: "plus") { beginAdd() }
            }
        }
        .task(id: "\(section.rawValue)-\(kind.rawValue)") {
            await loadHealthMetrics(requestRefresh: true)
            await store.load(kind: kind)
            chartRevealProgress = 0
            withAnimation(.easeOut(duration: 0.62)) { chartRevealProgress = 1 }
        }
        .task {
            let updates = await healthMetrics.updates()
            for await event in updates {
                guard Task.isCancelled == false,
                      event.metrics.contains(where: { [.body, .workouts, .sleep, .activity, .energy].contains($0.domain) }) else {
                    continue
                }
                async let localLoad: Void = store.load(kind: kind)
                async let healthLoad: Void = loadHealthMetrics(
                    now: event.completedAt,
                    requestRefresh: false
                )
                _ = await (localLoad, healthLoad)
            }
        }
        .sheet(isPresented: $showsCapture, onDismiss: clearEditingState) {
            switch section {
            case .body:
                WellnessMetricCapture(
                    kind: kind,
                    existing: editingBodyMetric,
                    lastValue: store.samples.first.map(displayValue)
                ) { value in
                    Task {
                        await store.save(value, kind: kind)
                        await HealthCoordinator.shared.jitCoordinator.offerConnectAfterReward(leadDomain: .body, trigger: "wellness_body_metric")
                    }
                }
            case .workouts:
                WorkoutCaptureView(existing: editingWorkout) { value in Task { await store.save(value, kind: kind) } }
            case .sleep:
                SleepNoteCaptureView(existing: editingSleep) { value in Task { await store.save(value, kind: kind) } }
            case .movement:
                MovementCaptureView(existing: editingMovement) { value in Task { await store.save(value, kind: kind) } }
            }
        }
        .sheet(isPresented: $showsCustomization) {
            WellnessCustomizationView(preferences: store.preferences) { updated in
                store.savePreferences(updated)
                if !enabledMetrics.contains(kind), let first = enabledMetrics.first {
                    kind = first
                }
            }
        }
        .sheet(item: $educationDomain) { domain in
            HealthConnectPromptSheet(
                leadDomain: domain,
                onConnect: { domains in
                    educationDomain = nil
                    Task {
                        await healthStore.connect(domains: domains)
                        await loadHealthMetrics(requestRefresh: true)
                        await store.load(kind: kind)
                    }
                },
                onDecline: { educationDomain = nil }
            )
        }
        .alert("Wellness needs attention", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(store.errorMessage ?? "") }
    }

    @ViewBuilder
    private var focusedContent: some View {
        if case let .failed(message) = store.state {
            ContentUnavailableView("Wellness is unavailable", systemImage: "exclamationmark.triangle", description: Text(message))
        } else if store.state == .loading {
            ProgressView("Loading \(section.title.lowercased())")
                .frame(maxWidth: .infinity, minHeight: 160)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                healthStatusNotice
                switch section {
                case .body: bodyMetricsSection
                case .workouts: workoutsSection
                case .sleep: sleepSection
                case .movement: movementSection
                }
            }
        }
    }

    @ViewBuilder
    private var healthStatusNotice: some View {
        if V2FeatureFlags.healthIntegrationsV1Enabled,
           let status = healthSnapshot?.statuses[section.healthDomain] {
            switch status.signal {
            case .setupRequired:
                statusNotice(
                    title: "Apple Health is not connected",
                    detail: "Manual records stay available. Connect only if you want to import available \(section.title.lowercased()) data.",
                    symbol: "heart.text.clipboard",
                    actionTitle: "Connect Health",
                    action: { educationDomain = section.healthDomain }
                )
            case .writeDenied:
                statusNotice(
                    title: "Writing to Apple Health is off",
                    detail: "Local logging still works. Apple keeps read choices private, so LifeBoard does not label missing read data as denied.",
                    symbol: "hand.raised"
                )
            case .unavailable:
                statusNotice(
                    title: "Apple Health is unavailable",
                    detail: "Saved LifeBoard records remain available and manual capture still works.",
                    symbol: "heart.slash"
                )
            case .stale:
                statusNotice(
                    title: "Apple Health data may be out of date",
                    detail: "The history below shows the last available records. LifeBoard refreshes automatically.",
                    symbol: "arrow.clockwise"
                )
            case .offline, .partial:
                statusNotice(
                    title: "Some Apple Health data is unavailable",
                    detail: "The history below shows the last available records. LifeBoard will refresh automatically.",
                    symbol: "arrow.clockwise"
                )
            case .protectedDataLocked:
                statusNotice(
                    title: "Health data is locked",
                    detail: "Unlock this device to refresh Apple Health. Saved LifeBoard records remain visible.",
                    symbol: "lock"
                )
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Refreshing Apple Health…")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .accessibilityElement(children: .combine)
            case .noRecord, .explicitZero, .recorded:
                EmptyView()
            }
        }
    }

    private static func durationLabel(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private var trailingSevenDayWorkouts: [WorkoutRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        return store.workouts.filter { $0.startedAt >= cutoff }
    }

    private var trailingSevenDayWorkoutDuration: TimeInterval {
        trailingSevenDayWorkouts.reduce(0) { $0 + $1.duration }
    }

    private var trailingSevenDayWorkoutCount: Int { trailingSevenDayWorkouts.count }

    private var movementSummary: MovementSummaryProjection {
        HealthFirstMovementSummaryResolver.resolve(
            health: healthSnapshot,
            manual: store.movements
        )
    }

    private var movementStepPoints: [HomeSeriesPoint] {
        if movementSummary.source == .appleHealth,
           let values = movementHealthHistory[.steps],
           values.isEmpty == false {
            return values.map { HomeSeriesPoint(date: $0.start, value: $0.value) }
        }
        return store.movements.compactMap { value in
            value.steps.map { HomeSeriesPoint(date: value.startedAt, value: Double($0)) }
        }.sorted { $0.date < $1.date }
    }

    private func movementSummaryDetail(_ summary: MovementSummaryProjection) -> String {
        var parts: [String] = []
        if let distance = summary.distanceMeters { parts.append(String(format: "%.1f km", distance / 1_000)) }
        if let energy = summary.activeEnergyKilocalories { parts.append("\(Int(energy.rounded())) active kcal") }
        parts.append(summary.source == .appleHealth ? "Apple Health" : "LifeBoard custom")
        return parts.isEmpty ? "No distance or active energy recorded" : parts.joined(separator: " · ")
    }

    private var filteredWorkouts: [WorkoutRecord] {
        filter(store.workouts) { "\($0.activityKind) \($0.note ?? "") \($0.startedAt.formatted())" }
    }

    private var filteredSleepNights: [HealthSleepPresentation.NightSummary] {
        let nights = HealthSleepPresentation.nightlySummaries(notes: store.sleepNotes)
        return filter(nights) { night in
            let notes = night.samples.compactMap(\.note).joined(separator: " ")
            return "\(notes) \(sleepNightSources(night)) \(night.startedAt.formatted())"
        }
    }

    private var filteredMovements: [MovementContextRecord] {
        filter(store.movements) { "\($0.steps ?? 0) \($0.distanceMeters ?? 0) \($0.startedAt.formatted())" }
    }

    private func filter<T>(_ values: [T], text: (T) -> String) -> [T] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return values }
        return values.filter { text($0).lowercased().contains(query) }
    }

    private func movementDetail(_ value: MovementContextRecord) -> String {
        var parts: [String] = []
        if let distance = value.distanceMeters { parts.append(String(format: "%.1f km", distance / 1_000)) }
        if let energy = value.activeEnergyKilocalories { parts.append("\(Int(energy.rounded())) active kcal") }
        parts.append(sourceLabel(value.source))
        return parts.joined(separator: " · ")
    }

    private func sleepNightSources(_ night: HealthSleepPresentation.NightSummary) -> String {
        Set(night.samples.map { sourceLabel($0.source) }).sorted().joined(separator: ", ")
    }

    private func sleepNightDetail(_ night: HealthSleepPresentation.NightSummary) -> String {
        let quality = night.samples.compactMap(\.quality).first.map { "Quality \($0)/5" }
        return [quality, sleepNightSources(night)].compactMap { $0 }.joined(separator: " · ")
    }

    private func sleepNightNote(_ night: HealthSleepPresentation.NightSummary) -> String? {
        let notes = night.samples.compactMap(\.note).filter { $0.isEmpty == false }
        if notes.isEmpty == false { return notes.joined(separator: " · ") }
        return night.samples.compactMap(\.quality).first.map { "Quality \($0)/5" }
    }

    private func loadHealthMetrics(
        now: Date = Date(),
        requestRefresh: Bool
    ) async {
        if requestRefresh { await healthMetrics.requestAutomaticRefresh() }
        async let snapshot = healthMetrics.currentSnapshot(now: now)
        async let activity = healthMetrics.cachedHistory(
            domain: .activity,
            range: .thirtyDays,
            now: now
        )
        async let energy = healthMetrics.cachedHistory(
            domain: .energy,
            range: .thirtyDays,
            now: now
        )
        let values = await (snapshot, activity, energy)
        healthSnapshot = values.0
        movementHealthHistory = values.1.merging(values.2) { existing, incoming in
            incoming.isEmpty ? existing : incoming
        }
    }

    private func statusNotice(
        title: String,
        detail: String,
        symbol: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .lifeBoardClaySurface(.resting)
        .accessibilityElement(children: .contain)
    }

    private func emptyState(title: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ContentUnavailableView(title, systemImage: symbol, description: Text("Add a private manual record, or connect Apple Health to bring in available data."))
            HStack(spacing: 10) {
                Button(section.addTitle) { beginAdd() }.buttonStyle(.lifeBoardPrimary)
                if shouldOfferHealthConnection {
                    Button("Connect Health") { educationDomain = section.healthDomain }.buttonStyle(.lifeBoardChip)
                }
            }
        }
    }

    private var shouldOfferHealthConnection: Bool {
        guard V2FeatureFlags.healthIntegrationsV1Enabled,
              let status = healthSnapshot?.statuses[section.healthDomain] else { return false }
        if case .neverRequested = status.readRequestState { return true }
        return false
    }

    private func beginAdd() {
        clearEditingState()
        showsCapture = true
    }

    private func clearEditingState() {
        editingBodyMetric = nil
        editingWorkout = nil
        editingSleep = nil
        editingMovement = nil
    }

    private func beginEdit(_ value: BodyMetricSample) { editingBodyMetric = value; showsCapture = true }
    private func beginEdit(_ value: WorkoutRecord) { editingWorkout = value; showsCapture = true }
    private func beginEdit(_ value: SleepNote) { editingSleep = value; showsCapture = true }
    private func beginEdit(_ value: MovementContextRecord) { editingMovement = value; showsCapture = true }

    /// Today-first: the day's state and one obvious capture action lead the
    /// screen; history and analysis follow.
    ///
    /// Note the reading, not the presentation, carries the distinction between
    /// "logged today", "last known from an earlier day" and "nothing at all".
    /// The previous version collapsed the last two into one grey subheadline, so
    /// a stale value and an empty record looked the same.
    private var todayCard: some View {
        WellnessHero(
            label: "Today",
            reading: bodyMetricReading,
            provenance: nil,
            timeframe: bodyMetricTimeframe,
            actionTitle: todaySamples.isEmpty ? "Log today’s \(kind.title.lowercased())" : "Add another value",
            action: beginAdd
        )
        .accessibilityLabel("Today, \(kind.title)")
    }

    private var bodyMetricReading: MetricReading {
        if let sample = todaySamples.first {
            return .recorded(value: display(sample), unit: nil)
        }
        if let last = store.samples.first {
            return .stale(
                value: display(last),
                unit: nil,
                age: last.observedAt.formatted(date: .abbreviated, time: .omitted)
            )
        }
        return .noRecord
    }

    private var bodyMetricTimeframe: String? {
        guard let sample = todaySamples.first else { return nil }
        return "Logged \(sample.observedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var wellnessChart: some View {
        let values = Array(store.samples.prefix(30).reversed())
        return Chart(values) { sample in
            LineMark(
                x: .value("Date", sample.observedAt),
                y: .value(kind.title, displayValue(sample))
            )
            .foregroundStyle(Color(SemanticColorTokens.foundationSageAccent))
            .interpolationMethod(.catmullRom)
            PointMark(
                x: .value("Date", sample.observedAt),
                y: .value(kind.title, displayValue(sample))
            )
            .foregroundStyle(Color(SemanticColorTokens.foundationSageAccent))
            .symbolSize(28)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
        .frame(height: 148)
        // Sweeps when valid data first appears and again when the range
        // changes — which here means switching metric. Empty and denied states
        // never reach this branch, so a sweep can never imply data that is not
        // there.
        .lifeboardChartRevealSweep(progress: chartRevealProgress)
        .padding(16)
        // `ClaySurfaceModifier` already strokes the hairline. The explicit
        // overlay that used to sit here drew a second one on the same boundary
        // at double weight — the identical bug was fixed for the nutrition
        // chart and missed on this one.
        .lifeBoardClaySurface(.raised)
        .accessibilityLabel("\(kind.title) trend chart")
        .accessibilityValue(store.samples.isEmpty ? "No data" : "\(store.samples.count) entries. Latest \(display(store.samples[0])).")
    }

    @ViewBuilder
    private var sourceConflictsSection: some View {
        if !store.conflicts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Source review").font(Typography.sectionTitle())
                Text("These readings arrived close together from different sources. Choosing one changes only the display; source history stays intact.")
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                ForEach(store.conflicts) { conflict in
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(conflict.samples) { sample in
                            let isPreferred = conflict.preferredSample(using: store.preferences)?.id == sample.id
                            Button {
                                store.prefer(sampleID: sample.id, for: conflict.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(display(sample))
                                            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                                        Text("\(sourceLabel(sample.source)) · \(sample.observedAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                                    }
                                    Spacer()
                                    Image(systemName: isPreferred ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isPreferred
                                            ? Color(SemanticColorTokens.foundationSageAccent)
                                            : Color(SemanticColorTokens.inkTertiary))
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(display(sample)), \(sourceLabel(sample.source))")
                            .accessibilityValue(isPreferred ? "Preferred display reading" : "Not preferred")
                        }
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) { Divider() }
                }
            }
        }
    }

    private var enabledMetrics: [BodyMetricKind] {
        store.preferences.enabledMetrics.isEmpty ? BodyMetricKind.allCases : store.preferences.enabledMetrics
    }

    private func displayValue(_ sample: BodyMetricSample) -> Double {
        (try? sample.value(in: store.preferences.preferredUnit(for: sample.kind))) ?? sample.normalizedValue
    }

    private func display(_ sample: BodyMetricSample) -> String {
        let value = displayValue(sample)
        let unit = store.preferences.preferredUnit(for: sample.kind)
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit.symbol)"
    }

    private func sourceLabel(_ source: WellnessCaptureSource) -> String {
        switch source {
        case .manual: "Manual"
        case .healthKit: "Health"
        case .watch: "Watch"
        case .imported: "Imported"
        }
    }
}

/// One recorded reading.
///
/// Provenance moves from a grey caption into a chip beside the value, because
/// "where did this number come from" is the question people actually ask of a
/// health history, and DESIGN.md requires value, timeframe and source to travel
/// together. Manual entries get no chip — the absence is the signal, and a chip
/// reading "Manual" on every hand-typed row is noise.

private struct WellnessMetricCapture: View {
    let kind: BodyMetricKind
    let existing: BodyMetricSample?
    let onSave: (BodyMetricSample) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double
    @State private var unit: WellnessDisplayUnit
    @State private var pending: BodyMetricSample?
    @State private var reviewMessage: String?
    @State private var successTrigger = 0
    @State private var revealTrigger = 0

    init(
        kind: BodyMetricKind,
        existing: BodyMetricSample? = nil,
        lastValue: Double? = nil,
        onSave: @escaping (BodyMetricSample) -> Void
    ) {
        self.kind = kind
        self.existing = existing
        self.onSave = onSave
        let initialUnit = existing?.displayUnit ?? kind.canonicalUnit
        _unit = State(initialValue: initialUnit)
        _value = State(initialValue: existing.flatMap { try? $0.value(in: initialUnit) }
            ?? lastValue
            ?? Self.tape(for: kind, unit: initialUnit).start)
    }

    var body: some View {
        ComposerScaffold(
            title: kind.title,
            subtitle: "Scrub to the reading, or tap the number to type it.",
            confirmTitle: "Save",
            isConfirmEnabled: value > 0,
            identifier: "wellness.capture",
            onConfirm: prepare
        ) {
            WellnessCaptureValueSection(
                kind: kind,
                unit: $unit,
                value: $value,
                units: units
            )
            WellnessCaptureReviewSection(message: reviewMessage) {
                guard let pending else { return }
                onSave(pending)
                successTrigger &+= 1
                dismiss()
            }
        }
        .lifeboardCompletionBurst(trigger: successTrigger)
        .lifeboardHealthSyncPulse(trigger: successTrigger)
        // A vital under the finger warps as it moves; the review line settles in
        // rather than appearing. Both were available and neither was used here.
        .lifeboardVitalOrbWarp(trigger: successTrigger)
        .lifeboardContextLens(trigger: revealTrigger)
        .onAppear { revealTrigger &+= 1 }
        .lifeBoardMotion(.contentInsertion, value: reviewMessage)
    }

    private var units: [WellnessDisplayUnit] {
        switch kind {
        case .bodyMass: [.kilograms, .pounds]
        case .waistCircumference: [.centimeters, .inches]
        default: [kind.canonicalUnit]
        }
    }

    /// Sensible tape geometry per metric and unit. A weight tape stepping by 1 kg
    /// and a body-fat tape stepping by 1% are the same control with completely
    /// different physics; getting this wrong makes the scrub either useless or
    /// impossible to land.
    static func tape(
        for kind: BodyMetricKind,
        unit: WellnessDisplayUnit
    ) -> (range: ClosedRange<Double>, step: Double, coarse: Double, digits: Int, start: Double) {
        switch kind {
        case .bodyMass:
            unit == .pounds
                ? (40...660, 0.2, 10, 1, 165)
                : (20...300, 0.1, 5, 1, 75)
        case .bodyFatPercentage:
            (3...70, 0.1, 5, 1, 25)
        case .waistCircumference:
            unit == .inches
                ? (16...80, 0.25, 5, 1, 34)
                : (40...200, 0.5, 10, 1, 86)
        case .restingHeartRate:
            (30...200, 1, 10, 0, 60)
        }
    }

    private func prepare() {
        guard let sample = try? BodyMetricSample(
            id: existing?.id ?? UUID(),
            kind: kind,
            value: value,
            unit: unit,
            observedAt: existing?.observedAt ?? Date(),
            capturedTimeZone: existing?.capturedTimeZone ?? .autoupdatingCurrent,
            source: existing?.source ?? .manual,
            sourceIdentifier: existing?.sourceIdentifier,
            note: existing?.note,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        ) else { return }
        switch WellnessOutlierPolicy().review(kind: kind, normalizedValue: sample.normalizedValue) {
        case .accepted:
            onSave(sample)
            successTrigger &+= 1
            dismiss()
        case .requiresConfirmation(let message):
            // Unchanged behaviour: an implausible reading is never silently
            // rejected or silently accepted, it is handed back with the reason.
            pending = sample
            reviewMessage = message
        }
    }
}

private struct WellnessCaptureValueSection: View {
    let kind: BodyMetricKind
    @Binding var unit: WellnessDisplayUnit
    @Binding var value: Double
    let units: [WellnessDisplayUnit]

    var body: some View {
        let tape = WellnessMetricCapture.tape(for: kind, unit: unit)
        ComposerSection(kind.title) {
            ValueDrum(
                kind.title,
                value: $value,
                in: tape.range,
                step: tape.step,
                coarseStep: tape.coarse,
                unit: unit.symbol,
                fractionDigits: tape.digits,
                identifier: "wellness.capture.value"
            )
            if units.count > 1 {
                OptionRail(
                    "Unit",
                    selection: $unit,
                    values: units,
                    identifierPrefix: "wellness.capture.unit",
                    title: \.symbol
                )
            }
        }
    }
}

private struct WellnessCaptureReviewSection: View {
    let message: String?
    let confirm: () -> Void

    var body: some View {
        if let message {
            ComposerSection("Please confirm", detail: message) {
                Button("Save this value anyway", action: confirm)
                    .buttonStyle(.lifeBoardPrimary)
                    .accessibilityIdentifier("wellness.capture.confirmOutlier")
            }
        }
    }
}

private struct WorkoutCaptureView: View {
    let existing: WorkoutRecord?
    let onSave: (WorkoutRecord) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var activity: String
    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var distanceKilometers: Double
    @State private var energyKilocalories: Double
    @State private var note: String
    @State private var errorMessage: String?

    init(existing: WorkoutRecord?, onSave: @escaping (WorkoutRecord) -> Void) {
        self.existing = existing
        self.onSave = onSave
        let now = Date()
        _activity = State(initialValue: existing?.activityKind ?? "")
        _startedAt = State(initialValue: existing?.startedAt ?? now.addingTimeInterval(-3_600))
        _endedAt = State(initialValue: existing?.endedAt ?? now)
        _distanceKilometers = State(initialValue: (existing?.distanceMeters ?? 0) / 1_000)
        _energyKilocalories = State(initialValue: existing?.energyKilocalories ?? 0)
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        ComposerScaffold(
            title: existing == nil ? "Add Workout" : "Edit Workout",
            subtitle: "A factual record of what you did.",
            confirmTitle: "Save",
            isConfirmEnabled: activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && endedAt >= startedAt,
            identifier: "wellness.workout.capture",
            onConfirm: save
        ) {
            ComposerSection("Workout") {
                ComposerField("Activity", prompt: "Walk, run, strength…", text: $activity, identifier: "wellness.workout.activity")
                DateCapsuleRow("Started", selection: $startedAt, identifier: "wellness.workout.started")
                DateCapsuleRow("Ended", selection: $endedAt, minimum: startedAt, identifier: "wellness.workout.ended")
                ComposerNumberField("Distance", value: $distanceKilometers, unit: "km", identifier: "wellness.workout.distance")
                ComposerNumberField("Active energy", value: $energyKilocalories, unit: "kcal", identifier: "wellness.workout.energy")
                ComposerField("Note", prompt: "Optional context", text: $note, shape: .prose(lineLimit: 2...5), identifier: "wellness.workout.note")
            }
            CaptureErrorSection(message: errorMessage)
        }
    }

    private func save() {
        do {
            let value = try WorkoutRecord(
                id: existing?.id ?? UUID(),
                activityKind: activity,
                startedAt: startedAt,
                endedAt: endedAt,
                energyKilocalories: energyKilocalories > 0 ? energyKilocalories : nil,
                distanceMeters: distanceKilometers > 0 ? distanceKilometers * 1_000 : nil,
                source: .manual,
                note: note,
                createdAt: existing?.createdAt ?? Date(),
                updatedAt: Date()
            )
            onSave(value)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct SleepNoteCaptureView: View {
    let existing: SleepNote?
    let onSave: (SleepNote) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var quality: Int
    @State private var note: String
    @State private var errorMessage: String?

    init(existing: SleepNote?, onSave: @escaping (SleepNote) -> Void) {
        self.existing = existing
        self.onSave = onSave
        let now = Date()
        _startedAt = State(initialValue: existing?.startedAt ?? now.addingTimeInterval(-8 * 3_600))
        _endedAt = State(initialValue: existing?.endedAt ?? now)
        _quality = State(initialValue: existing?.quality ?? 0)
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        ComposerScaffold(
            title: existing == nil ? "Add Sleep Note" : "Edit Sleep Note",
            subtitle: "Describe the night without turning it into a score.",
            confirmTitle: "Save",
            isConfirmEnabled: endedAt >= startedAt,
            identifier: "wellness.sleep.capture",
            onConfirm: save
        ) {
            ComposerSection("Sleep") {
                DateCapsuleRow("Sleep time", selection: $startedAt, identifier: "wellness.sleep.started")
                DateCapsuleRow("Wake time", selection: $endedAt, minimum: startedAt, identifier: "wellness.sleep.ended")
                OptionRail(
                    "Quality",
                    selection: $quality,
                    values: Array(0...5),
                    identifierPrefix: "wellness.sleep.quality",
                    title: { $0 == 0 ? "Not rated" : "\($0)" }
                )
                ComposerField("Note", prompt: "Optional context", text: $note, shape: .prose(lineLimit: 2...6), identifier: "wellness.sleep.note")
            }
            CaptureErrorSection(message: errorMessage)
        }
    }

    private func save() {
        do {
            let value = try SleepNote(
                id: existing?.id ?? UUID(),
                startedAt: startedAt,
                endedAt: endedAt,
                quality: quality == 0 ? nil : quality,
                note: note,
                source: .manual,
                capturedTimeZone: existing.flatMap { TimeZone(identifier: $0.capturedTimeZoneIdentifier) } ?? .autoupdatingCurrent,
                createdAt: existing?.createdAt ?? Date(),
                updatedAt: Date()
            )
            onSave(value)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct MovementCaptureView: View {
    let existing: MovementContextRecord?
    let onSave: (MovementContextRecord) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var steps: Double
    @State private var distanceKilometers: Double
    @State private var energyKilocalories: Double
    @State private var errorMessage: String?

    init(existing: MovementContextRecord?, onSave: @escaping (MovementContextRecord) -> Void) {
        self.existing = existing
        self.onSave = onSave
        let now = Date()
        _startedAt = State(initialValue: existing?.startedAt ?? Calendar.current.startOfDay(for: now))
        _endedAt = State(initialValue: existing?.endedAt ?? now)
        _steps = State(initialValue: Double(existing?.steps ?? 0))
        _distanceKilometers = State(initialValue: (existing?.distanceMeters ?? 0) / 1_000)
        _energyKilocalories = State(initialValue: existing?.activeEnergyKilocalories ?? 0)
    }

    private var hasMeasurement: Bool { steps > 0 || distanceKilometers > 0 || energyKilocalories > 0 }

    var body: some View {
        ComposerScaffold(
            title: existing == nil ? "Add Movement" : "Edit Movement",
            subtitle: "Record only the values you know.",
            confirmTitle: "Save",
            isConfirmEnabled: hasMeasurement && endedAt >= startedAt,
            identifier: "wellness.movement.capture",
            onConfirm: save
        ) {
            ComposerSection("Interval") {
                DateCapsuleRow("Started", selection: $startedAt, identifier: "wellness.movement.started")
                DateCapsuleRow("Ended", selection: $endedAt, minimum: startedAt, identifier: "wellness.movement.ended")
            }
            ComposerSection("Measurements", footer: "Enter at least one value. Zero or unknown fields are not saved.") {
                ComposerNumberField("Steps", value: $steps, format: .number.precision(.fractionLength(0)), unit: "steps", identifier: "wellness.movement.steps")
                ComposerNumberField("Distance", value: $distanceKilometers, unit: "km", identifier: "wellness.movement.distance")
                ComposerNumberField("Active energy", value: $energyKilocalories, unit: "kcal", identifier: "wellness.movement.energy")
            }
            CaptureErrorSection(message: errorMessage)
        }
    }

    private func save() {
        do {
            let value = try MovementContextRecord(
                id: existing?.id ?? UUID(),
                startedAt: startedAt,
                endedAt: endedAt,
                steps: steps > 0 ? Int(steps.rounded()) : nil,
                distanceMeters: distanceKilometers > 0 ? distanceKilometers * 1_000 : nil,
                activeEnergyKilocalories: energyKilocalories > 0 ? energyKilocalories : nil,
                source: .manual,
                createdAt: existing?.createdAt ?? Date(),
                updatedAt: Date()
            )
            onSave(value)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct CaptureErrorSection: View {
    let message: String?

    var body: some View {
        if let message {
            ComposerSection {
                Label(message, systemImage: "exclamationmark.circle")
                    .foregroundStyle(Color(SemanticColorTokens.foundationDanger))
            }
        }
    }
}

private extension Comparable { func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) } }


// MARK: - Wellness areas

/// The four recorded areas, lifted out of `WellnessView`'s declaration.
///
/// Same file, so these still reach the view's `private` state. The move is for
/// the `-Onone` stack budget the file-size ratchet tracks as `largest`: Debug
/// inlines computed `some View` properties into their caller's frame, so it is
/// the size of the *type* that overflows the main stack, not the size of the
/// file.
extension WellnessView {
    private var bodyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            LensPicker(
                "Body metric",
                selection: $kind,
                values: enabledMetrics,
                identifierPrefix: "wellness.metric",
                title: \.title,
                identifier: \.rawValue
            )
            todayCard
            if store.samples.isEmpty {
                emptyState(title: "No \(kind.title.lowercased()) entries", symbol: "waveform.path.ecg")
            } else {
                wellnessChart
            }
            sourceConflictsSection
            VStack(alignment: .leading, spacing: 10) {
                Text("History").font(Typography.sectionTitle())
                if filteredSamples.isEmpty, searchText.isEmpty == false {
                    Text("No entries match “\(searchText)”. History is unchanged.")
                        .font(.subheadline).foregroundStyle(Color(SemanticColorTokens.inkSecondary)).padding(.vertical, 8)
                }
                ForEach(filteredSamples) { sample in
                    WellnessHistoryRow(
                        timestamp: sample.observedAt,
                        value: display(sample),
                        provenance: sourceLabel(sample.source),
                        isImported: sample.source.permitsManualCorrection == false,
                        note: sample.note,
                        edit: sample.source.permitsManualCorrection ? { beginEdit(sample) } : nil,
                        delete: sample.source.permitsManualCorrection ? { Task { await store.delete(sample, kind: kind) } } : nil
                    )
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(kind.title) history table")
        }
    }

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let latest = filteredWorkouts.first {
                WellnessHero(
                    label: latest.activityKind,
                    reading: .recorded(value: Self.durationLabel(latest.duration), unit: nil),
                    provenance: sourceLabel(latest.source),
                    timeframe: latest.startedAt.formatted(date: .abbreviated, time: .shortened),
                    actionTitle: section.addTitle,
                    action: beginAdd
                )
            } else {
                emptyState(title: "No workouts recorded", symbol: "figure.run")
            }
            if store.workouts.isEmpty == false {
                // The trailing-week rollup is two facts, so it reads as two
                // metrics rather than as one sentence a person has to parse.
                HStack(spacing: 8) {
                    MetricHeroWell(MetricHero(
                        label: "Last 7 days",
                        reading: .recorded(value: Self.durationLabel(trailingSevenDayWorkoutDuration), unit: nil),
                        accessibilityID: "wellness.workouts.week.duration"
                    ))
                    MetricHeroWell(MetricHero(
                        label: "Sessions",
                        reading: trailingSevenDayWorkoutCount == 0
                            ? .explicitZero(unit: nil)
                            : .recorded(value: trailingSevenDayWorkoutCount.formatted(), unit: nil),
                        accessibilityID: "wellness.workouts.week.count"
                    ))
                }
            }
            if store.workouts.count > 1 {
                TrendChart(
                    points: store.workouts
                        .prefix(30)
                        .map { HomeSeriesPoint(date: $0.startedAt, value: max(0, $0.duration / 60)) }
                        .sorted { $0.date < $1.date },
                    tint: Color(SemanticColorTokens.foundationApricotAccent),
                    unit: "minutes"
                )
                .frame(height: 120)
            }
            Text("History").font(Typography.sectionTitle())
            ForEach(filteredWorkouts) { workout in
                WellnessHistoryRow(
                    timestamp: workout.startedAt,
                    value: "\(workout.activityKind) · \(Self.durationLabel(workout.duration))",
                    provenance: sourceLabel(workout.source),
                    isImported: workout.source.permitsManualCorrection == false,
                    note: workout.note,
                    edit: workout.source.permitsManualCorrection ? { beginEdit(workout) } : nil,
                    delete: workout.source.permitsManualCorrection ? { Task { await store.delete(kind: .workout, id: workout.id, selectedKind: kind) } } : nil
                )
            }
        }
    }

    private var sleepSection: some View {
        let nights = filteredSleepNights
        return VStack(alignment: .leading, spacing: 16) {
            if let latest = nights.first {
                WellnessHero(
                    label: "Last night",
                    reading: .recorded(value: Self.durationLabel(latest.totalDuration), unit: nil),
                    provenance: sleepNightDetail(latest),
                    timeframe: nil,
                    actionTitle: section.addTitle,
                    action: beginAdd
                )
            } else {
                emptyState(title: "No sleep notes recorded", symbol: "bed.double")
            }
            if nights.isEmpty == false {
                let recent = Array(nights.prefix(7))
                let average = recent.reduce(0) { $0 + $1.totalDuration } / Double(recent.count)
                let rated = recent.flatMap(\.samples).compactMap(\.quality)
                HStack(spacing: 8) {
                    MetricHeroWell(MetricHero(
                        label: "Recent average",
                        reading: .recorded(value: Self.durationLabel(average), unit: nil),
                        timeframe: "Last \(recent.count) night\(recent.count == 1 ? "" : "s")",
                        accessibilityID: "wellness.sleep.average"
                    ))
                    // Quality is genuinely absent on most nights. Reporting the
                    // count of *rated* nights keeps that visible instead of
                    // averaging over nights that were never rated at all.
                    MetricHeroWell(MetricHero(
                        label: "Quality rated",
                        reading: rated.isEmpty
                            ? .noRecord
                            : .recorded(value: rated.count.formatted(), unit: rated.count == 1 ? "night" : "nights"),
                        accessibilityID: "wellness.sleep.quality"
                    ))
                }
            }
            if nights.count > 1 {
                TrendChart(
                    points: nights
                        .prefix(30)
                        .map { HomeSeriesPoint(date: $0.night, value: max(0, $0.totalDuration / 3_600)) }
                        .sorted { $0.date < $1.date },
                    tint: Color(SemanticColorTokens.foundationSageAccent),
                    unit: "hours"
                )
                .frame(height: 120)
            }
            Text("Nightly history").font(Typography.sectionTitle())
            ForEach(nights) { night in
                let editable = night.samples.count == 1
                    ? night.samples.first(where: { $0.source.permitsManualCorrection })
                    : nil
                WellnessHistoryRow(
                    timestamp: night.startedAt,
                    value: Self.durationLabel(night.totalDuration),
                    provenance: sleepNightSources(night),
                    isImported: editable == nil,
                    note: sleepNightNote(night),
                    edit: editable.map { value in { beginEdit(value) } },
                    delete: editable.map { value in
                        { Task { await store.delete(kind: .sleep, id: value.id, selectedKind: kind) } }
                    }
                )
            }
        }
    }

    private var movementSection: some View {
        let summary = movementSummary
        let stepPoints = movementStepPoints
        return VStack(alignment: .leading, spacing: 16) {
            if summary.steps != nil || summary.distanceMeters != nil || summary.activeEnergyKilocalories != nil {
                WellnessHero(
                    label: "Today",
                    reading: movementReading(summary),
                    provenance: movementSummaryDetail(summary),
                    timeframe: nil,
                    actionTitle: section.addTitle,
                    action: beginAdd
                )
            } else {
                emptyState(title: "No movement recorded", symbol: "figure.walk")
            }
            if stepPoints.count > 1 {
                TrendChart(points: stepPoints, tint: Color(SemanticColorTokens.foundationSageAccent), unit: "steps")
                    .frame(height: 120)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom records").font(Typography.sectionTitle())
                Text("Custom LifeBoard records stay separate from Apple Health totals.")
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                if filteredMovements.isEmpty {
                    Text("No custom movement records")
                        .font(.subheadline)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                } else {
                    ForEach(filteredMovements) { movement in
                        WellnessHistoryRow(
                            timestamp: movement.startedAt,
                            value: movement.steps.map { "\($0.formatted()) steps" } ?? "Movement",
                            provenance: sourceLabel(movement.source),
                            isImported: movement.source.permitsManualCorrection == false,
                            note: movementDetail(movement),
                            edit: movement.source.permitsManualCorrection ? { beginEdit(movement) } : nil,
                            delete: movement.source.permitsManualCorrection ? { Task { await store.delete(kind: .movement, id: movement.id, selectedKind: kind) } } : nil
                        )
                    }
                }
            }
        }
    }

    /// Steps lead, distance is the fallback, and "recorded" is the last resort.
    ///
    /// Kept as an explicit ladder rather than a `??` chain so the unit travels
    /// with the value it belongs to — the previous version formatted the value
    /// and dropped the unit into the same string, which is what made the numeral
    /// impossible to set at metric scale.
    private func movementReading(_ summary: MovementSummaryProjection) -> MetricReading {
        if let steps = summary.steps {
            return steps == 0
                ? .explicitZero(unit: "steps")
                : .recorded(value: steps.formatted(), unit: "steps")
        }
        if let distance = summary.distanceMeters {
            return .recorded(value: String(format: "%.1f", distance / 1_000), unit: "km")
        }
        return .recorded(value: "Recorded", unit: nil)
    }

}
