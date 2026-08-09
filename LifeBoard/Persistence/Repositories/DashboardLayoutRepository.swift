import LifeBoardContracts
import LifeBoardDomain
import CoreData
import Foundation

public final class CoreDataDashboardLayoutRepository: DashboardLayoutRepository, @unchecked Sendable {
    private enum EntityName {
        static let layout = "DashboardLayout"
        static let placement = "DashboardWidgetPlacement"
    }

    private let container: NSPersistentContainer

    public init(container: NSPersistentContainer) {
        self.container = container
    }

    public func fetchHome() async throws -> DashboardLayoutValue? {
        try await container.performBackgroundTask { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.layout)
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false),
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            let layouts = try request.execute()
            let preferred = layouts.first {
                ($0.value(forKey: "mode") as? String) == DashboardMode.smart.rawValue
            } ?? layouts.first
            return try preferred.map { try self.migrate(Self.value(from: $0)) }
        }
    }

    public func fetch(mode: DashboardMode) async throws -> DashboardLayoutValue? {
        try await fetchHome()
    }

    public func saveHome(_ layout: DashboardLayoutValue) async throws {
        var migrated = try migrate(layout)
        if migrated.mode != .smart {
            migrated = DashboardLayoutValue(
                mode: .smart,
                schemaVersion: migrated.schemaVersion,
                isDefault: migrated.isDefault,
                createdAt: Date(),
                updatedAt: migrated.updatedAt,
                placements: migrated.placements
            )
        }
        try await persist(migrated)
    }

    public func save(_ layout: DashboardLayoutValue) async throws {
        try await saveHome(layout)
    }

    private func persist(_ migrated: DashboardLayoutValue) async throws {
        try await container.performBackgroundTask { context in
            guard let layoutDescription = NSEntityDescription.entity(forEntityName: EntityName.layout, in: context),
                  let placementDescription = NSEntityDescription.entity(forEntityName: EntityName.placement, in: context) else {
                throw DashboardLayoutRepositoryError.modelUnavailable
            }

            let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.layout)
            request.predicate = NSPredicate(format: "id == %@", migrated.id as CVarArg)
            request.fetchLimit = 1
            let object = try request.execute().first ?? NSManagedObject(entity: layoutDescription, insertInto: context)

            object.setValue(migrated.id, forKey: "id")
            object.setValue(migrated.mode.rawValue, forKey: "mode")
            object.setValue(migrated.schemaVersion, forKey: "schemaVersion")
            object.setValue(migrated.isDefault, forKey: "isDefault")
            object.setValue(migrated.createdAt, forKey: "createdAt")
            object.setValue(Date(), forKey: "updatedAt")

            let existing = (object.value(forKey: "placements") as? Set<NSManagedObject>) ?? []
            let byID = Dictionary(uniqueKeysWithValues: existing.compactMap { placement -> (UUID, NSManagedObject)? in
                guard let id = placement.value(forKey: "id") as? UUID else { return nil }
                return (id, placement)
            })
            let incomingIDs = Set(migrated.placements.map(\.id))

            for stale in existing where (stale.value(forKey: "id") as? UUID).map(incomingIDs.contains) != true {
                context.delete(stale)
            }

            for placement in migrated.placements {
                let placementObject = byID[placement.id]
                    ?? NSManagedObject(entity: placementDescription, insertInto: context)
                placementObject.setValue(placement.id, forKey: "id")
                placementObject.setValue(placement.widgetKind, forKey: "widgetKind")
                placementObject.setValue(placement.semanticSize.rawValue, forKey: "semanticSize")
                placementObject.setValue(placement.ordinal, forKey: "ordinal")
                placementObject.setValue(placement.isVisible, forKey: "isVisible")
                placementObject.setValue(placement.configuration.payload, forKey: "configurationData")
                placementObject.setValue(placement.configuration.version, forKey: "configurationVersion")
                placementObject.setValue(object, forKey: "layout")
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }

    public func resetHomeToCuratedDefault() async throws -> DashboardLayoutValue {
        let layout = DashboardLayoutValue(
            mode: .smart,
            isDefault: true,
            placements: Self.curatedHomePlacements()
        )
        try await saveHome(layout)
        return layout
    }

    public func resetToCuratedDefault(mode: DashboardMode) async throws -> DashboardLayoutValue {
        try await resetHomeToCuratedDefault()
    }

    public func migrate(_ layout: DashboardLayoutValue) throws -> DashboardLayoutValue {
        guard layout.schemaVersion <= FoundationSchema.dashboardLayoutVersion else {
            throw DashboardLayoutRepositoryError.unsupportedSchemaVersion(layout.schemaVersion)
        }

        var migrated = layout
        if migrated.schemaVersion < 3, migrated.isDefault {
            let existing = migrated.placements
            let curated = Self.curatedHomePlacements()
            var consumedIDs = Set<UUID>()
            var upgraded: [DashboardWidgetPlacementValue] = curated.compactMap { desired in
                if let preserved = existing.first(where: {
                    $0.widgetKind == desired.widgetKind && consumedIDs.contains($0.id) == false
                }) {
                    consumedIDs.insert(preserved.id)
                    return preserved
                }
                return desired
            }
            upgraded.append(contentsOf: existing.filter { consumedIDs.contains($0.id) == false })
            for index in upgraded.indices { upgraded[index].ordinal = index }
            migrated.placements = upgraded
        }
        if migrated.schemaVersion < 4 {
            migrated.placements = HomeGridPackingService.normalized(migrated.placements)
        }
        if migrated.schemaVersion < 5 {
            // These roles are rendered exactly once by Home's anchored
            // orientation layer. Remove only app-owned copies; pinned/user
            // placements and unknown widget payloads remain recoverable, and
            // Home renders those pinned copies in "Your space".
            //
            // The anchored set is read from the registry rather than repeated
            // here. It used to be a literal set in this file *and* another in
            // the Home view, with different ownership semantics — the view
            // dropped pinned anchored cards unconditionally, so the recovery
            // path this migration deliberately preserves was unreachable.
            let registry = DefaultDashboardWidgetRegistry.shared
            migrated.placements.removeAll { placement in
                let descriptor = registry.descriptor(
                    for: DashboardWidgetKind(rawValue: placement.widgetKind)
                )
                return descriptor?.sectionRole == .anchored && placement.ownership != .pinned
            }

            if migrated.isDefault {
                let existing = migrated.placements
                let curated = Self.curatedHomePlacements()
                var consumedIDs = Set<UUID>()
                var upgraded = curated.map { desired in
                    if let preserved = existing.first(where: {
                        $0.widgetKind == desired.widgetKind && consumedIDs.contains($0.id) == false
                    }) {
                        consumedIDs.insert(preserved.id)
                        return preserved
                    }
                    return desired
                }
                // Preserve unknown widgets and user-added copies after the new
                // defaults. The renderer decides current availability.
                upgraded.append(contentsOf: existing.filter { consumedIDs.contains($0.id) == false })
                for index in upgraded.indices { upgraded[index].ordinal = index }
                migrated.placements = upgraded
            }
            migrated.placements = HomeGridPackingService.normalized(migrated.placements)
        }
        migrated.schemaVersion = FoundationSchema.dashboardLayoutVersion
        migrated.placements.sort {
            if $0.ordinal == $1.ordinal { return $0.id.uuidString < $1.id.uuidString }
            return $0.ordinal < $1.ordinal
        }
        // Unknown widget kinds remain intact. Renderers decide availability and hide unsupported kinds.
        return migrated
    }

    private static func value(from object: NSManagedObject) -> DashboardLayoutValue {
        let placementObjects = (object.value(forKey: "placements") as? Set<NSManagedObject>) ?? []
        let placements = placementObjects.map { placement in
            DashboardWidgetPlacementValue(
                id: placement.value(forKey: "id") as? UUID ?? UUID(),
                widgetKind: placement.value(forKey: "widgetKind") as? String ?? "unknown",
                semanticSize: (placement.value(forKey: "semanticSize") as? String)
                    .flatMap(WidgetSizePreset.persistedValue(rawValue:)) ?? .standard,
                ordinal: placement.value(forKey: "ordinal") as? Int ?? 0,
                isVisible: placement.value(forKey: "isVisible") as? Bool ?? false,
                configuration: .init(
                    version: placement.value(forKey: "configurationVersion") as? Int ?? 1,
                    payload: placement.value(forKey: "configurationData") as? Data ?? Data()
                )
            )
        }

        return DashboardLayoutValue(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            mode: (object.value(forKey: "mode") as? String).flatMap(DashboardMode.init(rawValue:)) ?? .smart,
            schemaVersion: object.value(forKey: "schemaVersion") as? Int ?? 1,
            isDefault: object.value(forKey: "isDefault") as? Bool ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? .distantPast,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? .distantPast,
            placements: placements.sorted { $0.ordinal < $1.ordinal }
        )
    }

    public static func curatedHomePlacements() -> [DashboardWidgetPlacementValue] {
        HomeGridPackingService.curatedHomePlacements()
    }
}
