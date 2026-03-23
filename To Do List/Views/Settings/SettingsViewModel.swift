import Foundation
import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Notifications

    @Published var preferences: TaskerNotificationPreferences
    @Published var permissionStatus: TaskerNotificationAuthorizationStatus = .notDetermined

    // MARK: - LLM

    @Published var currentModelDisplayName: String
    @Published var decorativeButtonEffectsEnabled: Bool

    // MARK: - Navigation callbacks (set by SettingsPageViewController)

    var onNavigateToProjects: (() -> Void)?
    var onNavigateToLifeManagement: (() -> Void)?
    var onNavigateToAISettings: (() -> Void)?
    var onNavigateToChats: (() -> Void)?
    var onNavigateToModels: (() -> Void)?
    var onRestartOnboarding: (() -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - Dependencies

    private let notificationPreferencesStore: TaskerNotificationPreferencesStore
    private let appManager: AppManager

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
        decorativeButtonEffectsEnabled ? "Customized" : "Default"
    }

    var setupStatusDetail: String {
        decorativeButtonEffectsEnabled
            ? "Decorative button effects are enabled."
            : "Using the default button appearance."
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

    // MARK: - Init

    init(
        appManager: AppManager = AppManager(),
        notificationPreferencesStore: TaskerNotificationPreferencesStore = .shared
    ) {
        self.appManager = appManager
        self.notificationPreferencesStore = notificationPreferencesStore
        self.preferences = notificationPreferencesStore.load()
        self.currentModelDisplayName = appManager.compactModelDisplayName(appManager.currentModelName ?? "")
        self.decorativeButtonEffectsEnabled = V2FeatureFlags.userDecorativeCTAEffectsEnabled
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

    func setDecorativeButtonEffectsEnabled(_ isEnabled: Bool) {
        decorativeButtonEffectsEnabled = isEnabled
        V2FeatureFlags.userDecorativeCTAEffectsEnabled = isEnabled
        TaskerFeedback.selection()
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
        currentModelDisplayName = appManager.compactModelDisplayName(appManager.currentModelName ?? "")
        decorativeButtonEffectsEnabled = V2FeatureFlags.userDecorativeCTAEffectsEnabled
        refreshPermissionStatus()
    }

    func restartOnboarding() {
        TaskerFeedback.medium()
        onRestartOnboarding?()
    }

    private func saveAndReconcile() {
        notificationPreferencesStore.save(preferences)
        reconcileNotifications(reason: "settings_changed")
    }

    private func reconcileNotifications(reason: String) {
        (UIApplication.shared.delegate as? AppDelegate)?.reconcileNotifications(reason: reason)
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
