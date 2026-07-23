import CoreData
import Foundation

public struct DashboardWidgetConfigurationEnvelope: Codable, Hashable, Sendable {
    public let version: Int
    public let payload: Data

    public init(version: Int, payload: Data) {
        self.version = version
        self.payload = payload
    }

    public var homeConfiguration: HomeCardConfiguration {
        if version >= HomeCardConfiguration.storageVersion,
           let decoded = try? JSONDecoder().decode(HomeCardConfiguration.self, from: payload) {
            return decoded
        }
        return HomeCardConfiguration(domainPayload: payload)
    }

    public static func home(_ configuration: HomeCardConfiguration) -> Self {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return Self(
            version: HomeCardConfiguration.storageVersion,
            payload: (try? encoder.encode(configuration)) ?? Data()
        )
    }
}

public struct HomeCardSourceConfiguration: Codable, Hashable, Sendable {
    public var destination: LifeBoardDestination
    public var sourceID: String?
    public var filter: String?

    public init(destination: LifeBoardDestination, sourceID: String? = nil, filter: String? = nil) {
        self.destination = destination
        self.sourceID = sourceID
        self.filter = filter
    }
}

public struct HomePlacementMetadata: Codable, Hashable, Sendable {
    public var ownership: HomeCardOwnership
    public var gridPosition: HomeGridPosition?
    public var smartSlot: HomeSmartSlotConfiguration?

    public init(
        ownership: HomeCardOwnership = .pinned,
        gridPosition: HomeGridPosition? = nil,
        smartSlot: HomeSmartSlotConfiguration? = nil
    ) {
        self.ownership = ownership
        self.gridPosition = gridPosition
        self.smartSlot = smartSlot
    }
}

public struct HomeCardConfiguration: Codable, Hashable, Sendable {
    public static let storageVersion = 2

    public var source: HomeCardSourceConfiguration?
    public var placement: HomePlacementMetadata
    public var domainPayload: Data

    public init(
        source: HomeCardSourceConfiguration? = nil,
        placement: HomePlacementMetadata = .init(),
        domainPayload: Data = Data()
    ) {
        self.source = source
        self.placement = placement
        self.domainPayload = domainPayload
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

    public var homeConfiguration: HomeCardConfiguration {
        configuration.homeConfiguration
    }

    public var ownership: HomeCardOwnership {
        homeConfiguration.placement.ownership
    }

    public var gridPosition: HomeGridPosition? {
        homeConfiguration.placement.gridPosition
    }

    public var smartSlot: HomeSmartSlotConfiguration? {
        homeConfiguration.placement.smartSlot
    }

    public mutating func updateHomeConfiguration(
        _ update: (inout HomeCardConfiguration) -> Void
    ) {
        var decoded = configuration.homeConfiguration
        update(&decoded)
        configuration = .home(decoded)
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
            migrated.placements = HomeGridPackingEngine.normalized(migrated.placements)
        }
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
            (.tasks, .standard),
            (.routines, .standard),
            (.scheduleCapacity, .standard),
            (.quickCapture, .compact),
            (.compactTimeline, .wide),
            (.journal, .standard),
            (.progressReflection, .standard)
        ]
        let placements = specifications.enumerated().map { index, specification in
            DashboardWidgetPlacementValue(
                widgetKind: specification.0.rawValue,
                semanticSize: specification.1,
                ordinal: index
            )
        }
        return HomeGridPackingEngine.normalized(placements)
    }
}

public enum HomeGridPackingEngine {
    public static func normalized(
        _ placements: [DashboardWidgetPlacementValue],
        columns: Int = 4
    ) -> [DashboardWidgetPlacementValue] {
        let columnCount = max(1, columns)
        var occupied = Set<HomeGridPosition>()
        var result: [DashboardWidgetPlacementValue] = []

        for (ordinal, value) in placements.sorted(by: placementOrder).enumerated() {
            var placement = value
            placement.ordinal = ordinal
            let span = placement.semanticSize.canonicalGridSpan
            let width = min(columnCount, span.columns)
            let position = firstAvailablePosition(
                width: width,
                height: span.rows,
                columns: columnCount,
                occupied: occupied
            )
            for row in position.row..<(position.row + span.rows) {
                for column in position.column..<(position.column + width) {
                    occupied.insert(.init(column: column, row: row))
                }
            }
            placement.updateHomeConfiguration { configuration in
                configuration.placement.gridPosition = position
                if configuration.placement.ownership == .smart,
                   configuration.placement.smartSlot == nil {
                    configuration.placement.smartSlot = .init()
                }
            }
            result.append(placement)
        }
        return result
    }

    private static func firstAvailablePosition(
        width: Int,
        height: Int,
        columns: Int,
        occupied: Set<HomeGridPosition>
    ) -> HomeGridPosition {
        var row = 0
        while true {
            for column in 0...max(0, columns - width) {
                let fits = (row..<(row + height)).allSatisfy { candidateRow in
                    (column..<(column + width)).allSatisfy { candidateColumn in
                        occupied.contains(.init(column: candidateColumn, row: candidateRow)) == false
                    }
                }
                if fits { return .init(column: column, row: row) }
            }
            row += 1
        }
    }

    private static func placementOrder(
        _ lhs: DashboardWidgetPlacementValue,
        _ rhs: DashboardWidgetPlacementValue
    ) -> Bool {
        if lhs.ordinal != rhs.ordinal { return lhs.ordinal < rhs.ordinal }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

public struct HomeLayoutTransaction: Codable, Hashable, Sendable {
    public let id: UUID
    public let before: DashboardLayoutValue
    public let after: DashboardLayoutValue
    public let committedAt: Date

    public init(
        id: UUID = UUID(),
        before: DashboardLayoutValue,
        after: DashboardLayoutValue,
        committedAt: Date = Date()
    ) {
        self.id = id
        self.before = before
        self.after = after
        self.committedAt = committedAt
    }

    public var undoLayout: DashboardLayoutValue { before }
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
        current.placements = HomeGridPackingEngine.normalized(current.placements)
        touch()
    }

    public mutating func setOwnership(
        _ ownership: HomeCardOwnership,
        smartSlot: HomeSmartSlotConfiguration? = nil,
        id: UUID
    ) {
        guard let index = current.placements.firstIndex(where: { $0.id == id }) else { return }
        current.placements[index].updateHomeConfiguration { configuration in
            configuration.placement.ownership = ownership
            configuration.placement.smartSlot = ownership == .smart
                ? (smartSlot ?? configuration.placement.smartSlot ?? .init())
                : nil
        }
        touch()
    }

    public mutating func setSource(_ source: HomeCardSourceConfiguration?, id: UUID) {
        guard let index = current.placements.firstIndex(where: { $0.id == id }) else { return }
        current.placements[index].updateHomeConfiguration { configuration in
            configuration.source = source
        }
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
        current.placements = HomeGridPackingEngine.normalized(current.placements)
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
        placements = HomeGridPackingEngine.normalized(placements)
    }
}
