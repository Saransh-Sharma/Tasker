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
    private let barcodeReviewService: NutritionBarcodeReviewService

    init(repository: any NutritionRepository) {
        self.repository = repository
        barcodeReviewService = NutritionBarcodeReviewService(repository: repository)
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
}

struct NutritionView: View {
    @State private var store: NutritionTimelineStore
    @State private var showsComposer = false
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
    private let scanDeduplicator = NutritionScanDeduplicator()

    init(repository: any NutritionRepository) {
        _store = State(initialValue: NutritionTimelineStore(repository: repository))
    }

    var body: some View {
        ScrollView {
            timelineContent
                .padding(20)
        }
        .background(Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea())
        .navigationTitle("Nutrition")
        .toolbar { nutritionToolbar }
        .task { await store.load() }
        .refreshable { await store.load() }
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
        .lifeBoardClaySurface(.well, cornerRadius: 15, fill: Color(SemanticColorTokens.foundationSurfaceSelected))
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
            Text(title).font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(10)
        .lifeBoardClaySurface(.well, cornerRadius: 15, fill: Color(SemanticColorTokens.foundationSurfaceSelected))
    }

    /// Honest trailing-week report: recorded energy per day, no goals or
    /// grades implied. Days without logs stay visibly empty.
    private var weeklyReportSection: some View {
        let report = store.weeklyReport
        return VStack(alignment: .leading, spacing: 10) {
            Text("Past 7 days").font(Typography.sectionTitle())
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
                .lifeBoardClaySurface(.raised, cornerRadius: 18)
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
    /// Workouts and sleep have always existed in the model and were never
    /// rendered, while this module's own row promised "weight, sleep,
    /// workouts, and trends".
    private(set) var workouts: [WorkoutRecord] = []
    private(set) var sleepNotes: [SleepNote] = []
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
            samples = try await repository.bodyMetricSamples(kind: kind)
            workouts = try await repository.workoutRecords()
            sleepNotes = try await repository.sleepNotes()
            conflicts = WellnessSourceConflictDetector().conflicts(in: samples)
            errorMessage = nil
            state = samples.isEmpty && workouts.isEmpty && sleepNotes.isEmpty
                ? .noSamples
                : .fresh(lastSyncAt: Date())
        } catch {
            errorMessage = "Wellness history is unavailable right now."
            state = .failed(message: errorMessage ?? "Wellness history is unavailable right now.")
        }
    }
    func save(_ sample: BodyMetricSample, kind: BodyMetricKind) async { do { try await repository.save(sample); await load(kind: kind); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = "That measurement could not be saved." } }
    func delete(_ sample: BodyMetricSample, kind: BodyMetricKind) async { do { try await repository.delete(kind: .bodyMetric, id: sample.id); await load(kind: kind); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = "That measurement could not be removed." } }

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

struct WellnessView: View {
    @State private var store: WellnessHistoryStore
    @State private var kind: BodyMetricKind = .bodyMass
    @State private var showsCapture = false
    @State private var showsCustomization = false
    @State private var searchText = ""
    @State private var chartRevealProgress: Double = 1
    init(
        repository: any WellnessRepository,
        preferenceStore: any WellnessPreferenceStore = UserDefaultsWellnessPreferenceStore()
    ) {
        _store = State(initialValue: WellnessHistoryStore(
            repository: repository,
            preferenceStore: preferenceStore
        ))
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
                // The system segmented control is 32pt tall — a touch-target
                // violation on every row it appeared in — and truncates to "…"
                // rather than reflowing. The house lens picker exists for
                // exactly this substitution.
                LensPicker(
                    "Wellness metric",
                    selection: $kind,
                    values: enabledMetrics,
                    identifierPrefix: "wellness.metric",
                    title: \.title,
                    identifier: \.rawValue
                )
                todayCard
                if case let .failed(message) = store.state {
                    ContentUnavailableView(
                        "Wellness is unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                } else if store.state == .loading {
                    ProgressView("Loading wellness history")
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else if store.samples.isEmpty {
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
                            isImported: sample.source != .manual,
                            note: sample.note
                        ) {
                            Task { await store.delete(sample, kind: kind) }
                        }
                    }
                }.accessibilityElement(children: .contain).accessibilityLabel("\(kind.title) history table")

                workoutsSection
                sleepSection
            }.padding(20)
        }
        .background {
            GrainedCanvas()
        }
        .navigationTitle("Wellness")
        .searchable(text: $searchText, prompt: "Search values or dates")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Customize", systemImage: "slider.horizontal.3") { showsCustomization = true }
                Button("Add value", systemImage: "plus") { showsCapture = true }
            }
        }
        .task(id: kind) {
            await store.load(kind: kind)
            // Replay the sweep for the newly selected metric's data.
            chartRevealProgress = 0
            withAnimation(.easeOut(duration: 0.62)) { chartRevealProgress = 1 }
        }
        .task {
            let updates = await HealthSyncInvalidationService.shared.updates()
            for await event in updates {
                guard Task.isCancelled == false,
                      event.metrics.contains(where: { [.body, .workouts, .sleep].contains($0.domain) }) else {
                    continue
                }
                await store.load(kind: kind)
            }
        }
        // Seed the tape with the most recent reading. Almost every entry is a
        // small move from the last one, so starting at a generic default made
        // the person scrub past their own history to get back to where they are.
        .sheet(isPresented: $showsCapture) {
            WellnessMetricCapture(kind: kind, lastValue: store.samples.first.map(displayValue)) { value in
                Task {
                    await store.save(value, kind: kind)
                    await HealthCoordinator.shared.jitCoordinator.offerConnectAfterReward(leadDomain: .body, trigger: "wellness_body_metric")
                }
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
    }

    /// `WorkoutRecord` has existed in the model with no UI at all.
    @ViewBuilder
    private var workoutsSection: some View {
        if store.workouts.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                Text("Workouts").font(Typography.sectionTitle())
                TrendChart(
                    points: store.workouts
                        .prefix(30)
                        .map { HomeSeriesPoint(date: $0.startedAt, value: max(0, $0.duration / 60)) }
                        .sorted { $0.date < $1.date },
                    tint: Color(SemanticColorTokens.foundationApricotAccent),
                    unit: "minutes"
                )
                .frame(height: 120)

                ForEach(store.workouts.prefix(12)) { workout in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.activityKind).font(.body.weight(.medium))
                            Text(workout.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            if let note = workout.note {
                                Text(note).font(.caption2).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                        }
                        Spacer()
                        Text(Self.durationLabel(workout.duration)).monospacedDigit()
                    }
                    .frame(minHeight: 44)
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) { Divider() }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Workout history")
        }
    }

    /// Sleep notes were captured in Track's Body area and had no home here,
    /// even though this module's own description promised them.
    @ViewBuilder
    private var sleepSection: some View {
        let nights = HealthSleepPresentation.nightlySummaries(notes: store.sleepNotes)
        if nights.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                Text("Sleep").font(Typography.sectionTitle())
                TrendChart(
                    points: nights
                        .prefix(30)
                        .map { HomeSeriesPoint(date: $0.night, value: max(0, $0.totalDuration / 3_600)) }
                        .sorted { $0.date < $1.date },
                    tint: Color(SemanticColorTokens.foundationSageAccent),
                    unit: "hours"
                )
                .frame(height: 120)

                ForEach(nights.prefix(12)) { night in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.durationLabel(night.totalDuration)).font(.body.weight(.medium))
                            Text(night.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            if night.samples.count > 1 {
                                Text("\(night.samples.count) Apple Health sleep stages")
                                    .font(.caption2)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            } else if let annotation = night.samples.first?.note {
                                Text(annotation).font(.caption2).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                        }
                        Spacer()
                        if let quality = night.samples.compactMap(\.quality).first {
                            Text("Quality \(quality)/5")
                                .font(.caption)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        }
                    }
                    .frame(minHeight: 44)
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) { Divider() }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Sleep history")
        }
    }

    private static func durationLabel(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    /// Today-first: the day's state and one obvious capture action lead the
    /// screen; history and analysis follow.
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today").font(.caption.weight(.semibold)).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            if let sample = todaySamples.first {
                Text(display(sample)).font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
                Text("Logged \(sample.observedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            } else {
                Text(store.samples.first.map { "Last: \(display($0)) · \($0.observedAt.formatted(date: .abbreviated, time: .omitted))" } ?? "Nothing logged yet")
                    .font(.subheadline).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            // `.borderedProminent` with a `.tint` is unsafe inside these roots:
            // an ambient `foregroundStyle` propagates into the label and defeats
            // the system's automatic contrasting colour. `.lifeBoardPrimary`
            // pins the on-accent role explicitly, which is the only arrangement
            // that survives it.
            Button {
                showsCapture = true
            } label: {
                Label(
                    todaySamples.isEmpty ? "Log today’s \(kind.title.lowercased())" : "Add another value",
                    systemImage: "plus.circle.fill"
                )
            }
            .buttonStyle(.lifeBoardPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .lifeBoardClaySurface(.well, cornerRadius: 22, fill: Color(SemanticColorTokens.foundationSurfaceSelected))
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
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Color(SemanticColorTokens.foundationHairline)) }
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

private struct WellnessMetricOrderRow: View {
    let kind: BodyMetricKind
    @Binding var unit: WellnessDisplayUnit
    let hide: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(kind.title)
                .font(.lifeboard(.body))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            Spacer(minLength: 8)
            Menu {
                Picker(kind.title, selection: $unit) {
                    ForEach(WellnessDisplayPreferences.units(for: kind), id: \.self) { option in
                        Text(option.symbol).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Text(unit.symbol)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
            }
            .accessibilityLabel(Text("\(kind.title) unit"))
            Button(action: hide) {
                Image(systemName: "eye.slash")
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                    .frame(width: 34, height: 34)
                    .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Hide \(kind.title)"))
        }
    }
}

private struct WellnessHistoryRow: View {
    let timestamp: Date
    let value: String
    let provenance: String
    let isImported: Bool
    let note: String?
    let delete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                HStack(spacing: 6) {
                    if isImported {
                        Text(provenance)
                            .font(.lifeboard(.caption2))
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
                    }
                    if let note {
                        Text(note)
                            .font(.lifeboard(.caption2))
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            .lineLimit(2)
                    }
                }
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.lifeboard(.bodyStrong))
                .monospacedDigit()
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            Menu {
                Button("Delete", systemImage: "trash", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                    .frame(width: 34, height: 34)
                    .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
            }
            .accessibilityLabel(Text("Actions for \(value) on \(timestamp.formatted(date: .abbreviated, time: .shortened))"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
        .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
        .lifeBoardScrollEntrance(intensity: 0.55)
        .accessibilityElement(children: .contain)
    }
}

private struct WellnessCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WellnessDisplayPreferences
    let save: (WellnessDisplayPreferences) -> Void

    init(
        preferences: WellnessDisplayPreferences,
        save: @escaping (WellnessDisplayPreferences) -> Void
    ) {
        _draft = State(initialValue: preferences)
        self.save = save
    }

    var body: some View {
        ComposerScaffold(
            title: "Customize Wellness",
            subtitle: "Which metrics appear, in which order.",
            confirmTitle: "Save",
            isConfirmEnabled: draft.enabledMetrics.isEmpty == false,
            titleDisplayMode: .inline,
            identifier: "wellness.customize",
            onConfirm: { save(draft); dismiss() }
        ) {
            ComposerSection(
                "Body dashboard",
                detail: "Drag to reorder, or use the Move up and Move down actions.",
                footer: "Enabled metrics keep their order. Source readings and history are never deleted when a metric is hidden."
            ) {
                // `ReorderableRows` rather than `List` + `EditButton`.
                // Dropping edit mode would have removed the only Switch Control
                // path to reordering, so the per-row Move actions the component
                // requires are what make this substitution legitimate.
                ReorderableRows(
                    items: $draft.enabledMetrics,
                    rowIdentifier: { "wellness.customize.\($0.rawValue)" },
                    accessibilityLabel: \.title
                ) { kind in
                    WellnessMetricOrderRow(
                        kind: kind,
                        unit: unitBinding(for: kind),
                        hide: { draft.enabledMetrics.removeAll { $0 == kind } }
                    )
                }
            }
            if hiddenMetrics.isEmpty == false {
                ComposerSection("Hidden metrics") {
                    ForEach(hiddenMetrics, id: \.self) { kind in
                        Button {
                            draft.enabledMetrics.append(kind)
                        } label: {
                            Label("Show \(kind.title)", systemImage: "plus.circle")
                        }
                        .buttonStyle(.lifeBoardChip)
                    }
                }
            }
        }
    }

    private func unitBinding(for kind: BodyMetricKind) -> Binding<WellnessDisplayUnit> {
        Binding(
            get: { draft.preferredUnit(for: kind) },
            set: { draft.preferredUnits[kind] = $0 }
        )
    }

    private func displayOrder(for kind: BodyMetricKind) -> Int {
        (draft.enabledMetrics.firstIndex(of: kind) ?? BodyMetricKind.allCases.firstIndex(of: kind) ?? 0) + 1
    }

    private var hiddenMetrics: [BodyMetricKind] {
        BodyMetricKind.allCases.filter { !draft.enabledMetrics.contains($0) }
    }
}

/// Logging one body measurement.
///
/// Was a bare `.decimalPad` field beside a `Stepper("Adjust")` that moved weight
/// one kilogram per tap — the least tactile control in an app whose whole
/// premise is tactility. The tape is the right instrument for this: almost every
/// entry is a small move from the last reading, which is a scrub, not a typing
/// task. The keyboard stays one tap away on the readout for the times it isn't.
private struct WellnessMetricCapture: View {
    let kind: BodyMetricKind
    let onSave: (BodyMetricSample) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double
    @State private var unit: WellnessDisplayUnit
    @State private var pending: BodyMetricSample?
    @State private var reviewMessage: String?
    @State private var successTrigger = 0

    init(kind: BodyMetricKind, lastValue: Double? = nil, onSave: @escaping (BodyMetricSample) -> Void) {
        self.kind = kind
        self.onSave = onSave
        _unit = State(initialValue: kind.canonicalUnit)
        _value = State(initialValue: lastValue ?? Self.tape(for: kind, unit: kind.canonicalUnit).start)
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
        guard let sample = try? BodyMetricSample(kind: kind, value: value, unit: unit) else { return }
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

private extension Comparable { func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) } }

@MainActor @Observable
final class LifeMomentsStore {
    private(set) var moments: [LifeMoment] = []
    var errorMessage: String?
    let repository: any LifeMomentRepository
    init(repository: any LifeMomentRepository) { self.repository = repository }
    func load() async { do { moments = try await repository.moments(includeArchived: false); errorMessage = nil } catch { errorMessage = "Moments are unavailable right now." } }
    func save(_ value: LifeMoment) async { do { try await repository.save(value); await load(); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = error.localizedDescription } }
    func archive(_ value: LifeMoment) async { do { try await repository.archive(id: value.id, at: Date()); await load(); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = error.localizedDescription } }
    func delete(_ value: LifeMoment) async { do { try await repository.delete(id: value.id); await load(); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = error.localizedDescription } }
}

struct LifeMomentsView: View {
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if store.moments.isEmpty {
                    ContentUnavailableView(
                        "Keep a meaningful date close",
                        systemImage: "sparkles",
                        description: Text("Countdowns and anniversaries stay private unless you allow Home display.")
                    )
                    .padding(.top, 40)
                } else {
                    Text("Meaningful moments")
                        .font(Typography.sectionTitle())
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        .padding(.horizontal, 4)
                }
                ForEach(filteredMoments) { moment in
                    LifeMomentCard(moment: moment) {
                        editing = moment
                        showsComposer = true
                    } archive: {
                        Task { await store.archive(moment) }
                    } delete: {
                        Task { await store.delete(moment) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 132)
        }
        .background {
            GrainedCanvas()
        }
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

/// One meaningful date, as an object rather than a table row.
///
/// The list used `List` + `swipeActions`, which put archive and delete behind a
/// gesture with no visible equivalent. On clay the row becomes a card and the
/// two actions move into a menu, so they are reachable by pointer, keyboard and
/// VoiceOver as well as by knowing to swipe.
private struct LifeMomentCard: View {
    let moment: LifeMoment
    let open: () -> Void
    let archive: () -> Void
    let delete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.lifeBoardTransitionCoordinator) private var transitions
    @State private var developProgress: Double = 1
    @State private var dissolveProgress: Double = 0

    private var countdown: (label: String, isPast: Bool) {
        guard let days = moment.calendarDaysUntilNextOccurrence(from: Date()) else {
            return ("Past", true)
        }
        return (days == 0 ? "Today" : "\(days)d", false)
    }

    var body: some View {
        Button(action: open) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: moment.kind == .countdown ? "hourglass" : "calendar.badge.heart")
                    .font(.lifeboard(.title3))
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
                    .frame(width: 34, height: 34)
                    .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(moment.title)
                        .font(.lifeboard(.bodyStrong))
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        .multilineTextAlignment(.leading)
                    Text(moment.eventDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                Spacer(minLength: 8)

                if dynamicTypeSize.isAccessibilitySize == false {
                    countdownBadge
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lifeBoardClay(.raised, cornerRadius: Radius.largeCard))
        // A Life Moment is literally a memory, which is what DESIGN.md reserves
        // `memoryDevelopReveal` for. Claimed once per card per window session so
        // it develops when the card first arrives and never again on scroll —
        // repeated rows stay quiet.
        .lifeboardMemoryDevelopReveal(progress: developProgress)
        // The dissolve runs only after the repository delete resolves. A card
        // that erodes ahead of a failing write is a lie about the data.
        .lifeboardDissolveAway(
            progress: dissolveProgress,
            tint: Color(SemanticColorTokens.foundationApricotAccent)
        )
        .lifeBoardScrollEntrance(intensity: 0.7)
        .task {
            guard transitions?.claimOneShot("lifeMoment.develop.\(moment.id)") == true else { return }
            developProgress = 0
            withAnimation(.easeOut(duration: 0.7)) { developProgress = 1 }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(moment.title), \(moment.eventDate.formatted(date: .abbreviated, time: .omitted)), \(countdown.label)"))
        .accessibilityAction(named: Text("Archive"), archive)
        .accessibilityAction(named: Text("Delete"), performDelete)
        .contextMenu {
            Button("Archive", systemImage: "archivebox", action: archive)
            Button("Delete", systemImage: "trash", role: .destructive, action: performDelete)
        }
    }

    /// Persist first, then dissolve. The caller's `delete` closure owns the
    /// repository write; the erosion is only the receipt of it.
    private func performDelete() {
        delete()
        withAnimation(.easeIn(duration: 0.42)) { dissolveProgress = 1 }
    }

    private var countdownBadge: some View {
        Text(countdown.label)
            .font(.lifeboard(.bodyStrong))
            .monospacedDigit()
            .foregroundStyle(
                Color(countdown.isPast
                    ? SemanticColorTokens.inkTertiary
                    : SemanticColorTokens.inkPrimary)
            )
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
            .accessibilityHidden(true)
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
    @State private var successTrigger = 0
    init(existing: LifeMoment?, onSave: @escaping (LifeMoment) -> Void) {
        self.existing = existing; self.onSave = onSave
        _title = State(initialValue: existing?.title ?? ""); _date = State(initialValue: existing?.eventDate ?? Date())
        _kind = State(initialValue: existing?.kind ?? .countdown); _recurrence = State(initialValue: existing?.recurrenceRule ?? .none)
        _note = State(initialValue: existing?.note ?? ""); _homeDisplay = State(initialValue: existing?.permitsHomeDisplay ?? false)
    }
    var body: some View {
        ComposerScaffold(
            title: existing == nil ? "New Moment" : "Edit Moment",
            subtitle: "A date worth keeping close.",
            confirmTitle: "Save",
            isConfirmEnabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            identifier: "lifeMoment.composer",
            onConfirm: save
        ) {
            MomentDetailSection(title: $title, date: $date, kind: $kind)
            MomentRepeatSection(recurrence: $recurrence)
            MomentPrivacySection(homeDisplay: $homeDisplay)
            MomentNoteSection(note: $note)
        }
        .lifeboardCompletionBurst(trigger: successTrigger)
    }

    private func save() {
        guard let value = try? LifeMoment(
            id: existing?.id ?? UUID(),
            title: title,
            kind: kind,
            eventDate: date,
            recurrenceRule: recurrence,
            note: note,
            sensitivity: existing?.sensitivity ?? .privateStandard,
            permitsHomeDisplay: homeDisplay,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        ) else { return }
        onSave(value)
        successTrigger &+= 1
        dismiss()
    }
}

private struct MomentDetailSection: View {
    @Binding var title: String
    @Binding var date: Date
    @Binding var kind: LifeMomentKind

    var body: some View {
        ComposerSection("Moment") {
            ComposerField(
                "Title",
                prompt: "Anniversary, first day, the trip…",
                text: $title,
                showsLabel: false,
                identifier: "lifeMoment.title"
            )
            DateCapsuleRow("Date", selection: $date)
            OptionRail(
                "Kind",
                selection: $kind,
                values: LifeMomentKind.allCases,
                identifierPrefix: "lifeMoment.kind",
                title: Self.kindTitle,
                systemImage: { $0 == .countdown ? "hourglass" : "calendar.badge.heart" }
            )
        }
    }

    /// The raw value is a camel-cased identifier; `.capitalized` alone turned it
    /// into "Recurringmeaningfulevent" on screen.
    private static func kindTitle(_ kind: LifeMomentKind) -> String {
        kind == .countdown ? "Countdown" : "Recurring event"
    }
}

private struct MomentRepeatSection: View {
    @Binding var recurrence: LifeMomentRecurrenceRule

    private static let options: [LifeMomentRecurrenceRule] = [.none, .weekly, .monthly, .yearly]

    var body: some View {
        ComposerSection("Repeat") {
            OptionRail(
                "Recurrence",
                selection: $recurrence,
                values: Self.options,
                identifierPrefix: "lifeMoment.recurrence",
                title: Self.title,
                showsLabel: false
            )
        }
    }

    private static func title(_ rule: LifeMomentRecurrenceRule) -> String {
        switch rule {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        default: "Never"
        }
    }
}

private struct MomentPrivacySection: View {
    @Binding var homeDisplay: Bool

    var body: some View {
        ComposerSection(
            "Privacy",
            footer: "The title and date stay off Home, widgets, and suggestions until enabled."
        ) {
            Toggle("Allow date on Home", isOn: $homeDisplay)
                .toggleStyle(.lifeBoardClay)
                .accessibilityIdentifier("lifeMoment.homeDisplay")
        }
    }
}

private struct MomentNoteSection: View {
    @Binding var note: String

    var body: some View {
        ComposerSection("Note") {
            ComposerField(
                "Optional note",
                prompt: "Why this one matters…",
                text: $note,
                shape: .prose(lineLimit: 2...6),
                showsLabel: false
            )
        }
    }
}
