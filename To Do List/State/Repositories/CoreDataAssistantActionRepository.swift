import Foundation
import CoreData

public final class CoreDataAssistantActionRepository: AssistantActionRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let completionQueue: DispatchQueue

    /// Initializes a new instance.
    public init(container: NSPersistentContainer, completionQueue: DispatchQueue = .main) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        self.completionQueue = completionQueue
    }

    /// Executes createRun.
    public func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        persist(run, completion: completion)
    }

    /// Executes updateRun.
    public func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        persist(run, completion: completion)
    }

    /// Executes fetchRun.
    public func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void) {
        viewContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(id, field: "assistantActionRun.id")
                guard let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.viewContext,
                    entityName: "AssistantActionRun",
                    predicate: NSPredicate(format: "id == %@", id as CVarArg)
                ) else {
                    self.complete(.success(nil), completion: completion)
                    return
                }
                self.complete(.success(Self.map(object)), completion: completion)
            } catch {
                self.complete(.failure(error), completion: completion)
            }
        }
    }

    /// Executes persist.
    private func persist(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(run.id, field: "assistantActionRun.id")
                if let threadID = run.threadID {
                    _ = try V2CoreDataRepositorySupport.requireNonEmpty(
                        threadID,
                        field: "assistantActionRun.threadID"
                    )
                }
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "AssistantActionRun",
                    id: run.id
                )
                object.setValue(run.id, forKey: "id")
                object.setValue(run.threadID, forKey: "threadID")
                object.setValue(run.proposalData, forKey: "proposalData")
                object.setValue(run.status.rawValue, forKey: "status")
                object.setValue(run.confirmedAt, forKey: "confirmedAt")
                object.setValue(run.appliedAt, forKey: "appliedAt")
                object.setValue(run.rejectedAt, forKey: "rejectedAt")
                object.setValue(run.resultSummary, forKey: "resultSummary")
                object.setValue(run.executionTraceData, forKey: "executionTraceData")
                object.setValue(run.rollbackStatus?.rawValue, forKey: "rollbackStatus")
                object.setValue(run.rollbackVerifiedAt, forKey: "rollbackVerifiedAt")
                object.setValue(run.lastErrorCode, forKey: "lastErrorCode")
                object.setValue(run.createdAt, forKey: "createdAt")
                try self.backgroundContext.save()
                self.complete(.success(run), completion: completion)
            } catch {
                self.complete(.failure(error), completion: completion)
            }
        }
    }

    private func complete<T>(
        _ result: Result<T, Error>,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        completionQueue.async {
            completion(result)
        }
    }

    /// Executes map.
    private static func map(_ object: NSManagedObject) -> AssistantActionRunDefinition {
        AssistantActionRunDefinition(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            threadID: object.value(forKey: "threadID") as? String,
            proposalData: object.value(forKey: "proposalData") as? Data,
            status: AssistantActionStatus(rawValue: object.value(forKey: "status") as? String ?? "pending") ?? .pending,
            confirmedAt: object.value(forKey: "confirmedAt") as? Date,
            appliedAt: object.value(forKey: "appliedAt") as? Date,
            rejectedAt: object.value(forKey: "rejectedAt") as? Date,
            resultSummary: object.value(forKey: "resultSummary") as? String,
            executionTraceData: object.value(forKey: "executionTraceData") as? Data,
            rollbackStatus: AssistantRollbackStatus(rawValue: object.value(forKey: "rollbackStatus") as? String ?? ""),
            rollbackVerifiedAt: object.value(forKey: "rollbackVerifiedAt") as? Date,
            lastErrorCode: object.value(forKey: "lastErrorCode") as? String,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
        )
    }
}
