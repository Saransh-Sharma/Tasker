import Foundation
import Observation
import UIKit

public enum LifeBoardDestination: String, Codable, CaseIterable, Hashable, Sendable {
    case home
    case plan
    case track
    case insights
    case eva

    public var title: String {
        switch self {
        case .home: return "Home"
        case .plan: return "Plan"
        case .track: return "Track"
        case .insights: return "Insights"
        case .eva: return "Eva"
        }
    }

    public var systemImage: String {
        switch self {
        case .home: return "house"
        case .plan: return "calendar"
        case .track: return "chart.bar.fill"
        case .insights: return "sparkles"
        case .eva: return "bubble.left.and.bubble.right"
        }
    }
}

public enum DaypartSelection: String, Codable, CaseIterable, Hashable, Sendable {
    case automatic
    case morning
    case afternoon
    case evening
    case night

    public var title: String {
        switch self {
        case .automatic: return "Auto"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    public var systemImage: String {
        switch self {
        case .automatic: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .morning: return "sun.horizon"
        case .afternoon: return "sun.max"
        case .evening: return "sunset"
        case .night: return "moon.stars"
        }
    }
}

public enum ResolvedDaypart: String, Codable, CaseIterable, Hashable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    public var greeting: String {
        switch self {
        case .morning: return "Good morning!"
        case .afternoon: return "Good afternoon!"
        case .evening: return "Good evening!"
        case .night: return "Good night!"
        }
    }
}

public enum LifeBoardComfortProfile: String, Codable, CaseIterable, Hashable, Sendable {
    case calm
    case balanced
    case playful

    public var title: String { rawValue.capitalized }
}

public enum DashboardMode: String, Codable, CaseIterable, Hashable, Sendable {
    case smart
    case work
    case personal
    case lowEnergy

    public var title: String {
        switch self {
        case .smart: return "Smart"
        case .work: return "Work"
        case .personal: return "Personal"
        case .lowEnergy: return "Low Energy"
        }
    }
}

public enum WidgetSizePreset: String, CaseIterable, Hashable, Sendable {
    case compact
    case standard
    case wide
    case tall

    public static func persistedValue(rawValue: String) -> WidgetSizePreset? {
        if rawValue == "hero" { return .tall }
        return WidgetSizePreset(rawValue: rawValue)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self.persistedValue(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported widget size preset: \(rawValue)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension WidgetSizePreset: Codable {}

public enum CaptureKind: String, Codable, CaseIterable, Hashable, Sendable {
    case task
    case habit
    case journal
    case note
    case trackerEntry
    case mood
    case hydration
    case medicationEvent
    case routineRun
    case timeBlock

    public var title: String {
        switch self {
        case .task: return "Task"
        case .habit: return "Habit"
        case .journal: return "Journal"
        case .note: return "Note"
        case .trackerEntry: return "Tracker Entry"
        case .mood: return "Mood + Energy"
        case .hydration: return "Hydration"
        case .medicationEvent: return "Medication Event"
        case .routineRun: return "Routine Run"
        case .timeBlock: return "Time Block"
        }
    }

    public var isAvailableInFoundation: Bool {
        true
    }
}

public enum DataSensitivity: String, Codable, CaseIterable, Hashable, Sendable {
    case privateSensitive
    case privateStandard
    case shareEligible
}

public enum AmbientRenderingTier: String, Codable, CaseIterable, Hashable, Sendable {
    case `static`
    case ambient2D
    case enhanced3D

    public var title: String {
        switch self {
        case .static: return "Static"
        case .ambient2D: return "Ambient 2D"
        case .enhanced3D: return "Enhanced 3D"
        }
    }
}

public enum LifeBoardDaypartResolver {
    public static func resolve(
        selection: DaypartSelection,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> ResolvedDaypart {
        switch selection {
        case .automatic:
            return resolve(at: date, calendar: calendar)
        case .morning:
            return .morning
        case .afternoon:
            return .afternoon
        case .evening:
            return .evening
        case .night:
            return .night
        }
    }

    public static func resolve(at date: Date, calendar: Calendar = .current) -> ResolvedDaypart {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }

    public static func nextAutomaticBoundary(after date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        for hour in [5, 12, 17, 21] {
            guard let boundary = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfDay) else {
                continue
            }
            if boundary > date { return boundary }
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay)
            ?? date.addingTimeInterval(86_400)
        return calendar.date(bySettingHour: 5, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}

public struct DaypartOverride: Codable, Hashable, Sendable {
    public let daypart: ResolvedDaypart
    public let activatedAt: Date
    public let expiresAt: Date
    public let timeZoneIdentifier: String

    public init(daypart: ResolvedDaypart, activatedAt: Date, expiresAt: Date, timeZoneIdentifier: String) {
        self.daypart = daypart
        self.activatedAt = activatedAt
        self.expiresAt = expiresAt
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public var selection: DaypartSelection {
        DaypartSelection(rawValue: daypart.rawValue) ?? .automatic
    }
}

public struct DaypartOverrideController: Sendable {
    public private(set) var activeOverride: DaypartOverride?

    public init(activeOverride: DaypartOverride? = nil) {
        self.activeOverride = activeOverride
    }

    public mutating func select(_ selection: DaypartSelection, at date: Date, calendar: Calendar) {
        guard selection != .automatic,
              let daypart = ResolvedDaypart(rawValue: selection.rawValue) else {
            activeOverride = nil
            return
        }
        activeOverride = DaypartOverride(
            daypart: daypart,
            activatedAt: date,
            expiresAt: LifeBoardDaypartResolver.nextAutomaticBoundary(after: date, calendar: calendar),
            timeZoneIdentifier: calendar.timeZone.identifier
        )
    }

    public mutating func resolvedSelection(at date: Date, calendar: Calendar) -> DaypartSelection {
        guard let activeOverride else { return .automatic }
        guard date < activeOverride.expiresAt else {
            self.activeOverride = nil
            return .automatic
        }
        if activeOverride.timeZoneIdentifier != calendar.timeZone.identifier {
            self.activeOverride = DaypartOverride(
                daypart: activeOverride.daypart,
                activatedAt: activeOverride.activatedAt,
                expiresAt: LifeBoardDaypartResolver.nextAutomaticBoundary(after: date, calendar: calendar),
                timeZoneIdentifier: calendar.timeZone.identifier
            )
        }
        return self.activeOverride?.selection ?? .automatic
    }
}

public enum LifeBoardFoundationPreferenceKey {
    public static let comfortProfile = "foundation.presentation.comfort_profile"
    public static let daypartSelection = "foundation.presentation.daypart_selection"
    public static let daypartOverride = "foundation.presentation.daypart_override"
    public static let renderingTier = "foundation.presentation.rendering_tier"
    public static let restorationState = "foundation.navigation.restoration_state"
}

@MainActor
@Observable
public final class LifeBoardPresentationPreferences {
    public var comfortProfile: LifeBoardComfortProfile {
        didSet { defaults.set(comfortProfile.rawValue, forKey: LifeBoardFoundationPreferenceKey.comfortProfile) }
    }

    public var daypartSelection: DaypartSelection {
        didSet { persistDaypartSelection() }
    }

    public var renderingTier: AmbientRenderingTier {
        didSet { defaults.set(renderingTier.rawValue, forKey: LifeBoardFoundationPreferenceKey.renderingTier) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var overrideController: DaypartOverrideController
    @ObservationIgnored private let nowProvider: @Sendable () -> Date
    @ObservationIgnored private let calendarProvider: @Sendable () -> Calendar

    public init(
        defaults: UserDefaults? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: @escaping @Sendable () -> Calendar = { Calendar.current }
    ) {
        let resolvedDefaults = defaults
            ?? UserDefaults(suiteName: AppGroupConstants.suiteName)
            ?? .standard
        self.defaults = resolvedDefaults
        nowProvider = now
        calendarProvider = calendar
        let storedOverride = resolvedDefaults.data(forKey: LifeBoardFoundationPreferenceKey.daypartOverride)
            .flatMap { try? JSONDecoder().decode(DaypartOverride.self, from: $0) }
        let legacySelection = resolvedDefaults.string(forKey: LifeBoardFoundationPreferenceKey.daypartSelection)
            .flatMap(DaypartSelection.init(rawValue:)) ?? .automatic
        var controller = DaypartOverrideController(activeOverride: storedOverride)
        let currentDate = now()
        let currentCalendar = calendar()
        if storedOverride == nil, legacySelection != .automatic {
            // Phase I persisted a manual selection without an expiry envelope. Promote it
            // once so existing users keep their choice until the next natural boundary.
            controller.select(legacySelection, at: currentDate, calendar: currentCalendar)
        }
        let resolvedSelection = controller.resolvedSelection(at: currentDate, calendar: currentCalendar)
        overrideController = controller
        comfortProfile = resolvedDefaults.string(forKey: LifeBoardFoundationPreferenceKey.comfortProfile)
            .flatMap(LifeBoardComfortProfile.init(rawValue:)) ?? .balanced
        daypartSelection = resolvedSelection
        renderingTier = resolvedDefaults.string(forKey: LifeBoardFoundationPreferenceKey.renderingTier)
            .flatMap(AmbientRenderingTier.init(rawValue:)) ?? .ambient2D
    }

    public func resolvedDaypart(at date: Date = Date(), calendar: Calendar = .current) -> ResolvedDaypart {
        let selection = resolvedDaypartSelection(at: date, calendar: calendar)
        return LifeBoardDaypartResolver.resolve(selection: selection, at: date, calendar: calendar)
    }

    public var activeDaypartOverride: DaypartOverride? {
        overrideController.activeOverride
    }

    public func returnToAutomaticDaypart() {
        daypartSelection = .automatic
    }

    private func persistDaypartSelection() {
        overrideController.select(daypartSelection, at: nowProvider(), calendar: calendarProvider())
        defaults.set(daypartSelection.rawValue, forKey: LifeBoardFoundationPreferenceKey.daypartSelection)
        persistOverride()
    }

    private func resolvedDaypartSelection(at date: Date, calendar: Calendar) -> DaypartSelection {
        let resolved = overrideController.resolvedSelection(at: date, calendar: calendar)
        if resolved != daypartSelection {
            daypartSelection = resolved
        } else {
            persistOverride()
        }
        return resolved
    }

    private func persistOverride() {
        guard let activeOverride = overrideController.activeOverride,
              let data = try? JSONEncoder().encode(activeOverride) else {
            defaults.removeObject(forKey: LifeBoardFoundationPreferenceKey.daypartOverride)
            return
        }
        defaults.set(data, forKey: LifeBoardFoundationPreferenceKey.daypartOverride)
    }
}

public struct LifeBoardThemeContext {
    public let daypart: ResolvedDaypart
    public let selection: DaypartSelection
    public let comfortProfile: LifeBoardComfortProfile
    public let renderingTier: AmbientRenderingTier
    public let colorScheme: UIUserInterfaceStyle
    public let accessibilityContrast: UIAccessibilityContrast
    public let reduceMotion: Bool
    public let reduceTransparency: Bool
    public let layoutClass: LifeBoardLayoutClass

    public init(
        daypart: ResolvedDaypart,
        selection: DaypartSelection,
        comfortProfile: LifeBoardComfortProfile,
        renderingTier: AmbientRenderingTier,
        colorScheme: UIUserInterfaceStyle,
        accessibilityContrast: UIAccessibilityContrast,
        reduceMotion: Bool,
        reduceTransparency: Bool,
        layoutClass: LifeBoardLayoutClass
    ) {
        self.daypart = daypart
        self.selection = selection
        self.comfortProfile = comfortProfile
        self.renderingTier = renderingTier
        self.colorScheme = colorScheme
        self.accessibilityContrast = accessibilityContrast
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency
        self.layoutClass = layoutClass
    }
}

public enum LifeOSFoundationSchema {
    public static let dashboardLayoutVersion = 2
    public static let goalContractVersion = 1
    public static let routineContractVersion = 1
    public static let trackerContractVersion = 1
    public static let journalContractVersion = 1
    public static let collaborationContractVersion = 1
}

public protocol LifeOSVersionedDomainContract: Codable, Hashable, Sendable {
    static var schemaVersion: Int { get }
    var id: UUID { get }
    var sensitivity: DataSensitivity { get }
}

public struct LifeOSDomainContract: LifeOSVersionedDomainContract {
    public static let schemaVersion = 1
    public let id: UUID
    public let kind: String
    public let sensitivity: DataSensitivity
    public let payloadVersion: Int

    public init(id: UUID, kind: String, sensitivity: DataSensitivity, payloadVersion: Int = 1) {
        self.id = id
        self.kind = kind
        self.sensitivity = sensitivity
        self.payloadVersion = payloadVersion
    }
}

public struct DashboardWidgetKind: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let focusNow = Self(rawValue: "focusNow")
    public static let lifeSnapshot = Self(rawValue: "lifeSnapshot")
    public static let care = Self(rawValue: "care")
    public static let scheduleCapacity = Self(rawValue: "scheduleCapacity")
    public static let quickCapture = Self(rawValue: "quickCapture")
    public static let compactTimeline = Self(rawValue: "compactTimeline")
    public static let progressReflection = Self(rawValue: "progressReflection")
}

public enum WidgetGalleryCategory: String, Codable, CaseIterable, Sendable {
    case orient, act, plan, wellbeing, reflect, progress
}

public enum WidgetMultiplicity: String, Codable, Sendable {
    case singleton
    case multipleInstances
}

public struct DashboardWidgetDescriptor: Codable, Hashable, Sendable {
    public let kind: DashboardWidgetKind
    public let title: String
    public let category: WidgetGalleryCategory
    public let supportedSizes: Set<WidgetSizePreset>
    public let multiplicity: WidgetMultiplicity
    public let sensitivity: DataSensitivity
    public let configurationVersion: Int

    public init(
        kind: DashboardWidgetKind,
        title: String,
        category: WidgetGalleryCategory,
        supportedSizes: Set<WidgetSizePreset>,
        multiplicity: WidgetMultiplicity,
        sensitivity: DataSensitivity,
        configurationVersion: Int = 1
    ) {
        self.kind = kind
        self.title = title
        self.category = category
        self.supportedSizes = supportedSizes
        self.multiplicity = multiplicity
        self.sensitivity = sensitivity
        self.configurationVersion = configurationVersion
    }
}

public protocol DashboardWidgetRegistry: Sendable {
    func descriptor(for kind: DashboardWidgetKind) -> DashboardWidgetDescriptor?
    func availableDescriptors() -> [DashboardWidgetDescriptor]
}

public struct DefaultDashboardWidgetRegistry: DashboardWidgetRegistry {
    public static let shared = DefaultDashboardWidgetRegistry()

    private let descriptors: [DashboardWidgetDescriptor]

    public init() {
        let allSizes = Set(WidgetSizePreset.allCases)
        descriptors = [
            .init(kind: .focusNow, title: "Focus Now", category: .act, supportedSizes: [.standard, .wide, .tall], multiplicity: .singleton, sensitivity: .privateStandard),
            .init(kind: .lifeSnapshot, title: "Life Snapshot", category: .orient, supportedSizes: [.standard, .wide, .tall], multiplicity: .singleton, sensitivity: .privateSensitive),
            .init(kind: .care, title: "Habits & Medication", category: .wellbeing, supportedSizes: allSizes, multiplicity: .singleton, sensitivity: .privateSensitive),
            .init(kind: .scheduleCapacity, title: "Schedule & Capacity", category: .plan, supportedSizes: [.standard, .wide, .tall], multiplicity: .multipleInstances, sensitivity: .privateStandard),
            .init(kind: .quickCapture, title: "Quick Capture", category: .act, supportedSizes: [.compact, .standard, .wide], multiplicity: .singleton, sensitivity: .privateStandard),
            .init(kind: .compactTimeline, title: "Day Shape", category: .plan, supportedSizes: [.standard, .wide, .tall], multiplicity: .multipleInstances, sensitivity: .privateStandard),
            .init(kind: .progressReflection, title: "Progress & Reflection", category: .reflect, supportedSizes: allSizes, multiplicity: .multipleInstances, sensitivity: .privateSensitive)
        ]
    }

    public func descriptor(for kind: DashboardWidgetKind) -> DashboardWidgetDescriptor? {
        descriptors.first { $0.kind == kind }
    }

    public func availableDescriptors() -> [DashboardWidgetDescriptor] {
        descriptors
    }
}

public enum SmartPromotionKind: String, Codable, Sendable {
    case safetySensitiveCare
    case activeContext
    case overdueOrSoon
    case timedRoutine
    case contextualSuggestion

    public var priority: Int {
        switch self {
        case .safetySensitiveCare: return 500
        case .activeContext: return 400
        case .overdueOrSoon: return 300
        case .timedRoutine: return 200
        case .contextualSuggestion: return 100
        }
    }
}

public struct SmartPromotionCandidate: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let kind: SmartPromotionKind
    public let title: String
    public let reason: String
    public let isUserStartedActiveFocus: Bool
    public let expiresAt: Date?

    public init(
        id: UUID,
        kind: SmartPromotionKind,
        title: String,
        reason: String,
        isUserStartedActiveFocus: Bool = false,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.reason = reason
        self.isUserStartedActiveFocus = isUserStartedActiveFocus
        self.expiresAt = expiresAt
    }
}

public protocol SmartHomePolicy: Sendable {
    func decide(candidates: [SmartPromotionCandidate], now: Date) -> SmartPromotionCandidate?
}

public struct DeterministicSmartHomePolicy: SmartHomePolicy {
    public init() {}

    public func decide(candidates: [SmartPromotionCandidate], now: Date) -> SmartPromotionCandidate? {
        let available = candidates.filter { $0.expiresAt.map { $0 > now } ?? true }
        if let activeFocus = available.first(where: \.isUserStartedActiveFocus) {
            return activeFocus
        }
        return available.sorted {
            if $0.kind.priority != $1.kind.priority { return $0.kind.priority > $1.kind.priority }
            return $0.id.uuidString < $1.id.uuidString
        }.first
    }
}
