import CoreData
import XCTest
@testable import LifeBoard

/// The migration chain for `TaskModelV3.xcdatamodeld`.
///
/// The app opens its stores with `NSMigratePersistentStoresAutomaticallyOption`
/// and `NSInferMappingModelAutomaticallyOption` — lightweight migration, with no
/// hand-written mapping models anywhere in the project. That works until a model
/// edit exceeds what Core Data can infer (a renamed attribute without a renaming
/// identifier, an entity hierarchy change, a changed relationship cardinality).
/// When it stops working the failure lands on a *user's* device, at launch, on
/// a store that already holds their data: `addPersistentStore` throws, and the
/// app cannot open the file it wrote.
///
/// Twenty-three model versions shipped with nothing checking this. These tests
/// are the check.
final class CoreDataMigrationChainTests: XCTestCase {
    // MARK: - Model loading

    /// Every compiled version inside the momd, oldest first.
    ///
    /// Ordering comes from `VersionInfo.plist`, not from the filenames — the
    /// versions are named after the feature that added them (`_Trackers`,
    /// `_WellnessCore`), so alphabetical order is not chronological order and
    /// sorting by name would silently test the wrong chain.
    private static func modelVersionURLs() throws -> [URL] {
        let momd = try PersistenceTestModel.url()
        let contents = try FileManager.default.contentsOfDirectory(
            at: momd,
            includingPropertiesForKeys: nil
        )
        return contents.filter { $0.pathExtension == "mom" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func currentModel() throws -> NSManagedObjectModel {
        try PersistenceTestModel.model()
    }

    // MARK: - Chain integrity

    func testEveryShippedModelVersionCanInferAMappingToTheCurrentModel() throws {
        let current = try Self.currentModel()
        let versions = try Self.modelVersionURLs()
        XCTAssertGreaterThanOrEqual(
            versions.count, 20,
            "the momd should contain every shipped version; finding only a few means the bundle lookup is wrong, not that versions were deleted"
        )

        var unmigratable: [String] = []
        for url in versions {
            guard let source = NSManagedObjectModel(contentsOf: url) else {
                XCTFail("model version did not load: \(url.lastPathComponent)")
                continue
            }
            if source.entityVersionHashesByName == current.entityVersionHashesByName {
                continue  // this *is* the current version
            }
            let inferred = try? NSMappingModel.inferredMappingModel(
                forSourceModel: source,
                destinationModel: current
            )
            if inferred == nil {
                unmigratable.append(url.deletingPathExtension().lastPathComponent)
            }
        }

        XCTAssertEqual(
            unmigratable, [],
            """
            Core Data cannot infer a migration from these versions to the current model. \
            A user still on one of them cannot open their store after updating. \
            Fix the offending model edit (a renaming identifier usually suffices) or \
            add an explicit mapping model.
            """
        )
    }

    // MARK: - End-to-end

    /// Writes a store at the oldest shipped version, puts a row in it, then
    /// opens it with the current model exactly the way the app does — and
    /// checks the row is still there afterwards.
    ///
    /// The inference check above proves a migration *can* be built. This proves
    /// one actually runs and carries data across.
    func testDataWrittenAtTheOldestVersionSurvivesMigrationToCurrent() throws {
        let versions = try Self.modelVersionURLs()
        let oldestURL = try XCTUnwrap(
            versions.first(where: { $0.lastPathComponent == "TaskModelV3.mom" }),
            "the original TaskModelV3 version is missing from the momd"
        )
        let oldest = try XCTUnwrap(NSManagedObjectModel(contentsOf: oldestURL))
        let taskEntity = try XCTUnwrap(
            oldest.entitiesByName["TaskDefinition"],
            "TaskDefinition should exist in the first version"
        )
        let configuration = try XCTUnwrap(
            oldest.configurations.first(where: {
                oldest.entities(forConfigurationName: $0)?.contains(taskEntity) == true
            }) ?? oldest.configurations.first,
            "no configuration contains TaskDefinition"
        )

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-chain-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("TaskModelV3.sqlite")

        let identifier = UUID()
        try autoreleasepool {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: oldest)
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: configuration,
                at: storeURL,
                options: nil
            )
            let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator
            try context.performAndWait {
                let task = NSEntityDescription.insertNewObject(
                    forEntityName: "TaskDefinition",
                    into: context
                )
                task.setValue(identifier, forKey: "id")
                if task.entity.attributesByName["title"] != nil {
                    task.setValue("A task written before every migration", forKey: "title")
                }
                try context.save()
            }
            for store in coordinator.persistentStores {
                try coordinator.remove(store)
            }
        }

        // Opened the same way `makeV3PersistentContainer` opens it.
        let current = try Self.currentModel()
        let migrated = NSPersistentStoreCoordinator(managedObjectModel: current)
        let options: [AnyHashable: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        let currentConfiguration = current.configurations.first(where: {
            current.entities(forConfigurationName: $0)?
                .contains(where: { $0.name == "TaskDefinition" }) == true
        })
        try migrated.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: currentConfiguration,
            at: storeURL,
            options: options
        )

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = migrated
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
            request.predicate = NSPredicate(format: "id == %@", identifier as CVarArg)
            let results = try context.fetch(request)
            XCTAssertEqual(
                results.count, 1,
                "the task written at the first model version did not survive migration to the current one"
            )
        }
    }

    // MARK: - Store layout

    /// The app splits its data across two configurations and opens one store
    /// per configuration. An entity that belongs to neither is unreachable at
    /// runtime — it migrates fine and then cannot be fetched.
    func testEveryEntityBelongsToAConfigurationTheAppOpens() throws {
        let current = try Self.currentModel()
        let opened = ["CloudSync", "LocalOnly"]
        for name in opened {
            XCTAssertTrue(
                current.configurations.contains(name),
                "the app opens a store for configuration `\(name)`, which the model does not declare"
            )
        }

        let reachable = Set(
            opened.flatMap { current.entities(forConfigurationName: $0)?.compactMap(\.name) ?? [] }
        )
        let all = Set(current.entities.compactMap(\.name))
        XCTAssertEqual(
            all.subtracting(reachable), [],
            "these entities are in no configuration the app opens, so nothing can read them"
        )
    }
}
