import CoreData
import Foundation

public struct DashboardWidgetConfigurationEnvelope: Codable, Hashable, Sendable {
    public let version: Int
    public let payload: Data

    public init(version: Int, payload: Data) {
        self.version = version
        self.payload = payload
    }
}

public struct DashboardWidgetPlacementValue: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var widgetKind: String
    public var semanticSize: WidgetSizePreset
    public var ordinal: Int
    public var isVisible: Bool
    public var configuration: DashboardWidgetConfigurationEnvelope

    public init(
        id: UUID = UUID(),
        widgetKind: String,
        semanticSize: WidgetSizePreset,
        ordinal: Int,
        isVisible: Bool = true,
        configuration: DashboardWidgetConfigurationEnvelope = .init(version: 1, payload: Data())
    ) {
        self.id = id
        self.widgetKind = widgetKind
        self.semanticSize = semanticSize
        self.ordinal = ordinal
        self.isVisible = isVisible
        self.configuration = configuration
    }
}

public struct DashboardLayoutValue: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var mode: DashboardMode
    public var schemaVersion: Int
    public var isDefault: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var placements: [DashboardWidgetPlacementValue]

    public init(
        id: UUID = UUID(),
        mode: DashboardMode,
        schemaVersion: Int = LifeOSFoundationSchema.dashboardLayoutVersion,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        placements: [DashboardWidgetPlacementValue] = []
    ) {
        self.id = id
        self.mode = mode
        self.schemaVersion = schemaVersion
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.placements = placements
    }
}

public protocol DashboardLayoutRepository: Sendable {
    func fetchHome() async throws -> DashboardLayoutValue?
    func saveHome(_ layout: DashboardLayoutValue) async throws
    func resetHomeToCuratedDefault() async throws -> DashboardLayoutValue

    /// Phase I compatibility. Mode-specific callers now resolve the shared Home layout.
    func fetch(mode: DashboardMode) async throws -> DashboardLayoutValue?
    func save(_ layout: DashboardLayoutValue) async throws
    func resetToCuratedDefault(mode: DashboardMode) async throws -> DashboardLayoutValue
    func migrate(_ layout: DashboardLayoutValue) throws -> DashboardLayoutValue
}

public enum DashboardLayoutRepositoryError: Error, Equatable {
    case modelUnavailable
    case unsupportedSchemaVersion(Int)
}

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
        guard layout.schemaVersion <= LifeOSFoundationSchema.dashboardLayoutVersion else {
            throw DashboardLayoutRepositoryError.unsupportedSchemaVersion(layout.schemaVersion)
        }

        var migrated = layout
        migrated.schemaVersion = LifeOSFoundationSchema.dashboardLayoutVersion
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
        let specifications: [(DashboardWidgetKind, WidgetSizePreset)] = [
            (.focusNow, .wide),
            (.lifeSnapshot, .wide),
            (.care, .standard),
            (.scheduleCapacity, .standard),
            (.quickCapture, .compact),
            (.compactTimeline, .wide),
            (.progressReflection, .standard)
        ]
        return specifications.enumerated().map { index, specification in
            DashboardWidgetPlacementValue(
                widgetKind: specification.0.rawValue,
                semanticSize: specification.1,
                ordinal: index
            )
        }
    }
}

public struct HomeLayoutDraft: Equatable, Sendable {
    public let original: DashboardLayoutValue
    public private(set) var current: DashboardLayoutValue

    public init(layout: DashboardLayoutValue) {
        original = layout
        current = layout
    }

    public var hasChanges: Bool { current != original }

    public mutating func move(fromOffsets: IndexSet, toOffset: Int) {
        var placements = current.placements.sorted { $0.ordinal < $1.ordinal }
        let moving = fromOffsets.sorted().compactMap { placements.indices.contains($0) ? placements[$0] : nil }
        for index in fromOffsets.sorted(by: >) where placements.indices.contains(index) {
            placements.remove(at: index)
        }
        let removedBeforeDestination = fromOffsets.filter { $0 < toOffset }.count
        let destination = min(max(0, toOffset - removedBeforeDestination), placements.count)
        placements.insert(contentsOf: moving, at: destination)
        normalize(&placements)
        current.placements = placements
        touch()
    }

    public mutating func resize(id: UUID, to size: WidgetSizePreset, registry: DashboardWidgetRegistry) {
        guard let index = current.placements.firstIndex(where: { $0.id == id }),
              let descriptor = registry.descriptor(
                for: DashboardWidgetKind(rawValue: current.placements[index].widgetKind)
              ),
              descriptor.supportedSizes.contains(size) else {
            return
        }
        current.placements[index].semanticSize = size
        touch()
    }

    public mutating func setVisible(_ isVisible: Bool, id: UUID) {
        guard let index = current.placements.firstIndex(where: { $0.id == id }) else { return }
        current.placements[index].isVisible = isVisible
        touch()
    }

    public mutating func add(
        kind: DashboardWidgetKind,
        size: WidgetSizePreset,
        registry: DashboardWidgetRegistry
    ) {
        guard let descriptor = registry.descriptor(for: kind),
              descriptor.supportedSizes.contains(size) else {
            return
        }
        if descriptor.multiplicity == .singleton,
           current.placements.contains(where: { $0.widgetKind == kind.rawValue }) {
            return
        }
        current.placements.append(
            DashboardWidgetPlacementValue(
                widgetKind: kind.rawValue,
                semanticSize: size,
                ordinal: current.placements.count
            )
        )
        touch()
    }

    public mutating func remove(id: UUID) {
        current.placements.removeAll { $0.id == id }
        normalize(&current.placements)
        touch()
    }

    public mutating func resetToCuratedDefault() {
        current.placements = CoreDataDashboardLayoutRepository.curatedHomePlacements()
        current.isDefault = true
        touch()
    }

    public mutating func cancel() {
        current = original
    }

    public func committedLayout() throws -> DashboardLayoutValue {
        var committed = current
        committed.schemaVersion = LifeOSFoundationSchema.dashboardLayoutVersion
        committed.updatedAt = Date()
        return committed
    }

    private mutating func touch() {
        current.isDefault = false
        current.updatedAt = Date()
    }

    private func normalize(_ placements: inout [DashboardWidgetPlacementValue]) {
        for index in placements.indices {
            placements[index].ordinal = index
        }
    }
}
