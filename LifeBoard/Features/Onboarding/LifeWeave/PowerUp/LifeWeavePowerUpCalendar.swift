import Foundation
import LifeBoardDomain
import SwiftUI

/// What this connector has already asked the system, for the length of one
/// journey. Nothing here is persisted, and nothing here is Calendar truth.
///
/// The chosen calendars belong to `CalendarIntegrationService`, the grant
/// outcome belongs to the draft's granted/denied lists, and today's events
/// belong to the service too. This object only remembers what has already been
/// asked so the screen does not ask twice — a cache of questions, not answers.
///
/// It is shared rather than owned by the view for one reason: the bottom dock is
/// rendered by the flow shell from `LifeWeaveOnboardingModel`, so the dock seam
/// below has to reach the same state the connector view is looking at. Every
/// stage-changing mutation is therefore paired with a draft write, which is what
/// actually tells the shell to re-read the dock; a session-only change (a
/// calendar list arriving, a proof read finishing) is view-visible and does not
/// need to.
@MainActor
final class CalendarPowerUpSession: ObservableObject {
    static let shared = CalendarPowerUpSession()

    /// The best answer this connector has been able to get from the system.
    /// Re-resolved on every appearance rather than remembered across launches.
    @Published fileprivate(set) var authorization: CalendarAuthorizationStatus = .notDetermined
    @Published fileprivate(set) var calendars: [CalendarSourceSnapshot] = []
    @Published fileprivate(set) var isLoadingCalendars = false
    /// The user has committed a scope, so the connector may show what it bought
    /// them. Deliberately not persisted: a journey resumed after a relaunch
    /// returns to the chooser with the same selection still ticked, which is an
    /// honest place to land, rather than to a proof built from a stale read.
    @Published fileprivate(set) var didCommitSelection = false
    @Published fileprivate(set) var isReadingProof = false
    /// Events the service can actually see across the chosen calendars, or `nil`
    /// while that is unknown. Never a placeholder, and never a guess.
    @Published fileprivate(set) var visibleEventCount: Int?

    private var isRequestingAccess = false

    fileprivate func reset() {
        authorization = .notDetermined
        calendars = []
        isLoadingCalendars = false
        didCommitSelection = false
        isReadingProof = false
        visibleEventCount = nil
    }

    fileprivate func updateAuthorization(_ status: CalendarAuthorizationStatus) {
        authorization = status
    }

    fileprivate func beginLoadingCalendars() {
        isLoadingCalendars = true
    }

    fileprivate func finishLoadingCalendars(_ loaded: [CalendarSourceSnapshot]) {
        calendars = loaded
        isLoadingCalendars = false
    }

    /// Re-entrancy guard for the one action that opens a system dialog.
    fileprivate func beginAccessRequestIfIdle() -> Bool {
        guard isRequestingAccess == false else { return false }
        isRequestingAccess = true
        return true
    }

    fileprivate func endAccessRequest() {
        isRequestingAccess = false
    }

    fileprivate func markSelectionCommitted() {
        didCommitSelection = true
    }

    fileprivate func beginProofRead() {
        isReadingProof = true
    }

    fileprivate func finishProofRead(eventCount: Int?) {
        visibleEventCount = eventCount
        isReadingProof = false
    }
}

/// Power Up 1 of 3 — the Calendar connector's behaviour.
///
/// A separate file rather than a separate model: the journey has one owner, and
/// splitting by connector here is only so three people can work at once without
/// editing the same 400 lines. Calendar truth stays in its own service; this
/// file asks that service questions and records what the user decided.
@MainActor
extension LifeWeaveOnboardingModel {

    var calendarSession: CalendarPowerUpSession { .shared }

    /// The one place this connector decides which screen it is on.
    var calendarStage: CalendarPowerUpStage {
        CalendarPowerUpStage.resolve(
            authorization: calendarSession.authorization,
            hasCommittedSelection: calendarSession.didCommitSelection
        )
    }

    var selectedCalendarCount: Int { draft.selectedCalendarIDs.count }

    func isCalendarSelected(_ id: String) -> Bool {
        draft.selectedCalendarIDs.contains(id)
    }

    // MARK: - Entering the connector

    /// Resolve where this connector stands, from the service, every time.
    ///
    /// No `calendarConnected` flag is stored anywhere: the answer is whatever
    /// the service can tell us right now, which is also the only way somebody
    /// who allowed Calendar in iOS Settings between two appearances gets picked
    /// up without being asked again.
    func prepareCalendarPowerUp() async {
        let session = calendarSession

        // A second run of the journey — a workspace refresh, say — must not
        // inherit the first run's answers from a process that never quit.
        if await powerUps.calendarAuthorizationStatus() == .notDetermined,
           draft.selectedCalendarIDs.isEmpty {
            session.reset()
        }
        // The real status, not an inference. `recordedCalendarAuthorization()`
        // can only ever produce granted/denied/notDetermined from the draft's
        // outcome lists, which silently turned a restricted device into a denied
        // one and told it to flip a Settings switch it does not have.
        session.updateAuthorization(await powerUps.calendarAuthorizationStatus())

        await refreshAvailableCalendars()

        if calendarStage == .proof, session.visibleEventCount == nil {
            await readCalendarProof()
        }
    }

    /// Asks the service what it can see. Never prompts: the fetch is refused
    /// outright unless read access already exists, so this is safe on a screen
    /// whose whole point is that the user has not decided yet.
    private func refreshAvailableCalendars() async {
        let session = calendarSession
        guard session.isLoadingCalendars == false else { return }

        session.beginLoadingCalendars()
        let loaded = await powerUps.availableCalendars()
        session.finishLoadingCalendars(loaded)

        // A non-empty list is proof of read access — the integration service
        // clears its calendars and returns early in every other state. It is the
        // only status this connector can read back today, and it is what stops
        // somebody who allowed Calendar months ago from being asked again on
        // their first run of this flow. An *empty* list proves nothing (no
        // access, no calendars, and a slow fetch look identical), so it never
        // downgrades an answer.
        if loaded.isEmpty == false, session.authorization.isAuthorizedForRead == false {
            recordCalendarOutcome(granted: true)
        }
    }

    // MARK: - Selection

    /// Nothing is preselected, and the empty selection is a real state.
    ///
    /// v5 ticked every available calendar the moment access was granted, which
    /// quietly opted people into showing a shared family calendar, a colleague's
    /// availability, and every subscribed holiday feed in a planning surface
    /// they had not seen yet. `FilterCalendarEventsUseCase` reads an empty
    /// selection as *no calendars* rather than *all of them*, so the honest
    /// alternative is to require one deliberate tap.
    func toggleCalendarSelection(_ id: String) {
        var ids = draft.selectedCalendarIDs
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
        mutateDraft { state in state.selectedCalendarIDs = ids }
        feedback.selection()
    }

    // MARK: - Dock seam
    //
    // The shell owns one dock for both phases. These five members are what it
    // reads for this connector, so the primary's meaning can change with the
    // stage without the shell learning anything about calendars.

    var calendarPrimaryTitle: String {
        switch calendarStage {
        case .primer: "Connect Calendar"
        case .chooser: "Use selected calendars"
        // Named rather than "Continue", because the next thing is another ask
        // and the user is entitled to see it coming. Derived from the connector
        // order so it cannot drift if that order changes.
        case .proof: "Continue to \(LifeWeavePowerUpStep.calendar.next?.spokenName ?? "the next step")"
        // Write-only is not a refusal, so asking is still on the table.
        case .recovery(.writeOnly): "Ask for full access"
        case .recovery: "Continue without Calendar"
        }
    }

    var calendarSecondaryTitle: String? {
        switch calendarStage {
        // Skipping is always these two words, and it is the only way past this
        // connector without connecting. The primary never means "skip".
        case .primer, .chooser, .recovery(.writeOnly): "Not now"
        // Nothing left to decline: the recovery primary already continues
        // without Calendar, and the proof's primary moves on.
        case .proof, .recovery: nil
        }
    }

    var isCalendarPrimaryDisabled: Bool {
        switch calendarStage {
        // A decided product call. Granting access and connecting nothing
        // produces an empty schedule everywhere — Home, Plan, and the day EVA
        // reasons over — which reads as a broken calendar rather than as a
        // choice. Skipping is what "Not now" is for.
        case .chooser: draft.selectedCalendarIDs.isEmpty
        case .primer, .proof, .recovery: false
        }
    }

    func performCalendarPrimary() async {
        switch calendarStage {
        case .primer:
            await requestCalendarAccess()
        case .chooser:
            await commitCalendarSelection()
        case .proof:
            advancePowerUp()
        // User-initiated, from a state that is not a denial. Nothing in this
        // connector re-requests on its own.
        case .recovery(.writeOnly):
            await requestCalendarAccess()
        case .recovery:
            advancePowerUp()
        }
    }

    func performCalendarSecondary() {
        deferCurrentPowerUp()
    }

    /// The one sanctioned way to the app's Settings page, reused rather than
    /// re-rolled — this connector is the fifth place that would have written the
    /// same `openSettingsURLString` dance.
    func openCalendarSystemSettings() {
        PermissionRecoveryCard.openSystemSettings()
    }

    // MARK: - Internals

    /// What the journey has already recorded the system saying.
    ///
    /// Granted and denied are separate lists precisely so this cannot invent a
    /// third state: an unanswered connector is `notDetermined`, not "denied by
    /// omission".
    private func recordedCalendarAuthorization() -> CalendarAuthorizationStatus {
        if draft.grantedPermissionIDs.contains(PermissionKind.calendar.id) { return .authorized }
        if draft.deniedPermissionIDs.contains(PermissionKind.calendar.id) { return .denied }
        return .notDetermined
    }

    private func requestCalendarAccess() async {
        let session = calendarSession
        guard session.beginAccessRequestIfIdle() else { return }
        defer { session.endAccessRequest() }

        PermissionPromptState.recordRequested(.calendar)
        let granted = await powerUps.requestCalendarAccess()
        recordCalendarOutcome(granted: granted)

        if granted {
            feedback.light()
            await refreshAvailableCalendars()
        }
    }

    /// Records what the system actually answered, in the same shape the rest of
    /// onboarding uses, so a refusal in the system sheet can never render as a
    /// connected calendar.
    private func recordCalendarOutcome(granted: Bool) {
        let id = PermissionKind.calendar.id
        mutateDraft { state in
            state.grantedPermissionIDs.removeAll { $0 == id }
            state.deniedPermissionIDs.removeAll { $0 == id }
            if granted {
                state.grantedPermissionIDs.append(id)
            } else {
                state.deniedPermissionIDs.append(id)
            }
        }
        calendarSession.updateAuthorization(granted ? .authorized : .denied)
    }

    /// Pushing the scope to the service is what makes it real. The draft keeps a
    /// record of the choice; it is not what any planning surface reads.
    private func commitCalendarSelection() async {
        // Reconciled against what the device actually has, the same way the
        // service reconciles on refresh — a calendar that disappeared between
        // the fetch and the tap must not be committed as a scope.
        let available = Set(calendarSession.calendars.map(\.id))
        let ids = draft.selectedCalendarIDs.filter { available.contains($0) }
        guard ids.isEmpty == false else {
            // Everything chosen has disappeared from the device since the list
            // was read. Write the reconciliation back and reload, so the chooser
            // says so — rather than leaving a primary that does nothing.
            mutateDraft { state in state.selectedCalendarIDs = ids }
            await refreshAvailableCalendars()
            return
        }

        await powerUps.updateSelectedCalendarIDs(ids)
        calendarSession.markSelectionCommitted()
        mutateDraft { state in state.selectedCalendarIDs = ids }
        feedback.successSignature()

        await readCalendarProof()
    }

    /// Reads back what the chosen calendars actually contain.
    ///
    /// Bounded, and deliberately not optimistic. The service reloads its events
    /// off a preferences notification, so the count is not there the instant the
    /// scope is pushed; a zero taken too early would be shown to the user as
    /// "nothing on your calendar", which is a lie about their day rather than a
    /// slow read. An unfinished read ends with no number at all instead.
    private func readCalendarProof() async {
        let session = calendarSession
        session.beginProofRead()

        var count: Int?
        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline, Task.isCancelled == false {
            let probe = await powerUps.upcomingEventCount()
            count = probe
            if let probe, probe > 0 { break }
            try? await Task.sleep(for: .milliseconds(250))
        }

        session.finishProofRead(eventCount: count)
    }
}
