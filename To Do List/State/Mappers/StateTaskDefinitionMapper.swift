import Foundation
import CoreData

public enum StateTaskDefinitionMapper {
    public static func toDomain(from entity: NTask) -> Task {
        StateTaskMapper.toDomain(from: entity)
    }

    @discardableResult
    public static func apply(_ model: Task, to entity: NTask) -> NTask {
        StateTaskMapper.updateEntity(entity, from: model)
        entity.title = model.name
        entity.notes = model.details
        entity.status = model.isComplete ? "completed" : "pending"
        entity.updatedAt = Date() as NSDate
        return entity
    }
}
