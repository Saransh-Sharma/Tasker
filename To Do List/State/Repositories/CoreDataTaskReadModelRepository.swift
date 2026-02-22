import Foundation
import CoreData

public final class CoreDataTaskReadModelRepository: TaskReadModelRepositoryProtocol {
    private let context: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.context = container.newBackgroundContext()
        self.context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Executes fetchTasks.
    public func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        context.perform {
            do {
                let predicate = self.predicate(for: query)
                let totalCount = try self.countTasks(predicate: predicate)
                let entities = try self.fetchTaskEntities(
                    predicate: predicate,
                    sortDescriptors: self.sortDescriptors(for: query.sortBy),
                    limit: query.limit,
                    offset: query.offset
                )
                let definitions = try CoreDataTaskDefinitionRepository.mapTaskDefinitions(entities, context: self.context)
                completion(.success(TaskDefinitionSliceResult(
                    tasks: definitions,
                    totalCount: totalCount,
                    limit: query.limit,
                    offset: query.offset
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes searchTasks.
    public func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        context.perform {
            do {
                let predicate = self.searchPredicate(for: query)
                let totalCount = try self.countTasks(predicate: predicate)
                let entities = try self.fetchTaskEntities(
                    predicate: predicate,
                    sortDescriptors: self.sortDescriptors(for: .updatedAtDescending),
                    limit: query.limit,
                    offset: query.offset
                )
                let definitions = try CoreDataTaskDefinitionRepository.mapTaskDefinitions(entities, context: self.context)
                completion(.success(TaskDefinitionSliceResult(
                    tasks: definitions,
                    totalCount: totalCount,
                    limit: query.limit,
                    offset: query.offset
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchLatestTaskUpdatedAt.
    public func fetchLatestTaskUpdatedAt(completion: @escaping (Result<Date?, Error>) -> Void) {
        context.perform {
            do {
                let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
                request.sortDescriptors = [
                    NSSortDescriptor(key: "updatedAt", ascending: false),
                    NSSortDescriptor(key: "taskID", ascending: true),
                    NSSortDescriptor(key: "id", ascending: true)
                ]
                request.fetchLimit = 1
                let latest = try self.context.fetch(request).first?.value(forKey: "updatedAt") as? Date
                completion(.success(latest))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchProjectTaskCounts.
    public func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    ) {
        context.perform {
            do {
                let countExpr = NSExpressionDescription()
                countExpr.name = "taskCount"
                countExpr.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "taskID")])
                countExpr.expressionResultType = .integer64AttributeType

                let request = NSFetchRequest<NSDictionary>(entityName: "TaskDefinition")
                request.resultType = .dictionaryResultType
                request.propertiesToGroupBy = ["projectID"]
                request.propertiesToFetch = ["projectID", countExpr]
                if includeCompleted == false {
                    request.predicate = NSPredicate(format: "isComplete == NO")
                }

                let rows = try self.context.fetch(request)
                var counts: [UUID: Int] = [:]
                for row in rows {
                    guard let projectID = row["projectID"] as? UUID else { continue }
                    let countValue = (row["taskCount"] as? NSNumber)?.intValue ?? 0
                    counts[projectID] = countValue
                }
                completion(.success(counts))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchProjectCompletionScoreTotals.
    public func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    ) {
        context.perform {
            do {
                let countExpr = NSExpressionDescription()
                countExpr.name = "taskCount"
                countExpr.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "taskID")])
                countExpr.expressionResultType = .integer64AttributeType

                let request = NSFetchRequest<NSDictionary>(entityName: "TaskDefinition")
                request.resultType = .dictionaryResultType
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "isComplete == YES"),
                    NSPredicate(format: "dateCompleted >= %@", startDate as NSDate),
                    NSPredicate(format: "dateCompleted <= %@", endDate as NSDate)
                ])
                request.propertiesToGroupBy = ["projectID", "priority"]
                request.propertiesToFetch = ["projectID", "priority", countExpr]

                let rows = try self.context.fetch(request)
                var totals: [UUID: Int] = [:]
                for row in rows {
                    guard let projectID = row["projectID"] as? UUID else { continue }
                    let countValue = (row["taskCount"] as? NSNumber)?.intValue ?? 0
                    let priorityRaw = (row["priority"] as? NSNumber)?.int32Value
                        ?? (row["priority"] as? Int32)
                        ?? Int32(TaskPriority.low.rawValue)
                    let priority = TaskPriority(rawValue: priorityRaw)
                    totals[projectID, default: 0] += countValue * priority.scorePoints
                }
                completion(.success(totals))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes countTasks.
    private func countTasks(predicate: NSPredicate?) throws -> Int {
        let countRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TaskDefinition")
        countRequest.predicate = predicate
        let count = try context.count(for: countRequest)
        return max(0, count)
    }

    /// Executes fetchTaskEntities.
    private func fetchTaskEntities(
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        limit: Int,
        offset: Int
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        request.fetchLimit = max(1, limit)
        request.fetchOffset = max(0, offset)
        return try context.fetch(request)
    }

    /// Executes predicate.
    private func predicate(for query: TaskReadQuery) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        if let projectID = query.projectID {
            predicates.append(NSPredicate(format: "projectID == %@", projectID as CVarArg))
        }
        if query.includeCompleted == false {
            predicates.append(NSPredicate(format: "isComplete == NO"))
        }
        if let dueDateStart = query.dueDateStart {
            predicates.append(NSPredicate(format: "dueDate >= %@", dueDateStart as NSDate))
        }
        if let dueDateEnd = query.dueDateEnd {
            predicates.append(NSPredicate(format: "dueDate <= %@", dueDateEnd as NSDate))
        }
        if let updatedAfter = query.updatedAfter {
            predicates.append(NSPredicate(format: "updatedAt >= %@", updatedAfter as NSDate))
        }
        guard predicates.isEmpty == false else { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    /// Executes searchPredicate.
    private func searchPredicate(for query: TaskSearchQuery) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        if let projectID = query.projectID {
            predicates.append(NSPredicate(format: "projectID == %@", projectID as CVarArg))
        }
        if query.includeCompleted == false {
            predicates.append(NSPredicate(format: "isComplete == NO"))
        }
        let trimmed = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false {
            predicates.append(
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "title CONTAINS[cd] %@", trimmed),
                    NSPredicate(format: "notes CONTAINS[cd] %@", trimmed)
                ])
            )
        }
        guard predicates.isEmpty == false else { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    /// Executes sortDescriptors.
    private func sortDescriptors(for sort: TaskReadSort) -> [NSSortDescriptor] {
        switch sort {
        case .dueDateAscending:
            return [
                NSSortDescriptor(key: "dueDate", ascending: true),
                NSSortDescriptor(key: "updatedAt", ascending: false),
                NSSortDescriptor(key: "taskID", ascending: true),
                NSSortDescriptor(key: "id", ascending: true)
            ]
        case .dueDateDescending:
            return [
                NSSortDescriptor(key: "dueDate", ascending: false),
                NSSortDescriptor(key: "updatedAt", ascending: false),
                NSSortDescriptor(key: "taskID", ascending: true),
                NSSortDescriptor(key: "id", ascending: true)
            ]
        case .updatedAtDescending:
            return [
                NSSortDescriptor(key: "updatedAt", ascending: false),
                NSSortDescriptor(key: "taskID", ascending: true),
                NSSortDescriptor(key: "id", ascending: true)
            ]
        }
    }
}
