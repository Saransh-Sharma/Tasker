import SwiftUI

// The Setup Center sections, one `struct` each.
//
// They were six computed `some View`s and two `@ViewBuilder`s on
// `SetupCenterView`, which meant every control on the screen — including the
// EVA state machine's seven branches — built its view value inside the root's
// frame. That is the shape that walks the main thread's guard page at `-Onone`,
// and Setup Center is reached during onboarding, at launch.

// MARK: - Hero

/// The one thing Setup Center is for.
///
/// Hero glass when there is something to decide, floating clay when there is
/// not. `DESIGN.md`: "A screen with no obvious single dominant object does not
/// get a hero — it gets clay throughout, which is a legitimate and common
/// outcome." That withdrawal is also what makes the glass mean something on the
/// way in.
struct SetupCenterFocusSection: View {
    let focus: SetupCenterFocus
    let palette: DaypartPalette
    let action: SetupCenterAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(focus.status)
                .lifeboardFont(.meta)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .accessibilityIdentifier("setupCenter.focus.status")

            Text(focus.title)
                .lifeboardFont(.sectionTitle)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)

            Text(focus.context)
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            if let action {
                Button(action.title, action: action.perform)
                    .buttonStyle(.lifeBoardPrimary)
                    .disabled(action.isEnabled == false)
                    .accessibilityIdentifier(action.identifier)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SetupCenterFocusSurface(isHero: focus.target != .complete, palette: palette))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("setupCenter.focus")
    }
}

/// Hero arbitration belongs to the screen, never to the section.
///
/// Both arms share `Radius.hero`, which is the "one silhouette, two materials"
/// rule: swapping the material must not reflow, resize or reorder anything, and
/// the same 24pt corner is what `SetupCenterHomeCard` carries so the card on
/// Home reads as the same object opening.
private struct SetupCenterFocusSurface: ViewModifier {
    let isHero: Bool
    let palette: DaypartPalette

    func body(content: Content) -> some View {
        if isHero {
            content.lifeBoardHeroSurface(palette: palette)
        } else {
            content.lifeBoardClaySurface(.floating, cornerRadius: Radius.hero)
        }
    }
}

// MARK: - Connector card

/// Raised clay, one connector.
///
/// Replaces a hand-rolled `RoundedRectangle(cornerRadius: 22)` fill plus a
/// manual stroke — a radius that is not on the shape scale, and a surface with
/// no specular rim, no depth shadow and no Increase-Contrast or
/// Reduce-Transparency handling. `lifeBoardClaySurface` supplies all four.
struct SetupCenterConnectorCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let state: SetupCenterConnectorState
    let identifier: String
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                SettingsRowIcon(iconName: systemImage, tone: state.tone)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .lifeboardFont(.headline)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text(subtitle)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if dynamicTypeSize.isAccessibilitySize == false {
                    SetupCenterStateBadge(state: state)
                }
            }

            // At accessibility sizes the badge stops competing with the title
            // for the same line and moves below it, rather than being shrunk.
            if dynamicTypeSize.isAccessibilitySize {
                SetupCenterStateBadge(state: state)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.resting, cornerRadius: Radius.largeCard)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

/// Glyph *and* text. State was previously carried by tint plus a VoiceOver
/// label, which left a sighted person to distinguish five states by colour.
private struct SetupCenterStateBadge: View {
    let state: SetupCenterConnectorState

    var body: some View {
        Label(state.label, systemImage: state.symbolName)
            .lifeboardFont(.caption2)
            .foregroundStyle(Color.lifeboard(.textSecondary))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
    }
}

/// The action a card owns when the hero has not taken it.
private struct SetupCenterCardAction: View {
    let action: SetupCenterAction?

    var body: some View {
        if let action {
            // `.lifeBoardChip`, not `.lifeBoardClay`: `ClayButtonStyle` applies a
            // surface but no font, padding or minimum height, so a bare title
            // rendered as body text sitting on a shrink-wrapped slab. A card's
            // action is also genuinely secondary now that the hero owns the
            // focused one, and a pill is what `DESIGN.md` gives compact actions.
            Button(action.title, action: action.perform)
                .buttonStyle(.lifeBoardChip)
                .disabled(action.isEnabled == false)
                .accessibilityIdentifier(action.identifier)
        }
    }
}

// MARK: - Connectors

struct SetupCenterCalendarSection: View {
    let state: SetupCenterConnectorState
    let summary: String
    let action: SetupCenterAction?

    var body: some View {
        SetupCenterConnectorCard(
            title: "Calendar",
            subtitle: "See the real shape of your day so plans fit around existing events.",
            systemImage: "calendar",
            state: state,
            identifier: "setupCenter.calendar"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(summary)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                SetupCenterCardAction(action: action)
            }
        }
    }
}

struct SetupCenterHealthSection: View {
    let state: SetupCenterConnectorState
    let access: HealthAccessState
    let action: SetupCenterAction?

    var body: some View {
        SetupCenterConnectorCard(
            title: "Apple Health",
            subtitle: "Bring local wellness context into LifeBoard and sync supported entries back to Health.",
            systemImage: "heart.text.square.fill",
            state: state,
            identifier: "setupCenter.health"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(statusText)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                SetupCenterCardAction(action: action)
            }
        }
    }

    private var statusText: String {
        switch access.readState {
        case .notRequested:
            "Not requested"
        case .requestPresented:
            "Health access requested · \(access.authorizedWriteCount) write categories authorized"
        case .dataAvailable:
            "Health data available · \(access.authorizedWriteCount) write categories authorized"
        }
    }
}

struct SetupCenterRemindersSection: View {
    let state: SetupCenterConnectorState
    let action: SetupCenterAction?

    var body: some View {
        SetupCenterConnectorCard(
            title: "Reminders",
            subtitle: "Create reminders now. LifeBoard asks for notification access only when your first alert needs it.",
            systemImage: "bell.badge",
            state: state,
            identifier: "setupCenter.reminders"
        ) {
            SetupCenterCardAction(action: action)
        }
    }
}

// MARK: - EVA

struct SetupCenterEvaSection: View {
    let state: SetupCenterConnectorState
    let accessState: EvaCloudAccessState
    let progressCaption: String?
    let errorMessage: String?
    let grants: [(grant: EvaConsentPolicy.Grant, title: String, isOn: Binding<Bool>)]
    let action: SetupCenterAction?
    let onDecline: () -> Void
    let onChooseOffline: () -> Void

    var body: some View {
        SetupCenterConnectorCard(
            title: "EVA",
            subtitle: "Use the Cloud smart layer with only the categories you approve.",
            systemImage: "sparkles",
            state: state,
            identifier: "setupCenter.eva"
        ) {
            SetupCenterEvaStateSection(
                accessState: accessState,
                progressCaption: progressCaption,
                errorMessage: errorMessage,
                grants: grants,
                action: action,
                onDecline: onDecline,
                onChooseOffline: onChooseOffline
            )
        }
    }
}

/// EVA's activation state machine, in its own frame.
struct SetupCenterEvaStateSection: View {
    let accessState: EvaCloudAccessState
    let progressCaption: String?
    let errorMessage: String?
    let grants: [(grant: EvaConsentPolicy.Grant, title: String, isOn: Binding<Bool>)]
    let action: SetupCenterAction?
    let onDecline: () -> Void
    let onChooseOffline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch accessState {
            case .needsDisclosure:
                SetupCenterEvaGrantsSection(grants: grants)
                SetupCenterCardAction(action: action)
                Button("Not now", action: onDecline)
                    .buttonStyle(.lifeBoardChip)
            case .hydrating, .activating:
                ProgressView(progressCaption ?? "Checking Cloud EVA…")
                    .lifeboardFont(.caption1)
                    .accessibilityIdentifier("setupCenter.eva.progress")
            case .temporarilyUnavailable(let message):
                Text(errorMessage ?? message)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                    .fixedSize(horizontal: false, vertical: true)
                SetupCenterCardAction(action: action)
                Button("Use Offline EVA", action: onChooseOffline)
                    .buttonStyle(.lifeBoardChip)
            case .appleReauthenticationRequired:
                Text("Apple confirmation restores this linked account. LifeBoard won't replace it with a new guest.")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                SetupCenterCardAction(action: action)
                Button("Use Offline EVA", action: onChooseOffline)
                    .buttonStyle(.lifeBoardChip)
            case .quotaExhausted(let nextAvailableAt):
                Text(quotaMessage(nextAvailableAt))
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                SetupCenterCardAction(action: action)
            case .ageBlocked(let message):
                Text(message)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                    .fixedSize(horizontal: false, vertical: true)
                SetupCenterCardAction(action: action)
            case .ready:
                Label("Cloud EVA is ready", systemImage: "checkmark.circle.fill")
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(Color.lifeboard(.statusSuccess))
            }

            if let errorMessage, accessState.showsStandaloneError {
                Text(errorMessage)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("setupCenter.eva.error")
            }
        }
    }

    private func quotaMessage(_ nextAvailableAt: Date?) -> String {
        nextAvailableAt.map {
            "Your rolling Cloud EVA allowance begins returning \($0.formatted(date: .omitted, time: .shortened))."
        } ?? "Your rolling Cloud EVA allowance is currently used."
    }
}

/// The consent toggles.
///
/// These stay real `Toggle`s so they keep reporting as switches to VoiceOver and
/// XCUITest; only the style changes.
struct SetupCenterEvaGrantsSection: View {
    let grants: [(grant: EvaConsentPolicy.Grant, title: String, isOn: Binding<Bool>)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompts and the context you confirm pass through LifeBoard's Cloudflare service to OpenAI. Guest credentials stay on this device; protect EVA with Apple to recover the cloud account after reinstalling.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(grants, id: \.grant) { entry in
                Toggle(entry.title, isOn: entry.isOn)
                    .toggleStyle(.lifeBoardClay)
                    .accessibilityIdentifier("setupCenter.eva.grant.\(entry.grant.rawValue)")
            }
        }
    }
}

private extension EvaCloudAccessState {
    /// The failure states already render the message inline; repeating it below
    /// would say the same thing twice.
    var showsStandaloneError: Bool {
        switch self {
        case .temporarilyUnavailable, .ageBlocked: false
        case .needsDisclosure, .hydrating, .activating, .appleReauthenticationRequired, .quotaExhausted, .ready: true
        }
    }
}
