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

/// The three intentionally small ways of looking at recorded life data.
public enum TrackLens: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case today
    case areas
    case history

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// Insight is organized by the question a person is asking, not by database scope.
public enum InsightsLens: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case overview
    case trends
    case review

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// Presentation-neutral lifecycle shared by async controls and proposal cards.
public enum LifeBoardInteractionPhase: String, Codable, CaseIterable, Hashable, Sendable {
    case idle
    case pressed
    case running
    case success
    case recoverableFailure
    case cancelled
}

/// A stable, serializable point used to hand capture motion between screen coordinates.
public struct LifeBoardNormalizedPoint: Codable, Hashable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = min(1, max(0, x))
        self.y = min(1, max(0, y))
    }
}

public struct CapturePresentationContext: Codable, Hashable, Sendable {
    public let sourceRoot: LifeBoardDestination
    public let sourcePoint: LifeBoardNormalizedPoint?
    public let preferredCaptureKind: CaptureKind?

    public init(
        sourceRoot: LifeBoardDestination,
        sourcePoint: LifeBoardNormalizedPoint? = nil,
        preferredCaptureKind: CaptureKind? = nil
    ) {
        self.sourceRoot = sourceRoot
        self.sourcePoint = sourcePoint
        self.preferredCaptureKind = preferredCaptureKind
    }
}

/// The smallest authorized context that may cross from a product surface into Eva.
public struct EvaEntryContext: Codable, Hashable, Sendable {
    public let origin: LifeBoardDestination
    public let evidenceReferences: [UUID]
    public let requestedAssistance: String
    public let createdAt: Date

    public init(
        origin: LifeBoardDestination,
        evidenceReferences: [UUID] = [],
        requestedAssistance: String,
        createdAt: Date = Date()
    ) {
        self.origin = origin
        self.evidenceReferences = evidenceReferences
        self.requestedAssistance = requestedAssistance
        self.createdAt = createdAt
    }
}

/// The centrally governed signature-effect allowlist.
public enum LifeBoardSignatureEffect: String, Codable, CaseIterable, Hashable, Sendable {
    case daypartBloom
    case evaInkReveal
    case journalMediaReveal
    case memoryDevelopReveal
    case fastingEmberRing
    case healthSyncPulse
    case vitalOrbWarp
    case clayPressBloom
    case daypartCrossDissolve
    case completionBurst
    case contextLens
    /// The dock/composer selection well refracts the content beneath it.
    case liquidGlassRefract
    /// Charts and sparklines draw in behind a travelling gradient mask.
    case chartRevealSweep
    /// Bounded warp on the background plane during a card-to-detail zoom.
    case cardMorphWarp
    /// Static warm tooth over large canvas areas. Never animates.
    case paperGrain
    /// Completion dissolves a row away instead of fading it.
    case dissolveAway
    /// Directional one-shot warmth beneath the Inbox deck after triage settles.
    case triageSettle
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

    public var systemImage: String {
        switch self {
        case .smart: return "sparkles"
        case .work: return "briefcase"
        case .personal: return "person.crop.circle"
        // A leaf, not a moon — night is already the daypart's symbol.
        case .lowEnergy: return "leaf"
        }
    }

    public var summary: String {
        switch self {
        case .smart: return "Everything, ordered by what needs you."
        case .work: return "Work commitments only. Personal care stays private."
        case .personal: return "Life outside work."
        case .lowEnergy: return "Less on screen. Care and rest first."
        }
    }
}

/// Visual information density is orthogonal to Home's content mode.
///
/// Work mode can be Minimal or Rich, and Low Energy remains a semantic mode
/// rather than being overloaded as the only way to see less.
public enum DashboardDensity: String, Codable, CaseIterable, Hashable, Sendable {
    case minimal
    case balanced
    case rich

    public var title: String { rawValue.capitalized }
}

/// Life context a card's content belongs to. Mirrors planning's own context so
/// Home can filter without the foundation layer depending on planning types.
public enum HomeContentContext: String, Codable, CaseIterable, Hashable, Sendable {
    case neutral
    case work
    case personal
}

/// How many anchored sections a mode is willing to show.
public struct HomeSectionBudget: Hashable, Sendable {
    public var showsToday: Bool
    public var showsDayAhead: Bool
    public var showsNeedsAttention: Bool
    public var showsCloseLoop: Bool
    public var showsUserSpace: Bool
    /// Row cap inside list-shaped cards.
    public var queueLimit: Int

    public init(
        showsToday: Bool = true,
        showsDayAhead: Bool = true,
        showsNeedsAttention: Bool = true,
        showsCloseLoop: Bool = true,
        showsUserSpace: Bool = true,
        queueLimit: Int = 4
    ) {
        self.showsToday = showsToday
        self.showsDayAhead = showsDayAhead
        self.showsNeedsAttention = showsNeedsAttention
        self.showsCloseLoop = showsCloseLoop
        self.showsUserSpace = showsUserSpace
        self.queueLimit = queueLimit
    }

    public func applying(_ density: DashboardDensity) -> HomeSectionBudget {
        var result = self
        switch density {
        case .minimal:
            result.showsDayAhead = false
            result.showsCloseLoop = false
            result.queueLimit = min(result.queueLimit, 2)
        case .balanced:
            break
        case .rich:
            result.queueLimit = max(result.queueLimit, 6)
        }
        return result
    }
}

/// Modes were persisted and restored but unreachable, and only `.lowEnergy`
/// ever changed anything. This makes each mode mean something at the data
/// layer: providers filter their own queries by the permitted contexts rather
/// than the view hiding rows after the fact.
public protocol DashboardModePolicy: Sendable {
    func contexts(for mode: DashboardMode) -> Set<HomeContentContext>
    func permits(_ descriptor: DashboardWidgetDescriptor, in mode: DashboardMode) -> Bool
    func sectionBudget(for mode: DashboardMode) -> HomeSectionBudget
}

public struct DeterministicDashboardModePolicy: DashboardModePolicy {
    public init() {}

    public func contexts(for mode: DashboardMode) -> Set<HomeContentContext> {
        switch mode {
        case .smart, .lowEnergy: [.neutral, .work, .personal]
        // Neutral items are unlabelled, not "not work" — dropping them would
        // hide most of an unorganised workspace.
        case .work: [.neutral, .work]
        case .personal: [.neutral, .personal]
        }
    }

    public func permits(_ descriptor: DashboardWidgetDescriptor, in mode: DashboardMode) -> Bool {
        switch mode {
        case .smart, .personal:
            return true
        case .work:
            // Work mode is what someone screen-shares. Health, journal and
            // body data stay out of it.
            return descriptor.sensitivity != .privateSensitive
        case .lowEnergy:
            // Recovery first: care and wellbeing, nothing that asks for output.
            return descriptor.category == .wellbeing
                || descriptor.category == .orient
                || descriptor.kind == .focusNow
        }
    }

    public func sectionBudget(for mode: DashboardMode) -> HomeSectionBudget {
        switch mode {
        case .smart, .work, .personal:
            HomeSectionBudget()
        case .lowEnergy:
            HomeSectionBudget(
                showsToday: false,
                showsDayAhead: false,
                showsNeedsAttention: false,
                showsCloseLoop: false,
                showsUserSpace: false,
                queueLimit: 1
            )
        }
    }
}

public enum WidgetSizePreset: String, CaseIterable, Hashable, Sendable {
    case compact
    case standard
    case wide
    case tall
    case expanded

    public static func persistedValue(rawValue: String) -> WidgetSizePreset? {
        if rawValue == "hero" { return .tall }
        if rawValue == "glance" { return .compact }
        if rawValue == "story" { return .tall }
        return WidgetSizePreset(rawValue: rawValue)
    }

    public var title: String {
        switch self {
        case .compact: return "Glance"
        case .standard: return "Compact"
        case .wide: return "Wide"
        case .tall: return "Story"
        case .expanded: return "Expanded"
        }
    }

    public var canonicalGridSpan: HomeGridSpan {
        switch self {
        case .compact: return .init(columns: 2, rows: 1)
        case .standard: return .init(columns: 2, rows: 2)
        case .wide: return .init(columns: 4, rows: 2)
        case .tall: return .init(columns: 4, rows: 3)
        case .expanded: return .init(columns: 4, rows: 4)
        }
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

public struct HomeGridSpan: Codable, Hashable, Sendable {
    public let columns: Int
    public let rows: Int

    public init(columns: Int, rows: Int) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
    }
}

public struct HomeGridPosition: Codable, Hashable, Sendable {
    public var column: Int
    public var row: Int

    public init(column: Int, row: Int) {
        self.column = max(0, column)
        self.row = max(0, row)
    }
}

public enum HomeCardOwnership: String, Codable, CaseIterable, Hashable, Sendable {
    case pinned
    case smart
    case suggested
    case system

    public var accessibilityDescription: String {
        switch self {
        case .pinned: return "Pinned by you"
        case .smart: return "Adaptive smart slot"
        case .suggested: return "Suggested for now"
        case .system: return "Active system state"
        }
    }
}

public enum HomeSmartSlotSchedule: String, Codable, CaseIterable, Hashable, Sendable {
    case morning
    case workday
    case evening
    case weekend
    case always

    public var title: String {
        switch self {
        case .morning: return "Morning"
        case .workday: return "Workday"
        case .evening: return "Evening"
        case .weekend: return "Weekend"
        case .always: return "Always adaptive"
        }
    }
}

public struct HomeSmartSlotConfiguration: Codable, Hashable, Sendable {
    public var allowedDestinations: Set<LifeBoardDestination>
    public var schedule: HomeSmartSlotSchedule
    public var frozenWidgetKind: String?

    public init(
        allowedDestinations: Set<LifeBoardDestination> = Set(LifeBoardDestination.allCases),
        schedule: HomeSmartSlotSchedule = .always,
        frozenWidgetKind: String? = nil
    ) {
        self.allowedDestinations = allowedDestinations
        self.schedule = schedule
        self.frozenWidgetKind = frozenWidgetKind
    }
}

public struct HomeContextReason: Codable, Hashable, Sendable {
    public let message: String
    public let signal: String

    public init(message: String, signal: String) {
        self.message = message
        self.signal = signal
    }
}

public enum HomeCandidateSemanticRole: String, Codable, CaseIterable, Hashable, Sendable {
    case primaryNow
    case dayAheadStory
    case attention
    case care
    case reflection
}

public enum HomeContextDisposition: String, Codable, CaseIterable, Hashable, Sendable {
    case available
    case hiddenToday
    case suggestLess
    case neverSuggest
    case pinned
}

public enum HomeContextRefreshBoundary: String, Codable, CaseIterable, Hashable, Sendable {
    case appForeground
    case calendarBoundary
    case taskMutation
    case timerChange
    case trackerCommit
    case daypartBoundary
    case explicitRefresh
}

public enum HomeContextFreezeReason: String, Codable, CaseIterable, Hashable, Sendable {
    case scrolling
    case touchingCard
    case keyboardFocus
    case voiceOverFocus
    case readingCard
    case presentedSheet
    case homeEditing
}

public struct HomeContextFeedbackRecord: Codable, Hashable, Sendable {
    public var disposition: HomeContextDisposition
    public var hiddenUntil: Date?
    public var lastShownAt: Date?
    public var shownCount: Int

    public init(
        disposition: HomeContextDisposition = .available,
        hiddenUntil: Date? = nil,
        lastShownAt: Date? = nil,
        shownCount: Int = 0
    ) {
        self.disposition = disposition
        self.hiddenUntil = hiddenUntil
        self.lastShownAt = lastShownAt
        self.shownCount = max(0, shownCount)
    }
}

/// Local preference storage for explainable recommendation controls. The store
/// persists identifiers and dispositions only—never card titles or reasons.
@MainActor
public final class HomeContextFeedbackStore {
    private let defaults: UserDefaults
    private let key: String
    private let consentKey: String
    private var records: [String: HomeContextFeedbackRecord]
    private var sensitiveConsentKinds: Set<String>

    public init(
        defaults: UserDefaults = .standard,
        key: String = "lifeOS.home.contextFeedback.v1",
        consentKey: String = "lifeOS.home.sensitiveConsent.v1"
    ) {
        self.defaults = defaults
        self.key = key
        self.consentKey = consentKey
        records = defaults.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([String: HomeContextFeedbackRecord].self, from: $0) }
            ?? [:]
        sensitiveConsentKinds = Set(defaults.stringArray(forKey: consentKey) ?? [])
    }

    public func record(for candidateID: String, now: Date = Date()) -> HomeContextFeedbackRecord {
        var result = records[candidateID] ?? .init()
        if result.disposition == .hiddenToday,
           result.hiddenUntil.map({ $0 <= now }) ?? true {
            result.disposition = .available
            result.hiddenUntil = nil
            records[candidateID] = result
            persist()
        }
        return result
    }

    public func dispositions(now: Date = Date()) -> [String: HomeContextDisposition] {
        Dictionary(uniqueKeysWithValues: records.keys.map { id in
            (id, record(for: id, now: now).disposition)
        })
    }

    public func hideToday(
        candidateID: String,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        var record = records[candidateID] ?? .init()
        record.disposition = .hiddenToday
        record.hiddenUntil = calendar.dateInterval(of: .day, for: now)?.end
        records[candidateID] = record
        persist()
    }

    public func suggestLess(candidateID: String) {
        update(candidateID, disposition: .suggestLess)
    }

    public func neverSuggest(candidateID: String) {
        update(candidateID, disposition: .neverSuggest)
    }

    public func keepOnHome(candidateID: String) {
        update(candidateID, disposition: .pinned)
    }

    public func markShown(candidateID: String, at date: Date = Date()) {
        var record = records[candidateID] ?? .init()
        record.lastShownAt = date
        record.shownCount += 1
        records[candidateID] = record
        persist()
    }

    public func permitsSensitiveContent(for kind: DashboardWidgetKind) -> Bool {
        sensitiveConsentKinds.contains(kind.rawValue)
    }

    public func setSensitiveContentPermission(_ permitted: Bool, for kind: DashboardWidgetKind) {
        if permitted {
            sensitiveConsentKinds.insert(kind.rawValue)
        } else {
            sensitiveConsentKinds.remove(kind.rawValue)
        }
        defaults.set(sensitiveConsentKinds.sorted(), forKey: consentKey)
    }

    private func update(_ candidateID: String, disposition: HomeContextDisposition) {
        var record = records[candidateID] ?? .init()
        record.disposition = disposition
        record.hiddenUntil = nil
        records[candidateID] = record
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: key)
        }
    }
}

public struct HomeContextCandidate: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let widgetKind: DashboardWidgetKind
    public let title: String
    public let reason: HomeContextReason
    public let destination: LifeBoardDestination
    public let sensitivity: DataSensitivity
    public let priority: Int
    public let relevantFrom: Date
    public let relevantUntil: Date?
    public let isUserStartedActiveState: Bool
    /// Optional only for decoding pre-role persisted candidates. Every new
    /// candidate receives a concrete role during initialization.
    public let semanticRole: HomeCandidateSemanticRole?

    public init(
        id: String,
        widgetKind: DashboardWidgetKind,
        title: String,
        reason: HomeContextReason,
        destination: LifeBoardDestination,
        sensitivity: DataSensitivity = .privateStandard,
        priority: Int,
        relevantFrom: Date = Date(),
        relevantUntil: Date? = nil,
        isUserStartedActiveState: Bool = false,
        semanticRole: HomeCandidateSemanticRole? = nil
    ) {
        self.id = id
        self.widgetKind = widgetKind
        self.title = title
        self.reason = reason
        self.destination = destination
        self.sensitivity = sensitivity
        self.priority = priority
        self.relevantFrom = relevantFrom
        self.relevantUntil = relevantUntil
        self.isUserStartedActiveState = isUserStartedActiveState
        self.semanticRole = semanticRole ?? Self.defaultSemanticRole(for: widgetKind)
    }

    public var resolvedSemanticRole: HomeCandidateSemanticRole {
        semanticRole ?? Self.defaultSemanticRole(for: widgetKind)
    }

    private static func defaultSemanticRole(for kind: DashboardWidgetKind) -> HomeCandidateSemanticRole {
        switch kind {
        case .focusNow, .tasks:
            .primaryNow
        case .scheduleCapacity, .compactTimeline:
            .dayAheadStory
        case .care, .bodyMetric, .workout, .sleep, .fasting:
            .care
        case .journal, .progressReflection:
            .reflection
        default:
            .attention
        }
    }
}

public struct HomeContextCandidateContext: Hashable, Sendable {
    public let date: Date
    public let timeZoneIdentifier: String
    public let refreshBoundary: HomeContextRefreshBoundary
    public let availableCapabilities: Set<String>

    public init(
        date: Date = Date(),
        timeZone: TimeZone = .autoupdatingCurrent,
        refreshBoundary: HomeContextRefreshBoundary,
        availableCapabilities: Set<String> = []
    ) {
        self.date = date
        timeZoneIdentifier = timeZone.identifier
        self.refreshBoundary = refreshBoundary
        self.availableCapabilities = availableCapabilities
    }

    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .autoupdatingCurrent
    }
}

/// Domain modules own candidate creation. Home only merges display-ready
/// candidates, preventing the adaptive canvas from reaching into canonical
/// repositories or learning domain-specific eligibility rules.
public protocol HomeContextCandidateProvider: Sendable {
    var providerID: String { get }
    func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate]
}

public actor HomeContextCandidateProviderRegistry {
    private var providers: [String: any HomeContextCandidateProvider] = [:]

    public init(providers: [any HomeContextCandidateProvider] = []) {
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.providerID, $0) })
    }

    public func register(_ provider: any HomeContextCandidateProvider) {
        providers[provider.providerID] = provider
    }

    public func unregister(providerID: String) {
        providers.removeValue(forKey: providerID)
    }

    public func providerIDs() -> [String] { providers.keys.sorted() }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        let ordered = providers.values.sorted { $0.providerID < $1.providerID }
        let collected = await withTaskGroup(of: [HomeContextCandidate].self) { group in
            for provider in ordered {
                group.addTask { await provider.candidates(context: context) }
            }
            var values: [HomeContextCandidate] = []
            for await candidates in group { values.append(contentsOf: candidates) }
            return values
        }
        var unique: [String: HomeContextCandidate] = [:]
        for candidate in collected {
            if let current = unique[candidate.id], current.priority >= candidate.priority { continue }
            unique[candidate.id] = candidate
        }
        return unique.values.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.id < $1.id
        }
    }
}

public struct HomeContextSelection: Codable, Hashable, Sendable {
    /// One hero plus up to three in "Needs attention". Nine domain providers
    /// feed this; a cap of two meant the section could only ever render a
    /// single row, and only when exactly two candidates survived.
    public static let maximumCandidates = 4

    public let candidates: [HomeContextCandidate]
    public let evaluatedAt: Date

    public init(candidates: [HomeContextCandidate], evaluatedAt: Date) {
        self.candidates = Array(candidates.prefix(Self.maximumCandidates))
        self.evaluatedAt = evaluatedAt
    }
}

/// Local-first coordinator for stable, explainable Home recommendations.
/// Callers freeze it while scrolling, editing, touching a card, or serving
/// VoiceOver focus so visible suggestions never change under the user.
@MainActor
public final class HomeContextEngine {
    private let policy: any HomeContextPolicy
    private let minimumDisplayDuration: TimeInterval
    private let repetitionCooldown: TimeInterval
    private var current = HomeContextSelection(candidates: [], evaluatedAt: .distantPast)
    private var freezeReasons: Set<String> = []

    public init(
        policy: any HomeContextPolicy = DeterministicHomeContextPolicy(),
        minimumDisplayDuration: TimeInterval = 45,
        repetitionCooldown: TimeInterval = 30 * 60
    ) {
        self.policy = policy
        self.minimumDisplayDuration = max(0, minimumDisplayDuration)
        self.repetitionCooldown = max(0, repetitionCooldown)
    }

    public func selection() -> HomeContextSelection { current }

    public func setFrozen(_ frozen: Bool, reason: String) {
        if frozen {
            freezeReasons.insert(reason)
        } else {
            freezeReasons.remove(reason)
        }
    }

    public func setFrozen(_ frozen: Bool, reason: HomeContextFreezeReason) {
        setFrozen(frozen, reason: reason.rawValue)
    }

    @discardableResult
    public func reevaluate(
        candidates: [HomeContextCandidate],
        dispositions: [String: HomeContextDisposition],
        permitsSensitiveHomeContent: Bool,
        feedback: [String: HomeContextFeedbackRecord] = [:],
        now: Date = Date(),
        force: Bool = false
    ) -> HomeContextSelection {
        guard force || (freezeReasons.isEmpty
            && now.timeIntervalSince(current.evaluatedAt) >= minimumDisplayDuration) else {
            return current
        }
        let interval = LifeOSPerformanceOperation.homeContextEvaluation.begin()
        defer { LifeOSPerformanceOperation.homeContextEvaluation.end(interval) }
        let currentlyVisible = Set(current.candidates.map(\.id))
        let stableCandidates = candidates.filter { candidate in
            guard candidate.isUserStartedActiveState == false,
                  currentlyVisible.contains(candidate.id) == false,
                  let lastShownAt = feedback[candidate.id]?.lastShownAt else { return true }
            return now.timeIntervalSince(lastShownAt) >= repetitionCooldown
        }
        current = policy.select(
            candidates: stableCandidates,
            dispositions: dispositions,
            permitsSensitiveHomeContent: permitsSensitiveHomeContent,
            now: now
        )
        return current
    }
}

public protocol HomeContextPolicy: Sendable {
    func select(
        candidates: [HomeContextCandidate],
        dispositions: [String: HomeContextDisposition],
        permitsSensitiveHomeContent: Bool,
        now: Date
    ) -> HomeContextSelection
}

public struct DeterministicHomeContextPolicy: HomeContextPolicy {
    public init() {}

    public func select(
        candidates: [HomeContextCandidate],
        dispositions: [String: HomeContextDisposition],
        permitsSensitiveHomeContent: Bool,
        now: Date
    ) -> HomeContextSelection {
        let eligible = candidates.filter { candidate in
            guard candidate.relevantFrom <= now,
                  candidate.relevantUntil.map({ $0 > now }) ?? true else { return false }
            guard candidate.sensitivity != .privateSensitive || permitsSensitiveHomeContent else { return false }
            switch dispositions[candidate.id] ?? .available {
            case .available, .suggestLess: return true
            case .hiddenToday, .neverSuggest, .pinned: return false
            }
        }
        let sorted = eligible.sorted { lhs, rhs in
            if lhs.isUserStartedActiveState != rhs.isUserStartedActiveState {
                return lhs.isUserStartedActiveState
            }
            let lhsPenalty = dispositions[lhs.id] == .suggestLess ? 1_000 : 0
            let rhsPenalty = dispositions[rhs.id] == .suggestLess ? 1_000 : 0
            if lhs.priority - lhsPenalty != rhs.priority - rhsPenalty {
                return lhs.priority - lhsPenalty > rhs.priority - rhsPenalty
            }
            return lhs.id < rhs.id
        }
        var claimedRoles = Set<HomeCandidateSemanticRole>()
        let semanticallyUnique = sorted.filter {
            claimedRoles.insert($0.resolvedSemanticRole).inserted
        }
        // "Now" is a decision, not merely the highest numeric score. If any
        // actionable candidate exists it owns the hero; day-ahead and care
        // stories follow without displacing it.
        let orderedBySemanticRole = semanticallyUnique.sorted { lhs, rhs in
            let lhsRank = Self.semanticRank(lhs.resolvedSemanticRole)
            let rhsRank = Self.semanticRank(rhs.resolvedSemanticRole)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            let lhsIndex = sorted.firstIndex(of: lhs) ?? Int.max
            let rhsIndex = sorted.firstIndex(of: rhs) ?? Int.max
            return lhsIndex < rhsIndex
        }
        return HomeContextSelection(
            candidates: Array(orderedBySemanticRole.prefix(HomeContextSelection.maximumCandidates)),
            evaluatedAt: now
        )
    }

    private static func semanticRank(_ role: HomeCandidateSemanticRole) -> Int {
        switch role {
        case .primaryNow: 0
        case .care, .attention, .dayAheadStory, .reflection: 1
        }
    }
}

public enum LifeThreadArtifactKind: String, Codable, CaseIterable, Hashable, Sendable {
    case greeting
    case focus
    case userTurn
    case assistantTurn
    case transactionPreview
    case trackerUpdate
    case journalMoment
    case planChange
    case insight
    case media
    case generatedVisual
    case actionReceipt
    case permission
    case degradedState
}

public struct LifeThreadArtifact: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let kind: LifeThreadArtifactKind
    public var title: String?
    public var body: String
    public var sourceReference: String?
    public var destination: LifeBoardDestination?
    public var sensitivity: DataSensitivity

    public init(
        id: UUID = UUID(),
        kind: LifeThreadArtifactKind,
        title: String? = nil,
        body: String,
        sourceReference: String? = nil,
        destination: LifeBoardDestination? = nil,
        sensitivity: DataSensitivity = .privateStandard
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.sourceReference = sourceReference
        self.destination = destination
        self.sensitivity = sensitivity
    }
}

public struct LifeThreadItem: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var timestamp: Date
    public var priority: Int
    public var artifact: LifeThreadArtifact

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        priority: Int = 0,
        artifact: LifeThreadArtifact
    ) {
        self.id = id
        self.timestamp = timestamp
        self.priority = priority
        self.artifact = artifact
    }
}

public enum LifeThreadComposerState: String, Codable, CaseIterable, Hashable, Sendable {
    case resting
    case focused
    case tools
    case recording
    case scanning
    case working
    case review
    case settling
    case dictating
}

public enum LifeThreadComposerRecovery: String, Codable, Hashable, Sendable {
    case `continue`
    case retry
}

public enum LifeBoardInteractionOrigin: String, Codable, CaseIterable, Hashable, Sendable {
    case directTap
    case gesture
    case conversation
    case appIntent
    case watch
    case widget
    case imported
    case restored
    case accessibility
}

public enum LifeBoardMotionProfile: String, Codable, CaseIterable, Hashable, Sendable {
    case press
    case selection
    case localState
    case contentInsertion
    case controlMorph
    case directManipulation
    case micro
    case cardReflow
    case route
    case celebration
    case ambient
}

public struct LifeBoardTransactionPreview: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let destination: LifeBoardDestination
    public let summary: String
    public let changes: [String]
    public let warnings: [String]
    public let origin: LifeBoardInteractionOrigin

    public init(
        id: UUID = UUID(),
        destination: LifeBoardDestination,
        summary: String,
        changes: [String],
        warnings: [String] = [],
        origin: LifeBoardInteractionOrigin
    ) {
        self.id = id
        self.destination = destination
        self.summary = summary
        self.changes = changes
        self.warnings = warnings
        self.origin = origin
    }
}

public struct LifeBoardActionReceipt: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let transactionID: UUID
    public let message: String
    public let committedAt: Date
    public let canUndo: Bool

    public init(
        id: UUID = UUID(),
        transactionID: UUID,
        message: String,
        committedAt: Date = Date(),
        canUndo: Bool = true
    ) {
        self.id = id
        self.transactionID = transactionID
        self.message = message
        self.committedAt = committedAt
        self.canUndo = canUndo
    }
}

public struct LifeThreadProjectionSource: Hashable, Sendable {
    public let projectionID: UUID
    public let timestamp: Date
    public let priority: Int
    public let artifactKind: LifeThreadArtifactKind
    public let title: String?
    public let body: String
    public let sourceReference: String
    public let destination: LifeBoardDestination?
    public let sensitivity: DataSensitivity

    public init(
        projectionID: UUID,
        timestamp: Date,
        priority: Int = 0,
        artifactKind: LifeThreadArtifactKind,
        title: String? = nil,
        body: String,
        sourceReference: String,
        destination: LifeBoardDestination? = nil,
        sensitivity: DataSensitivity = .privateStandard
    ) {
        self.projectionID = projectionID
        self.timestamp = timestamp
        self.priority = priority
        self.artifactKind = artifactKind
        self.title = title
        self.body = body
        self.sourceReference = sourceReference
        self.destination = destination
        self.sensitivity = sensitivity
    }
}

/// Reconstructs the Today Story from canonical records. The service is pure:
/// it owns no database and uses the source's stable identity for both the item
/// and artifact, so repeated projections remain deterministic.
public struct LifeThreadProjectionService: Sendable {
    public init() {}

    public func project(
        _ sources: [LifeThreadProjectionSource],
        on day: Date,
        calendar: Calendar = .autoupdatingCurrent,
        permittedSensitivities: Set<DataSensitivity> = Set(DataSensitivity.allCases)
    ) -> [LifeThreadItem] {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return [] }
        return sources
            .filter { interval.contains($0.timestamp) && permittedSensitivities.contains($0.sensitivity) }
            .map { source in
                LifeThreadItem(
                    id: source.projectionID,
                    timestamp: source.timestamp,
                    priority: source.priority,
                    artifact: LifeThreadArtifact(
                        id: source.projectionID,
                        kind: source.artifactKind,
                        title: source.title,
                        body: source.body,
                        sourceReference: source.sourceReference,
                        destination: source.destination,
                        sensitivity: source.sensitivity
                    )
                )
            }
            .sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }
}

public struct LifeThreadIntentInput: Hashable, Sendable {
    public let text: String
    public let attachments: [String]
    public let destination: LifeBoardDestination
    public let origin: LifeBoardInteractionOrigin
    /// Whether the text arrived via keyboard or live dictation.
    public let inputSource: InputSource
    /// The day the user is looking at (may differ from today on Plan/Track).
    public let selectedDate: Date?
    /// Semantic time of day from the atmosphere clock.
    public let daypart: ResolvedDaypart?
    /// Active dashboard mode (smart/work/personal/lowEnergy).
    public let dashboardMode: DashboardMode?
    /// Whether readable calendar access has been granted.
    public let calendarAvailable: Bool
    /// Whether the Day Compass considers a rescue eligible right now.
    public let dayRescueEligible: Bool
    /// Whether there are overdue tasks that qualify for the rescue deck.
    public let overdueRescueEligible: Bool
    /// Count of overdue tasks so adapters can tailor messaging.
    public let overdueTaskCount: Int

    public enum InputSource: String, Codable, Hashable, Sendable {
        case typed
        case dictated
    }

    public init(
        text: String,
        attachments: [String] = [],
        destination: LifeBoardDestination,
        origin: LifeBoardInteractionOrigin = .conversation,
        inputSource: InputSource = .typed,
        selectedDate: Date? = nil,
        daypart: ResolvedDaypart? = nil,
        dashboardMode: DashboardMode? = nil,
        calendarAvailable: Bool = false,
        dayRescueEligible: Bool = false,
        overdueRescueEligible: Bool = false,
        overdueTaskCount: Int = 0
    ) {
        self.text = text
        self.attachments = attachments
        self.destination = destination
        self.origin = origin
        self.inputSource = inputSource
        self.selectedDate = selectedDate
        self.daypart = daypart
        self.dashboardMode = dashboardMode
        self.calendarAvailable = calendarAvailable
        self.dayRescueEligible = dayRescueEligible
        self.overdueRescueEligible = overdueRescueEligible
        self.overdueTaskCount = overdueTaskCount
    }
}

public struct LifeThreadAnswerRequest: Hashable, Sendable {
    public let prompt: String
    public let destination: LifeBoardDestination

    public init(prompt: String, destination: LifeBoardDestination) {
        self.prompt = prompt
        self.destination = destination
    }
}

public struct LifeThreadCaptureDraft: Hashable, Sendable {
    public let id: UUID
    public let kind: CaptureKind
    public let text: String
    public let attachments: [String]
    public let destination: LifeBoardDestination
    /// Structured seed carrying the raw text, optional parsed proposals, and
    /// input source so editors can prefill and present correctable chips.
    public let seed: CaptureSeed?

    public init(
        id: UUID = UUID(),
        kind: CaptureKind,
        text: String,
        attachments: [String] = [],
        destination: LifeBoardDestination,
        seed: CaptureSeed? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.attachments = attachments
        self.destination = destination
        self.seed = seed
    }
}

/// Carries raw text, optional structured `ParsedCapture`, and the input source
/// through the resolution pipeline so editors can prefill and present proposals.
///
/// Every field is a *proposal*: the editor renders each as a correctable chip
/// and commits nothing the user has not explicitly reviewed.
public struct CaptureSeed: Codable, Hashable, Sendable {
    public let rawText: String
    public let parsedCapture: ParsedCapture?
    public let inputSource: LifeThreadIntentInput.InputSource

    public init(
        rawText: String,
        parsedCapture: ParsedCapture? = nil,
        inputSource: LifeThreadIntentInput.InputSource = .typed
    ) {
        self.rawText = rawText
        self.parsedCapture = parsedCapture
        self.inputSource = inputSource
    }
}

public struct LifeThreadNavigationRequest: Hashable, Sendable {
    public let destination: LifeBoardDestination
    public let sourceReference: String?
    /// Optional route to push within the destination's navigation stack.
    public let route: AppRoute?
    /// Human-readable label for the interpretation row (e.g. "Day Plan").
    public let routeLabel: String?

    public init(
        destination: LifeBoardDestination,
        sourceReference: String? = nil,
        route: AppRoute? = nil,
        routeLabel: String? = nil
    ) {
        self.destination = destination
        self.sourceReference = sourceReference
        self.route = route
        self.routeLabel = routeLabel
    }
}

public enum LifeThreadIntentResolution: Hashable, Sendable {
    case answer(LifeThreadAnswerRequest)
    case captureDraft(LifeThreadCaptureDraft)
    case transactionPreview(LifeBoardTransactionPreview)
    case navigation(LifeThreadNavigationRequest)
    /// The input is ambiguous — present concrete choices to the user.
    case clarification(ClarificationRequest)
    /// An in-app action that doesn't fit capture/navigation (rescue, schedule).
    case surfaceAction(UniversalInputSurfaceAction)
}

// MARK: - Clarification

/// Presented when the intent is ambiguous. The original text stays editable
/// in the composer while the user picks one of the concrete options.
public struct ClarificationRequest: Hashable, Sendable {
    public let question: String
    public let options: [ClarificationOption]
    /// Preserved so the user can edit and resubmit instead of picking.
    public let originalText: String

    public init(question: String, options: [ClarificationOption], originalText: String) {
        self.question = question
        self.options = options
        self.originalText = originalText
    }
}

public struct ClarificationOption: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let label: String
    public let systemImage: String
    public let resolution: LifeThreadIntentResolution

    public init(
        id: UUID = UUID(),
        label: String,
        systemImage: String,
        resolution: LifeThreadIntentResolution
    ) {
        self.id = id
        self.label = label
        self.systemImage = systemImage
        self.resolution = resolution
    }
}

/// Actions triggered from the universal input that are not captures or navigation:
/// they operate on existing surfaces or flows.
public enum UniversalInputSurfaceAction: String, Codable, Hashable, Sendable {
    /// Select Home and focus the calendar timeline / schedule glance.
    case showTodaySchedule
    /// Present the Day Compass rescue flow.
    case dayRescue
    /// Present the Overdue Rescue deck.
    case overdueRescue

    /// Compact label for the interpretation chip row.
    public var interpretationLabel: String {
        switch self {
        case .showTodaySchedule: return "Open · Meetings"
        case .dayRescue: return "Open · Day Rescue"
        case .overdueRescue: return "Open · Overdue Rescue"
        }
    }

    public var systemImage: String {
        switch self {
        case .showTodaySchedule: return "calendar"
        case .dayRescue: return "lifepreserver"
        case .overdueRescue: return "exclamationmark.triangle"
        }
    }
}

public protocol LifeThreadIntentAdapter: Sendable {
    func resolve(_ input: LifeThreadIntentInput) async -> LifeThreadIntentResolution?
}

/// Mutation adapters return an executable command instead of a free-floating
/// preview. The resolver prepares that command before exposing the existing
/// `.transactionPreview` outcome, keeping the public four-outcome contract
/// while guaranteeing that an enabled Apply button has real work behind it.
public protocol LifeThreadMutationIntentAdapter: Sendable {
    func resolveMutation(_ input: LifeThreadIntentInput) async -> LifeBoardMutationCommand?
}

/// Domain adapters recognize captures, mutations, and navigation. Unrecognized
/// conversational input becomes an answer request; it never mutates data.
public actor LifeThreadIntentResolver {
    private let adapters: [any LifeThreadIntentAdapter]
    private let mutationAdapters: [any LifeThreadMutationIntentAdapter]
    private let mutationCoordinator: LifeBoardMutationCoordinator

    public init(
        adapters: [any LifeThreadIntentAdapter] = [],
        mutationAdapters: [any LifeThreadMutationIntentAdapter] = [],
        mutationCoordinator: LifeBoardMutationCoordinator = .init()
    ) {
        self.adapters = adapters
        self.mutationAdapters = mutationAdapters
        self.mutationCoordinator = mutationCoordinator
    }

    public func resolve(_ input: LifeThreadIntentInput) async -> LifeThreadIntentResolution {
        let interval = LifeOSPerformanceOperation.composerResolution.begin()
        defer { LifeOSPerformanceOperation.composerResolution.end(interval) }
        for adapter in mutationAdapters {
            if let command = await adapter.resolveMutation(input) {
                return .transactionPreview(await mutationCoordinator.prepare(command))
            }
        }
        for adapter in adapters {
            if let resolution = await adapter.resolve(input) { return resolution }
        }
        return .answer(.init(prompt: input.text, destination: input.destination))
    }
}

public struct LifeBoardMutationCommand: Sendable {
    public let preview: LifeBoardTransactionPreview
    fileprivate let applyOperation: @Sendable () async throws -> String
    fileprivate let undoOperation: @Sendable () async throws -> Void

    public init(
        preview: LifeBoardTransactionPreview,
        apply: @escaping @Sendable () async throws -> String,
        undo: @escaping @Sendable () async throws -> Void
    ) {
        self.preview = preview
        applyOperation = apply
        undoOperation = undo
    }
}

public enum LifeBoardMutationCoordinatorError: Error, Equatable, Sendable {
    case previewNotPrepared(UUID)
    case receiptNotUndoable(UUID)
}

public actor LifeBoardActionReceiptStore {
    private var receipts: [UUID: LifeBoardActionReceipt] = [:]

    public init() {}

    public func save(_ receipt: LifeBoardActionReceipt) {
        receipts[receipt.id] = receipt
    }

    public func receipt(id: UUID) -> LifeBoardActionReceipt? { receipts[id] }

    public func recent(limit: Int = 20) -> [LifeBoardActionReceipt] {
        receipts.values
            .sorted { $0.committedAt > $1.committedAt }
            .prefix(max(0, limit))
            .map { $0 }
    }

    public func remove(id: UUID) {
        receipts.removeValue(forKey: id)
    }
}

/// The canonical preview/apply/undo gateway for direct and conversational
/// actions. Prepared commands are process-local; canonical domain stores remain
/// responsible for durable records and idempotency.
public actor LifeBoardMutationCoordinator {
    private let receiptStore: LifeBoardActionReceiptStore
    private var prepared: [UUID: LifeBoardMutationCommand] = [:]
    private var applied: [UUID: LifeBoardMutationCommand] = [:]

    public init(receiptStore: LifeBoardActionReceiptStore = .init()) {
        self.receiptStore = receiptStore
    }

    @discardableResult
    public func prepare(_ command: LifeBoardMutationCommand) -> LifeBoardTransactionPreview {
        prepared[command.preview.id] = command
        return command.preview
    }

    public func discard(previewID: UUID) {
        prepared.removeValue(forKey: previewID)
    }

    public func isPrepared(previewID: UUID) -> Bool {
        prepared[previewID] != nil
    }

    public func apply(previewID: UUID, at date: Date = Date()) async throws -> LifeBoardActionReceipt {
        guard let command = prepared.removeValue(forKey: previewID) else {
            throw LifeBoardMutationCoordinatorError.previewNotPrepared(previewID)
        }
        let message = try await command.applyOperation()
        let receipt = LifeBoardActionReceipt(
            transactionID: previewID,
            message: message,
            committedAt: date,
            canUndo: true
        )
        applied[receipt.id] = command
        await receiptStore.save(receipt)
        return receipt
    }

    public func undo(receiptID: UUID) async throws {
        guard let command = applied.removeValue(forKey: receiptID),
              let receipt = await receiptStore.receipt(id: receiptID),
              receipt.canUndo else {
            throw LifeBoardMutationCoordinatorError.receiptNotUndoable(receiptID)
        }
        do {
            try await command.undoOperation()
            await receiptStore.remove(id: receiptID)
        } catch {
            applied[receiptID] = command
            throw error
        }
    }
}

public struct LifeThreadAttachmentDraft: Hashable, Identifiable, Sendable {
    public let id: UUID
    public let displayName: String
    public let localIdentifier: String

    public init(id: UUID = UUID(), displayName: String, localIdentifier: String) {
        self.id = id
        self.displayName = displayName
        self.localIdentifier = localIdentifier
    }
}

@MainActor
@Observable
public final class LifeThreadComposerCoordinator {
    public private(set) var state: LifeThreadComposerState = .resting
    public private(set) var destination: LifeBoardDestination
    public var draftText = ""
    public private(set) var attachments: [LifeThreadAttachmentDraft] = []
    public private(set) var workingLabel: String?
    public private(set) var preview: LifeBoardTransactionPreview?
    public private(set) var recovery: LifeThreadComposerRecovery?
    public private(set) var recoveryMessage: String?
    /// Structured understanding of the user's input, shown as a chip row
    /// for review before opening an editor.
    public private(set) var interpretation: ComposerInterpretation?
    /// Disambiguation when the intent is ambiguous. The original draft text
    /// stays editable while the user picks one of the concrete options.
    public private(set) var clarification: ClarificationRequest?
    /// Tracks whether the last input came from typing or dictation so the
    /// intent resolver can use input source as a classification signal.
    public private(set) var lastInputSource: LifeThreadIntentInput.InputSource = .typed

    public init(destination: LifeBoardDestination = .home) {
        self.destination = destination
    }

    public var hasDraft: Bool {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || attachments.isEmpty == false
    }

    public func move(to destination: LifeBoardDestination) {
        self.destination = destination
    }

    public func focus() { state = .focused }
    public func showTools() { state = .tools }
    public func beginRecording() { state = .recording }
    public func beginScanning() { state = .scanning }

    public func beginDictating() {
        lastInputSource = .dictated
        state = .dictating
    }

    public func finishDictating(composedText: String) {
        draftText = composedText
        lastInputSource = .dictated
        state = .focused
    }

    public func cancelDictating(restoringText: String) {
        draftText = restoringText
        lastInputSource = .typed
        state = hasDraft ? .focused : .resting
    }

    public func beginWorking(_ truthfulLabel: String) {
        recovery = nil
        recoveryMessage = nil
        interpretation = nil
        clarification = nil
        workingLabel = truthfulLabel
        state = .working
    }

    public func offerRecovery(_ action: LifeThreadComposerRecovery, message: String) {
        workingLabel = nil
        recovery = action
        recoveryMessage = message
        state = hasDraft ? .focused : .resting
    }

    public func review(_ preview: LifeBoardTransactionPreview) {
        self.preview = preview
        workingLabel = nil
        state = .review
    }

    // MARK: - Interpretation

    public func showInterpretation(_ interp: ComposerInterpretation) {
        interpretation = interp
        clarification = nil
        workingLabel = nil
        state = .review
    }

    public func showInterpretation(for draft: LifeThreadCaptureDraft) {
        var chips: [InterpretationChip] = []
        if let parsed = draft.seed?.parsedCapture {
            if let date = parsed.dueDate {
                let fmt = DateFormatter()
                fmt.dateStyle = .medium
                fmt.timeStyle = parsed.isAllDay ? .none : .short
                chips.append(.init(label: "📅 \(fmt.string(from: date))"))
            }
            if let priority = parsed.priority {
                chips.append(.init(label: "!\(priority)"))
            }
            if let project = parsed.projectName {
                chips.append(.init(label: "+\(project)"))
            }
            for tag in parsed.tags {
                chips.append(.init(label: "#\(tag)"))
            }
        }
        let image: String
        switch draft.kind {
        case .task: image = "checkmark.circle"
        case .journal: image = "book"
        case .note: image = "note.text"
        case .habit: image = "repeat"
        default: image = "square.and.pencil"
        }
        showInterpretation(.init(
            label: draft.kind.title,
            systemImage: image,
            chips: chips,
            resolution: .captureDraft(draft)
        ))
    }

    /// Compact interpretation row for navigation resolutions (e.g. "Open ·
    /// Day Plan", "Navigate · Plan · Weekly Planner"). The user gets a
    /// one-tap confirm/Cancel before the navigation executes, so a
    /// mis-classification doesn't whisk them away.
    public func showInterpretation(for navigation: LifeThreadNavigationRequest) {
        var chips: [InterpretationChip] = []
        let label = navigation.routeLabel ?? navigation.destination.title
        if navigation.destination != .home {
            chips.append(.init(label: navigation.destination.title))
        }
        if let routeLabel = navigation.routeLabel, routeLabel != navigation.destination.title {
            chips.append(.init(label: routeLabel))
        }
        showInterpretation(.init(
            label: "Open · \(label)",
            systemImage: "arrow.up.forward.app",
            chips: chips,
            resolution: .navigation(navigation)
        ))
    }

    /// Compact interpretation row for surface-action resolutions (e.g.
    /// "Open · Overdue Rescue" or "Open · Day Rescue"). Surface actions
    /// preserve the draft and don't autofocus the composer, so the user
    /// can resume after the deck dismisses.
    public func showInterpretation(for action: UniversalInputSurfaceAction) {
        showInterpretation(.init(
            label: action.interpretationLabel,
            systemImage: action.systemImage,
            chips: [],
            resolution: .surfaceAction(action)
        ))
    }

    public func dismissInterpretation() {
        interpretation = nil
        state = hasDraft ? .focused : .resting
    }

    // MARK: - Clarification

    public func showClarification(_ request: ClarificationRequest) {
        clarification = request
        interpretation = nil
        workingLabel = nil
        state = .review
    }

    public func dismissClarification() {
        clarification = nil
        state = hasDraft ? .focused : .resting
    }

    public func settle() {
        preview = nil
        workingLabel = nil
        recovery = nil
        recoveryMessage = nil
        interpretation = nil
        clarification = nil
        state = .settling
    }

    public func finishSettling() {
        state = hasDraft ? .focused : .resting
    }

    public func addAttachment(_ attachment: LifeThreadAttachmentDraft) {
        attachments.append(attachment)
    }

    public func removeAttachment(id: UUID) {
        attachments.removeAll { $0.id == id }
    }

    /// This is deliberately explicit so root navigation cannot discard work.
    public func dismissDraft() {
        draftText = ""
        attachments = []
        preview = nil
        workingLabel = nil
        recovery = nil
        recoveryMessage = nil
        interpretation = nil
        clarification = nil
        lastInputSource = .typed
        state = .resting
    }
}

/// Structured understanding of the user's input, shown as a compact chip row
/// inside the composer for review before opening an editor.
public struct ComposerInterpretation: Hashable, Sendable {
    public let label: String
    public let systemImage: String
    public let chips: [InterpretationChip]
    public let resolution: LifeThreadIntentResolution

    public init(label: String, systemImage: String, chips: [InterpretationChip], resolution: LifeThreadIntentResolution) {
        self.label = label
        self.systemImage = systemImage
        self.chips = chips
        self.resolution = resolution
    }
}

public struct InterpretationChip: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let label: String

    public init(id: UUID = UUID(), label: String) {
        self.id = id
        self.label = label
    }
}

public struct PhraseSettlingPolicy: Hashable, Sendable {
    public var maximumGraphemes: Int
    public var maximumDelay: TimeInterval

    public init(maximumGraphemes: Int = 72, maximumDelay: TimeInterval = 0.14) {
        self.maximumGraphemes = max(1, maximumGraphemes)
        self.maximumDelay = max(0, maximumDelay)
    }

    public func settledPrefix(in buffer: String, elapsed: TimeInterval) -> String? {
        guard buffer.isEmpty == false else { return nil }
        if let boundary = buffer.firstIndex(where: { ".!?;:\n".contains($0) }) {
            return String(buffer[...boundary])
        }
        if buffer.count >= maximumGraphemes {
            return String(buffer.prefix(maximumGraphemes))
        }
        // Date's binary representation can land a few nanoseconds below an
        // exact 140 ms boundary. Treat that as the boundary, not another frame.
        if elapsed + 0.000_001 >= maximumDelay { return buffer }
        return nil
    }
}

public actor PhraseSettler {
    private let policy: PhraseSettlingPolicy
    private var buffer = ""
    private var lastSettlementAt: Date

    public init(policy: PhraseSettlingPolicy = .init(), now: Date = Date()) {
        self.policy = policy
        lastSettlementAt = now
    }

    public func append(_ fragment: String, at date: Date = Date()) -> [String] {
        buffer.append(fragment)
        var settled: [String] = []
        while let prefix = policy.settledPrefix(
            in: buffer,
            elapsed: date.timeIntervalSince(lastSettlementAt)
        ) {
            settled.append(prefix)
            buffer.removeFirst(prefix.count)
            lastSettlementAt = date
        }
        return settled
    }

    public func flush(at date: Date = Date()) -> String? {
        guard buffer.isEmpty == false else { return nil }
        let result = buffer
        buffer = ""
        lastSettlementAt = date
        return result
    }

    /// Stop keeps already emitted phrases readable and drops only this buffer.
    public func stopDiscardingUncommitted() {
        buffer = ""
        lastSettlementAt = Date()
    }

    public func uncommittedText() -> String { buffer }
}

public struct PhraseSettlementUpdate: Hashable, Sendable {
    public var displayText: String
    public var newlySettledText: String

    public init(displayText: String, newlySettledText: String) {
        self.displayText = displayText
        self.newlySettledText = newlySettledText
    }
}

/// Converts a cumulative streaming transcript into stable phrase-sized UI
/// updates. The model runtime can continue publishing cumulative text while the
/// presentation only changes on punctuation, length, or the 140 ms boundary.
public struct CumulativePhraseSettler: Sendable {
    private let policy: PhraseSettlingPolicy
    private var settledText = ""
    private var latestCumulativeText = ""
    private var lastSettlementAt: Date

    public init(policy: PhraseSettlingPolicy = .init(), now: Date = Date()) {
        self.policy = policy
        lastSettlementAt = now
    }

    public mutating func ingest(
        cumulativeText: String,
        at date: Date = Date()
    ) -> PhraseSettlementUpdate {
        latestCumulativeText = cumulativeText
        guard cumulativeText.hasPrefix(settledText) else {
            // Sanitizers may retract an unfinished reasoning marker. Never
            // rewrite text the user has already read during the same stream.
            return .init(displayText: settledText, newlySettledText: "")
        }

        var buffer = String(cumulativeText.dropFirst(settledText.count))
        var newlySettled = ""
        while let prefix = policy.settledPrefix(
            in: buffer,
            elapsed: date.timeIntervalSince(lastSettlementAt)
        ) {
            newlySettled.append(prefix)
            settledText.append(prefix)
            buffer.removeFirst(prefix.count)
            lastSettlementAt = date
        }
        return .init(displayText: settledText, newlySettledText: newlySettled)
    }

    public mutating func complete(
        cumulativeText: String? = nil,
        at date: Date = Date()
    ) -> PhraseSettlementUpdate {
        if let cumulativeText { latestCumulativeText = cumulativeText }
        guard latestCumulativeText.hasPrefix(settledText) else {
            // Final sanitization is authoritative once generation has stopped.
            let replacement = latestCumulativeText
            settledText = replacement
            lastSettlementAt = date
            return .init(displayText: replacement, newlySettledText: replacement)
        }
        let suffix = String(latestCumulativeText.dropFirst(settledText.count))
        settledText.append(suffix)
        lastSettlementAt = date
        return .init(displayText: settledText, newlySettledText: suffix)
    }

    /// The settled prefix remains visible; only the private in-flight suffix is
    /// forgotten. This is the Stop-button contract.
    public mutating func stopDiscardingUncommitted(at date: Date = Date()) -> String {
        latestCumulativeText = settledText
        lastSettlementAt = date
        return settledText
    }

    public var displayText: String { settledText }
    public var uncommittedText: String {
        guard latestCumulativeText.hasPrefix(settledText) else { return "" }
        return String(latestCumulativeText.dropFirst(settledText.count))
    }
}

public enum GeneratedVisualState: String, Codable, CaseIterable, Hashable, Sendable {
    case promptReview
    case generating
    case ready
    case saved
    case discarded
    case unavailable
    case failed
}

public struct GeneratedVisualArtifact: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var promptSummary: String
    public var intendedUsage: String
    public var localAssetIdentifier: String?
    public var state: GeneratedVisualState
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        promptSummary: String,
        intendedUsage: String,
        localAssetIdentifier: String? = nil,
        state: GeneratedVisualState = .promptReview,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.promptSummary = promptSummary
        self.intendedUsage = intendedUsage
        self.localAssetIdentifier = localAssetIdentifier
        self.state = state
        self.createdAt = createdAt
    }
}

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

public enum AdaptiveHeroPriority: Int, Codable, CaseIterable, Hashable, Sendable {
    case generalFocus = 100
    case recovery = 200
    case timedRoutine = 300
    case urgentPlannedWork = 400
    case fixedCommitment = 500
    case safetySensitiveCare = 600
    case activeFocus = 700
}

public struct AdaptiveHeroSnapshot: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var priority: AdaptiveHeroPriority
    public var title: String
    public var detail: String?
    public var primaryActionTitle: String
    public var secondaryActionTitles: [String]
    public var sourceID: UUID?
    public var generatedAt: Date

    public init(
        id: String,
        priority: AdaptiveHeroPriority,
        title: String,
        detail: String? = nil,
        primaryActionTitle: String,
        secondaryActionTitles: [String] = [],
        sourceID: UUID? = nil,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.priority = priority
        self.title = title
        self.detail = detail
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitles = Array(secondaryActionTitles.prefix(2))
        self.sourceID = sourceID
        self.generatedAt = generatedAt
    }
}

public enum HomeSignalState: String, Codable, CaseIterable, Hashable, Sendable {
    case available
    case loading
    case setupRequired
    case permissionRequired
    case stale
    case unavailable

    public var permitsProgressRendering: Bool { self == .available }
}

public struct HomeSignalSlot: Codable, Equatable, Identifiable, Sendable {
    public typealias Availability = HomeSignalState

    public let id: String
    public var title: String
    public var valueText: String?
    public var progress: Double?
    public var systemImage: String
    public var availability: Availability
    public var sourceID: UUID?

    public init(
        id: String,
        title: String,
        valueText: String? = nil,
        progress: Double? = nil,
        systemImage: String,
        availability: Availability,
        sourceID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.valueText = valueText
        self.progress = availability.permitsProgressRendering
            ? progress.map { min(1, max(0, $0)) }
            : nil
        self.systemImage = systemImage
        self.availability = availability
        self.sourceID = sourceID
    }
}

public struct CaptureOrbPresentationState: Equatable, Sendable {
    public var isExpanded: Bool
    public var highlightedKind: CaptureKind?

    public init(isExpanded: Bool = false, highlightedKind: CaptureKind? = nil) {
        self.isExpanded = isExpanded
        self.highlightedKind = highlightedKind
    }
}

public struct CaptureOrbDragTarget: Equatable, Sendable {
    public let kind: CaptureKind
    public let frame: CGRect

    public init(kind: CaptureKind, frame: CGRect) {
        self.kind = kind
        self.frame = frame
    }
}

/// Deterministic hit testing for the capture orb's drag-and-release interaction.
/// A small expanded hit region makes narrow gaps forgiving without allowing a
/// release far outside the menu to create data accidentally.
public enum CaptureOrbDragSelectionPolicy {
    public static func selection(
        at location: CGPoint,
        targets: [CaptureOrbDragTarget],
        hitSlop: CGFloat = 10
    ) -> CaptureKind? {
        targets
            .filter { $0.frame.insetBy(dx: -hitSlop, dy: -hitSlop).contains(location) }
            .min { lhs, rhs in
                squaredDistance(from: location, to: lhs.frame.center)
                    < squaredDistance(from: location, to: rhs.frame.center)
            }?
            .kind
    }

    private static func squaredDistance(from point: CGPoint, to other: CGPoint) -> CGFloat {
        let dx = point.x - other.x
        let dy = point.y - other.y
        return (dx * dx) + (dy * dy)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

public struct EvaProactiveCard: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var destination: LifeBoardDestination
    public var localDay: PlanningDay
    public var title: String
    public var reason: String
    public var authorizedContextIDs: [String]
    public var sensitivity: DataSensitivity
    public var createdAt: Date
    public var dismissedAt: Date?
    public var snoozedUntil: Date?

    public init(
        id: UUID = UUID(),
        destination: LifeBoardDestination,
        localDay: PlanningDay,
        title: String,
        reason: String,
        authorizedContextIDs: [String] = [],
        sensitivity: DataSensitivity = .privateStandard,
        createdAt: Date = Date(),
        dismissedAt: Date? = nil,
        snoozedUntil: Date? = nil
    ) {
        self.id = id
        self.destination = destination
        self.localDay = localDay
        self.title = title
        self.reason = reason
        self.authorizedContextIDs = authorizedContextIDs
        self.sensitivity = sensitivity
        self.createdAt = createdAt
        self.dismissedAt = dismissedAt
        self.snoozedUntil = snoozedUntil
    }
}

public enum ProactiveCardPolicy {
    public static func canPresent(
        _ candidate: EvaProactiveCard,
        existing: [EvaProactiveCard],
        activeFocus: Bool,
        safetySensitiveCareRequiresAttention: Bool,
        hasPinnedCommitment: Bool,
        now: Date = Date()
    ) -> Bool {
        guard !activeFocus, !safetySensitiveCareRequiresAttention, !hasPinnedCommitment else { return false }
        let destinationCards = existing.filter { $0.destination == candidate.destination }
        guard destinationCards.contains(where: {
            $0.dismissedAt == nil && ($0.snoozedUntil == nil || $0.snoozedUntil! <= now)
        }) == false else { return false }
        return destinationCards.contains(where: { $0.localDay == candidate.localDay }) == false
    }
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
    public static let dashboardLayoutVersion = 5
    public static let goalContractVersion = 1
    public static let routineContractVersion = 1
    public static let trackerContractVersion = 1
    public static let journalContractVersion = 1
    public static let collaborationContractVersion = 1
    public static let wellnessContractVersion = 1
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

    /// Carries whatever setup the user deferred — permissions they skipped,
    /// targets they have not set — and removes itself once there is nothing
    /// left to offer. Onboarding cannot ask for everything, so the long tail
    /// lives here rather than in a longer wizard.
    public static let setupChecklist = Self(rawValue: "setupChecklist")
    public static let focusNow = Self(rawValue: "focusNow")
    public static let lifeSnapshot = Self(rawValue: "lifeSnapshot")
    public static let care = Self(rawValue: "care")
    public static let tasks = Self(rawValue: "tasks")
    public static let routines = Self(rawValue: "routines")
    public static let scheduleCapacity = Self(rawValue: "scheduleCapacity")
    public static let quickCapture = Self(rawValue: "quickCapture")
    public static let compactTimeline = Self(rawValue: "compactTimeline")
    public static let journal = Self(rawValue: "journal")
    public static let progressReflection = Self(rawValue: "progressReflection")
    public static let fasting = Self(rawValue: "fasting")
    public static let goals = Self(rawValue: "goals")
    public static let evaConversation = Self(rawValue: "evaConversation")
    public static let bodyMetric = Self(rawValue: "bodyMetric")
    public static let workout = Self(rawValue: "workout")
    public static let sleep = Self(rawValue: "sleep")
    public static let movement = Self(rawValue: "movement")
    public static let lifeMoment = Self(rawValue: "lifeMoment")
    public static let nutritionSummary = Self(rawValue: "nutritionSummary")
    public static let recentMeal = Self(rawValue: "recentMeal")
    public static let logMeal = Self(rawValue: "logMeal")
}

public enum WidgetGalleryCategory: String, Codable, CaseIterable, Sendable {
    case orient, act, plan, wellbeing, reflect, progress
}

public enum WidgetMultiplicity: String, Codable, Sendable {
    case singleton
    case multipleInstances
}

/// How a card presents itself. One archetype is one reusable body that must
/// render at *every* supported size — this is what removes the old
/// `EmptyView()` fallthrough, where eleven kinds drew nothing at wide and tall
/// (and therefore nothing at all at accessibility text sizes, which force wide).
public enum HomeCardArchetype: String, Codable, CaseIterable, Hashable, Sendable {
    /// Hero numeral, unit and change. Sparkline or chart as it grows.
    case metric
    /// Circular progress against a target.
    case ring
    /// A series over time: sparkline → chart → chart plus table.
    case trend
    /// Rows of work with state and a primary action.
    case queue
    /// Recent-performance dots or heat grid.
    case streak
    /// One claim, its rationale and one action. Home's hero.
    case decision
    /// A compressed view of the day's shape.
    case spine
    /// A remembered moment: mood, media or excerpt.
    case moment
    /// Time remaining until a dated thing.
    case countdown
    /// A capture affordance rather than a readout.
    case action
}

/// Which anchored Home section a card belongs to. Previously this lived as
/// three hardcoded string sets inside the Home view plus a fourth copy in the
/// layout repository, so registering a new kind silently dropped it into
/// "Your space" and the two anchored copies could disagree.
public enum HomeSectionRole: String, Codable, CaseIterable, Hashable, Sendable {
    /// Rendered by a fixed Home section, never as a free-floating placement.
    case anchored
    /// Today's committed work.
    case today
    /// Recurring care, routines and wellbeing.
    case keepSteady
    /// Reflection and closing the day.
    case closeLoop
    /// Whatever the user chose to pin.
    case userSpace

    public var title: String {
        switch self {
        case .anchored: "Now"
        case .today: "Today"
        case .keepSteady: "Keep steady"
        case .closeLoop: "Close the loop"
        case .userSpace: "Your space"
        }
    }
}

public struct DashboardWidgetDescriptor: Codable, Hashable, Sendable {
    public let kind: DashboardWidgetKind
    public let title: String
    public let category: WidgetGalleryCategory
    public let supportedSizes: Set<WidgetSizePreset>
    public let multiplicity: WidgetMultiplicity
    public let sensitivity: DataSensitivity
    public let archetype: HomeCardArchetype
    public let sectionRole: HomeSectionRole
    public let configurationVersion: Int

    public init(
        kind: DashboardWidgetKind,
        title: String,
        category: WidgetGalleryCategory,
        supportedSizes: Set<WidgetSizePreset>,
        multiplicity: WidgetMultiplicity,
        sensitivity: DataSensitivity,
        archetype: HomeCardArchetype = .queue,
        sectionRole: HomeSectionRole = .userSpace,
        configurationVersion: Int = 1
    ) {
        self.kind = kind
        self.title = title
        self.category = category
        self.supportedSizes = supportedSizes
        self.multiplicity = multiplicity
        self.sensitivity = sensitivity
        self.archetype = archetype
        self.sectionRole = sectionRole
        self.configurationVersion = configurationVersion
    }
}

public typealias HomeBoardLayout = DashboardLayoutValue
public typealias HomeCardPlacement = DashboardWidgetPlacementValue
public typealias HomeCardDefinition = DashboardWidgetDescriptor
public typealias HomeCardSize = WidgetSizePreset

public enum HomeCardSnapshotAvailability: String, Codable, CaseIterable, Hashable, Sendable {
    case ready
    case empty
    case degraded
    case unavailable
    case redacted
}

public enum HomeCardRedactionMode: String, Codable, CaseIterable, Hashable, Sendable {
    case automatic
    case revealPermitted
    case forceRedacted
}

public struct HomeCardSnapshotContext: Hashable, Sendable {
    public var date: Date
    public var timeZoneIdentifier: String
    public var semanticSize: HomeCardSize
    public var configuration: HomeCardConfiguration
    public var permittedSensitivities: Set<DataSensitivity>
    public var redactionMode: HomeCardRedactionMode
    public var availableCapabilities: Set<String>

    public init(
        date: Date = Date(),
        timeZone: TimeZone = .autoupdatingCurrent,
        semanticSize: HomeCardSize,
        configuration: HomeCardConfiguration = .init(),
        permittedSensitivities: Set<DataSensitivity> = [.privateStandard, .shareEligible],
        redactionMode: HomeCardRedactionMode = .automatic,
        availableCapabilities: Set<String> = []
    ) {
        self.date = date
        self.timeZoneIdentifier = timeZone.identifier
        self.semanticSize = semanticSize
        self.configuration = configuration
        self.permittedSensitivities = permittedSensitivities
        self.redactionMode = redactionMode
        self.availableCapabilities = availableCapabilities
    }

    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .autoupdatingCurrent
    }

    public func permits(_ sensitivity: DataSensitivity) -> Bool {
        redactionMode != .forceRedacted && permittedSensitivities.contains(sensitivity)
    }
}

public enum HomeCardActionRole: String, Codable, CaseIterable, Hashable, Sendable {
    case primary
    case secondary
    case destructive
}

public struct HomeCardActionDescriptor: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let role: HomeCardActionRole
    public let destination: LifeBoardDestination?
    public let requiresMutationPreview: Bool

    public init(
        id: String,
        title: String,
        systemImage: String,
        role: HomeCardActionRole = .secondary,
        destination: LifeBoardDestination? = nil,
        requiresMutationPreview: Bool = false
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.destination = destination
        self.requiresMutationPreview = requiresMutationPreview
    }
}

/// A hero number with its unit and, where it is meaningful, its change.
public struct HomeMetricValue: Codable, Hashable, Sendable {
    public enum Trend: String, Codable, Hashable, Sendable { case up, down, flat }

    public var amount: Double
    /// Digits after the decimal point when rendering. Steps want 0; weight wants 1.
    public var fractionDigits: Int
    public var unit: String?
    /// Change against the comparison window, already resolved by the provider.
    public var delta: Double?
    public var deltaDescription: String?
    public var trend: Trend
    /// Optional recent history for the inline sparkline.
    public var history: [HomeSeriesPoint]

    public init(
        amount: Double,
        fractionDigits: Int = 0,
        unit: String? = nil,
        delta: Double? = nil,
        deltaDescription: String? = nil,
        trend: Trend = .flat,
        history: [HomeSeriesPoint] = []
    ) {
        self.amount = amount
        self.fractionDigits = max(0, min(4, fractionDigits))
        self.unit = unit
        self.delta = delta
        self.deltaDescription = deltaDescription
        self.trend = trend
        self.history = history
    }
}

public struct HomeSeriesPoint: Codable, Hashable, Sendable, Identifiable {
    public var date: Date
    public var value: Double
    /// Short axis label. Charts must never rely on colour alone.
    public var label: String?

    public var id: Date { date }

    public init(date: Date, value: Double, label: String? = nil) {
        self.date = date
        self.value = value
        self.label = label
    }
}

public struct HomeQueueItem: Codable, Hashable, Sendable, Identifiable {
    public enum State: String, Codable, Hashable, Sendable {
        case pending, inProgress, done, overdue, skipped
    }

    public var id: String
    public var title: String
    public var supporting: String?
    public var state: State
    public var systemImage: String?

    public init(
        id: String,
        title: String,
        supporting: String? = nil,
        state: State = .pending,
        systemImage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.supporting = supporting
        self.state = state
        self.systemImage = systemImage
    }
}

public struct HomeDayState: Codable, Hashable, Sendable, Identifiable {
    public enum Outcome: String, Codable, Hashable, Sendable {
        case complete, partial, missed, offDay, future
    }

    public var date: Date
    public var outcome: Outcome

    public var id: Date { date }

    public init(date: Date, outcome: Outcome) {
        self.date = date
        self.outcome = outcome
    }
}

public struct HomeMomentPreview: Codable, Hashable, Sendable {
    public var excerpt: String?
    public var moodLabel: String?
    /// Bundle-relative or app-container path. Never inlined into system surfaces.
    public var imagePath: String?
    public var capturedAt: Date?

    public init(
        excerpt: String? = nil,
        moodLabel: String? = nil,
        imagePath: String? = nil,
        capturedAt: Date? = nil
    ) {
        self.excerpt = excerpt
        self.moodLabel = moodLabel
        self.imagePath = imagePath
        self.capturedAt = capturedAt
    }
}

/// Structured card content. Cards previously carried only `value`/`detail`
/// strings, which the renderer joined with " · " into a single `Text` — so a
/// card could not be a number or a chart even in principle. The string fields
/// remain as the VoiceOver and system-surface path.
public enum HomeCardPayload: Codable, Hashable, Sendable {
    case none
    case metric(HomeMetricValue)
    case progress(fraction: Double, label: String?)
    case series([HomeSeriesPoint])
    case queue([HomeQueueItem])
    case streak([HomeDayState])
    case countdown(target: Date, label: String)
    case moment(HomeMomentPreview)

    public var isEmpty: Bool {
        switch self {
        case .none: true
        case .series(let points): points.isEmpty
        case .queue(let items): items.isEmpty
        case .streak(let days): days.isEmpty
        default: false
        }
    }
}

public struct HomeCardSnapshot: Codable, Hashable, Sendable {
    public var availability: HomeCardSnapshotAvailability
    public var title: String
    public var value: String?
    public var detail: String?
    public var payload: HomeCardPayload
    public var actions: [HomeCardActionDescriptor]
    public var updatedAt: Date

    public init(
        availability: HomeCardSnapshotAvailability,
        title: String,
        value: String? = nil,
        detail: String? = nil,
        payload: HomeCardPayload = .none,
        actions: [HomeCardActionDescriptor] = [],
        updatedAt: Date = Date()
    ) {
        self.availability = availability
        self.title = title
        self.value = value
        self.detail = detail
        self.payload = payload
        self.actions = actions
        self.updatedAt = updatedAt
    }

    /// Sensitive cards may show a numeral inside the app and must never leak
    /// one into a widget, Spotlight item or notification preview.
    public func redactingPayload() -> HomeCardSnapshot {
        var copy = self
        copy.payload = .none
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case availability, title, value, detail, payload, actions, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        availability = try container.decode(HomeCardSnapshotAvailability.self, forKey: .availability)
        title = try container.decode(String.self, forKey: .title)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        // Absent in every snapshot persisted before this schema, including
        // app-group widget envelopes still on disk.
        payload = try container.decodeIfPresent(HomeCardPayload.self, forKey: .payload) ?? .none
        actions = try container.decodeIfPresent([HomeCardActionDescriptor].self, forKey: .actions) ?? []
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

/// Domain-owned providers keep Home out of canonical databases. In-app cards,
/// widgets, and previews may consume the same snapshot while retaining separate
/// rendering lifecycles.
public protocol HomeCardProvider: Sendable {
    var definition: HomeCardDefinition { get }
    var primaryDestination: LifeBoardDestination { get }
    var privacyClassification: DataSensitivity { get }
    var inlineActions: [HomeCardActionDescriptor] { get }
    func snapshot(
        configuration: HomeCardConfiguration,
        size: HomeCardSize,
        at date: Date
    ) async -> HomeCardSnapshot
    func snapshot(context: HomeCardSnapshotContext) async -> HomeCardSnapshot
}

public extension HomeCardProvider {
    var inlineActions: [HomeCardActionDescriptor] {
        [
            .init(
                id: "open-source",
                title: "Open",
                systemImage: "arrow.up.forward",
                role: .primary,
                destination: primaryDestination
            )
        ]
    }

    func snapshot(context: HomeCardSnapshotContext) async -> HomeCardSnapshot {
        guard context.permits(privacyClassification) else {
            return HomeCardSnapshot(
                availability: .redacted,
                title: definition.title,
                detail: "Hidden until you allow this information on Home.",
                updatedAt: context.date
            )
        }
        var result = await snapshot(
            configuration: context.configuration,
            size: context.semanticSize,
            at: context.date
        )
        if result.actions.isEmpty {
            result.actions = inlineActions
        }
        return result
    }
}

public enum HomeCardProviderRegistryError: Error, Equatable, Sendable {
    case duplicateProvider(DashboardWidgetKind)
    case providerNotFound(DashboardWidgetKind)
    case unsupportedSize(DashboardWidgetKind, HomeCardSize)
}

/// A stable provider lookup boundary. Home asks this actor for display-ready
/// snapshots and never reaches into a domain repository itself.
public actor HomeCardProviderRegistry {
    private var providers: [DashboardWidgetKind: any HomeCardProvider] = [:]

    public init(providers: [any HomeCardProvider] = []) throws {
        for provider in providers {
            let kind = provider.definition.kind
            guard self.providers[kind] == nil else {
                throw HomeCardProviderRegistryError.duplicateProvider(kind)
            }
            self.providers[kind] = provider
        }
    }

    public func register(_ provider: any HomeCardProvider) throws {
        let kind = provider.definition.kind
        guard providers[kind] == nil else {
            throw HomeCardProviderRegistryError.duplicateProvider(kind)
        }
        providers[kind] = provider
    }

    public func unregister(kind: DashboardWidgetKind) {
        providers.removeValue(forKey: kind)
    }

    public func registeredDefinitions() -> [HomeCardDefinition] {
        providers.values
            .map(\.definition)
            .sorted { lhs, rhs in
                if lhs.category == rhs.category { return lhs.title < rhs.title }
                return lhs.category.rawValue < rhs.category.rawValue
            }
    }

    public func provider(for kind: DashboardWidgetKind) -> (any HomeCardProvider)? {
        providers[kind]
    }

    public func snapshot(
        for kind: DashboardWidgetKind,
        context: HomeCardSnapshotContext
    ) async throws -> HomeCardSnapshot {
        guard let provider = providers[kind] else {
            throw HomeCardProviderRegistryError.providerNotFound(kind)
        }
        guard provider.definition.supportedSizes.contains(context.semanticSize) else {
            throw HomeCardProviderRegistryError.unsupportedSize(kind, context.semanticSize)
        }
        let interval = LifeOSPerformanceOperation.homeCardSnapshot.begin()
        defer { LifeOSPerformanceOperation.homeCardSnapshot.end(interval) }
        return await provider.snapshot(context: context)
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
            .init(kind: .setupChecklist, title: "Finish setup", category: .orient, supportedSizes: [.standard, .wide], multiplicity: .singleton, sensitivity: .privateStandard, archetype: .ring, sectionRole: .userSpace),
            .init(kind: .focusNow, title: "Focus Now", category: .act, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .singleton, sensitivity: .privateStandard, archetype: .decision, sectionRole: .anchored),
            .init(kind: .lifeSnapshot, title: "Life Snapshot", category: .orient, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .metric, sectionRole: .anchored),
            .init(kind: .care, title: "Care", category: .wellbeing, supportedSizes: allSizes, multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .queue, sectionRole: .keepSteady),
            // Today's committed work belongs above wellbeing, not last on the
            // board. It has its own anchored section now.
            .init(kind: .tasks, title: "Today’s Tasks", category: .act, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .singleton, sensitivity: .privateStandard, archetype: .queue, sectionRole: .today),
            .init(kind: .routines, title: "Routines", category: .wellbeing, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .singleton, sensitivity: .privateStandard, archetype: .queue, sectionRole: .keepSteady),
            .init(kind: .scheduleCapacity, title: "Schedule & Capacity", category: .plan, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .multipleInstances, sensitivity: .privateStandard, archetype: .spine, sectionRole: .anchored),
            .init(kind: .quickCapture, title: "Quick Capture", category: .act, supportedSizes: [.compact, .standard, .wide], multiplicity: .singleton, sensitivity: .privateStandard, archetype: .action, sectionRole: .anchored),
            .init(kind: .compactTimeline, title: "Day Shape", category: .plan, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .multipleInstances, sensitivity: .privateStandard, archetype: .spine, sectionRole: .anchored),
            .init(kind: .journal, title: "Journal", category: .reflect, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .moment, sectionRole: .closeLoop),
            .init(kind: .progressReflection, title: "Progress & Reflection", category: .reflect, supportedSizes: allSizes, multiplicity: .multipleInstances, sensitivity: .privateSensitive, archetype: .trend, sectionRole: .closeLoop),
            .init(kind: .fasting, title: "Active Fast", category: .wellbeing, supportedSizes: allSizes, multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .ring, sectionRole: .keepSteady),
            .init(kind: .goals, title: "Goal Progress", category: .progress, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .multipleInstances, sensitivity: .privateStandard, archetype: .ring, sectionRole: .keepSteady),
            .init(kind: .evaConversation, title: "Saved Eva Insight", category: .reflect, supportedSizes: [.standard, .wide, .tall], multiplicity: .multipleInstances, sensitivity: .privateSensitive, archetype: .moment, sectionRole: .closeLoop),
            .init(kind: .bodyMetric, title: "Body Metric", category: .wellbeing, supportedSizes: allSizes, multiplicity: .multipleInstances, sensitivity: .privateSensitive, archetype: .trend, sectionRole: .keepSteady),
            .init(kind: .workout, title: "Recent Workout", category: .wellbeing, supportedSizes: allSizes, multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .metric, sectionRole: .keepSteady),
            .init(kind: .sleep, title: "Sleep Note", category: .wellbeing, supportedSizes: allSizes, multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .trend, sectionRole: .keepSteady),
            .init(kind: .movement, title: "Movement", category: .wellbeing, supportedSizes: allSizes, multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .metric, sectionRole: .keepSteady),
            .init(kind: .lifeMoment, title: "Life Moment", category: .reflect, supportedSizes: allSizes, multiplicity: .multipleInstances, sensitivity: .privateStandard, archetype: .countdown, sectionRole: .closeLoop),
            .init(kind: .nutritionSummary, title: "Nutrition Summary", category: .wellbeing, supportedSizes: allSizes, multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .metric, sectionRole: .keepSteady),
            .init(kind: .recentMeal, title: "Recent Meal", category: .wellbeing, supportedSizes: [.compact, .standard, .wide, .tall], multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .moment, sectionRole: .keepSteady),
            .init(kind: .logMeal, title: "Log Meal", category: .act, supportedSizes: [.compact, .standard, .wide], multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .action, sectionRole: .keepSteady)
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
