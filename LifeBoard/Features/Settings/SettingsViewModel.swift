import Foundation
import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject, Sendable {

    // MARK: - Notifications

    @Published var preferences: NotificationPreferences
    @Published var workspacePreferences: WorkspacePreferences
    @Published var permissionStatus: NotificationAuthorizationStatus = .notDetermined

    // MARK: - LLM

    @Published var currentModelDisplayName: String
    @Published var decorativeButtonEffectsEnabled: Bool
    @Published var calendarAuthorizationStatus: CalendarAuthorizationStatus = .notDetermined
    @Published var selectedCalendarIDs: [String] = []
    @Published var availableCalendarCount: Int = 0
    @Published var includeDeclinedCalendarEvents: Bool = false
    @Published var includeCanceledCalendarEvents: Bool = false
    @Published var includeAllDayInAgenda: Bool = true
    @Published var includeAllDayInBusyStrip: Bool = false
    @Published var showCalendarEventsInTimeline: Bool = true

    // MARK: - Navigation callbacks (set by SettingsPageViewController)

    var onNavigateToLifeManagement: (() -> Void)?
    /// Set only by the Life OS shell, which owns the daypart, comfort-profile
    /// and rendering-tier preferences. The legacy UIKit host leaves this nil
    /// and the row hides itself.
    var onNavigateToAppearance: (() -> Void)?
    var onNavigateToAISettings: (() -> Void)?
    var onNavigateToChats: (() -> Void)?
    var onNavigateToModels: (() -> Void)?
    var onRestartOnboarding: (() -> Void)?
    var onOpenCalendarChooser: (() -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - Dependencies

    private let notificationPreferencesStore: NotificationPreferencesStore
    private let workspacePreferencesStore: WorkspacePreferencesStore
    private let calendarIntegrationService: CalendarIntegrationService
    private let appManager: AppManager
    /// Resolved once at construction, via `SettingsServices`, rather than read
    /// from the global container at each call site.
    ///
    /// The architecture guardrail forbids the view layer reaching into a
    /// singleton container: it hides what this type actually needs and makes it
    /// untestable without standing up global state. Kept optional because the
    /// service genuinely may not exist yet during early launch — the call sites
    /// already handled that.
    private let notificationService: (any NotificationServiceProtocol)?
    private var cancellables: Set<AnyCancellable> = []
    private var hasCustomizedAppearance: Bool {
        decorativeButtonEffectsEnabled
    }

    var calendarService: CalendarIntegrationService { calendarIntegrationService }
    var assistantAppManager: AppManager { appManager }

    // MARK: - Morning / Nightly times as Date for DatePicker binding

    var morningTime: Date {
        get { dateFrom(hour: preferences.morningHour, minute: preferences.morningMinute) }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            preferences.morningHour = comps.hour ?? preferences.morningHour
            preferences.morningMinute = comps.minute ?? preferences.morningMinute
            saveAndReconcile()
        }
    }

    var nightlyTime: Date {
        get { dateFrom(hour: preferences.nightlyHour, minute: preferences.nightlyMinute) }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            preferences.nightlyHour = comps.hour ?? preferences.nightlyHour
            preferences.nightlyMinute = comps.minute ?? preferences.nightlyMinute
            saveAndReconcile()
        }
    }

    var quietHoursStartTime: Date {
        get { dateFrom(hour: preferences.quietHoursStartHour, minute: preferences.quietHoursStartMinute) }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            preferences.quietHoursStartHour = comps.hour ?? preferences.quietHoursStartHour
            preferences.quietHoursStartMinute = comps.minute ?? preferences.quietHoursStartMinute
            saveAndReconcile()
        }
    }

    var quietHoursEndTime: Date {
        get { dateFrom(hour: preferences.quietHoursEndHour, minute: preferences.quietHoursEndMinute) }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            preferences.quietHoursEndHour = comps.hour ?? preferences.quietHoursEndHour
            preferences.quietHoursEndMinute = comps.minute ?? preferences.quietHoursEndMinute
            saveAndReconcile()
        }
    }

    var timelineRiseAndShineTime: Date {
        get {
            dateFrom(
                hour: workspacePreferences.timelineRiseAndShineHour,
                minute: workspacePreferences.timelineRiseAndShineMinute
            )
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            workspacePreferences.timelineRiseAndShineHour = comps.hour ?? workspacePreferences.timelineRiseAndShineHour
            workspacePreferences.timelineRiseAndShineMinute = comps.minute ?? workspacePreferences.timelineRiseAndShineMinute
            saveWorkspacePreferences()
        }
    }

    var timelineWindDownTime: Date {
        get {
            dateFrom(
                hour: workspacePreferences.timelineWindDownHour,
                minute: workspacePreferences.timelineWindDownMinute
            )
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            workspacePreferences.timelineWindDownHour = comps.hour ?? workspacePreferences.timelineWindDownHour
            workspacePreferences.timelineWindDownMinute = comps.minute ?? workspacePreferences.timelineWindDownMinute
            saveWorkspacePreferences()
        }
    }

    // MARK: - Version

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    var enabledNotificationCount: Int {
        [
            preferences.taskRemindersEnabled,
            preferences.dueSoonEnabled,
            preferences.overdueNudgesEnabled,
            preferences.morningAgendaEnabled,
            preferences.nightlyRetrospectiveEnabled
        ]
        .filter { $0 }
        .count
    }

    var notificationEnabledSummary: String {
        String(localized: "\(enabledNotificationCount) on")
    }

    var notificationStatusLabel: String {
        switch permissionStatus {
        case .authorized, .provisional, .ephemeral:
            return notificationEnabledSummary
        case .notDetermined:
            return notificationEnabledSummary
        case .denied:
            return String(localized: "Off")
        }
    }

    var notificationStatusDetail: String {
        String(localized: "Reminders and summaries")
    }

    var notificationTone: SettingsTone {
        switch permissionStatus {
        case .authorized, .provisional, .ephemeral:
            return .success
        case .notDetermined:
            return .warning
        case .denied:
            // Off is a choice the person made, not an error.
            return .neutral
        }
    }

    var memoryItemCount: Int {
        let memory = LLMPersonalMemoryDefaultsStore.load()
        return LLMPersonalMemorySection.allCases.reduce(0) { partial, section in
            partial + memory.entries(for: section).filter { $0.text.isEmpty == false }.count
        }
    }

    var memorySummary: String {
        memoryItemCount == 0 ? String(localized: "No memories") : String(localized: "\(memoryItemCount) saved")
    }

    var aiAssistantSummary: String {
        currentModelDisplayName.isEmpty ? String(localized: "No model") : currentModelDisplayName
    }

    var selectedMascotID: AssistantMascotID {
        workspacePreferences.chiefOfStaffMascotID
    }

    var selectedMascotPersona: AssistantMascotPersona {
        AssistantMascotPersona.persona(for: selectedMascotID)
    }

    var chiefOfStaffSummary: String {
        selectedMascotPersona.displayName
    }

    var modelsSummary: String {
        currentModelDisplayName.isEmpty ? String(localized: "Default") : currentModelDisplayName
    }

    var aiAssistantDetail: String {
        String(localized: "Chat, models, memory and privacy")
    }

    var setupStatusLabel: String {
        hasCustomizedAppearance ? String(localized: "Customized") : String(localized: "Default")
    }

    var setupStatusDetail: String {
        hasCustomizedAppearance
            ? String(localized: "Custom appearance")
            : String(localized: "Default appearance")
    }

    var onboardingSummary: String {
        String(localized: "Replay setup")
    }

    var dueSoonLeadTimeSummary: String {
        let minutes = preferences.dueSoonLeadMinutes

        switch minutes {
        case 60:
            return String(localized: "1 hr")
        case 120:
            return String(localized: "2 hr")
        default:
            return String(localized: "\(minutes) min")
        }
    }

    var morningAgendaSummary: String {
        formattedTime(hour: preferences.morningHour, minute: preferences.morningMinute)
    }

    var nightlyRetrospectiveSummary: String {
        formattedTime(hour: preferences.nightlyHour, minute: preferences.nightlyMinute)
    }

    var quietHoursSummary: String {
        guard preferences.quietHoursEnabled else { return String(localized: "Off") }
        return "\(formattedTime(hour: preferences.quietHoursStartHour, minute: preferences.quietHoursStartMinute))–\(formattedTime(hour: preferences.quietHoursEndHour, minute: preferences.quietHoursEndMinute))"
    }

    var timelineRiseAndShineSummary: String {
        formattedTime(
            hour: workspacePreferences.timelineRiseAndShineHour,
            minute: workspacePreferences.timelineRiseAndShineMinute
        )
    }

    var timelineWindDownSummary: String {
        let time = formattedTime(
            hour: workspacePreferences.timelineWindDownHour,
            minute: workspacePreferences.timelineWindDownMinute
        )
        guard timelineWindDownOccursNextDay else { return time }
        return String(localized: "\(time) next day")
    }

    var weekStartsOnSummary: String {
        workspacePreferences.weekStartsOn.displayTitle
    }

    var calendarStatusSummary: String {
        if calendarAuthorizationStatus.isAuthorizedForRead == false {
            return String(localized: "Off")
        }
        if selectedCalendarIDs.isEmpty {
            return String(localized: "None")
        }
        return String(localized: "\(selectedCalendarIDs.count) selected")
    }

    var calendarStatusDetail: String {
        String(localized: "Read-only. Events show next to your tasks.")
    }

    var calendarAccessStatusLabel: String {
        let accessAction = calendarIntegrationService.accessAction(for: calendarAuthorizationStatus)
        switch calendarAuthorizationStatus {
        case .authorized:
            return String(localized: "On")
        case .notDetermined:
            return String(localized: "Off")
        case .denied:
            switch accessAction {
            case .requestPermission:
                return String(localized: "Off")
            default:
                return String(localized: "Open Settings")
            }
        case .restricted:
            return String(localized: "Restricted")
        case .writeOnly:
            return String(localized: "Limited")
        }
    }

    var calendarAccessSubtitle: String {
        switch calendarAuthorizationStatus {
        case .authorized:
            return ""
        case .notDetermined:
            return String(localized: "Shows events next to your tasks.")
        case .denied:
            return String(localized: "Calendar access is off. Turn it on in Settings.")
        case .restricted:
            return String(localized: "Blocked by a device restriction.")
        case .writeOnly:
            return String(localized: "Needs full access to read events.")
        }
    }

    var calendarAccessTone: SettingsTone {
        let accessAction = calendarIntegrationService.accessAction(for: calendarAuthorizationStatus)
        switch calendarAuthorizationStatus {
        case .authorized:
            return .success
        case .notDetermined, .writeOnly:
            return .warning
        case .denied:
            return accessAction == .requestPermission ? .warning : .danger
        case .restricted:
            return .danger
        }
    }

    // MARK: - Init

    init(
        appManager: AppManager = AppManager(),
        notificationPreferencesStore: NotificationPreferencesStore = .shared,
        workspacePreferencesStore: WorkspacePreferencesStore = .shared,
        calendarIntegrationService: CalendarIntegrationService,
        notificationService: (any NotificationServiceProtocol)? = SettingsServices.notificationService
    ) {
        self.appManager = appManager
        self.notificationService = notificationService
        self.notificationPreferencesStore = notificationPreferencesStore
        self.workspacePreferencesStore = workspacePreferencesStore
        self.calendarIntegrationService = calendarIntegrationService
        self.preferences = notificationPreferencesStore.load()
        let loadedWorkspacePreferences = workspacePreferencesStore.load()
        self.workspacePreferences = loadedWorkspacePreferences
        self.currentModelDisplayName = appManager.compactModelDisplayName(appManager.currentModelName ?? "")
        self.decorativeButtonEffectsEnabled = V2FeatureFlags.userDecorativeCTAEffectsEnabled
        self.showCalendarEventsInTimeline = loadedWorkspacePreferences.showCalendarEventsInTimeline
        bindCalendarService()
    }

    // MARK: - Notification Toggles

    func togglePreference(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>, value: Bool) {
        preferences[keyPath: keyPath] = value
        saveAndReconcile()
        Haptic.pick.play()
    }

    func updateDueSoonLeadMinutes(_ minutes: Int) {
        preferences.dueSoonLeadMinutes = minutes
        saveAndReconcile()
        Haptic.pick.play()
    }

    func updateWeekStartsOn(_ weekday: Weekday) {
        guard workspacePreferences.weekStartsOn != weekday else { return }
        workspacePreferences.weekStartsOn = weekday
        saveWorkspacePreferences()
        Haptic.pick.play()
    }

    func setDecorativeButtonEffectsEnabled(_ isEnabled: Bool) {
        decorativeButtonEffectsEnabled = isEnabled
        V2FeatureFlags.userDecorativeCTAEffectsEnabled = isEnabled
        Haptic.pick.play()
    }

    // MARK: - Permission

    var isPermissionDenied: Bool { permissionStatus == .denied }
    var isPermissionNotDetermined: Bool { permissionStatus == .notDetermined }
    var isPermissionGranted: Bool {
        permissionStatus == .authorized || permissionStatus == .provisional || permissionStatus == .ephemeral
    }
    var showPermissionBanner: Bool { !isPermissionGranted }

    func refreshPermissionStatus() {
        guard let service = notificationService else {
            permissionStatus = .notDetermined
            return
        }
        service.fetchAuthorizationStatus { [weak self] status in
            Task { @MainActor in
                self?.permissionStatus = status
            }
        }
    }

    func requestNotificationPermission() {
        guard let service = notificationService else { return }
        Haptic.lift.play()
        switch permissionStatus {
        case .denied:
            guard let url = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(url) else { return }
            UIApplication.shared.open(url)
        case .notDetermined:
            service.requestPermission { [weak self] granted in
                Task { @MainActor in
                    self?.refreshPermissionStatus()
                    if granted {
                        self?.reconcileNotifications(reason: "settings_permission_granted")
                    }
                }
            }
        default:
            break
        }
    }

    // MARK: - Helpers

    func reload() {
        preferences = notificationPreferencesStore.load()
        workspacePreferences = workspacePreferencesStore.load()
        currentModelDisplayName = appManager.compactModelDisplayName(appManager.currentModelName ?? "")
        decorativeButtonEffectsEnabled = V2FeatureFlags.userDecorativeCTAEffectsEnabled
        refreshPermissionStatus()
        refreshCalendarState()
    }

    func restartOnboarding() {
        Haptic.lift.play()
        if let onRestartOnboarding {
            onRestartOnboarding()
        } else {
            NotificationCenter.default.post(name: .lifeboardStartOnboardingRequested, object: nil)
        }
    }

    private func saveAndReconcile() {
        notificationPreferencesStore.save(preferences)
        reconcileNotifications(reason: "settings_changed")
    }

    func requestCalendarPermission() {
        requestCalendarPermission { _ in }
    }

    func requestCalendarPermission(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        Haptic.lift.play()
        _ = calendarIntegrationService.performAccessAction(
            source: "settings",
            openSystemSettings: openSystemSettings
        ) { [weak self] granted in
            Task { @MainActor in
                self?.refreshCalendarState()
                completion(granted)
            }
        }
    }

    #if DEBUG
    func copyCalendarDiagnostics() {
        UIPasteboard.general.string = CalendarDiagnosticsStore.shared.recentEntriesText(limit: 20)
        Haptic.pick.play()
    }
    #endif

    /// Content-free recovery diagnostics.
    ///
    /// Ships in Release, unlike the calendar diagnostics above, because the
    /// people who need it most are users in a broken state rather than
    /// developers. That makes the redaction contract load-bearing: operation
    /// names, modes and counts only — never titles, entries, health values,
    /// search terms or attachment paths. Anything added here has to stay safe
    /// to paste into a support email.
    func copyRecoveryDiagnostics() {
        let mode = AppDelegate.persistentSyncModeSnapshot()
        let lines = [
            "lifeboard.recovery.diagnostics",
            "app_version=\(appVersion) build=\(buildNumber)",
            "store_mode=\(mode.modeName)",
            "store_reason=\(mode.reason)",
            "generated_at=\(ISO8601DateFormatter().string(from: Date()))"
        ]
        UIPasteboard.general.string = lines.joined(separator: "\n")
        Haptic.pick.play()
    }

    func openCalendarChooser() {
        guard calendarAuthorizationStatus.isAuthorizedForRead else {
            requestCalendarPermission()
            return
        }
        onOpenCalendarChooser?()
    }

    func updateSelectedCalendarIDs(_ selectedIDs: [String]) {
        calendarIntegrationService.updateSelectedCalendarIDs(selectedIDs)
    }

    func setIncludeDeclinedCalendarEvents(_ include: Bool) {
        includeDeclinedCalendarEvents = include
        calendarIntegrationService.setIncludeDeclined(include)
    }

    func setIncludeCanceledCalendarEvents(_ include: Bool) {
        includeCanceledCalendarEvents = include
        calendarIntegrationService.setIncludeCanceled(include)
    }

    func setIncludeAllDayInAgenda(_ include: Bool) {
        includeAllDayInAgenda = include
        calendarIntegrationService.setIncludeAllDayInAgenda(include)
    }

    func setIncludeAllDayInBusyStrip(_ include: Bool) {
        includeAllDayInBusyStrip = include
        calendarIntegrationService.setIncludeAllDayInBusyStrip(include)
    }

    func setShowCalendarEventsInTimeline(_ show: Bool) {
        guard workspacePreferences.showCalendarEventsInTimeline != show else { return }
        showCalendarEventsInTimeline = show
        workspacePreferences.showCalendarEventsInTimeline = show
        saveWorkspacePreferences()
        Haptic.pick.play()
    }

    func selectChiefOfStaffMascot(_ id: AssistantMascotID) {
        guard workspacePreferences.chiefOfStaffMascotID != id else { return }
        workspacePreferences.chiefOfStaffMascotID = id
        saveWorkspacePreferences()
        Haptic.pick.play()
    }

    func commitTimelineAnchorDraft(_ draft: TimelineAnchorDraft) {
        guard draft.hasChanges else { return }
        draft.apply(to: &workspacePreferences)
        saveWorkspacePreferences()
    }

    private func bindCalendarService() {
        calendarIntegrationService.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                self.calendarAuthorizationStatus = snapshot.authorizationStatus
                self.selectedCalendarIDs = snapshot.selectedCalendarIDs
                self.availableCalendarCount = snapshot.availableCalendars.count
                self.includeDeclinedCalendarEvents = snapshot.includeDeclined
                self.includeCanceledCalendarEvents = snapshot.includeCanceled
                self.includeAllDayInAgenda = snapshot.includeAllDayInAgenda
                self.includeAllDayInBusyStrip = snapshot.includeAllDayInBusyStrip
                self.workspacePreferences = self.workspacePreferencesStore.load()
                self.showCalendarEventsInTimeline = self.workspacePreferences.showCalendarEventsInTimeline
            }
            .store(in: &cancellables)
    }

    private func refreshCalendarState() {
        workspacePreferences = workspacePreferencesStore.load()
        let snapshot = calendarIntegrationService.snapshot
        calendarAuthorizationStatus = snapshot.authorizationStatus
        selectedCalendarIDs = snapshot.selectedCalendarIDs
        availableCalendarCount = snapshot.availableCalendars.count
        includeDeclinedCalendarEvents = snapshot.includeDeclined
        includeCanceledCalendarEvents = snapshot.includeCanceled
        includeAllDayInAgenda = snapshot.includeAllDayInAgenda
        includeAllDayInBusyStrip = snapshot.includeAllDayInBusyStrip
        showCalendarEventsInTimeline = workspacePreferences.showCalendarEventsInTimeline
    }

    private func saveWorkspacePreferences() {
        workspacePreferencesStore.save(workspacePreferences)
    }

    private func reconcileNotifications(reason: String) {
        (UIApplication.shared.delegate as? AppDelegate)?.reconcileNotifications(reason: reason)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    private func dateFrom(hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }
}
