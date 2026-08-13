import CoreData
import Foundation

public final class CoreDataNutritionRepository: NutritionRepository, @unchecked Sendable {
    private let container: NSPersistentContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(container: NSPersistentContainer) { self.container = container }

    public func foods(query: String) async throws -> [FoodItem] {
        try await read { [decoder] context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "FoodItem")
            request.affectedStores = Self.localStores(in: context)
            let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                request.predicate = NSPredicate(format: "name CONTAINS[cd] %@ OR brand CONTAINS[cd] %@", normalized, normalized)
            }
            request.sortDescriptors = [
                NSSortDescriptor(key: "isFavorite", ascending: false),
                NSSortDescriptor(key: "name", ascending: true)
            ]
            return try context.fetch(request).compactMap { Self.food($0, decoder: decoder) }
        }
    }

    public func food(barcode: String) async throws -> FoodItem? {
        try await read { [decoder] context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "FoodItem")
            request.affectedStores = Self.localStores(in: context)
            request.predicate = NSPredicate(format: "barcode == %@", barcode.filter(\.isNumber))
            request.fetchLimit = 1
            return try context.fetch(request).first.flatMap { Self.food($0, decoder: decoder) }
        }
    }

    public func recentFoods(limit: Int) async throws -> [FoodItem] {
        let entries = try await logs(from: nil, to: nil)
        let all = try await foods(query: "")
        let lookup = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        var seen = Set<UUID>()
        return entries.compactMap { entry in
            guard seen.insert(entry.foodID).inserted else { return nil }
            return lookup[entry.foodID]
        }.prefix(max(0, limit)).map { $0 }
    }

    public func logs(from: Date?, to: Date?) async throws -> [NutritionLogEntry] {
        try await read { [decoder] context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "NutritionLogEntry")
            request.affectedStores = Self.localStores(in: context)
            var predicates: [NSPredicate] = []
            if let from { predicates.append(NSPredicate(format: "loggedAt >= %@", from as NSDate)) }
            if let to { predicates.append(NSPredicate(format: "loggedAt < %@", to as NSDate)) }
            if !predicates.isEmpty { request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates) }
            request.sortDescriptors = [NSSortDescriptor(key: "loggedAt", ascending: false)]
            return try context.fetch(request).compactMap { Self.log($0, decoder: decoder) }
        }
    }

    public func goals() async throws -> [NutritionGoal] {
        try await read { [decoder] context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "NutritionGoal")
            request.affectedStores = Self.localStores(in: context)
            request.sortDescriptors = [NSSortDescriptor(key: "effectiveFrom", ascending: false)]
            return try context.fetch(request).compactMap { Self.goal($0, decoder: decoder) }
        }
    }

    public func recipes() async throws -> [NutritionRecipe] {
        try await read { [decoder] context in
            let request = Self.localRequest(entity: "Recipe", context: context)
            request.sortDescriptors = [
                NSSortDescriptor(key: "isFavorite", ascending: false),
                NSSortDescriptor(key: "title", ascending: true)
            ]
            return try context.fetch(request).compactMap { Self.recipe($0, decoder: decoder) }
        }
    }

    public func ingredients(recipeID: UUID) async throws -> [RecipeIngredient] {
        try await read { context in
            let request = Self.localRequest(entity: "RecipeIngredient", context: context)
            request.predicate = NSPredicate(format: "recipeID == %@", recipeID as CVarArg)
            request.sortDescriptors = [
                NSSortDescriptor(key: "ordinal", ascending: true),
                NSSortDescriptor(key: "id", ascending: true)
            ]
            return try context.fetch(request).compactMap(Self.ingredient)
        }
    }

    public func mealTemplates() async throws -> [NutritionMealTemplate] {
        try await read { [decoder] context in
            let request = Self.localRequest(entity: "MealTemplate", context: context)
            request.sortDescriptors = [
                NSSortDescriptor(key: "isFavorite", ascending: false),
                NSSortDescriptor(key: "lastUsedAt", ascending: false),
                NSSortDescriptor(key: "title", ascending: true)
            ]
            return try context.fetch(request).compactMap { Self.mealTemplate($0, decoder: decoder) }
        }
    }

    public func groceryLists(includeArchived: Bool) async throws -> [NutritionGroceryList] {
        try await read { [decoder] context in
            let request = Self.localRequest(entity: "GroceryList", context: context)
            if !includeArchived {
                request.predicate = NSPredicate(format: "isArchived == NO")
            }
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            return try context.fetch(request).compactMap { Self.groceryList($0, decoder: decoder) }
        }
    }

    public func servingMemory(foodID: UUID) async throws -> NutritionServingMemory? {
        try await read { context in
            let request = Self.localRequest(entity: "ServingMemory", context: context)
            request.predicate = NSPredicate(format: "foodID == %@", foodID as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "lastUsedAt", ascending: false)]
            request.fetchLimit = 1
            return try context.fetch(request).first.flatMap(Self.servingMemory)
        }
    }

    public func preferences() async throws -> NutritionPreferences {
        try await read { [decoder] context in
            guard let object = try Self.fetch(
                "NutritionPreference",
                id: NutritionPreferences.canonicalID,
                context: context
            ), let value = Self.preferences(object, decoder: decoder) else {
                return try NutritionPreferences()
            }
            return value
        }
    }

    public func save(_ food: FoodItem) async throws {
        let macros = try encoder.encode(food.macrosPer100Grams)
        let servings = try encoder.encode(food.servings)
        try await write { context in
            let object = try Self.upsert("FoodItem", id: food.id, context: context)
            Self.set(object, values: [
                "id": food.id, "name": food.name, "brand": food.brand, "barcode": food.barcode,
                "macrosPer100GramsData": macros, "servingsData": servings, "sourceRaw": food.source.rawValue,
                "externalReference": food.externalReference, "isFavorite": food.isFavorite,
                "createdAt": food.createdAt, "updatedAt": food.updatedAt
            ])
        }
    }

    public func save(_ entry: NutritionLogEntry) async throws {
        let macros = try encoder.encode(entry.resolvedMacrosSnapshot)
        try await write { context in
            let object = try Self.upsert("NutritionLogEntry", id: entry.id, context: context)
            Self.set(object, values: [
                "id": entry.id, "foodID": entry.foodID, "foodNameSnapshot": entry.foodNameSnapshot,
                "mealSlotRaw": entry.mealSlot.rawValue, "quantity": entry.quantity,
                "servingNameSnapshot": entry.servingNameSnapshot, "servingGramsSnapshot": entry.servingGramsSnapshot,
                "resolvedMacrosSnapshotData": macros, "loggedAt": entry.loggedAt,
                "capturedTimeZoneIdentifier": entry.capturedTimeZoneIdentifier, "note": entry.note,
                "recipeID": entry.recipeID, "mealTemplateID": entry.mealTemplateID,
                "provenanceRaw": entry.provenance.rawValue, "sourceReference": entry.sourceReference,
                "createdAt": entry.createdAt, "updatedAt": entry.updatedAt
            ])
            let macroValues: [(HealthMetric, String, Double)] = [
                (.dietaryEnergy, "calories", entry.resolvedMacrosSnapshot.calories),
                (.dietaryProtein, "protein", entry.resolvedMacrosSnapshot.proteinGrams),
                (.dietaryCarbohydrates, "carbohydrates", entry.resolvedMacrosSnapshot.carbohydrateGrams),
                (.dietaryFat, "fat", entry.resolvedMacrosSnapshot.fatGrams)
            ]
            try HealthOutboxCoreDataWriter.enqueue(
                payloads: macroValues.map { metric, role, value in
                    .init(
                        localID: entry.id,
                        metric: metric,
                        role: role,
                        value: value,
                        startDate: entry.loggedAt
                    )
                },
                kind: .update,
                in: context
            )
        }
    }

    public func save(_ goal: NutritionGoal) async throws {
        let macros = try encoder.encode(goal.targetMacros)
        try await write { context in
            let object = try Self.upsert("NutritionGoal", id: goal.id, context: context)
            Self.set(object, values: [
                "id": goal.id, "targetMacrosData": macros, "effectiveFrom": goal.effectiveFrom,
                "capturedTimeZoneIdentifier": goal.capturedTimeZoneIdentifier,
                "createdAt": goal.createdAt, "updatedAt": goal.updatedAt
            ])
        }
    }

    public func save(_ recipe: NutritionRecipe, ingredients: [RecipeIngredient]) async throws {
        guard ingredients.allSatisfy({ $0.recipeID == recipe.id }) else {
            throw NutritionError.invalidRecipe
        }
        let nutrition = try encoder.encode(recipe.resolvedNutrition)
        try await write { context in
            let object = try Self.upsert("Recipe", id: recipe.id, context: context)
            Self.set(object, values: [
                "id": recipe.id, "title": recipe.title, "instructions": recipe.instructions,
                "servingCount": recipe.servingCount, "resolvedNutritionData": nutrition,
                "sourceRaw": recipe.source.rawValue, "externalReference": recipe.externalReference,
                "isFavorite": recipe.isFavorite, "createdAt": recipe.createdAt, "updatedAt": recipe.updatedAt
            ])

            let request = Self.localRequest(entity: "RecipeIngredient", context: context)
            request.predicate = NSPredicate(format: "recipeID == %@", recipe.id as CVarArg)
            let incomingIDs = Set(ingredients.map(\.id))
            for stale in try context.fetch(request) {
                let staleID = stale.value(forKey: "id") as? UUID
                if staleID.map(incomingIDs.contains) != true {
                    context.delete(stale)
                }
            }
            for ingredient in ingredients {
                let ingredientObject = try Self.upsert("RecipeIngredient", id: ingredient.id, context: context)
                Self.set(ingredientObject, values: [
                    "id": ingredient.id, "recipeID": ingredient.recipeID, "foodID": ingredient.foodID,
                    "nameSnapshot": ingredient.nameSnapshot, "quantity": ingredient.quantity,
                    "unitLabel": ingredient.unitLabel, "gramsSnapshot": ingredient.gramsSnapshot,
                    "ordinal": ingredient.ordinal, "createdAt": ingredient.createdAt, "updatedAt": ingredient.updatedAt
                ])
            }
        }
    }

    public func save(_ template: NutritionMealTemplate) async throws {
        let items = try encoder.encode(template.items)
        try await write { context in
            let object = try Self.upsert("MealTemplate", id: template.id, context: context)
            Self.set(object, values: [
                "id": template.id, "title": template.title, "mealSlotRaw": template.mealSlot.rawValue,
                "itemsData": items, "isFavorite": template.isFavorite, "lastUsedAt": template.lastUsedAt,
                "createdAt": template.createdAt, "updatedAt": template.updatedAt
            ])
        }
    }

    public func save(_ groceryList: NutritionGroceryList) async throws {
        let items = try encoder.encode(groceryList.items)
        try await write { context in
            let object = try Self.upsert("GroceryList", id: groceryList.id, context: context)
            Self.set(object, values: [
                "id": groceryList.id, "title": groceryList.title, "itemsData": items,
                "isArchived": groceryList.isArchived, "createdAt": groceryList.createdAt,
                "updatedAt": groceryList.updatedAt
            ])
        }
    }

    public func save(_ memory: NutritionServingMemory) async throws {
        try await write { context in
            let request = Self.localRequest(entity: "ServingMemory", context: context)
            request.predicate = NSPredicate(format: "foodID == %@", memory.foodID as CVarArg)
            request.fetchLimit = 1
            let object = try context.fetch(request).first
                ?? Self.upsert("ServingMemory", id: memory.id, context: context)
            Self.set(object, values: [
                "id": memory.id, "foodID": memory.foodID, "servingName": memory.servingName,
                "grams": memory.grams, "lastUsedAt": memory.lastUsedAt, "usageCount": memory.usageCount
            ])
        }
    }

    public func save(_ preferences: NutritionPreferences) async throws {
        let macros = try preferences.macroTargets.map(encoder.encode)
        let micronutrients = try encoder.encode(preferences.micronutrientTargets)
        try await write { context in
            let object = try Self.upsert("NutritionPreference", id: preferences.id, context: context)
            Self.set(object, values: [
                "id": preferences.id, "caloriesHidden": preferences.caloriesHidden,
                "macroTargetsData": macros, "micronutrientTargetsData": micronutrients,
                "updatedAt": preferences.updatedAt
            ])
        }
    }

    public func deleteFood(id: UUID) async throws { try await delete("FoodItem", id: id) }
    public func deleteLog(id: UUID) async throws {
        try await write { context in
            guard let object = try Self.fetch("NutritionLogEntry", id: id, context: context) else {
                throw NutritionError.recordNotFound
            }
            let date = object.value(forKey: "loggedAt") as? Date ?? Date()
            try HealthOutboxCoreDataWriter.enqueue(
                payloads: [
                    .init(localID: id, metric: .dietaryEnergy, role: "calories", startDate: date),
                    .init(localID: id, metric: .dietaryProtein, role: "protein", startDate: date),
                    .init(localID: id, metric: .dietaryCarbohydrates, role: "carbohydrates", startDate: date),
                    .init(localID: id, metric: .dietaryFat, role: "fat", startDate: date)
                ],
                kind: .delete,
                in: context
            )
            context.delete(object)
        }
    }

    private func delete(_ entity: String, id: UUID) async throws {
        try await write { context in
            guard let object = try Self.fetch(entity, id: id, context: context) else { throw NutritionError.recordNotFound }
            context.delete(object)
        }
    }

    private static func food(_ object: NSManagedObject, decoder: JSONDecoder) -> FoodItem? {
        guard let id = object.value(forKey: "id") as? UUID,
              let name = object.value(forKey: "name") as? String,
              let macroData = object.value(forKey: "macrosPer100GramsData") as? Data,
              let macros = try? decoder.decode(NutritionMacros.self, from: macroData) else { return nil }
        let servings = (object.value(forKey: "servingsData") as? Data).flatMap { try? decoder.decode([FoodServingDefinition].self, from: $0) } ?? []
        return try? FoodItem(
            id: id, name: name, brand: object.value(forKey: "brand") as? String,
            barcode: object.value(forKey: "barcode") as? String, macrosPer100Grams: macros, servings: servings,
            source: (object.value(forKey: "sourceRaw") as? String).flatMap(FoodSource.init(rawValue:)) ?? .userCreated,
            externalReference: object.value(forKey: "externalReference") as? String,
            isFavorite: (object.value(forKey: "isFavorite") as? NSNumber)?.boolValue ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private static func log(_ object: NSManagedObject, decoder: JSONDecoder) -> NutritionLogEntry? {
        guard let id = object.value(forKey: "id") as? UUID,
              let foodID = object.value(forKey: "foodID") as? UUID,
              let name = object.value(forKey: "foodNameSnapshot") as? String,
              let slotRaw = object.value(forKey: "mealSlotRaw") as? String,
              let slot = NutritionMealSlot(rawValue: slotRaw),
              let macroData = object.value(forKey: "resolvedMacrosSnapshotData") as? Data,
              let macros = try? decoder.decode(NutritionMacros.self, from: macroData),
              let loggedAt = object.value(forKey: "loggedAt") as? Date else { return nil }
        return try? NutritionLogEntry(
            id: id, foodID: foodID, foodNameSnapshot: name, mealSlot: slot,
            quantity: (object.value(forKey: "quantity") as? NSNumber)?.doubleValue ?? 1,
            servingNameSnapshot: object.value(forKey: "servingNameSnapshot") as? String ?? "serving",
            servingGramsSnapshot: (object.value(forKey: "servingGramsSnapshot") as? NSNumber)?.doubleValue ?? 100,
            resolvedMacrosSnapshot: macros, loggedAt: loggedAt,
            capturedTimeZoneIdentifier: object.value(forKey: "capturedTimeZoneIdentifier") as? String ?? TimeZone.autoupdatingCurrent.identifier,
            note: object.value(forKey: "note") as? String,
            recipeID: object.value(forKey: "recipeID") as? UUID,
            mealTemplateID: object.value(forKey: "mealTemplateID") as? UUID,
            provenance: (object.value(forKey: "provenanceRaw") as? String)
                .flatMap(NutritionLogProvenance.init(rawValue:)) ?? .foodLibrary,
            sourceReference: object.value(forKey: "sourceReference") as? String,
            createdAt: object.value(forKey: "createdAt") as? Date ?? loggedAt,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? loggedAt
        )
    }

    private static func goal(_ object: NSManagedObject, decoder: JSONDecoder) -> NutritionGoal? {
        guard let id = object.value(forKey: "id") as? UUID,
              let data = object.value(forKey: "targetMacrosData") as? Data,
              let macros = try? decoder.decode(NutritionMacros.self, from: data),
              let effective = object.value(forKey: "effectiveFrom") as? Date else { return nil }
        return NutritionGoal(
            id: id, targetMacros: macros, effectiveFrom: effective,
            capturedTimeZone: TimeZone(identifier: object.value(forKey: "capturedTimeZoneIdentifier") as? String ?? "") ?? .autoupdatingCurrent,
            createdAt: object.value(forKey: "createdAt") as? Date ?? effective,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? effective
        )
    }

    private static func recipe(_ object: NSManagedObject, decoder: JSONDecoder) -> NutritionRecipe? {
        guard let id = object.value(forKey: "id") as? UUID,
              let title = object.value(forKey: "title") as? String,
              let data = object.value(forKey: "resolvedNutritionData") as? Data,
              let nutrition = try? decoder.decode(NutritionMacros.self, from: data) else { return nil }
        return try? NutritionRecipe(
            id: id, title: title, instructions: object.value(forKey: "instructions") as? String,
            servingCount: (object.value(forKey: "servingCount") as? NSNumber)?.doubleValue ?? 1,
            resolvedNutrition: nutrition,
            source: (object.value(forKey: "sourceRaw") as? String).flatMap(FoodSource.init(rawValue:)) ?? .userCreated,
            externalReference: object.value(forKey: "externalReference") as? String,
            isFavorite: (object.value(forKey: "isFavorite") as? NSNumber)?.boolValue ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private static func ingredient(_ object: NSManagedObject) -> RecipeIngredient? {
        guard let id = object.value(forKey: "id") as? UUID,
              let recipeID = object.value(forKey: "recipeID") as? UUID,
              let name = object.value(forKey: "nameSnapshot") as? String else { return nil }
        return try? RecipeIngredient(
            id: id, recipeID: recipeID, foodID: object.value(forKey: "foodID") as? UUID,
            nameSnapshot: name,
            quantity: (object.value(forKey: "quantity") as? NSNumber)?.doubleValue ?? 1,
            unitLabel: object.value(forKey: "unitLabel") as? String ?? "serving",
            gramsSnapshot: (object.value(forKey: "gramsSnapshot") as? NSNumber)?.doubleValue ?? 100,
            ordinal: (object.value(forKey: "ordinal") as? NSNumber)?.intValue ?? 0,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private static func mealTemplate(_ object: NSManagedObject, decoder: JSONDecoder) -> NutritionMealTemplate? {
        guard let id = object.value(forKey: "id") as? UUID,
              let title = object.value(forKey: "title") as? String,
              let slotRaw = object.value(forKey: "mealSlotRaw") as? String,
              let slot = NutritionMealSlot(rawValue: slotRaw),
              let itemsData = object.value(forKey: "itemsData") as? Data,
              let items = try? decoder.decode([MealTemplateItem].self, from: itemsData) else { return nil }
        return try? NutritionMealTemplate(
            id: id, title: title, mealSlot: slot, items: items,
            isFavorite: (object.value(forKey: "isFavorite") as? NSNumber)?.boolValue ?? false,
            lastUsedAt: object.value(forKey: "lastUsedAt") as? Date,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private static func groceryList(_ object: NSManagedObject, decoder: JSONDecoder) -> NutritionGroceryList? {
        guard let id = object.value(forKey: "id") as? UUID,
              let title = object.value(forKey: "title") as? String else { return nil }
        let items = (object.value(forKey: "itemsData") as? Data)
            .flatMap { try? decoder.decode([GroceryListItem].self, from: $0) } ?? []
        return try? NutritionGroceryList(
            id: id, title: title, items: items,
            isArchived: (object.value(forKey: "isArchived") as? NSNumber)?.boolValue ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private static func servingMemory(_ object: NSManagedObject) -> NutritionServingMemory? {
        guard let id = object.value(forKey: "id") as? UUID,
              let foodID = object.value(forKey: "foodID") as? UUID,
              let name = object.value(forKey: "servingName") as? String else { return nil }
        return try? NutritionServingMemory(
            id: id, foodID: foodID, servingName: name,
            grams: (object.value(forKey: "grams") as? NSNumber)?.doubleValue ?? 100,
            lastUsedAt: object.value(forKey: "lastUsedAt") as? Date ?? Date(),
            usageCount: (object.value(forKey: "usageCount") as? NSNumber)?.intValue ?? 0
        )
    }

    private static func preferences(_ object: NSManagedObject, decoder: JSONDecoder) -> NutritionPreferences? {
        let macros = (object.value(forKey: "macroTargetsData") as? Data)
            .flatMap { try? decoder.decode(NutritionMacros.self, from: $0) }
        let micronutrients = (object.value(forKey: "micronutrientTargetsData") as? Data)
            .flatMap { try? decoder.decode([String: Double].self, from: $0) } ?? [:]
        return try? NutritionPreferences(
            id: object.value(forKey: "id") as? UUID ?? NutritionPreferences.canonicalID,
            caloriesHidden: (object.value(forKey: "caloriesHidden") as? NSNumber)?.boolValue ?? false,
            macroTargets: macros, micronutrientTargets: micronutrients,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private func read<T: Sendable>(_ body: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = container.newBackgroundContext()
        return try await context.perform { try body(context) }
    }

    private func write(_ body: @escaping @Sendable (NSManagedObjectContext) throws -> Void) async throws {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        try await context.perform {
            try HealthPrivacyMigrationAccess.requireValidated(in: context)
            try body(context)
            if context.hasChanges { try context.save() }
        }
    }

    private static func fetch(_ entity: String, id: UUID, context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.affectedStores = localStores(in: context)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func localRequest(entity: String, context: NSManagedObjectContext) -> NSFetchRequest<NSManagedObject> {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.affectedStores = localStores(in: context)
        return request
    }

    private static func upsert(_ entity: String, id: UUID, context: NSManagedObjectContext) throws -> NSManagedObject {
        if let value = try fetch(entity, id: id, context: context) {
            return value
        }
        let value = NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
        if let store = localStores(in: context).first {
            context.assign(value, to: store)
        }
        return value
    }

    private static func localStores(in context: NSManagedObjectContext) -> [NSPersistentStore] {
        context.persistentStoreCoordinator?.persistentStores.filter {
            $0.configurationName == "LocalOnly"
        } ?? []
    }

    private static func set(_ object: NSManagedObject, values: [String: Any?]) {
        for (key, value) in values { object.setValue(value, forKey: key) }
    }
}

public final class CoreDataLifeMomentRepository: LifeMomentRepository, @unchecked Sendable {
    private let container: NSPersistentContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(container: NSPersistentContainer) { self.container = container }

    public func moments(includeArchived: Bool) async throws -> [LifeMoment] {
        try await read { [decoder] context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "LifeMoment")
            if !includeArchived { request.predicate = NSPredicate(format: "isArchived == NO") }
            request.sortDescriptors = [NSSortDescriptor(key: "eventDate", ascending: true)]
            return try context.fetch(request).compactMap { Self.value($0, decoder: decoder) }
        }
    }

    public func moment(id: UUID) async throws -> LifeMoment? {
        try await read { [decoder] context in
            try Self.fetch(id, context: context).flatMap { Self.value($0, decoder: decoder) }
        }
    }

    public func save(_ moment: LifeMoment) async throws {
        let recurrence = try encoder.encode(moment.recurrenceRule)
        try await write { context in
            let object = try Self.fetch(moment.id, context: context) ?? NSEntityDescription.insertNewObject(forEntityName: "LifeMoment", into: context)
            let values: [String: Any?] = [
                "id": moment.id, "title": moment.title, "kindRaw": moment.kind.rawValue,
                "eventDate": moment.eventDate, "recurrenceData": recurrence,
                "capturedTimeZoneIdentifier": moment.capturedTimeZoneIdentifier, "note": moment.note,
                "sensitivityRaw": moment.sensitivity.rawValue, "permitsHomeDisplay": moment.permitsHomeDisplay,
                "isArchived": moment.isArchived, "createdAt": moment.createdAt, "updatedAt": moment.updatedAt
            ]
            for (key, value) in values { object.setValue(value, forKey: key) }
        }
    }

    public func archive(id: UUID, at date: Date) async throws {
        guard var value = try await moment(id: id) else { throw LifeMomentRepositoryError.notFound }
        value.isArchived = true
        value.updatedAt = max(date, value.createdAt)
        try await save(value)
    }

    public func delete(id: UUID) async throws {
        try await write { context in
            guard let object = try Self.fetch(id, context: context) else { throw LifeMomentRepositoryError.notFound }
            context.delete(object)
        }
    }

    private static func value(_ object: NSManagedObject, decoder: JSONDecoder) -> LifeMoment? {
        guard let id = object.value(forKey: "id") as? UUID,
              let title = object.value(forKey: "title") as? String,
              let kindRaw = object.value(forKey: "kindRaw") as? String,
              let kind = LifeMomentKind(rawValue: kindRaw),
              let date = object.value(forKey: "eventDate") as? Date else { return nil }
        let recurrence = (object.value(forKey: "recurrenceData") as? Data).flatMap { try? decoder.decode(LifeMomentRecurrenceRule.self, from: $0) } ?? .none
        return try? LifeMoment(
            id: id, title: title, kind: kind, eventDate: date, recurrenceRule: recurrence,
            capturedTimeZone: TimeZone(identifier: object.value(forKey: "capturedTimeZoneIdentifier") as? String ?? "") ?? .autoupdatingCurrent,
            note: object.value(forKey: "note") as? String,
            sensitivity: (object.value(forKey: "sensitivityRaw") as? String).flatMap(DataSensitivity.init(rawValue:)) ?? .privateStandard,
            permitsHomeDisplay: (object.value(forKey: "permitsHomeDisplay") as? NSNumber)?.boolValue ?? false,
            isArchived: (object.value(forKey: "isArchived") as? NSNumber)?.boolValue ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? date,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? date
        )
    }

    private func read<T: Sendable>(_ body: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = container.newBackgroundContext()
        return try await context.perform { try body(context) }
    }

    private func write(_ body: @escaping @Sendable (NSManagedObjectContext) throws -> Void) async throws {
        let context = container.newBackgroundContext()
        try await context.perform { try body(context); if context.hasChanges { try context.save() } }
    }

    private static func fetch(_ id: UUID, context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "LifeMoment")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
