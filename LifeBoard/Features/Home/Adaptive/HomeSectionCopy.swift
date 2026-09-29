import SwiftUI
import LifeBoardDomain

/// Pure derivations lifted out of `AdaptiveHome`.
///
/// `@MainActor` is required rather than decorative: several of these read
/// `@Observable @MainActor` stores.
@MainActor
enum HomeSectionCopy {
    static func symbol(for kind: DashboardWidgetKind, store: AdaptiveHomeStore) -> String {
        store.registry.descriptor(for: kind)?.systemImage ?? "square.grid.2x2"
    }

    static func heroLabel(for priority: AdaptiveHeroPriority?) -> String {
        switch priority {
        case .activeFocus: String(localized: "Focus in progress")
        case .safetySensitiveCare: String(localized: "Medication due")
        case .fixedCommitment: String(localized: "Happening now")
        case .urgentPlannedWork: String(localized: "Must do")
        case .timedRoutine: String(localized: "Routine")
        case .recovery: String(localized: "Recovery")
        case .generalFocus, .none: String(localized: "Focus Now")
        }
    }

    static func heroSymbol(for priority: AdaptiveHeroPriority?) -> String {
        switch priority {
        case .activeFocus: "timer"
        case .safetySensitiveCare: "cross.case"
        case .fixedCommitment: "calendar"
        case .urgentPlannedWork: "exclamationmark.circle"
        case .timedRoutine: "list.bullet.clipboard"
        case .recovery: "arrow.counterclockwise"
        case .generalFocus, .none: "scope"
        }
    }

    static func compactHeroActionTitle(_ title: String) -> String {
        switch title {
        case "Choose a focus": "Choose"
        case "Open focus", "Open day": "Open"
        default: title
        }
    }

    static func homeAvailability(
        for domain: HealthDomain,
        value: HealthAggregateValue?,
        healthStore: HealthConnectionStore
    ) -> HomeSignalState {
        let signal = healthStore.statuses[domain]?.signal ?? .setupRequired
        switch signal {
        case .loading: return .loading
        case .setupRequired: return .permissionRequired
        case .stale, .partial: return value == nil ? .unavailable : .stale
        case .unavailable, .protectedDataLocked, .offline, .writeDenied: return value == nil ? .unavailable : .stale
        case .noRecord: return .setupRequired
        case .explicitZero, .recorded: return value == nil ? .setupRequired : .available
        }
    }

    static func signalRank(_ slot: HomeSignalSlot) -> Int {
        let stateRank: Int = switch slot.availability {
        case .available: 40
        case .stale: 30
        case .loading: 20
        case .setupRequired, .permissionRequired: 10
        case .unavailable: 0
        }
        let domainRank: Int = switch slot.id {
        case "steps": 4
        case "active": 3
        case "hydration": 2
        case "fasting": 1
        default: 0
        }
        return stateRank + domainRank
    }

    /// Water-like signals fill with liquid; movement signals keep the plain
    /// arc so the metaphor stays honest.
    static func liquidTint(for slot: HomeSignalSlot, palette: DaypartPalette) -> Color? {
        guard slot.availability == .available || slot.availability == .stale else { return nil }
        switch slot.id {
        case "hydration": return Color(SemanticColorTokens.foundationSageAccent).opacity(0.55)
        case "fasting": return Color(SemanticColorTokens.foundationApricotAccent).opacity(0.6)
        default: return nil
        }
    }

    static func ringState(for slot: HomeSignalSlot) -> MetricRing.RingState {
        switch slot.availability {
        case .loading:
            return .loading
        case .setupRequired:
            return .setupRequired
        case .permissionRequired:
            // These two were one case, and the collapse discarded a distinction
            // the domain had just made: `homeAvailability` above separates
            // "HealthKit was never authorized" (.permissionRequired) from
            // "authorized, nothing recorded yet" (.setupRequired). Both drew the
            // same dashed "+", so a declined permission read as unfinished
            // setup — and the "+" implied tapping would let you add a value,
            // which it cannot.
            return .permissionRequired
        case .unavailable:
            return .unavailable
        case .stale:
            guard let value = slot.valueText else { return .unavailable }
            return .stale(progress: slot.progress ?? 0, centerText: value)
        case .available:
            guard let value = slot.valueText else { return .setupRequired }
            let progress = slot.progress ?? 0
            if progress == 0 { return .zero(centerText: value) }
            return progress >= 1 ? .complete(centerText: value) : .value(progress: progress, centerText: value)
        }
    }

    static func accessibilityAvailability(_ availability: HomeSignalSlot.Availability) -> String {
        switch availability {
        case .available: String(localized: "available")
        case .loading: String(localized: "loading")
        case .setupRequired: String(localized: "not set up")
        case .permissionRequired: String(localized: "not shared")
        case .stale: String(localized: "out of date")
        case .unavailable: String(localized: "unavailable")
        }
    }

    static func compactHours(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval / 60))
        return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
    }

    static func spokenHours(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval / 60))
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = totalMinutes >= 60 ? [.hour, .minute] : [.minute]
        return formatter.string(from: TimeInterval(totalMinutes * 60)) ?? compactHours(interval)
    }

    /// "45 min", "1 hr, 30 min": the app's one duration format.
    static func duration(_ seconds: TimeInterval) -> String {
        LifeBoardDuration.text(seconds: seconds)
    }

    static func hydrationLabel(_ lifeOSStore: HomeLifeOSProjectionStore) -> String {
        guard let amount = lifeOSStore.trackSnapshot?.hydrationAmountMilliliters else { return String(localized: "Set up") }
        return String(localized: "\(Int(amount)) ml")
    }

    static func medicationLabel(_ lifeOSStore: HomeLifeOSProjectionStore) -> String {
        let count = lifeOSStore.trackSnapshot?.unresolvedMedicationEvents.count ?? 0
        if count == 0 { return String(localized: "Nothing to log") }
        return count == 1 ? String(localized: "1 dose to log") : String(localized: "\(count) doses to log")
    }

    /// A time of day as a word for a card title ("Morning care").
    static func daypartName(_ daypart: ResolvedDaypart) -> String {
        switch daypart {
        case .morning: String(localized: "Morning")
        case .afternoon: String(localized: "Afternoon")
        case .evening: String(localized: "Evening")
        case .night: String(localized: "Night")
        }
    }

    /// One care row: the medicine by name, and when it was due. A dose whose
    /// time has passed asks to be logged instead of showing a status word.
    static func medicationRow(
        name: String?,
        scheduledAt: Date,
        isPastDue: Bool
    ) -> (title: String, detail: String) {
        let time = scheduledAt.formatted(date: .omitted, time: .shortened)
        return (
            name?.isEmpty == false ? name! : String(localized: "Medication"),
            isPastDue ? String(localized: "Due at \(time) · Taken or skipped?") : String(localized: "Due at \(time)")
        )
    }

    static func capacityDescription(
        router: AppRouter,
        projectionAdapter: HomeProjectionCoordinator
    ) -> String {
        if router.dashboardMode == .lowEnergy { return String(localized: "Low energy mode") }
        if projectionAdapter.snapshot.overdueCount > 2 { return String(localized: "Full day. Pick one to finish first.") }
        return String(localized: "Time for one focus session.")
    }

    static func taskWidgetTitle(_ lifeOSStore: HomeLifeOSProjectionStore) -> String {
        let selectedDate = lifeOSStore.taskAgenda.selectedDate
        if Calendar.current.isDate(selectedDate, inSameDayAs: lifeOSStore.presentationDate) {
            // The section above already says "Today"; "Today’s tasks" under it
            // read as the same heading twice.
            return String(localized: "Tasks")
        }
        let day = selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return String(localized: "\(day) tasks")
    }

    static func taskWidgetEmptyMessage(_ lifeOSStore: HomeLifeOSProjectionStore) -> String {
        let selectedDate = lifeOSStore.taskAgenda.selectedDate
        if Calendar.current.isDate(selectedDate, inSameDayAs: lifeOSStore.presentationDate) {
            // When Up next is also empty this is the only line about the day.
            let upNext = HomeTodayStorySection.upNextItems(lifeOSStore: lifeOSStore, now: Date())
            return upNext.isEmpty ? String(localized: "Nothing else today") : String(localized: "No tasks due today")
        }
        let date = selectedDate.formatted(.dateTime.month(.abbreviated).day())
        return String(localized: "No tasks due \(date)")
    }

    static func spineTitle(for stage: DayLoopStage) -> String {
        switch stage {
        // The ritual row under the heading carries "Start the day" and
        // "Close the day"; the heading names the time instead of repeating it.
        case .commit: String(localized: "This morning")
        case .act: String(localized: "Now")
        case .repair: String(localized: "Worth a look")
        case .close: String(localized: "This evening")
        // Not "Done" or "Complete" — the day is put down, not scored.
        case .rest: String(localized: "Day closed")
        }
    }

    /// The loop's rhythm: how the last two weeks went, then the current run.
    ///
    /// Both numbers render at the same size in the same label, which is the
    /// anti-guilt mechanism — it is arithmetic, not copy. Consistency leads so
    /// breaking a run cannot make the smallest number the first visual fact.
    ///
    /// `nil` before anything has been closed: "0 days running" would be a
    /// verdict on nothing.
    static func dayLoopRhythmText(_ dayLoopSummary: DayLoopSummary?) -> String? {
        guard let summary = dayLoopSummary, summary.hasNoHistory == false else { return nil }
        // "closed" names what is being counted: "3 of 14 days" had no subject.
        let closed = summary.closedInWindow, total = summary.window
        let window = String(localized: "\(closed) of \(total) days closed")
        guard summary.runLength > 0 else { return window }
        let run = summary.runLength
        return String(localized: "\(window) · \(run) in a row")
    }

    /// The domain provider registry is the only source of card copy.
    ///
    /// A parallel switch used to live here as a "first-frame fallback" and had
    /// drifted into a second, contradictory copy set for the same cards —
    /// tasks-empty existed in three spellings, fasting and journal in two, and
    /// Focus Now shipped the ungrammatical "Choose one kind next step". A card
    /// shows its title alone until its provider resolves, which is a frame at
    /// most, rather than showing something that disagrees with what follows.
    static func widgetSummary(
        _ kind: DashboardWidgetKind,
        size: HomeCardSize,
        lifeOSStore: HomeLifeOSProjectionStore
    ) -> String {
        guard let snapshot = lifeOSStore.cardSnapshot(kind: kind, size: size) else { return "" }
        return snapshot.value ?? snapshot.detail ?? ""
    }
}
