import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

// The optional power-up chain: calendar, Health, reminders. Everything here runs
// *after* the commit has succeeded, so nothing on these screens can fail in a
// way that costs the user their Life Map. Each step asks for exactly one thing,
// reports what the system actually answered, and always offers a way past.

// MARK: - Calendar

/// Grant, then scope.
///
/// The scoping half is not decoration. An empty `selectedCalendarIDs` means *no
/// calendars* to `FilterCalendarEventsUseCase`, so a granted-but-unscoped
/// calendar renders an empty schedule everywhere — including in the projection
/// EVA reasons over. The model preselects everything available on grant; this
/// list exists so the user can narrow it while the reason is still fresh.
struct LifeMapCalendarStep: View {
    let isGranted: Bool
    let isDenied: Bool
    let isBusy: Bool
    let sections: [CalendarChooserSection]
    let selectedIDs: [String]
    let onRequest: () -> Void
    let onToggle: (String) -> Void
    let onSkip: () -> Void

    var body: some View {
        LifeMapQuestionScaffold(
            title: "See your real day",
            support: supportText
        ) {
            if isGranted {
                calendarList
            } else if isDenied {
                PermissionRecoveryCard(kind: .calendar)
            } else {
                LifeMapConnectPitch(
                    symbol: "calendar",
                    headline: "LifeBoard reads your calendar. It never writes to it.",
                    detail: "Your schedule becomes context for planning and for EVA — busy blocks, free gaps, and what is coming next."
                )
                HStack(spacing: Theme.Spacing.sm) {
                    Button(PermissionKind.calendar.allowTitle, action: onRequest)
                        .buttonStyle(LifeMapPrimaryButtonStyle())
                        .disabled(isBusy)
                        .accessibilityIdentifier(LifeMapAccessibilityID.permission(PermissionKind.calendar.id))
                    Button("Not now", action: onSkip)
                        .buttonStyle(LifeMapSecondaryButtonStyle())
                        .accessibilityIdentifier(LifeMapAccessibilityID.permissionSkip(PermissionKind.calendar.id))
                }
            }
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.calendar))
    }

    private var supportText: String {
        if isGranted { return "Everything is on. Turn off anything you would rather LifeBoard ignored." }
        if isDenied { return "Calendar access is off. LifeBoard still works — your day just won't show real events." }
        return "Optional. Declining never blocks LifeBoard."
    }

    private var calendarList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(.lifeboard(.eyebrow))
                        .tracking(1.2)
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                    ForEach(section.calendars) { calendar in
                        LifeMapCalendarRow(
                            calendar: calendar,
                            isSelected: selectedIDs.contains(calendar.id),
                            onToggle: { onToggle(calendar.id) }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if sections.isEmpty {
                Text("No calendars found on this device.")
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .padding(Theme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lifeBoardClaySurface(.resting, cornerRadius: 20)
            }
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.calendarList)
    }
}

private struct LifeMapCalendarRow: View {
    let calendar: CalendarSourceSnapshot
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Theme.Spacing.md) {
                Circle()
                    .fill(HexColor.color(calendar.colorHex, fallback: Color.lifeboard(.accentPrimary)))
                    .frame(width: 12, height: 12)
                Text(calendar.title)
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(Color.lifeboard(isSelected ? .statusSuccess : .textQuaternary))
            }
            .padding(Theme.Spacing.md + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.resting, cornerRadius: 16)
        }
        .buttonStyle(LifeMapPressButtonStyle())
        .accessibilityIdentifier(LifeMapAccessibilityID.calendarRow(calendar.id))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Health

/// Reading and writing are two different questions.
///
/// `connect(domains:)` defaults to switching write-back on for every writable
/// domain, which is right for an in-app surface that named writing explicitly
/// and wrong for a first run. Onboarding authorizes reads, then asks about
/// writing separately — and starts every write toggle off.
struct LifeMapHealthStep: View {
    let isConnected: Bool
    let isBusy: Bool
    let writableDomains: [HealthDomain]
    let writeBackDomainIDs: [String]
    let onConnect: () -> Void
    let onToggleWriteBack: (HealthDomain, Bool) -> Void
    let onSkip: () -> Void

    var body: some View {
        LifeMapQuestionScaffold(
            title: "Bring your health in",
            support: isConnected
                ? "Reading is on. Choose anything LifeBoard may also write back."
                : "Optional. Declining never blocks LifeBoard."
        ) {
            if isConnected {
                if writableDomains.isEmpty {
                    Text("Nothing you chose writes back to Apple Health. LifeBoard will only read.")
                        .font(.lifeboard(.body))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .padding(Theme.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lifeBoardClaySurface(.resting, cornerRadius: 20)
                } else {
                    writeBackList
                }
            } else {
                LifeMapConnectPitch(
                    symbol: "heart.text.square",
                    headline: "LifeBoard reads what you already log.",
                    detail: "Health data stays on this device. It is never sent to EVA's cloud unless you grant that separately."
                )
                HStack(spacing: Theme.Spacing.sm) {
                    Button(PermissionKind.appleHealth.allowTitle, action: onConnect)
                        .buttonStyle(LifeMapPrimaryButtonStyle())
                        .disabled(isBusy)
                        .accessibilityIdentifier(LifeMapAccessibilityID.permission(PermissionKind.appleHealth.id))
                    Button("Not now", action: onSkip)
                        .buttonStyle(LifeMapSecondaryButtonStyle())
                        .accessibilityIdentifier(LifeMapAccessibilityID.permissionSkip(PermissionKind.appleHealth.id))
                }
            }
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.health))
    }

    private var writeBackList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("LET LIFEBOARD WRITE")
                .font(.lifeboard(.eyebrow))
                .tracking(1.2)
                .foregroundStyle(Color.lifeboard(.textTertiary))
            ForEach(writableDomains) { domain in
                Toggle(isOn: Binding(
                    get: { writeBackDomainIDs.contains(domain.id) },
                    set: { onToggleWriteBack(domain, $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(domain.title)
                            .font(.lifeboard(.bodyStrong))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                        Text("What you log in LifeBoard also appears in Apple Health.")
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard(.textTertiary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Color.lifeboard(.accentPrimary))
                .padding(Theme.Spacing.md + 2)
                .lifeBoardClaySurface(.resting, cornerRadius: 16)
                .accessibilityIdentifier(LifeMapAccessibilityID.healthWriteBackRow(domain.id))
            }
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.healthWriteBackList)
    }
}

// MARK: - Reminders

struct LifeMapRemindersStep: View {
    let isGranted: Bool
    let isDenied: Bool
    let isBusy: Bool
    let onRequest: () -> Void
    let onSkip: () -> Void

    var body: some View {
        LifeMapQuestionScaffold(
            title: "A nudge when it matters",
            support: isDenied
                ? "Notifications are off. Everything still works — LifeBoard just won't interrupt."
                : "Optional. Declining never blocks LifeBoard."
        ) {
            if isGranted {
                Label("Reminders are on", systemImage: "checkmark.circle.fill")
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .padding(Theme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lifeBoardClaySurface(.resting, cornerRadius: 20)
            } else if isDenied {
                PermissionRecoveryCard(kind: .notifications)
            } else {
                LifeMapConnectPitch(
                    symbol: "bell.badge",
                    headline: "Only what you asked for.",
                    detail: "Reminders come from the routines and habits you chose — never from LifeBoard deciding you need encouragement."
                )
                HStack(spacing: Theme.Spacing.sm) {
                    Button(PermissionKind.notifications.allowTitle, action: onRequest)
                        .buttonStyle(LifeMapPrimaryButtonStyle())
                        .disabled(isBusy)
                        .accessibilityIdentifier(LifeMapAccessibilityID.permission(PermissionKind.notifications.id))
                    Button("Not now", action: onSkip)
                        .buttonStyle(LifeMapSecondaryButtonStyle())
                        .accessibilityIdentifier(LifeMapAccessibilityID.permissionSkip(PermissionKind.notifications.id))
                }
            }
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.reminders))
    }
}

// MARK: - Shared

/// The one-card "why" that precedes every system dialog.
///
/// The permission contract requires naming the capability unlocked, the data
/// read or written, and that the feature survives a refusal — before the
/// system sheet appears, not after.
struct LifeMapConnectPitch: View {
    let symbol: String
    let headline: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .font(.lifeboard(.title1))
                .foregroundStyle(Color.lifeboard(.accentPrimary))
                .frame(width: 54, height: 54)
                .lifeBoardClaySurface(.well, cornerRadius: 18)
            Text(headline)
                .font(.lifeboard(.bodyStrong))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 22)
    }
}
