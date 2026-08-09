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
    public var destination: Destination
    public var sourceID: String?
    public var filter: String?

    public init(destination: Destination, sourceID: String? = nil, filter: String? = nil) {
        self.destination = destination
        self.sourceID = sourceID
        self.filter = filter
    }
}

public struct HomePlacementMetadata: Codable, Hashable, Sendable {
    public var ownership: HomeCardOwnership
    public var gridPosition: HomeGridPosition?
    public var smartSlot: HomeSmartSlotConfiguration?
    public var sectionOverride: HomeSectionRole?

    public init(
        ownership: HomeCardOwnership = .pinned,
        gridPosition: HomeGridPosition? = nil,
        smartSlot: HomeSmartSlotConfiguration? = nil,
        sectionOverride: HomeSectionRole? = nil
    ) {
        self.ownership = ownership
        self.gridPosition = gridPosition
        self.smartSlot = smartSlot
        self.sectionOverride = sectionOverride
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

    public var sectionOverride: HomeSectionRole? {
        homeConfiguration.placement.sectionOverride
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
        schemaVersion: Int = FoundationSchema.dashboardLayoutVersion,
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

public enum HomeGridPackingService {
    public static func curatedHomePlacements() -> [DashboardWidgetPlacementValue] {
        let specifications: [(DashboardWidgetKind, WidgetSizePreset)] = [
            (.care, .standard),
            (.tasks, .standard),
            (.routines, .standard),
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
        return normalized(placements)
    }

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
        current.placements = HomeGridPackingService.normalized(current.placements)
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

    public mutating func setSection(_ section: HomeSectionRole?, id: UUID) {
        guard let index = current.placements.firstIndex(where: { $0.id == id }) else { return }
        current.placements[index].updateHomeConfiguration {
            $0.placement.sectionOverride = section
            $0.placement.ownership = .pinned
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
        current.placements = HomeGridPackingService.normalized(current.placements)
        touch()
    }

    public mutating func remove(id: UUID) {
        current.placements.removeAll { $0.id == id }
        normalize(&current.placements)
        touch()
    }

    public mutating func resetToCuratedDefault() {
        current.placements = HomeGridPackingService.curatedHomePlacements()
        current.isDefault = true
        touch()
    }

    public mutating func cancel() {
        current = original
    }

    public func committedLayout() throws -> DashboardLayoutValue {
        var committed = current
        committed.schemaVersion = FoundationSchema.dashboardLayoutVersion
        committed.updatedAt = Date()
        return committed
    }

    private mutating func touch() {
        current.isDefault = false
        current.updatedAt = Date()
    }

    private func normalize(_ placements: inout [DashboardWidgetPlacementValue]) {
        placements = HomeGridPackingService.normalized(placements)
    }
}
