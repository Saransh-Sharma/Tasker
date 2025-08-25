import Foundation
import CoreData

/// Use case protocol for retrieving a single task by ID
protocol GetTaskByIdUseCase {
    func execute(taskID: NSManagedObjectID, completion: @escaping (Result<NTask, Error>) -> Void)
}
