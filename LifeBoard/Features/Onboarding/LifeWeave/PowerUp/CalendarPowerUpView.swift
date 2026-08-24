import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// Which of the connector's four screens is showing.
///
/// Resolved, never stored. The v5 flow kept a `calendarConnected` flag beside
/// the permission it described, so a grant revoked in iOS Settings left a green
/// row in onboarding claiming otherwise. There is nothing to fall out of date
/// here: the only inputs are what the system says now and whether the user has
/// committed a scope in this sitting.
enum CalendarPowerUpStage: Equatable {
    case primer
    case chooser
    case proof
    case recovery(CalendarAuthorizationStatus)

    /// Pure, so the connector's shape is provable without EventKit, a device, or
    /// a running journey.
    static func resolve(
        authorization: CalendarAuthorizationStatus,
        hasCommittedSelection: Bool
    ) -> Self {
        switch authorization {
        case .notDetermined:
            .primer
        // Each of these needs a different sentence and a different way out, and
        // none of them may re-open the system dialog on their own.
        case .denied, .restricted, .writeOnly:
            .recovery(authorization)
        case .authorized:
            hasCommittedSelection ? .proof : .chooser
        }
    }
}

/// Identifiers this connector adds.
///
/// They sit here rather than in `LifeWeaveAccessibilityID` only because that
/// file belongs to the flow shell and three connectors are being written at
/// once; fold them in when the phase lands.
private enum CalendarPowerUpID {
    static let platformNote = "onboarding.lifeweave.calendar.platformNote"
    static let selectionCount = "onboarding.lifeweave.calendar.selectionCount"
    static let proof = "onboarding.lifeweave.calendar.proof"
    static let recovery = "onboarding.lifeweave.calendar.recovery"
    static let openSettings = "onboarding.lifeweave.calendar.openSettings"
}

/// Power Up 1 of 3 — primer, inline chooser, and value proof.
///
/// Owned by E3. Renders from `CalendarIntegrationService` truth by way of
/// `LifeWeaveOnboardingModel`; it must never touch EventKit directly.
struct CalendarPowerUpView: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    @StateObject private var session = CalendarPowerUpSession.shared

    @State private var hasSweptProof = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            LifeMapEyebrow("CALENDAR")

            switch model.calendarStage {
            case .primer: primer
            case .chooser: chooser
            case .proof: proof
            case .recovery(let status): recovery(status)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardMotion(.contentInsertion, value: model.calendarStage)
        .task { await model.prepareCalendarPowerUp() }
        .onChange(of: session.visibleEventCount) { _, count in
            guard let count, count > 0, hasSweptProof == false else { return }
            withAnimation(MotionProfile.contentInsertion.animation(
                reduceMotion: MotionOverride.effectiveReduceMotion
            )) {
                hasSweptProof = true
            }
        }
    }

    // MARK: - Primer

    private var primer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            title("See the real shape of your day.")

            paragraph("LifeBoard reads the calendars you choose to see busy time, free gaps, and what is coming next. It never edits your events.")

            // Named before the system sheet says it, not after. Somebody who has
            // just been told LifeBoard only reads, and is then shown a dialog
            // headed "Full Access", reads the two as a contradiction and
            // declines — and iOS has no narrower grant to ask for.
            note(
                symbol: "info.circle",
                text: "iOS may describe this as full calendar access because reading events requires it. LifeBoard still only reads."
            )

            support("Optional. Skipping never blocks LifeBoard.")
        }
    }

    // MARK: - Chooser

    private var chooser: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            title("Which calendars shape your day?")

            paragraph("Pick the ones you actually plan around. Nothing is chosen for you, and you can change this in Settings whenever you like.")

            if session.calendars.isEmpty {
                if session.isLoadingCalendars {
                    progress("Looking for your calendars…")
                } else {
                    card {
                        Text("No calendars found on this device.")
                            .lifeboardFont(.bodyStrong)
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                        Text("LifeBoard works without them. It will use any calendar you add later.")
                            .lifeboardFont(.caption1)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                ForEach(CalendarPresentation.chooserSections(from: session.calendars)) { section in
                    calendarSection(section)
                }
                selectionCount
            }
        }
        .lifeBoardMotion(.contentInsertion, value: model.selectedCalendarCount)
    }

    private func calendarSection(_ section: CalendarChooserSection) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(section.title)
                .lifeboardFont(.eyebrow)
                .tracking(1.2)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .accessibilityAddTraits(.isHeader)

            ForEach(section.calendars) { calendar in
                CalendarPowerUpRow(
                    calendar: calendar,
                    isSelected: model.isCalendarSelected(calendar.id)
                ) {
                    model.toggleCalendarSelection(calendar.id)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The count, and — at zero — why the primary will not move.
    ///
    /// A disabled button with no explanation is the shape of the v5 bug where
    /// people sat on a step waiting for something to happen.
    private var selectionCount: some View {
        let count = model.selectedCalendarCount
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("\(count) calendar\(count == 1 ? "" : "s") selected")
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.textPrimary))

            if count == 0 {
                Label(
                    "Choose at least one calendar, or skip this with Not now.",
                    systemImage: "exclamationmark.circle"
                )
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.statusWarning))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(CalendarPowerUpID.selectionCount)
    }

    // MARK: - Value proof

    private var proof: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            title("Your day just got more real.")

            if session.isReadingProof {
                progress("Reading selected calendars…")
            } else {
                card {
                    Text(proofHeadline)
                        .lifeboardFont(.bodyStrong)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)

                    if let names = selectedCalendarNames {
                        Label(names, systemImage: "calendar")
                            .lifeboardFont(.caption1)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Label("LifeBoard reads these. It never writes to them.", systemImage: "eye")
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier(CalendarPowerUpID.proof)
                // Only real event data gets the sweep. An empty day and a failed
                // read are both valid states, and sweeping them would dress up
                // an absence of information as an arrival of it.
                .lifeboardChartRevealSweep(progress: proofSweepProgress)
            }
        }
    }

    /// Drives the reveal sweep, and only when the read actually returned events.
    private var proofSweepProgress: Double {
        guard session.isReadingProof == false, let count = session.visibleEventCount, count > 0 else { return 0 }
        return hasSweptProof ? 1 : 0
    }

    /// Only ever says what the service reported.
    ///
    /// An empty calendar is a real connected state and gets a real sentence —
    /// inventing a sample event here, or padding the screen with what a busy day
    /// *would* look like, would make the one screen that proves the connection
    /// works the one screen that lies.
    private var proofHeadline: String {
        let calendarCount = model.selectedCalendarCount
        let calendarPhrase = "\(calendarCount) calendar\(calendarCount == 1 ? "" : "s")"

        guard let events = session.visibleEventCount else {
            // The read did not finish in time. Still true, and still useful.
            return "LifeBoard is now planning around \(calendarPhrase). Events show up on Home as soon as it can see them."
        }
        if events == 0 {
            return "Nothing scheduled on \(calendarPhrase) yet. LifeBoard will use them the moment something appears."
        }
        return "LifeBoard can already see \(events) event\(events == 1 ? "" : "s") across \(calendarPhrase)."
    }

    private var selectedCalendarNames: String? {
        let selected = session.calendars
            .filter { model.isCalendarSelected($0.id) }
            .map(\.title)
        guard selected.isEmpty == false else { return nil }
        return onboardingNaturalLanguageList(selected, fallback: "")
    }

    // MARK: - Recovery

    /// One stable card for every state the user cannot leave by tapping Allow.
    ///
    /// None of these re-request on their own. iOS shows the dialog once, and an
    /// app that keeps asking after a refusal is asking the system to say no on
    /// the user's behalf.
    @ViewBuilder
    private func recovery(_ status: CalendarAuthorizationStatus) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            title(recoveryTitle(status))

            card {
                Label(recoveryHeadline(status), systemImage: recoverySymbol(status))
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)

                Text(recoveryDetail(status))
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)

                if status == .denied {
                    Button("Open Settings") { model.openCalendarSystemSettings() }
                        .buttonStyle(.lifeBoardChip)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier(CalendarPowerUpID.openSettings)
                }
            }
            .accessibilityIdentifier(CalendarPowerUpID.recovery)

            support("LifeBoard still works. Your day just won't show real events.")
        }
    }

    private func recoveryTitle(_ status: CalendarAuthorizationStatus) -> String {
        switch status {
        case .writeOnly: "LifeBoard can add events, but not read them."
        case .restricted: "Calendar access is restricted on this device."
        default: "Calendar access is off."
        }
    }

    private func recoveryHeadline(_ status: CalendarAuthorizationStatus) -> String {
        switch status {
        case .writeOnly: "Write-only access"
        case .restricted: "Managed by this device"
        default: "Turned off in iOS Settings"
        }
    }

    private func recoverySymbol(_ status: CalendarAuthorizationStatus) -> String {
        switch status {
        case .writeOnly: "square.and.pencil"
        case .restricted: "lock"
        default: "calendar.badge.exclamationmark"
        }
    }

    private func recoveryDetail(_ status: CalendarAuthorizationStatus) -> String {
        switch status {
        case .writeOnly:
            "LifeBoard can put something on your calendar, but it cannot see busy time or free gaps. Reading is what makes your day real, and it is a separate answer."
        case .restricted:
            "A profile or Screen Time restriction controls calendar access here, so LifeBoard cannot ask for it. Whoever manages this device can change that."
        default:
            "LifeBoard will not ask again. Calendar access can be turned back on for LifeBoard in iOS Settings whenever you want it."
        }
    }

    // MARK: - Shared pieces

    private func title(_ text: String) -> some View {
        Text(text)
            .lifeboardFont(.screenTitle)
            .foregroundStyle(Color.lifeboard(.textPrimary))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .lifeboardFont(.body)
            .foregroundStyle(Color.lifeboard(.textSecondary))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func support(_ text: String) -> some View {
        Text(text)
            .lifeboardFont(.support)
            .foregroundStyle(Color.lifeboard(.textTertiary))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func note(symbol: String, text: String) -> some View {
        Label(text, systemImage: symbol)
            .lifeboardFont(.caption1)
            .foregroundStyle(Color.lifeboard(.textSecondary))
            .fixedSize(horizontal: false, vertical: true)
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.resting, cornerRadius: 16)
            .accessibilityIdentifier(CalendarPowerUpID.platformNote)
    }

    private func progress(_ text: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            ProgressView()
            Text(text)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.resting, cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            content()
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.resting, cornerRadius: 20)
        .accessibilityElement(children: .contain)
    }
}

/// One calendar, with its own colour and its own answer.
///
/// State is the checkmark and the label, never the tint alone: a calendar's
/// colour belongs to the calendar, so using colour to mean "chosen" would put
/// two meanings on the same dot.
private struct CalendarPowerUpRow: View {
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
                    .lifeboardFont(.body)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(Color.lifeboard(isSelected ? .accentPrimary : .textQuaternary))
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .lifeBoardClaySurface(
                isSelected ? .raised : .resting,
                cornerRadius: 16,
                fill: isSelected ? Color.lifeboard(.accentWash) : nil
            )
        }
        .buttonStyle(LifeMapPressButtonStyle())
        .accessibilityIdentifier(LifeWeaveAccessibilityID.calendarRow(calendar.id))
        .accessibilityLabel(Text(calendar.title))
        .accessibilityValue(Text(isSelected ? "Included" : "Not included"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
