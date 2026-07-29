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

public enum NutritionLogProvenance: String, Codable, Hashable, Sendable {
    case foodLibrary
    case recipe
    case mealTemplate
    case barcodeLocal
    case barcodeRemote
    case manual
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
    public var recipeID: UUID?
    public var mealTemplateID: UUID?
    public var provenance: NutritionLogProvenance
    public var sourceReference: String?
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
        recipeID: UUID? = nil,
        mealTemplateID: UUID? = nil,
        provenance: NutritionLogProvenance = .foodLibrary,
        sourceReference: String? = nil,
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
        self.recipeID = recipeID
        self.mealTemplateID = mealTemplateID
        self.provenance = provenance
        self.sourceReference = sourceReference?.nutritionTrimmed
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
        recipeID: UUID? = nil,
        mealTemplateID: UUID? = nil,
        provenance: NutritionLogProvenance = .foodLibrary,
        sourceReference: String? = nil,
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
        self.recipeID = recipeID
        self.mealTemplateID = mealTemplateID
        self.provenance = provenance
        self.sourceReference = sourceReference?.nutritionTrimmed
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }
}

public struct RecipeIngredient: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let recipeID: UUID
    public var foodID: UUID?
    public var nameSnapshot: String
    public var quantity: Double
    public var unitLabel: String
    public var gramsSnapshot: Double
    public var ordinal: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        recipeID: UUID,
        foodID: UUID? = nil,
        nameSnapshot: String,
        quantity: Double,
        unitLabel: String,
        gramsSnapshot: Double,
        ordinal: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard let name = nameSnapshot.nutritionTrimmed,
              let unit = unitLabel.nutritionTrimmed,
              quantity.isFinite, quantity > 0,
              gramsSnapshot.isFinite, gramsSnapshot > 0,
              ordinal >= 0 else { throw NutritionError.invalidRecipe }
        self.id = id
        self.recipeID = recipeID
        self.foodID = foodID
        self.nameSnapshot = name
        self.quantity = quantity
        self.unitLabel = unit
        self.gramsSnapshot = gramsSnapshot
        self.ordinal = ordinal
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }
}

public struct NutritionRecipe: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var instructions: String?
    public var servingCount: Double
    /// A durable snapshot recomputed only when the recipe itself is edited.
    public var resolvedNutrition: NutritionMacros
    public var source: FoodSource
    public var externalReference: String?
    public var isFavorite: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        instructions: String? = nil,
        servingCount: Double,
        resolvedNutrition: NutritionMacros,
        source: FoodSource = .userCreated,
        externalReference: String? = nil,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard let title = title.nutritionTrimmed,
              servingCount.isFinite, servingCount > 0 else { throw NutritionError.invalidRecipe }
        self.id = id
        self.title = title
        self.instructions = instructions?.nutritionTrimmed
        self.servingCount = servingCount
        self.resolvedNutrition = resolvedNutrition
        self.source = source
        self.externalReference = externalReference?.nutritionTrimmed
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }
}

public enum MealTemplateItemSource: String, Codable, Hashable, Sendable {
    case food
    case recipe
}

public struct MealTemplateItem: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var source: MealTemplateItemSource
    public var sourceID: UUID
    public var quantity: Double
    public var servingID: UUID?

    public init(
        id: UUID = UUID(),
        source: MealTemplateItemSource,
        sourceID: UUID,
        quantity: Double,
        servingID: UUID? = nil
    ) throws {
        guard quantity.isFinite, quantity > 0 else { throw NutritionError.invalidServing }
        self.id = id
        self.source = source
        self.sourceID = sourceID
        self.quantity = quantity
        self.servingID = servingID
    }
}

public struct NutritionMealTemplate: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var mealSlot: NutritionMealSlot
    public var items: [MealTemplateItem]
    public var isFavorite: Bool
    public var lastUsedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        mealSlot: NutritionMealSlot,
        items: [MealTemplateItem],
        isFavorite: Bool = false,
        lastUsedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard let title = title.nutritionTrimmed, !items.isEmpty else {
            throw NutritionError.invalidMealTemplate
        }
        self.id = id
        self.title = title
        self.mealSlot = mealSlot
        self.items = items
        self.isFavorite = isFavorite
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }
}

public struct GroceryListItem: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var quantity: Double?
    public var unitLabel: String?
    public var isChecked: Bool
    public var sourceRecipeID: UUID?

    public init(
        id: UUID = UUID(),
        title: String,
        quantity: Double? = nil,
        unitLabel: String? = nil,
        isChecked: Bool = false,
        sourceRecipeID: UUID? = nil
    ) throws {
        guard let title = title.nutritionTrimmed,
              quantity.map({ $0.isFinite && $0 > 0 }) ?? true else {
            throw NutritionError.invalidGroceryList
        }
        self.id = id
        self.title = title
        self.quantity = quantity
        self.unitLabel = unitLabel?.nutritionTrimmed
        self.isChecked = isChecked
        self.sourceRecipeID = sourceRecipeID
    }
}

public struct NutritionGroceryList: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var items: [GroceryListItem]
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        items: [GroceryListItem] = [],
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard let title = title.nutritionTrimmed else { throw NutritionError.invalidGroceryList }
        self.id = id
        self.title = title
        self.items = items
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }
}

public struct NutritionServingMemory: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let foodID: UUID
    public var servingName: String
    public var grams: Double
    public var lastUsedAt: Date
    public var usageCount: Int

    public init(
        id: UUID = UUID(),
        foodID: UUID,
        servingName: String,
        grams: Double,
        lastUsedAt: Date = Date(),
        usageCount: Int = 1
    ) throws {
        guard let servingName = servingName.nutritionTrimmed,
              grams.isFinite, grams > 0, usageCount >= 0 else { throw NutritionError.invalidServing }
        self.id = id
        self.foodID = foodID
        self.servingName = servingName
        self.grams = grams
        self.lastUsedAt = lastUsedAt
        self.usageCount = usageCount
    }
}

public struct NutritionPreferences: Codable, Hashable, Identifiable, Sendable {
    public static let canonicalID = UUID(uuidString: "9D985D6B-5D3D-4A13-A0B0-5B3CE68276D9")!

    public let id: UUID
    public var caloriesHidden: Bool
    public var macroTargets: NutritionMacros?
    public var micronutrientTargets: [String: Double]
    public var updatedAt: Date

    public init(
        id: UUID = canonicalID,
        caloriesHidden: Bool = false,
        macroTargets: NutritionMacros? = nil,
        micronutrientTargets: [String: Double] = [:],
        updatedAt: Date = Date()
    ) throws {
        guard micronutrientTargets.allSatisfy({
            $0.key.nutritionTrimmed != nil && $0.value.isFinite && $0.value >= 0
        }) else { throw NutritionError.invalidMacros }
        self.id = id
        self.caloriesHidden = caloriesHidden
        self.macroTargets = macroTargets
        self.micronutrientTargets = micronutrientTargets
        self.updatedAt = updatedAt
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
    case invalidRecipe
    case invalidMealTemplate
    case invalidGroceryList
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
    func recipes() async throws -> [NutritionRecipe]
    func ingredients(recipeID: UUID) async throws -> [RecipeIngredient]
    func mealTemplates() async throws -> [NutritionMealTemplate]
    func groceryLists(includeArchived: Bool) async throws -> [NutritionGroceryList]
    func servingMemory(foodID: UUID) async throws -> NutritionServingMemory?
    func preferences() async throws -> NutritionPreferences
    func save(_ recipe: NutritionRecipe, ingredients: [RecipeIngredient]) async throws
    func save(_ template: NutritionMealTemplate) async throws
    func save(_ groceryList: NutritionGroceryList) async throws
    func save(_ memory: NutritionServingMemory) async throws
    func save(_ preferences: NutritionPreferences) async throws
    func deleteFood(id: UUID) async throws
    func deleteLog(id: UUID) async throws
}

public actor InMemoryNutritionRepository: NutritionRepository {
    private var foodsByID: [UUID: FoodItem]
    private var logsByID: [UUID: NutritionLogEntry]
    private var recipesByID: [UUID: NutritionRecipe] = [:]
    private var ingredientsByRecipeID: [UUID: [RecipeIngredient]] = [:]
    private var templatesByID: [UUID: NutritionMealTemplate] = [:]
    private var groceryListsByID: [UUID: NutritionGroceryList] = [:]
    private var servingMemoryByFoodID: [UUID: NutritionServingMemory] = [:]
    private var storedPreferences: NutritionPreferences

    public init(foods: [FoodItem] = [], logs: [NutritionLogEntry] = []) {
        foodsByID = Dictionary(uniqueKeysWithValues: foods.map { ($0.id, $0) })
        logsByID = Dictionary(uniqueKeysWithValues: logs.map { ($0.id, $0) })
        storedPreferences = try! NutritionPreferences()
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

    public func recipes() -> [NutritionRecipe] {
        recipesByID.values.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
            if $0.title != $1.title { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    public func ingredients(recipeID: UUID) -> [RecipeIngredient] {
        (ingredientsByRecipeID[recipeID] ?? []).sorted {
            if $0.ordinal != $1.ordinal { return $0.ordinal < $1.ordinal }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    public func mealTemplates() -> [NutritionMealTemplate] {
        templatesByID.values.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
            return ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast)
        }
    }

    public func groceryLists(includeArchived: Bool) -> [NutritionGroceryList] {
        groceryListsByID.values
            .filter { includeArchived || !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func servingMemory(foodID: UUID) -> NutritionServingMemory? {
        servingMemoryByFoodID[foodID]
    }

    public func preferences() -> NutritionPreferences { storedPreferences }

    public func save(_ recipe: NutritionRecipe, ingredients: [RecipeIngredient]) throws {
        guard ingredients.allSatisfy({ $0.recipeID == recipe.id }) else { throw NutritionError.invalidRecipe }
        recipesByID[recipe.id] = recipe
        ingredientsByRecipeID[recipe.id] = ingredients
    }

    public func save(_ template: NutritionMealTemplate) { templatesByID[template.id] = template }
    public func save(_ groceryList: NutritionGroceryList) { groceryListsByID[groceryList.id] = groceryList }
    public func save(_ memory: NutritionServingMemory) { servingMemoryByFoodID[memory.foodID] = memory }
    public func save(_ preferences: NutritionPreferences) { storedPreferences = preferences }

    public func deleteFood(id: UUID) throws {
        guard foodsByID.removeValue(forKey: id) != nil else { throw NutritionError.recordNotFound }
    }

    public func deleteLog(id: UUID) throws {
        guard logsByID.removeValue(forKey: id) != nil else { throw NutritionError.recordNotFound }
    }
}

public struct NutritionLogMutationReceipt: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let before: NutritionLogEntry?
    public let after: NutritionLogEntry?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        before: NutritionLogEntry?,
        after: NutritionLogEntry?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.before = before
        self.after = after
        self.createdAt = createdAt
    }
}

/// Canonical mutation boundary for nutrition logs and reusable library data.
///
/// The service deliberately derives corrections from the saved snapshot rather
/// than today's food library, preserving what the user actually reviewed.
public actor NutritionWorkflowService {
    private let repository: any NutritionRepository

    public init(repository: any NutritionRepository) {
        self.repository = repository
    }

    public func correctLog(
        id: UUID,
        quantity: Double,
        mealSlot: NutritionMealSlot,
        loggedAt: Date,
        note: String?,
        at date: Date = Date()
    ) async throws -> NutritionLogMutationReceipt {
        guard quantity.isFinite, quantity > 0,
              let before = try await repository.logs(from: nil, to: nil).first(where: { $0.id == id }) else {
            throw NutritionError.recordNotFound
        }
        let factor = quantity / before.quantity
        let corrected = try NutritionLogEntry(
            id: before.id,
            foodID: before.foodID,
            foodNameSnapshot: before.foodNameSnapshot,
            mealSlot: mealSlot,
            quantity: quantity,
            servingNameSnapshot: before.servingNameSnapshot,
            servingGramsSnapshot: before.servingGramsSnapshot,
            resolvedMacrosSnapshot: try before.resolvedMacrosSnapshot.scaled(by: factor),
            loggedAt: loggedAt,
            capturedTimeZoneIdentifier: before.capturedTimeZoneIdentifier,
            note: note,
            recipeID: before.recipeID,
            mealTemplateID: before.mealTemplateID,
            provenance: before.provenance,
            sourceReference: before.sourceReference,
            createdAt: before.createdAt,
            updatedAt: date
        )
        try await repository.save(corrected)
        return .init(before: before, after: corrected, createdAt: date)
    }

    public func deleteLog(id: UUID, at date: Date = Date()) async throws -> NutritionLogMutationReceipt {
        guard let before = try await repository.logs(from: nil, to: nil).first(where: { $0.id == id }) else {
            throw NutritionError.recordNotFound
        }
        try await repository.deleteLog(id: id)
        return .init(before: before, after: nil, createdAt: date)
    }

    public func undo(_ receipt: NutritionLogMutationReceipt) async throws {
        switch (receipt.before, receipt.after) {
        case let (before?, _):
            try await repository.save(before)
        case let (nil, after?):
            try await repository.deleteLog(id: after.id)
        case (nil, nil):
            break
        }
    }

    public func instantiate(
        template: NutritionMealTemplate,
        loggedAt: Date = Date(),
        timeZone: TimeZone = .autoupdatingCurrent
    ) async throws -> [NutritionLogMutationReceipt] {
        let foods = Dictionary(uniqueKeysWithValues: try await repository.foods(query: "").map { ($0.id, $0) })
        let recipes = Dictionary(uniqueKeysWithValues: try await repository.recipes().map { ($0.id, $0) })
        var applied: [NutritionLogMutationReceipt] = []

        do {
            for item in template.items {
                let entry: NutritionLogEntry
                switch item.source {
                case .food:
                    guard let food = foods[item.sourceID] else { throw NutritionError.recordNotFound }
                    let selectedServing = item.servingID.flatMap { id in
                        food.servings.first(where: { $0.id == id })
                    } ?? food.servings.first
                    let serving: FoodServingDefinition
                    if let selectedServing {
                        serving = selectedServing
                    } else {
                        serving = try FoodServingDefinition(name: "100 g", grams: 100)
                    }
                    entry = try NutritionLogEntry(
                        food: food,
                        mealSlot: template.mealSlot,
                        quantity: item.quantity,
                        serving: serving,
                        loggedAt: loggedAt,
                        capturedTimeZone: timeZone,
                        mealTemplateID: template.id,
                        provenance: .mealTemplate,
                        sourceReference: template.title
                    )
                case .recipe:
                    guard let recipe = recipes[item.sourceID] else { throw NutritionError.recordNotFound }
                    let perServing = try recipe.resolvedNutrition.scaled(by: item.quantity / recipe.servingCount)
                    entry = try NutritionLogEntry(
                        id: UUID(),
                        foodID: recipe.id,
                        foodNameSnapshot: recipe.title,
                        mealSlot: template.mealSlot,
                        quantity: item.quantity,
                        servingNameSnapshot: "recipe serving",
                        servingGramsSnapshot: 1,
                        resolvedMacrosSnapshot: perServing,
                        loggedAt: loggedAt,
                        capturedTimeZoneIdentifier: timeZone.identifier,
                        note: nil,
                        recipeID: recipe.id,
                        mealTemplateID: template.id,
                        provenance: .mealTemplate,
                        sourceReference: template.title,
                        createdAt: loggedAt,
                        updatedAt: loggedAt
                    )
                }
                try await repository.save(entry)
                applied.append(.init(before: nil, after: entry, createdAt: loggedAt))
            }
        } catch {
            for receipt in applied.reversed() {
                try? await undo(receipt)
            }
            throw error
        }

        var usedTemplate = template
        usedTemplate.lastUsedAt = loggedAt
        usedTemplate.updatedAt = loggedAt
        try await repository.save(usedTemplate)
        return applied
    }

    public func groceryList(
        title: String,
        recipeIDs: [UUID],
        at date: Date = Date()
    ) async throws -> NutritionGroceryList {
        var items: [GroceryListItem] = []
        for recipeID in recipeIDs {
            let ingredients = try await repository.ingredients(recipeID: recipeID)
            items.append(contentsOf: try ingredients.map {
                try GroceryListItem(
                    title: $0.nameSnapshot,
                    quantity: $0.quantity,
                    unitLabel: $0.unitLabel,
                    sourceRecipeID: recipeID
                )
            })
        }
        let list = try NutritionGroceryList(
            title: title,
            items: items,
            createdAt: date,
            updatedAt: date
        )
        try await repository.save(list)
        return list
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
                let mealPreview = HomeMomentPreview(
                    excerpt: entry.foodNameSnapshot,
                    moodLabel: entry.mealSlot.rawValue.capitalized,
                    capturedAt: entry.loggedAt
                )
                return .init(availability: .ready, title: definition.title, value: entry.foodNameSnapshot, detail: size == .compact ? nil : "\(Int(entry.resolvedMacrosSnapshot.calories.rounded())) kcal · \(entry.mealSlot.rawValue.capitalized)", payload: .moment(mealPreview), actions: inlineActions, updatedAt: entry.updatedAt)
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
                // A hero numeral for the day's energy, with the last week's
                // daily totals behind it. Factual, never a target or a score.
                let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: date))
                let weekEntries = try await repository.logs(from: weekStart, to: date)
                var byDay: [Date: Double] = [:]
                for entry in weekEntries {
                    let day = calendar.startOfDay(for: entry.loggedAt)
                    byDay[day, default: 0] += entry.resolvedMacrosSnapshot.calories
                }
                let history = byDay
                    .map { HomeSeriesPoint(date: $0.key, value: $0.value) }
                    .sorted { $0.date < $1.date }

                var energyPayload = HomeCardPayload.none
                if entries.isEmpty == false {
                    energyPayload = .metric(
                        HomeMetricValue(
                            amount: total.calories.rounded(),
                            unit: "kcal",
                            history: history
                        )
                    )
                }
                return .init(availability: entries.isEmpty ? .empty : .ready, title: definition.title, value: entries.isEmpty ? nil : "\(Int(total.calories.rounded())) kcal", detail: entries.isEmpty ? "Log only when it is useful to you." : detail, payload: energyPayload, actions: inlineActions, updatedAt: entries.map(\.updatedAt).max() ?? date)
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
