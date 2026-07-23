import Foundation

public struct NutritionMacros: Codable, Hashable, Sendable {
    public var calories: Double
    public var proteinGrams: Double
    public var carbohydrateGrams: Double
    public var fatGrams: Double
    public var fiberGrams: Double?
    public var sodiumMilligrams: Double?

    public init(
        calories: Double,
        proteinGrams: Double,
        carbohydrateGrams: Double,
        fatGrams: Double,
        fiberGrams: Double? = nil,
        sodiumMilligrams: Double? = nil
    ) throws {
        let required = [calories, proteinGrams, carbohydrateGrams, fatGrams]
        guard required.allSatisfy({ $0.isFinite && $0 >= 0 }),
              fiberGrams.map({ $0.isFinite && $0 >= 0 }) ?? true,
              sodiumMilligrams.map({ $0.isFinite && $0 >= 0 }) ?? true else {
            throw NutritionError.invalidMacros
        }
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sodiumMilligrams = sodiumMilligrams
    }

    public func scaled(by factor: Double) throws -> Self {
        guard factor.isFinite, factor > 0 else { throw NutritionError.invalidServing }
        return try .init(
            calories: calories * factor,
            proteinGrams: proteinGrams * factor,
            carbohydrateGrams: carbohydrateGrams * factor,
            fatGrams: fatGrams * factor,
            fiberGrams: fiberGrams.map { $0 * factor },
            sodiumMilligrams: sodiumMilligrams.map { $0 * factor }
        )
    }

    public static var zero: Self {
        try! .init(calories: 0, proteinGrams: 0, carbohydrateGrams: 0, fatGrams: 0)
    }

    public func adding(_ other: Self) -> Self {
        try! .init(
            calories: calories + other.calories,
            proteinGrams: proteinGrams + other.proteinGrams,
            carbohydrateGrams: carbohydrateGrams + other.carbohydrateGrams,
            fatGrams: fatGrams + other.fatGrams,
            fiberGrams: Self.optionalSum(fiberGrams, other.fiberGrams),
            sodiumMilligrams: Self.optionalSum(sodiumMilligrams, other.sodiumMilligrams)
        )
    }

    private static func optionalSum(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard lhs != nil || rhs != nil else { return nil }
        return (lhs ?? 0) + (rhs ?? 0)
    }
}

public struct FoodServingDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var grams: Double

    public init(id: UUID = UUID(), name: String, grams: Double) throws {
        guard let name = name.nutritionTrimmed, grams.isFinite, grams > 0 else {
            throw NutritionError.invalidServing
        }
        self.id = id
        self.name = name
        self.grams = grams
    }
}

public enum FoodSource: String, Codable, Hashable, Sendable {
    case bundled
    case userCreated
    case openFoodFacts
}

public struct FoodItem: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var brand: String?
    public var barcode: String?
    /// Canonical nutrition for 100 grams.
    public var macrosPer100Grams: NutritionMacros
    public var servings: [FoodServingDefinition]
    public var source: FoodSource
    public var externalReference: String?
    public var isFavorite: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        macrosPer100Grams: NutritionMacros,
        servings: [FoodServingDefinition] = [],
        source: FoodSource = .userCreated,
        externalReference: String? = nil,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard let name = name.nutritionTrimmed else { throw NutritionError.invalidFood }
        let normalizedBarcode = barcode?.filter(\.isNumber)
        guard normalizedBarcode.map({ (8 ... 14).contains($0.count) }) ?? true else {
            throw NutritionError.invalidBarcode
        }
        self.id = id
        self.name = name
        self.brand = brand?.nutritionTrimmed
        self.barcode = normalizedBarcode?.nutritionTrimmed
        self.macrosPer100Grams = macrosPer100Grams
        self.servings = servings
        self.source = source
        self.externalReference = externalReference?.nutritionTrimmed
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }

    public func resolvedMacros(grams: Double) throws -> NutritionMacros {
        guard grams.isFinite, grams > 0 else { throw NutritionError.invalidServing }
        return try macrosPer100Grams.scaled(by: grams / 100)
    }
}

public enum NutritionMealSlot: String, Codable, CaseIterable, Hashable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack
}

public struct NutritionLogEntry: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let foodID: UUID
    public var foodNameSnapshot: String
    public var mealSlot: NutritionMealSlot
    public var quantity: Double
    public var servingNameSnapshot: String
    public var servingGramsSnapshot: Double
    /// Copied at logging time; later food-library edits cannot rewrite history.
    public var resolvedMacrosSnapshot: NutritionMacros
    public var loggedAt: Date
    public var capturedTimeZoneIdentifier: String
    public var note: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        food: FoodItem,
        mealSlot: NutritionMealSlot,
        quantity: Double,
        serving: FoodServingDefinition,
        loggedAt: Date = Date(),
        capturedTimeZone: TimeZone = .autoupdatingCurrent,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard quantity.isFinite, quantity > 0 else { throw NutritionError.invalidServing }
        self.id = id
        foodID = food.id
        foodNameSnapshot = food.name
        self.mealSlot = mealSlot
        self.quantity = quantity
        servingNameSnapshot = serving.name
        servingGramsSnapshot = serving.grams
        resolvedMacrosSnapshot = try food.resolvedMacros(grams: serving.grams * quantity)
        self.loggedAt = loggedAt
        capturedTimeZoneIdentifier = capturedTimeZone.identifier
        self.note = note?.nutritionTrimmed
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }

    public init(
        id: UUID,
        foodID: UUID,
        foodNameSnapshot: String,
        mealSlot: NutritionMealSlot,
        quantity: Double,
        servingNameSnapshot: String,
        servingGramsSnapshot: Double,
        resolvedMacrosSnapshot: NutritionMacros,
        loggedAt: Date,
        capturedTimeZoneIdentifier: String,
        note: String?,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        guard quantity.isFinite, quantity > 0, servingGramsSnapshot.isFinite, servingGramsSnapshot > 0,
              foodNameSnapshot.nutritionTrimmed != nil, servingNameSnapshot.nutritionTrimmed != nil else {
            throw NutritionError.invalidServing
        }
        self.id = id
        self.foodID = foodID
        self.foodNameSnapshot = foodNameSnapshot
        self.mealSlot = mealSlot
        self.quantity = quantity
        self.servingNameSnapshot = servingNameSnapshot
        self.servingGramsSnapshot = servingGramsSnapshot
        self.resolvedMacrosSnapshot = resolvedMacrosSnapshot
        self.loggedAt = loggedAt
        self.capturedTimeZoneIdentifier = capturedTimeZoneIdentifier
        self.note = note?.nutritionTrimmed
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }
}

public struct NutritionGoal: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var targetMacros: NutritionMacros
    public var effectiveFrom: Date
    public var capturedTimeZoneIdentifier: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        targetMacros: NutritionMacros,
        effectiveFrom: Date = Date(),
        capturedTimeZone: TimeZone = .autoupdatingCurrent,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.targetMacros = targetMacros
        self.effectiveFrom = effectiveFrom
        capturedTimeZoneIdentifier = capturedTimeZone.identifier
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }
}

public enum NutritionLookupScope: Equatable, Sendable {
    case localOnly
    case explicitRemoteRequest
}

public struct NutritionSearchResult: Hashable, Sendable {
    public var food: FoodItem
    public var matchReason: String
}

public enum NutritionError: Error, Equatable, Sendable {
    case invalidMacros
    case invalidServing
    case invalidFood
    case invalidBarcode
    case recordNotFound
    case externalLookupNotEnabled
}

public protocol NutritionRepository: Sendable {
    func foods(query: String) async throws -> [FoodItem]
    func food(barcode: String) async throws -> FoodItem?
    func recentFoods(limit: Int) async throws -> [FoodItem]
    func logs(from: Date?, to: Date?) async throws -> [NutritionLogEntry]
    func save(_ food: FoodItem) async throws
    func save(_ entry: NutritionLogEntry) async throws
    func goals() async throws -> [NutritionGoal]
    func save(_ goal: NutritionGoal) async throws
    func deleteFood(id: UUID) async throws
    func deleteLog(id: UUID) async throws
}

public actor InMemoryNutritionRepository: NutritionRepository {
    private var foodsByID: [UUID: FoodItem]
    private var logsByID: [UUID: NutritionLogEntry]

    public init(foods: [FoodItem] = [], logs: [NutritionLogEntry] = []) {
        foodsByID = Dictionary(uniqueKeysWithValues: foods.map { ($0.id, $0) })
        logsByID = Dictionary(uniqueKeysWithValues: logs.map { ($0.id, $0) })
    }

    public func foods(query: String) -> [FoodItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        return foodsByID.values
            .filter { query.isEmpty || $0.name.localizedLowercase.contains(query) || ($0.brand?.localizedLowercase.contains(query) ?? false) }
            .sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
                if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    public func food(barcode: String) -> FoodItem? {
        foodsByID.values.first { $0.barcode == barcode.filter(\.isNumber) }
    }

    public func recentFoods(limit: Int) -> [FoodItem] {
        let orderedFoodIDs = logsByID.values.sorted { $0.loggedAt > $1.loggedAt }.map(\.foodID)
        var seen = Set<UUID>()
        return orderedFoodIDs.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return foodsByID[id]
        }.prefix(max(0, limit)).map { $0 }
    }

    public func logs(from: Date?, to: Date?) -> [NutritionLogEntry] {
        logsByID.values.filter { value in
            (from.map { value.loggedAt >= $0 } ?? true) && (to.map { value.loggedAt < $0 } ?? true)
        }.sorted {
            if $0.loggedAt != $1.loggedAt { return $0.loggedAt > $1.loggedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    public func save(_ food: FoodItem) { foodsByID[food.id] = food }
    public func save(_ entry: NutritionLogEntry) { logsByID[entry.id] = entry }
    private var goalsByID: [UUID: NutritionGoal] = [:]

    public func goals() -> [NutritionGoal] {
        goalsByID.values.sorted { $0.effectiveFrom > $1.effectiveFrom }
    }

    public func save(_ goal: NutritionGoal) { goalsByID[goal.id] = goal }

    public func deleteFood(id: UUID) throws {
        guard foodsByID.removeValue(forKey: id) != nil else { throw NutritionError.recordNotFound }
    }

    public func deleteLog(id: UUID) throws {
        guard logsByID.removeValue(forKey: id) != nil else { throw NutritionError.recordNotFound }
    }
}

public struct NutritionLookupPolicy: Sendable {
    public var externalLookupEnabled: Bool

    public init(externalLookupEnabled: Bool = false) {
        self.externalLookupEnabled = externalLookupEnabled
    }

    public func permitsRemoteLookup(scope: NutritionLookupScope) throws -> Bool {
        guard scope == .explicitRemoteRequest else { return false }
        guard externalLookupEnabled else { throw NutritionError.externalLookupNotEnabled }
        return true
    }
}

public actor NutritionScanDeduplicator {
    private var lastSeen: [String: Date] = [:]
    private let window: TimeInterval

    public init(window: TimeInterval = 3) {
        self.window = max(0, window)
    }

    public func shouldAccept(barcode: String, at date: Date = Date()) -> Bool {
        let normalized = barcode.filter(\.isNumber)
        guard !normalized.isEmpty else { return false }
        defer { lastSeen[normalized] = date }
        guard let prior = lastSeen[normalized] else { return true }
        return date.timeIntervalSince(prior) > window
    }
}

public enum NutritionHomeCardFocus: Sendable {
    case dailySummary
    case recentMeal
    case logMeal
}

public struct NutritionHomeCardProvider: HomeCardProvider {
    public let definition: HomeCardDefinition
    public let primaryDestination = LifeBoardDestination.track
    public let privacyClassification = DataSensitivity.privateSensitive
    private let repository: any NutritionRepository
    private let focus: NutritionHomeCardFocus

    public init(definition: HomeCardDefinition, focus: NutritionHomeCardFocus, repository: any NutritionRepository) {
        self.definition = definition
        self.focus = focus
        self.repository = repository
    }

    public func snapshot(configuration: HomeCardConfiguration, size: HomeCardSize, at date: Date) async -> HomeCardSnapshot {
        do {
            switch focus {
            case .logMeal:
                return .init(availability: .ready, title: definition.title, value: "Log meal", detail: size == .compact ? nil : "Review food, serving, and macros before saving.", actions: inlineActions, updatedAt: date)
            case .recentMeal:
                guard let entry = try await repository.logs(from: nil, to: nil).first else {
                    return .init(availability: .empty, title: definition.title, detail: "Nothing logged—and nothing required.", actions: inlineActions, updatedAt: date)
                }
                return .init(availability: .ready, title: definition.title, value: entry.foodNameSnapshot, detail: size == .compact ? nil : "\(Int(entry.resolvedMacrosSnapshot.calories.rounded())) kcal · \(entry.mealSlot.rawValue.capitalized)", actions: inlineActions, updatedAt: entry.updatedAt)
            case .dailySummary:
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = .autoupdatingCurrent
                let entries = try await repository.logs(from: calendar.startOfDay(for: date), to: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)))
                let total = entries.reduce(NutritionMacros.zero) { $0.adding($1.resolvedMacrosSnapshot) }
                let detail: String? = switch size {
                case .compact: nil
                case .standard, .wide: "P \(Int(total.proteinGrams.rounded()))g · C \(Int(total.carbohydrateGrams.rounded()))g · F \(Int(total.fatGrams.rounded()))g"
                case .tall, .expanded: "\(entries.count) logged items. This is a factual summary, not a score or recommendation."
                }
                return .init(availability: entries.isEmpty ? .empty : .ready, title: definition.title, value: entries.isEmpty ? nil : "\(Int(total.calories.rounded())) kcal", detail: entries.isEmpty ? "Log only when it is useful to you." : detail, actions: inlineActions, updatedAt: entries.map(\.updatedAt).max() ?? date)
            }
        } catch {
            return .init(availability: .degraded, title: definition.title, detail: "Nutrition is unavailable right now. Your Home layout is unchanged.", updatedAt: date)
        }
    }
}

private extension String {
    var nutritionTrimmed: String? {
        let result = trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
