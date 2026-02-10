Created NLifeAreaIcon CoreData entity and supporting infrastructure:
- Added entity to TaskModel.xcdatamodeld with iconID, symbolName, category attributes
- Added relationship to Projects entity (inverse relationship on Projects)
- Created NSManagedObject subclass files (CoreDataClass + CoreDataProperties)
- Created LifeAreaIcon domain model with validation
- Created LifeAreaIconMapper with full CRUD operations (toEntity, toDomain, find, getOrCreate)
