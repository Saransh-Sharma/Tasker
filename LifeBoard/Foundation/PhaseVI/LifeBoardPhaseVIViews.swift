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
    var errorMessage: String?
    let repository: any NutritionRepository

    init(repository: any NutritionRepository) { self.repository = repository }

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

    func log(food: FoodItem, serving: FoodServingDefinition, quantity: Double, slot: NutritionMealSlot) async {
        do {
            try await repository.save(food)
            try await repository.save(NutritionLogEntry(food: food, mealSlot: slot, quantity: quantity, serving: serving))
            await load()
            LifeBoardSystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = "That meal could not be saved. Review the serving and try again." }
    }

    func delete(_ entry: NutritionLogEntry) async {
        do {
            try await repository.deleteLog(id: entry.id)
            recentlyDeleted = entry
            await load()
            LifeBoardSystemSurfaceRefresher.requestRefreshSoon()
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
            LifeBoardSystemSurfaceRefresher.requestRefreshSoon()
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

    var total: NutritionMacros { entries.reduce(.zero) { $0.adding($1.resolvedMacrosSnapshot) } }
}

struct LifeBoardNutritionView: View {
    @State private var store: NutritionTimelineStore
    @State private var showsComposer = false
    @State private var pendingDeletion: NutritionLogEntry?
    @State private var scannedFood: FoodItem?
    @State private var showsBarcodeScanner = false
    @State private var scanMessage: String?
    @State private var showsVoiceCapture = false
    @State private var voiceFoodName: String?
    private let scanDeduplicator = NutritionScanDeduplicator()

    init(repository: any NutritionRepository) {
        _store = State(initialValue: NutritionTimelineStore(repository: repository))
    }

    var body: some View {
        ScrollView {
            timelineContent
                .padding(20)
        }
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid).ignoresSafeArea())
        .navigationTitle("Nutrition")
        .toolbar { nutritionToolbar }
        .task { await store.load() }
        .refreshable { await store.load() }
        .sheet(isPresented: $showsComposer) {
            NutritionLogComposer(prefilledFood: scannedFood, prefilledName: voiceFoodName, onSave: logMeal)
        }
        .sheet(isPresented: $showsVoiceCapture) {
            voiceCaptureSheet
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
            Button("Scan barcode", systemImage: "barcode.viewfinder", action: beginBarcodeScan)
            Button("Log by voice", systemImage: "waveform") { showsVoiceCapture = true }
            Button("Log meal", systemImage: "plus") {
                scannedFood = nil
                voiceFoodName = nil
                showsComposer = true
            }
        }
    }

    private func beginBarcodeScan() {
        guard LifeBoardBarcodeScannerCapability.isAvailable else {
            scanMessage = LifeBoardBarcodeScanError.unavailable.localizedDescription
            return
        }
        showsBarcodeScanner = true
    }

    private func logMeal(food: FoodItem, serving: FoodServingDefinition, quantity: Double, slot: NutritionMealSlot) {
        Task { await store.log(food: food, serving: serving, quantity: quantity, slot: slot) }
    }

    private var barcodeScannerCover: some View {
        LifeBoardBarcodeScannerView(completion: handleBarcodeResult)
            .ignoresSafeArea()
    }

    private func handleBarcodeResult(_ result: Result<String, Error>) {
        showsBarcodeScanner = false
        switch result {
        case .success(let barcode):
            Task {
                guard await scanDeduplicator.shouldAccept(barcode: barcode) else { return }
                if let food = await store.food(barcode: barcode) {
                    scannedFood = food
                    showsComposer = true
                } else {
                    // Remote lookup stays an explicit future opt-in; today the
                    // library is local-first only, and we say so plainly.
                    scanMessage = "No local match. You can enter the food manually; online lookup is currently off."
                }
            }
        case .failure(let error):
            scanMessage = error.localizedDescription
        }
    }

    private var timelineHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today’s nourishment").font(LifeBoardFoundationTypography.screenTitle())
            Text("A factual record of what you choose to log—never a grade.")
                .font(.subheadline).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        }
    }

    @ViewBuilder
    private var timelineContent: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            timelineHeader
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
            defer { try? LifeBoardJournalAudioFiles.delete(relativePath: path) }
            let trimmed = transcription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard trimmed.isEmpty == false else { return false }
            voiceFoodName = trimmed
            scannedFood = nil
            showsVoiceCapture = false
            showsComposer = true
            return true
        }
        return NavigationStack {
            LifeBoardJournalAudioCapture(purpose: .search, onSave: onSave)
                .navigationTitle("Say the food")
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private func undoBanner(_ deleted: NutritionLogEntry) -> some View {
        HStack(spacing: 10) {
            Text("Removed “\(deleted.foodNameSnapshot)”")
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            Spacer(minLength: 8)
            Button("Undo") { Task { await store.undoDelete() } }
                .font(.caption.weight(.semibold))
            Button {
                store.dismissUndo()
            } label: {
                Image(systemName: "xmark").font(.caption2.weight(.bold)).frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss undo")
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSelected), in: RoundedRectangle(cornerRadius: 15))
    }

    private var macroSummary: some View {
        HStack(spacing: 8) {
            macro("Energy", value: "\(Int(store.total.calories.rounded())) kcal")
            macro("Protein", value: "\(Int(store.total.proteinGrams.rounded())) g")
            macro("Carbs", value: "\(Int(store.total.carbohydrateGrams.rounded())) g")
            macro("Fat", value: "\(Int(store.total.fatGrams.rounded())) g")
        }
        .accessibilityElement(children: .contain)
    }

    private func macro(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(10)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSelected), in: RoundedRectangle(cornerRadius: 15))
    }

    /// Honest trailing-week report: recorded energy per day, no goals or
    /// grades implied. Days without logs stay visibly empty.
    private var weeklyReportSection: some View {
        let report = store.weeklyReport
        return VStack(alignment: .leading, spacing: 10) {
            Text("Past 7 days").font(LifeBoardFoundationTypography.sectionTitle())
            if report.allSatisfy({ $0.calories == 0 }) {
                Text("Logged meals will build this picture over the week.")
                    .font(.subheadline).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            } else {
                Chart(report) { item in
                    BarMark(
                        x: .value("Day", item.day, unit: .day),
                        y: .value("Energy", item.calories)
                    )
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationSunAccent))
                    .cornerRadius(5)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
                .frame(height: 132)
                .padding(14)
                .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color(LifeBoardColorTokens.foundationHairline)) }
                .accessibilityLabel("Energy logged per day over the past week")
                .accessibilityValue(report.map { "\($0.day.formatted(.dateTime.weekday(.abbreviated))): \(Int($0.calories.rounded())) kilocalories" }.joined(separator: ", "))
            }
        }
    }

}

private struct NutritionMealSectionView: View {
    let slot: NutritionMealSlot
    let entries: [NutritionLogEntry]
    let onDelete: (NutritionLogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(slot.rawValue.capitalized).font(LifeBoardFoundationTypography.sectionTitle())
            if entries.isEmpty {
                Text("Nothing logged—and nothing required.")
                    .font(.subheadline).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary)).padding(.vertical, 8)
            } else {
                ForEach(entries) { entry in
                    row(entry)
                }
            }
        }
    }

    private func row(_ entry: NutritionLogEntry) -> some View {
        let quantityText = entry.quantity.formatted()
        let calorieCount = Int(entry.resolvedMacrosSnapshot.calories.rounded())
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.foodNameSnapshot).font(.headline)
                Text("\(quantityText) × \(entry.servingNameSnapshot) · \(calorieCount) kcal")
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
            Menu {
                Button("Remove", systemImage: "trash", role: .destructive) { onDelete(entry) }
            } label: {
                Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
            }
        }
        .padding(14)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color(LifeBoardColorTokens.foundationHairline)) }
    }
}

private struct NutritionLogComposer: View {
    let onSave: (FoodItem, FoodServingDefinition, Double, NutritionMealSlot) -> Void
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

    init(
        prefilledFood: FoodItem? = nil,
        prefilledName: String? = nil,
        onSave: @escaping (FoodItem, FoodServingDefinition, Double, NutritionMealSlot) -> Void
    ) {
        self.onSave = onSave
        _name = State(initialValue: prefilledFood?.name ?? prefilledName ?? "")
        _calories = State(initialValue: prefilledFood.map { String($0.macrosPer100Grams.calories) } ?? "")
        _protein = State(initialValue: prefilledFood.map { String($0.macrosPer100Grams.proteinGrams) } ?? "")
        _carbohydrates = State(initialValue: prefilledFood.map { String($0.macrosPer100Grams.carbohydrateGrams) } ?? "")
        _fat = State(initialValue: prefilledFood.map { String($0.macrosPer100Grams.fatGrams) } ?? "")
        _servingGrams = State(initialValue: prefilledFood?.servings.first.map { String($0.grams) } ?? "100")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") { TextField("Name", text: $name); Picker("Meal", selection: $slot) { ForEach(NutritionMealSlot.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } } }
                Section("Per 100 grams") {
                    TextField("Calories", text: $calories).keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $protein).keyboardType(.decimalPad)
                    TextField("Carbohydrates (g)", text: $carbohydrates).keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fat).keyboardType(.decimalPad)
                }
                Section("Serving") {
                    TextField("Serving grams", text: $servingGrams).keyboardType(.decimalPad)
                    Stepper("Quantity \(quantity.formatted())", value: $quantity, in: 0.25...20, step: 0.25)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.secondary) }
            }
            .navigationTitle("Review meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Log") { save() } }
            }
        }
    }

    private func save() {
        do {
            let macros = try NutritionMacros(
                calories: try number(calories), proteinGrams: try number(protein),
                carbohydrateGrams: try number(carbohydrates), fatGrams: try number(fat)
            )
            let serving = try FoodServingDefinition(name: "serving", grams: try number(servingGrams))
            let food = try FoodItem(name: name, macrosPer100Grams: macros, servings: [serving])
            onSave(food, serving, quantity, slot); dismiss()
        } catch { errorMessage = "Check the name, macros, and serving before logging." }
    }

    private func number(_ text: String) throws -> Double {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value >= 0 else { throw NutritionError.invalidMacros }
        return value
    }
}

@MainActor @Observable
final class WellnessHistoryStore {
    private(set) var samples: [BodyMetricSample] = []
    var errorMessage: String?
    let repository: any WellnessRepository
    init(repository: any WellnessRepository) { self.repository = repository }
    func load(kind: BodyMetricKind) async { do { samples = try await repository.bodyMetricSamples(kind: kind); errorMessage = nil } catch { errorMessage = "Wellness history is unavailable right now." } }
    func save(_ sample: BodyMetricSample, kind: BodyMetricKind) async { do { try await repository.save(sample); await load(kind: kind); LifeBoardSystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = "That measurement could not be saved." } }
    func delete(_ sample: BodyMetricSample, kind: BodyMetricKind) async { do { try await repository.delete(kind: .bodyMetric, id: sample.id); await load(kind: kind); LifeBoardSystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = "That measurement could not be removed." } }
}

struct LifeBoardWellnessView: View {
    @State private var store: WellnessHistoryStore
    @State private var kind: BodyMetricKind = .bodyMass
    @State private var showsCapture = false
    @State private var searchText = ""
    init(repository: any WellnessRepository) { _store = State(initialValue: WellnessHistoryStore(repository: repository)) }

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
                Picker("Metric", selection: $kind) { ForEach(BodyMetricKind.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                todayCard
                if store.samples.isEmpty {
                    ContentUnavailableView(
                        "No \(kind.title.lowercased()) entries",
                        systemImage: "waveform.path.ecg",
                        description: Text(V2FeatureFlags.healthIntegrationsV1Enabled
                            ? "Add a manual value, or allow Health access in Settings to bring in readings."
                            : "Add a manual value. Health import is currently off, so nothing arrives automatically.")
                    )
                } else {
                    wellnessChart
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("History").font(LifeBoardFoundationTypography.sectionTitle())
                    if filteredSamples.isEmpty, searchText.isEmpty == false {
                        Text("No entries match “\(searchText)”. History is unchanged.")
                            .font(.subheadline).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary)).padding(.vertical, 8)
                    }
                    ForEach(filteredSamples) { sample in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sample.observedAt.formatted(date: .abbreviated, time: .shortened))
                                if sample.source == .healthKit {
                                    Text("From Health").font(.caption2).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                                }
                            }
                            Spacer(); Text(display(sample)).monospacedDigit()
                            Menu { Button("Delete", role: .destructive) { Task { await store.delete(sample, kind: kind) } } } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                        }
                        .padding(12).background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 16))
                    }
                }.accessibilityElement(children: .contain).accessibilityLabel("\(kind.title) history table")
            }.padding(20)
        }
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid).ignoresSafeArea())
        .navigationTitle("Wellness")
        .searchable(text: $searchText, prompt: "Search values or dates")
        .toolbar { Button("Add value", systemImage: "plus") { showsCapture = true } }
        .task(id: kind) { await store.load(kind: kind) }
        .sheet(isPresented: $showsCapture) { WellnessMetricCapture(kind: kind) { value in Task { await store.save(value, kind: kind) } } }
    }

    /// Today-first: the day's state and one obvious capture action lead the
    /// screen; history and analysis follow.
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today").font(.caption.weight(.semibold)).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            if let sample = todaySamples.first {
                Text(display(sample)).font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
                Text("Logged \(sample.observedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            } else {
                Text(store.samples.first.map { "Last: \(display($0)) · \($0.observedAt.formatted(date: .abbreviated, time: .omitted))" } ?? "Nothing logged yet")
                    .font(.subheadline).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Button {
                showsCapture = true
            } label: {
                Label(todaySamples.isEmpty ? "Log today’s \(kind.title.lowercased())" : "Add another value", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(LifeBoardColorTokens.inkPrimary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSelected), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today, \(kind.title)")
    }

    private var wellnessChart: some View {
        let values = Array(store.samples.prefix(30).reversed())
        return Chart(values) { sample in
            LineMark(
                x: .value("Date", sample.observedAt),
                y: .value(kind.title, displayValue(sample))
            )
            .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
            .interpolationMethod(.catmullRom)
            PointMark(
                x: .value("Date", sample.observedAt),
                y: .value(kind.title, displayValue(sample))
            )
            .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
            .symbolSize(28)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
        .frame(height: 148)
        .padding(16)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Color(LifeBoardColorTokens.foundationHairline)) }
        .accessibilityLabel("\(kind.title) trend chart")
        .accessibilityValue(store.samples.isEmpty ? "No data" : "\(store.samples.count) entries. Latest \(display(store.samples[0])).")
    }

    private func displayValue(_ sample: BodyMetricSample) -> Double {
        (try? sample.value(in: sample.displayUnit)) ?? sample.normalizedValue
    }

    private func display(_ sample: BodyMetricSample) -> String { let value = displayValue(sample); return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(sample.displayUnit.symbol)" }
}

private struct WellnessMetricCapture: View {
    let kind: BodyMetricKind
    let onSave: (BodyMetricSample) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var unit: WellnessDisplayUnit
    @State private var pending: BodyMetricSample?
    @State private var reviewMessage: String?
    init(kind: BodyMetricKind, onSave: @escaping (BodyMetricSample) -> Void) { self.kind = kind; self.onSave = onSave; _unit = State(initialValue: kind.canonicalUnit) }
    var body: some View {
        NavigationStack { Form {
            Section(kind.title) { TextField("Value", text: $value).keyboardType(.decimalPad); Picker("Unit", selection: $unit) { ForEach(units, id: \.self) { Text($0.symbol).tag($0) } }; Stepper("Adjust", onIncrement: { adjust(1) }, onDecrement: { adjust(-1) }).accessibilityHint("Changes the value by one \(unit.symbol)") }
            if let reviewMessage { Section("Please confirm") { Text(reviewMessage); Button("Save this value anyway") { if let pending { onSave(pending); dismiss() } } } }
        }.navigationTitle("Review measurement").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { prepare() }.disabled(Double(value) == nil) } } }
    }
    private var units: [WellnessDisplayUnit] { switch kind { case .bodyMass: [.kilograms, .pounds]; case .waistCircumference: [.centimeters, .inches]; default: [kind.canonicalUnit] } }
    private func adjust(_ delta: Double) { value = String(((Double(value) ?? 0) + delta).clamped(to: 0...10_000)) }
    private func prepare() { guard let number = Double(value), let sample = try? BodyMetricSample(kind: kind, value: number, unit: unit) else { return }; switch WellnessOutlierPolicy().review(kind: kind, normalizedValue: sample.normalizedValue) { case .accepted: onSave(sample); dismiss(); case .requiresConfirmation(let message): pending = sample; reviewMessage = message } }
}

private extension Comparable { func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) } }

@MainActor @Observable
final class LifeMomentsStore {
    private(set) var moments: [LifeMoment] = []
    var errorMessage: String?
    let repository: any LifeMomentRepository
    init(repository: any LifeMomentRepository) { self.repository = repository }
    func load() async { do { moments = try await repository.moments(includeArchived: false); errorMessage = nil } catch { errorMessage = "Moments are unavailable right now." } }
    func save(_ value: LifeMoment) async { do { try await repository.save(value); await load(); LifeBoardSystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = error.localizedDescription } }
    func archive(_ value: LifeMoment) async { do { try await repository.archive(id: value.id, at: Date()); await load(); LifeBoardSystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = error.localizedDescription } }
    func delete(_ value: LifeMoment) async { do { try await repository.delete(id: value.id); await load(); LifeBoardSystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = error.localizedDescription } }
}

struct LifeBoardLifeMomentsView: View {
    @State private var store: LifeMomentsStore
    @State private var showsComposer = false
    @State private var editing: LifeMoment?
    @State private var searchText = ""
    init(repository: any LifeMomentRepository) { _store = State(initialValue: LifeMomentsStore(repository: repository)) }

    private var filteredMoments: [LifeMoment] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard query.isEmpty == false else { return store.moments }
        return store.moments.filter {
            $0.title.lowercased().contains(query) || ($0.note?.lowercased().contains(query) ?? false)
        }
    }

    /// Explicit, user-triggered JSON export. Nothing leaves the device unless
    /// the user picks a share destination themselves.
    private var exportPayload: String {
        struct Export: Codable {
            let title: String; let kind: String; let eventDate: Date
            let recurrence: String; let note: String?
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let values = store.moments.map { moment in
            let recurrence: String = switch moment.recurrenceRule {
            case .none: "never"
            case .weekly: "weekly"
            case .monthly: "monthly"
            case .yearly: "yearly"
            case .everyDays(let days): "every \(days) days"
            }
            return Export(title: moment.title, kind: moment.kind.rawValue, eventDate: moment.eventDate,
                          recurrence: recurrence, note: moment.note)
        }
        return (try? encoder.encode(values)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    var body: some View {
        List {
            Section {
                if store.moments.isEmpty { ContentUnavailableView("Keep a meaningful date close", systemImage: "sparkles", description: Text("Countdowns and anniversaries stay private unless you allow Home display.")) }
                ForEach(filteredMoments) { moment in
                    Button { editing = moment; showsComposer = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: moment.kind == .countdown ? "hourglass" : "calendar.badge.heart").frame(width: 30)
                            VStack(alignment: .leading) { Text(moment.title).font(.headline); Text(moment.eventDate.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary) }
                            Spacer(); Text(moment.calendarDaysUntilNextOccurrence(from: Date()).map { $0 == 0 ? "Today" : "\($0)d" } ?? "Past").font(.subheadline.monospacedDigit().weight(.semibold))
                        }.frame(minHeight: 54)
                    }.buttonStyle(.plain).swipeActions { Button("Archive") { Task { await store.archive(moment) } }.tint(.orange); Button("Delete", role: .destructive) { Task { await store.delete(moment) } } }
                }
            } header: { Text("Meaningful moments") }
        }
        .scrollContentBackground(.hidden).background(Color(LifeBoardColorTokens.foundationSurfaceSolid))
        .navigationTitle("Life Moments")
        .searchable(text: $searchText, prompt: "Search moments")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if store.moments.isEmpty == false {
                    ShareLink(item: exportPayload, preview: SharePreview("Life Moments export")) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
                Button("Add moment", systemImage: "plus") { editing = nil; showsComposer = true }
            }
        }
        .task { await store.load() }
        .sheet(isPresented: $showsComposer) { LifeMomentComposer(existing: editing) { value in Task { await store.save(value) } } }
    }
}

private struct LifeMomentComposer: View {
    let existing: LifeMoment?
    let onSave: (LifeMoment) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date
    @State private var kind: LifeMomentKind
    @State private var recurrence: LifeMomentRecurrenceRule
    @State private var note: String
    @State private var homeDisplay: Bool
    init(existing: LifeMoment?, onSave: @escaping (LifeMoment) -> Void) {
        self.existing = existing; self.onSave = onSave
        _title = State(initialValue: existing?.title ?? ""); _date = State(initialValue: existing?.eventDate ?? Date())
        _kind = State(initialValue: existing?.kind ?? .countdown); _recurrence = State(initialValue: existing?.recurrenceRule ?? .none)
        _note = State(initialValue: existing?.note ?? ""); _homeDisplay = State(initialValue: existing?.permitsHomeDisplay ?? false)
    }
    var body: some View {
        NavigationStack { Form {
            Section("Moment") { TextField("Title", text: $title); DatePicker("Date", selection: $date); Picker("Kind", selection: $kind) { ForEach(LifeMomentKind.allCases, id: \.self) { Text($0.rawValue.replacingOccurrences(of: "recurringMeaningfulEvent", with: "Recurring event").capitalized).tag($0) } } }
            Section("Repeat") { Picker("Recurrence", selection: $recurrence) { Text("Never").tag(LifeMomentRecurrenceRule.none); Text("Weekly").tag(LifeMomentRecurrenceRule.weekly); Text("Monthly").tag(LifeMomentRecurrenceRule.monthly); Text("Yearly").tag(LifeMomentRecurrenceRule.yearly) } }
            Section("Privacy") { Toggle("Allow date on Home", isOn: $homeDisplay); Text("The title and date stay off Home, widgets, and suggestions until enabled.").font(.caption).foregroundStyle(.secondary) }
            Section("Note") { TextField("Optional note", text: $note, axis: .vertical) }
        }.navigationTitle(existing == nil ? "New Moment" : "Edit Moment").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } }
    }
    private func save() { guard let value = try? LifeMoment(id: existing?.id ?? UUID(), title: title, kind: kind, eventDate: date, recurrenceRule: recurrence, note: note, sensitivity: existing?.sensitivity ?? .privateStandard, permitsHomeDisplay: homeDisplay, createdAt: existing?.createdAt ?? Date(), updatedAt: Date()) else { return }; onSave(value); dismiss() }
}
