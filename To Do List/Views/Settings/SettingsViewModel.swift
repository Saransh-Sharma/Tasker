import Foundation
import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Notifications

    @Published var preferences: TaskerNotificationPreferences
    @Published var workspacePreferences: TaskerWorkspacePreferences
    @Published var permissionStatus: TaskerNotificationAuthorizationStatus = .notDetermined

    // MARK: - LLM

    @Published var currentModelDisplayName: String
    @Published var decorativeButtonEffectsEnabled: Bool
    @Published var homeBackdropNoiseAmount: Int
    @Published var calendarAuthorizationStatus: TaskerCalendarAuthorizationStatus = .notDetermined
    @Published var selectedCalendarIDs: [String] = []
    @Published var availableCalendarCount: Int = 0
    @Published var includeDeclinedCalendarEvents: Bool = false
    @Published var includeCanceledCalendarEvents: Bool = false
    @Published var includeAllDayInAgenda: Bool = true
    @Published var includeAllDayInBusyStrip: Bool = false

    // MARK: - Navigation callbacks (set by SettingsPageViewController)

    var onNavigateToProjects: (() -> Void)?
    var onNavigateToLifeManagement: (() -> Void)?
    var onNavigateToAISettings: (() -> Void)?
    var onNavigateToChats: (() -> Void)?
    var onNavigateToModels: (() -> Void)?
    var onRestartOnboarding: (() -> Void)?
    var onOpenCalendarChooser: (() -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - Dependencies

    private let notificationPreferencesStore: TaskerNotificationPreferencesStore
    private let workspacePreferencesStore: TaskerWorkspacePreferencesStore
    private let calendarIntegrationService: CalendarIntegrationService?
    private let appManager: AppManager
    private var cancellables: Set<AnyCancellable> = []
    private var hasCustomizedAppearance: Bool {
        decorativeButtonEffectsEnabled || homeBackdropNoiseAmount != V2FeatureFlags.defaultHomeBackdropNoiseAmount
    }

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
        "\(enabledNotificationCount) on"
    }

    var notificationStatusLabel: String {
        switch permissionStatus {
        case .authorized, .provisional, .ephemeral:
            return notificationEnabledSummary
        case .notDetermined:
            return notificationEnabledSummary
        case .denied:
            return "Off"
        }
    }

    var notificationStatusDetail: String {
        "Control reminders, summaries, and quiet hours."
    }

    var notificationTone: TaskerSettingsTone {
        switch permissionStatus {
        case .authorized, .provisional, .ephemeral:
            return .success
        case .notDetermined:
            return .warning
        case .denied:
            return .danger
        }
    }

    var memoryItemCount: Int {
        let memory = LLMPersonalMemoryDefaultsStore.load()
        return LLMPersonalMemorySection.allCases.reduce(0) { partial, section in
            partial + memory.entries(for: section).filter { $0.text.isEmpty == false }.count
        }
    }

    var memorySummary: String {
        memoryItemCount == 0 ? "Memory empty" : "\(memoryItemCount) saved"
    }

    var aiAssistantSummary: String {
        currentModelDisplayName.isEmpty ? "No model" : currentModelDisplayName
    }

    var modelsSummary: String {
        currentModelDisplayName.isEmpty ? "System default" : currentModelDisplayName
    }

    var aiAssistantDetail: String {
        "Manage chat behavior, models, memory, and privacy."
    }

    var setupStatusLabel: String {
        hasCustomizedAppearance ? "Customized" : "Default"
    }

    var setupStatusDetail: String {
        hasCustomizedAppearance
            ? "Appearance effects are customized."
            : "Using the default appearance settings."
    }

    var onboardingSummary: String {
        "Replay onboarding any time."
    }

    var dueSoonLeadTimeSummary: String {
        let minutes = preferences.dueSoonLeadMinutes

        switch minutes {
        case 15:
            return "15 min"
        case 30:
            return "30 min"
        case 45:
            return "45 min"
        case 60:
            return "1 hr"
        case 90:
            return "1.5 hr"
        case 120:
            return "2 hr"
        default:
            return "\(minutes) min"
        }
    }

    var morningAgendaSummary: String {
        formattedTime(hour: preferences.morningHour, minute: preferences.morningMinute)
    }

    var nightlyRetrospectiveSummary: String {
        formattedTime(hour: preferences.nightlyHour, minute: preferences.nightlyMinute)
    }

    var quietHoursSummary: String {
        guard preferences.quietHoursEnabled else { return "Off" }
        return "\(formattedTime(hour: preferences.quietHoursStartHour, minute: preferences.quietHoursStartMinute))–\(formattedTime(hour: preferences.quietHoursEndHour, minute: preferences.quietHoursEndMinute))"
    }

    var weekStartsOnSummary: String {
        workspacePreferences.weekStartsOn.displayTitle
    }

    var calendarStatusSummary: String {
        if calendarAuthorizationStatus.isAuthorizedForRead == false {
            return String(localized: "Permission required")
        }
        if selectedCalendarIDs.isEmpty {
            return String(localized: "No calendars selected")
        }
        return String(localized: "\(selectedCalendarIDs.count) selected")
    }

    var calendarStatusDetail: String {
        String(localized: "Read-only schedule context for Home and task fit hints.")
    }

    var calendarAccessStatusLabel: String {
        switch calendarAuthorizationStatus {
        case .authorized:
            return String(localized: "Connected")
        case .notDetermined:
            return String(localized: "Not requested")
        case .denied:
            return String(localized: "Denied")
        case .restricted:
            return String(localized: "Restricted")
        case .writeOnly:
            return String(localized: "Write-only")
        }
    }

    var calendarAccessSubtitle: String {
        switch calendarAuthorizationStatus {
        case .authorized:
            return String(localized: "Tasker can read your selected calendars.")
        case .notDetermined:
            return String(localized: "Grant access to show schedule context in Home.")
        case .denied:
            return String(localized: "Calendar access is off. Open Settings to re-enable it.")
        case .restricted:
            return String(localized: "Calendar access is restricted by system policy.")
        case .writeOnly:
            return String(localized: "Tasker has write-only access. Open Settings to allow read access.")
        }
    }

    var calendarAccessTone: TaskerSettingsTone {
        switch calendarAuthorizationStatus {
        case .authorized:
            return .success
        case .notDetermined, .writeOnly:
            return .warning
        case .denied, .restricted:
            return .danger
        }
    }

    // MARK: - Init

    init(
        appManager: AppManager = AppManager(),
        notificationPreferencesStore: TaskerNotificationPreferencesStore = .shared,
        workspacePreferencesStore: TaskerWorkspacePreferencesStore = .shared,
        calendarIntegrationService: CalendarIntegrationService? = nil
    ) {
        self.appManager = appManager
        self.notificationPreferencesStore = notificationPreferencesStore
        self.workspacePreferencesStore = workspacePreferencesStore
        self.calendarIntegrationService = calendarIntegrationService
        self.preferences = notificationPreferencesStore.load()
        self.workspacePreferences = workspacePreferencesStore.load()
        self.currentModelDisplayName = appManager.compactModelDisplayName(appManager.currentModelName ?? "")
        self.decorativeButtonEffectsEnabled = V2FeatureFlags.userDecorativeCTAEffectsEnabled
        self.homeBackdropNoiseAmount = V2FeatureFlags.homeBackdropNoiseAmount
        bindCalendarService()
    }

    // MARK: - Notification Toggles

    func togglePreference(_ keyPath: WritableKeyPath<TaskerNotificationPreferences, Bool>, value: Bool) {
        preferences[keyPath: keyPath] = value
        saveAndReconcile()
        TaskerFeedback.selection()
    }

    func updateDueSoonLeadMinutes(_ minutes: Int) {
        preferences.dueSoonLeadMinutes = minutes
        saveAndReconcile()
        TaskerFeedback.selection()
    }

    func updateWeekStartsOn(_ weekday: Weekday) {
        guard workspacePreferences.weekStartsOn != weekday else { return }
        workspacePreferences.weekStartsOn = weekday
        workspacePreferencesStore.save(workspacePreferences)
    }

    func setDecorativeButtonEffectsEnabled(_ isEnabled: Bool) {
        decorativeButtonEffectsEnabled = isEnabled
        V2FeatureFlags.userDecorativeCTAEffectsEnabled = isEnabled
        TaskerFeedback.selection()
    }

    func setHomeBackdropNoiseAmount(_ amount: Int) {
        let clampedAmount = V2FeatureFlags.clampedHomeBackdropNoiseAmount(amount)
        homeBackdropNoiseAmount = clampedAmount
        V2FeatureFlags.homeBackdropNoiseAmount = clampedAmount
    }

    // MARK: - Permission

    var isPermissionDenied: Bool { permissionStatus == .denied }
    var isPermissionNotDetermined: Bool { permissionStatus == .notDetermined }
    var isPermissionGranted: Bool {
        permissionStatus == .authorized || permissionStatus == .provisional || permissionStatus == .ephemeral
    }
    var showPermissionBanner: Bool { !isPermissionGranted }

    func refreshPermissionStatus() {
        guard let service = EnhancedDependencyContainer.shared.notificationService else {
            permissionStatus = .notDetermined
            return
        }
        service.fetchAuthorizationStatus { [weak self] status in
            DispatchQueue.main.async {
                self?.permissionStatus = status
            }
        }
    }

    func requestNotificationPermission() {
        guard let service = EnhancedDependencyContainer.shared.notificationService else { return }
        TaskerFeedback.medium()
        switch permissionStatus {
        case .denied:
            guard let url = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(url) else { return }
            UIApplication.shared.open(url)
        case .notDetermined:
            service.requestPermission { [weak self] granted in
                DispatchQueue.main.async {
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
        homeBackdropNoiseAmount = V2FeatureFlags.homeBackdropNoiseAmount
        refreshPermissionStatus()
        refreshCalendarState()
    }

    func restartOnboarding() {
        TaskerFeedback.medium()
        onRestartOnboarding?()
    }

    private func saveAndReconcile() {
        notificationPreferencesStore.save(preferences)
        reconcileNotifications(reason: "settings_changed")
    }

    func requestCalendarPermission() {
        TaskerFeedback.medium()
        _ = calendarIntegrationService?.performAccessAction(openSystemSettings: openSystemSettings)
    }

    func openCalendarChooser() {
        guard calendarAuthorizationStatus.isAuthorizedForRead else {
            requestCalendarPermission()
            return
        }
        onOpenCalendarChooser?()
    }

    func setIncludeDeclinedCalendarEvents(_ include: Bool) {
        includeDeclinedCalendarEvents = include
        calendarIntegrationService?.setIncludeDeclined(include)
    }

    func setIncludeCanceledCalendarEvents(_ include: Bool) {
        includeCanceledCalendarEvents = include
        calendarIntegrationService?.setIncludeCanceled(include)
    }

    func setIncludeAllDayInAgenda(_ include: Bool) {
        includeAllDayInAgenda = include
        calendarIntegrationService?.setIncludeAllDayInAgenda(include)
    }

    func setIncludeAllDayInBusyStrip(_ include: Bool) {
        includeAllDayInBusyStrip = include
        calendarIntegrationService?.setIncludeAllDayInBusyStrip(include)
    }

    private func bindCalendarService() {
        calendarIntegrationService?.$snapshot
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
            }
            .store(in: &cancellables)
    }

    private func refreshCalendarState() {
        guard let calendarIntegrationService else {
            calendarAuthorizationStatus = .denied
            selectedCalendarIDs = []
            availableCalendarCount = 0
            includeDeclinedCalendarEvents = false
            includeCanceledCalendarEvents = false
            includeAllDayInAgenda = true
            includeAllDayInBusyStrip = false
            return
        }
        let snapshot = calendarIntegrationService.snapshot
        calendarAuthorizationStatus = snapshot.authorizationStatus
        selectedCalendarIDs = snapshot.selectedCalendarIDs
        availableCalendarCount = snapshot.availableCalendars.count
        includeDeclinedCalendarEvents = snapshot.includeDeclined
        includeCanceledCalendarEvents = snapshot.includeCanceled
        includeAllDayInAgenda = snapshot.includeAllDayInAgenda
        includeAllDayInBusyStrip = snapshot.includeAllDayInBusyStrip
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

    func formattedTime(hour: Int, minute: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
