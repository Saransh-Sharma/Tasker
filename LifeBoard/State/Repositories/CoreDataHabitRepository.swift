import Foundation
import CoreData

public final class CoreDataHabitRepository: HabitRepositoryProtocol, @unchecked Sendable {
    private let readContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let schemaValidationError: NSError?

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.readContext = container.newBackgroundContext()
        self.readContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        self.schemaValidationError = Self.schemaValidationError(in: container.managedObjectModel)
    }

    /// Executes fetchAll.
    public func fetchAll(completion: @escaping @Sendable (Result<[HabitDefinitionRecord], Error>) -> Void) {
        readContext.perform {
            if let schemaValidationError = self.schemaValidationError {
                completion(.failure(schemaValidationError))
                return
            }
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.readContext,
                    entityName: HabitDefinitionMapper.entityName,
                    sort: [
                        NSSortDescriptor(key: "createdAt", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                completion(.success(objects.map(HabitDefinitionMapper.toDomain)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchByID.
    public func fetchByID(id: UUID, completion: @escaping @Sendable (Result<HabitDefinitionRecord?, Error>) -> Void) {
        readContext.perform {
            if let schemaValidationError = self.schemaValidationError {
                completion(.failure(schemaValidationError))
                return
            }
            do {
                _ = try V2CoreDataRepositorySupport.requireID(id, field: "habit.id")
                let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.readContext,
                    entityName: HabitDefinitionMapper.entityName,
                    predicate: NSPredicate(format: "id == %@", id as CVarArg)
                )
                completion(.success(object.map(HabitDefinitionMapper.toDomain)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes create.
    public func create(_ habit: HabitDefinitionRecord, completion: @escaping @Sendable (Result<HabitDefinitionRecord, Error>) -> Void) {
        backgroundContext.perform {
            if let schemaValidationError = self.schemaValidationError {
                completion(.failure(schemaValidationError))
                return
            }
            do {
                _ = try V2CoreDataRepositorySupport.requireID(habit.id, field: "habit.id")
                _ = try V2CoreDataRepositorySupport.requireNonEmpty(habit.title, field: "habit.title")
                _ = try V2CoreDataRepositorySupport.requireNonEmpty(habit.habitType, field: "habit.habitType")
                if let lifeAreaID = habit.lifeAreaID {
                    _ = try V2CoreDataRepositorySupport.requireID(lifeAreaID, field: "habit.lifeAreaID")
                }
                if let projectID = habit.projectID {
                    _ = try V2CoreDataRepositorySupport.requireID(projectID, field: "habit.projectID")
                }
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: HabitDefinitionMapper.entityName,
                    id: habit.id
                )
                _ = HabitDefinitionMapper.apply(habit, to: object)
                try self.backgroundContext.save()
                completion(.success(habit))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes update.
    public func update(_ habit: HabitDefinitionRecord, completion: @escaping @Sendable (Result<HabitDefinitionRecord, Error>) -> Void) {
        create(habit, completion: completion)
    }

    /// Executes delete.
    public func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            if let schemaValidationError = self.schemaValidationError {
                completion(.failure(schemaValidationError))
                return
            }
            do {
                _ = try V2CoreDataRepositorySupport.requireID(id, field: "habit.id")
                if let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: HabitDefinitionMapper.entityName,
                    predicate: NSPredicate(format: "id == %@", id as CVarArg)
                ) {
                    self.backgroundContext.delete(object)
                    try self.backgroundContext.save()
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    static func schemaValidationError(in model: NSManagedObjectModel) -> NSError? {
        let requiredAttributes: Set<String> = [
            "id",
            "lifeAreaID",
            "projectID",
            "title",
            "habitType",
            "targetConfigData",
            "metricConfigData",
            "isPaused",
            "lastGeneratedDate",
            "streakCurrent",
            "streakBest",
            "kindRaw",
            "trackingModeRaw",
            "iconSymbolName",
            "iconCategoryKey",
            "colorHex",
            "notes",
            "archivedAt",
            "successMask14Raw",
            "failureMask14Raw",
            "lastHistoryRollDate",
            "createdAt",
            "updatedAt"
        ]

        guard let entity = model.entitiesByName[HabitDefinitionMapper.entityName] else {
            return NSError(
                domain: "CoreDataHabitRepository.Schema",
                code: 500,
                userInfo: [
                    NSLocalizedDescriptionKey: "Habit Core Data schema requirements are missing",
                    "missingRequirements": "\(HabitDefinitionMapper.entityName):missing_entity"
                ]
            )
        }

        let existing = Set(entity.attributesByName.keys)
        let missing = requiredAttributes.subtracting(existing).sorted()
        guard missing.isEmpty == false else {
            return nil
        }

        return NSError(
            domain: "CoreDataHabitRepository.Schema",
            code: 500,
            userInfo: [
                NSLocalizedDescriptionKey: "Habit Core Data schema requirements are missing",
                "missingRequirements": "\(HabitDefinitionMapper.entityName):\(missing.joined(separator: ","))"
            ]
        )
    }
}
