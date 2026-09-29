import LifeBoardDomain
import Foundation
import CoreData

public final class CoreDataTaskDependencyRepository: TaskDependencyRepositoryProtocol, @unchecked Sendable {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    /// Executes fetchDependencies.
    public func fetchDependencies(taskID: UUID, completion: @escaping @Sendable (Result<[TaskDependencyLinkDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(taskID, field: "taskDependency.taskID")
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "TaskDependency",
                    predicate: NSPredicate(format: "taskID == %@", taskID as CVarArg),
                    sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
                )
                let mapped = objects.compactMap { object -> TaskDependencyLinkDefinition? in
                    guard
                        let taskID = object.value(forKey: "taskID") as? UUID,
                        let dependsOnTaskID = object.value(forKey: "dependsOnTaskID") as? UUID,
                        let rawKind = object.value(forKey: "kind") as? String,
                        let kind = TaskDependencyKind(rawValue: rawKind)
                    else {
                        return nil
                    }
                    return TaskDependencyLinkDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        taskID: taskID,
                        dependsOnTaskID: dependsOnTaskID,
                        kind: kind,
                        createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
                    )
                }
                completion(.success(mapped))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes replaceDependencies.
    public func replaceDependencies(
        taskID: UUID,
        dependencies: [TaskDependencyLinkDefinition],
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(taskID, field: "taskDependency.taskID")
                let sanitized = dependencies
                    .filter { $0.taskID == taskID && $0.dependsOnTaskID != taskID }
                    .filter { $0.kind == .blocks || $0.kind == .related }
                    .compactMap { dependency -> TaskDependencyLinkDefinition? in
                        do {
                            _ = try V2CoreDataRepositorySupport.requireID(dependency.dependsOnTaskID, field: "taskDependency.dependsOnTaskID")
                            return dependency
                        } catch {
                            return nil
                        }
                    }

                let uniqueDependencies = Dictionary(
                    sanitized.map {
                        (
                            V2CoreDataRepositorySupport.compositeKey([
                                taskID.uuidString,
                                $0.dependsOnTaskID.uuidString,
                                $0.kind.rawValue
                            ]),
                            $0
                        )
                    },
                    uniquingKeysWith: { first, _ in first }
                ).values

                let existing = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.backgroundContext,
                    entityName: "TaskDependency",
                    predicate: NSPredicate(format: "taskID == %@", taskID as CVarArg)
                )
                for object in existing {
                    self.backgroundContext.delete(object)
                }

                for dependency in uniqueDependencies {
                    let object = NSEntityDescription.insertNewObject(forEntityName: "TaskDependency", into: self.backgroundContext)
                    object.setValue(dependency.id, forKey: "id")
                    object.setValue(taskID, forKey: "taskID")
                    object.setValue(dependency.dependsOnTaskID, forKey: "dependsOnTaskID")
                    object.setValue(dependency.kind.rawValue, forKey: "kind")
                    object.setValue(dependency.createdAt, forKey: "createdAt")
                }

                try self.backgroundContext.save()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
