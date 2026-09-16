import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// The receipt: facts only, and only facts that are true.
///
/// This replaced two template sentences ("Work & Career gets the clearest
/// path…", "Your routines can stay visible without becoming another score…").
/// They promised; a receipt shows. Deliberately not generated either — the
/// payoff must not depend on a model, a network, or an account.
enum LifeWeaveRevealCopy {

    enum RowKind: Equatable {
        case capture(text: String, kind: LifeMapCaptureKind)
        case emptyCapture
        case areas(String)
        case hours(String)
    }

    static func rows(for draft: LifeWeaveDraft) -> [RowKind] {
        var rows: [RowKind] = []
        // Only claimed when something was actually reviewed and written. A
        // skipped capture is an honest empty state, never dressed up.
        if let capture = draft.stagedCapture, capture.isReviewed {
            rows.append(.capture(text: capture.text, kind: capture.kind))
        } else {
            rows.append(.emptyCapture)
        }

        let names = draft.orderedLifeAreaTemplateIDs.compactMap { id in
            StarterWorkspaceCatalog.allLifeAreas.first { $0.id == id }?.name
        }
        if let primary = names.first {
            rows.append(.areas(LifeWeaveCopy.Ready.areas(primary: primary, others: names.count - 1)))
        }

        let start = OnboardingDayShapeDraft.label(forMinute: draft.dayShape.weekdayStartMinute)
        let end = OnboardingDayShapeDraft.label(forMinute: draft.dayShape.weekdayEndMinute)
        rows.append(.hours(LifeWeaveCopy.Ready.hours(start: start, end: end)))
        return rows
    }

    /// The receipt as plain strings, for VoiceOver and tests.
    static func receipt(for draft: LifeWeaveDraft) -> [String] {
        rows(for: draft).map { row in
            switch row {
            case .capture(let text, let kind): "\(text) · \(LifeWeaveCopy.Capture.kindTitle(kind))"
            case .emptyCapture: LifeWeaveCopy.Ready.emptyCapture
            case .areas(let line), .hours(let line): line
            }
        }
    }
}

/// The payoff.
///
/// Reward first, then an optional invitation, then one way out. Every
/// connection opens as a sheet over this screen and returns here, so an
/// optional choice never reads as more setup.
struct LifeWeaveRevealStep: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    let pillNamespace: Namespace.ID
    @StateObject private var evaAccess = EvaCloudAccessCoordinator.shared
    @State private var healthStore = HealthCoordinator.shared.connectionStore
    @State private var showsHours = false
    @State private var showsEvaData = false
    /// Drives the check marks drawing in, once, when the receipt appears.
    @State private var receiptSettled = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var draft: LifeWeaveDraft { model.draft }
    private var reduceMotion: Bool { MotionOverride.resolve(systemReduceMotion) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                Text(LifeWeaveCopy.Ready.title)
                    .lifeboardFont(.screenTitle)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                // Success is the placement guide's `eva_excited` moment, and it
                // only appears here — after the local write has succeeded.
                EvaMascotView(placement: .onboardingSuccess, size: .inline)
                    .scaleEffect(receiptSettled || reduceMotion ? 1 : 0.6)
                    .opacity(receiptSettled ? 1 : 0)
            }

            receipt

            if model.isPowerUpAvailable {
                connections
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard receiptSettled == false else { return }
            if let animation = MotionProfile.celebration.animation(reduceMotion: reduceMotion) {
                withAnimation(animation.delay(0.12)) { receiptSettled = true }
            } else {
                receiptSettled = true
            }
        }
        .sheet(isPresented: $showsHours) {
            LifeWeaveDayShapeSheet(model: model) { showsHours = false }
        }
        .sheet(isPresented: $showsEvaData) {
            EvaDataUseSheet { showsEvaData = false }
        }
    }

    // MARK: Receipt

    private var receipt: some View {
        VStack(alignment: .leading, spacing: 0) {
            let rows = LifeWeaveRevealCopy.rows(for: draft)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Rectangle()
                        .fill(Color.lifeboard(.strokeHairline))
                        .frame(height: 1)
                        .padding(.leading, 44)
                }
                receiptRow(row, index: index)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(LifeWeaveAccessibilityID.revealReceipt)
    }

    @ViewBuilder
    private func receiptRow(_ row: LifeWeaveRevealCopy.RowKind, index: Int) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            LifeWeaveReceiptCheck(
                isDone: row != .emptyCapture,
                isSettled: receiptSettled,
                delay: Double(index) * LifeBoardAnimation.staggerInterval * 2
            )
            switch row {
            case .capture(let text, let kind):
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .lifeboardFont(.bodyStrong)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(LifeWeaveCopy.Capture.kindTitle(kind))
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
                .accessibilityIdentifier("onboarding.savedCapture")
                .accessibilityElement(children: .combine)
            case .emptyCapture:
                Text(LifeWeaveCopy.Ready.emptyCapture)
                    .lifeboardFont(.body)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            case .areas(let line):
                Text(line)
                    .lifeboardFont(.body)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
            case .hours(let line):
                Text(line)
                    .lifeboardFont(.body)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Spacer(minLength: Theme.Spacing.xs)
                Button {
                    showsHours = true
                } label: {
                    Text(LifeWeaveCopy.Ready.edit)
                        .lifeboardFont(.bodyStrong)
                        .foregroundStyle(Color.lifeboard(.accentPrimary))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityIdentifier(LifeWeaveAccessibilityID.hoursEdit)
            }
            if case .hours = row {} else { Spacer(minLength: 0) }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(minHeight: 52)
        .modifier(LifeWeaveStaggeredEntrance(index: index))
        // The sentence the user typed arrives from the capture field.
        .matchedGeometryEffect(
            id: index == 0 ? LifeWeaveCaptureStep.pillID : "onboarding.receipt.\(index)",
            in: pillNamespace,
            isSource: false
        )
    }

    // MARK: Connections

    private var connections: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(LifeWeaveCopy.Ready.connectHeader)
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .accessibilityAddTraits(.isHeader)

            // Least sensitive first, and value before AI.
            ForEach([LifeWeavePowerUpStep.calendar, .health, .eva]) { connector in
                LifeWeaveConnectionRow(
                    connector: connector,
                    status: connectionStatus(connector),
                    isConnected: isConnected(connector)
                ) {
                    model.beginPowerUp(connector)
                }
            }

            evaNotice
        }
    }

    /// One sentence that still names OpenAI and that EVA is on, with the full
    /// disclosure one tap away. It replaced a forty-word paragraph that sat
    /// under the payoff and was the longest thing on the screen.
    private var evaNotice: some View {
        Button {
            showsEvaData = true
        } label: {
            (Text(LifeWeaveCopy.Ready.evaNotice + " ")
                .foregroundStyle(Color.lifeboard(.textSecondary))
             + Text(LifeWeaveCopy.Ready.evaNoticeLink)
                .foregroundStyle(Color.lifeboard(.accentPrimary))
                .underline())
                .lifeboardFont(.caption1)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.eva.automaticDisclosure")
        .accessibilityHint(LifeWeaveCopy.EvaData.title)
    }

    private func isConnected(_ connector: LifeWeavePowerUpStep) -> Bool {
        switch connector {
        case .calendar: model.selectedCalendarCount > 0
        case .health:
            if case .ready = healthStore.presentation { true } else { false }
        case .eva: evaAccess.state == .ready || (model.evaPrefersOffline && model.powerUps.offlineEvaReady())
        }
    }

    private func connectionStatus(_ connector: LifeWeavePowerUpStep) -> String {
        switch connector {
        case .calendar:
            let count = model.selectedCalendarCount
            guard count > 0 else { return LifeWeaveCopy.Connection.value(.calendar) }
            return count == 1 ? String(localized: "1 calendar") : LifeWeaveCopy.Connection.calendars(count)
        case .health:
            switch healthStore.presentation {
            case .ready: return LifeWeaveCopy.Connection.connected
            case .requesting, .syncing: return LifeWeaveCopy.Connection.connecting
            case .partial, .authorizationFailed, .protectedDataLocked: return LifeWeaveCopy.Connection.needsAttention
            case .reviewedNoDataYet: return String(localized: "Connected. No data yet.")
            case .unavailable: return String(localized: "Not on this device")
            case .notRequested: return LifeWeaveCopy.Connection.value(.health)
            }
        case .eva:
            if model.evaPrefersOffline {
                return model.powerUps.offlineEvaReady()
                    ? LifeWeaveCopy.Connection.offlineReady
                    : LifeWeaveCopy.Connection.needsAttention
            }
            switch evaAccess.state {
            case .ready: return LifeWeaveCopy.Connection.connected
            case .activating: return LifeWeaveCopy.Connection.connecting
            case .temporarilyUnavailable, .appleReauthenticationRequired: return LifeWeaveCopy.Connection.needsAttention
            default: return LifeWeaveCopy.Connection.value(.eva)
            }
        }
    }
}

/// A check that draws itself in when the receipt arrives.
private struct LifeWeaveReceiptCheck: View {
    let isDone: Bool
    let isSettled: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var progress: Double = 0

    var body: some View {
        ZStack {
            if isDone {
                Circle()
                    .fill(Color.lifeboard(.accentWash))
                CompletionMark(progress: progress)
                    .stroke(Color.lifeboard(.accentPrimary), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .padding(8)
            } else {
                Circle()
                    .stroke(Color.lifeboard(.textQuaternary), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
        .onAppear { settle() }
        .onChange(of: isSettled) { _, _ in settle() }
    }

    private func settle() {
        guard isSettled, isDone, progress < 1 else { return }
        let reduce = MotionOverride.resolve(systemReduceMotion)
        if let animation = MotionProfile.celebration.animation(reduceMotion: reduce) {
            withAnimation(animation.delay(delay)) { progress = 1 }
        } else {
            progress = 1
        }
    }
}

/// One optional connection: what it gives you, then — once connected — what
/// it is doing.
private struct LifeWeaveConnectionRow: View {
    let connector: LifeWeavePowerUpStep
    let status: String
    let isConnected: Bool
    let action: () -> Void

    @State private var connectedLight = 0

    private var symbol: String {
        switch connector {
        case .calendar: "calendar"
        case .health: "heart.fill"
        case .eva: "sparkles"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: symbol)
                    .lifeboardFont(.headline)
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
                    .frame(width: 36, height: 36)
                    .background(Color.lifeboard(.accentWash), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(LifeWeaveCopy.Connection.name(connector))
                        .lifeboardFont(.bodyStrong)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text(status)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .contentTransition(.opacity)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Spacing.xs)
                Image(systemName: isConnected ? "checkmark.circle.fill" : "chevron.right")
                    .lifeboardFont(isConnected ? .title3 : .caption1)
                    .foregroundStyle(Color.lifeboard(isConnected ? .statusSuccess : .textTertiary))
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(minHeight: 60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.resting, cornerRadius: Radius.row)
        }
        .buttonStyle(LifeMapPressButtonStyle())
        .lifeboardFirstLight(trigger: connectedLight, tint: Color.lifeboard(.statusSuccess))
        .lifeBoardMotion(.selection, value: isConnected)
        .lifeBoardMotion(.contentInsertion, value: status)
        .onChange(of: isConnected) { _, connected in
            if connected { connectedLight &+= 1 }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("onboarding.connection.\(connector.rawValue)")
    }
}

/// The full Cloud EVA disclosure, one tap from the Ready screen.
///
/// Same facts as the paragraph it replaced, as four short lines a person can
/// actually scan.
struct EvaDataUseSheet: View {
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .lifeboardFont(.title2)
                            .foregroundStyle(Color.lifeboard(.accentPrimary))
                            .frame(width: 56, height: 56)
                            .lifeBoardClaySurface(.well, cornerRadius: Radius.card)
                            .symbolEffect(.bounce, options: .nonRepeating)
                            .accessibilityHidden(true)
                        Text(LifeWeaveCopy.EvaData.title)
                            .lifeboardFont(.screenTitle)
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        ForEach(LifeWeaveCopy.EvaData.bullets, id: \.self) { line in
                            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                                Circle()
                                    .fill(Color.lifeboard(.accentPrimary))
                                    .frame(width: 6, height: 6)
                                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                                    .accessibilityHidden(true)
                                Text(line)
                                    .lifeboardFont(.body)
                                    .foregroundStyle(Color.lifeboard(.textPrimary))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    // Settings cannot open over a first run that is still on
                    // screen, so this says where the controls live instead of
                    // pretending to be a link.
                    Label(LifeWeaveCopy.EvaData.manage, systemImage: "gearshape")
                        .lifeboardFont(.support)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("onboarding.eva.dataUse.manage")
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Color.lifeboard(.bgCanvas))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LifeWeaveCopy.Dock.done, action: onDone)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("onboarding.eva.dataUse.sheet")
    }
}
