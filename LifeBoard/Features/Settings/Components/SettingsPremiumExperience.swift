import SwiftUI

struct SettingsSetupStatus: Equatable {
    struct Item: Identifiable, Equatable {
        enum State: Int, Equatable {
            case healthy
            case neutral
            case attention
        }

        let id: String
        let title: String
        let detail: String
        let systemImage: String
        let state: State
        let route: SettingsDetailRoute
    }

    let items: [Item]

    var visibleItems: [Item] {
        let actionable = items
            .filter { $0.state != .healthy }
            .sorted { $0.state.rawValue > $1.state.rawValue }
        return actionable.isEmpty ? Array(items.prefix(1)) : Array(actionable.prefix(2))
    }

    var title: String {
        let attentionCount = items.filter { $0.state == .attention }.count
        if attentionCount > 0 {
            return attentionCount == 1 ? String(localized: "Check 1 setting") : String(localized: "Check \(attentionCount) settings")
        }
        if items.contains(where: { $0.state == .neutral }) { return String(localized: "Finish setup") }
        return String(localized: "All set")
    }

    var subtitle: String {
        ""
    }
}

enum SettingsSetupStatusResolver {
    static func resolve(
        notificationPermissionGranted: Bool,
        notificationPermissionDenied: Bool,
        enabledNotificationCount: Int,
        calendarConnected: Bool,
        healthConnected: Bool,
        recoveryHealth: RecoveryStatus.Health
    ) -> SettingsSetupStatus {
        let reminders: SettingsSetupStatus.Item
        if notificationPermissionDenied {
            reminders = .init(
                id: "reminders",
                title: String(localized: "Notifications are off"),
                detail: String(localized: "Turn them on in Settings."),
                systemImage: "bell.slash.fill",
                state: .attention,
                route: .reminders
            )
        } else if notificationPermissionGranted {
            reminders = .init(
                id: "reminders",
                title: String(localized: "Reminders"),
                detail: enabledNotificationCount == 1 ? String(localized: "1 on") : String(localized: "\(enabledNotificationCount) on"),
                systemImage: "bell.badge.fill",
                state: .healthy,
                route: .reminders
            )
        } else {
            reminders = .init(
                id: "reminders",
                title: String(localized: "Reminders"),
                detail: String(localized: "Reminder times"),
                systemImage: "bell.fill",
                state: .neutral,
                route: .reminders
            )
        }

        let connectionCount = [calendarConnected, healthConnected].filter { $0 }.count
        let connections = SettingsSetupStatus.Item(
            id: "connections",
            title: String(localized: "Calendar & Health"),
            detail: connectionCount == 2
                ? String(localized: "Connected")
                : connectionCount == 1 ? String(localized: "1 of 2 connected") : String(localized: "Optional"),
            systemImage: connectionCount == 2 ? "link.badge.plus" : "link",
            state: connectionCount == 2 ? .healthy : .neutral,
            route: .calendarAndHealth
        )

        let recovery: SettingsSetupStatus.Item
        switch recoveryHealth {
        case .healthy:
            recovery = .init(
                id: "recovery",
                title: String(localized: "Data"),
                detail: String(localized: "Up to date"),
                systemImage: "checkmark.shield.fill",
                state: .healthy,
                route: .dataAndHelp
            )
        case .working:
            recovery = .init(
                id: "recovery",
                title: String(localized: "Data"),
                detail: String(localized: "Syncing…"),
                systemImage: "arrow.triangle.2.circlepath",
                state: .neutral,
                route: .dataAndHelp
            )
        case .attention, .unavailable:
            recovery = .init(
                id: "recovery",
                title: String(localized: "Check Recovery"),
                detail: String(localized: "Nothing was lost."),
                systemImage: "exclamationmark.shield.fill",
                state: .attention,
                route: .dataAndHelp
            )
        }

        return SettingsSetupStatus(items: [reminders, connections, recovery])
    }
}

extension SettingsDetailRoute {
    var summary: String {
        switch self {
        case .setupCenter: return String(localized: "Calendar, Health and Eva")
        case .planAndOrganize: return String(localized: "Week and timeline")
        case .calendarAndHealth: return String(localized: "Calendars and sync")
        case .eva: return String(localized: "Companion, memory and chat")
        case .reminders: return String(localized: "Reminders and summaries")
        case .lookAndFeel: return String(localized: "Atmosphere and motion")
        case .dataAndHelp: return String(localized: "Recovery and support")
        default: return title
        }
    }

    var systemImage: String {
        switch self {
        case .setupCenter: return "slider.horizontal.3"
        case .planAndOrganize: return "calendar.badge.clock"
        case .calendarAndHealth: return "heart.text.square.fill"
        case .eva: return "sparkles"
        case .reminders: return "bell.badge.fill"
        case .lookAndFeel: return "sun.max.fill"
        case .dataAndHelp: return "lifepreserver.fill"
        case .lifeManagement: return "square.grid.2x2.fill"
        case .llm: return "brain.head.profile.fill"
        case .chats: return "bubble.left.and.bubble.right.fill"
        case .models: return "cpu.fill"
        case .recovery: return "checkmark.shield.fill"
        case .notices: return "doc.text.fill"
        }
    }

    var tint: Color {
        switch self {
        case .setupCenter, .eva, .llm, .chats, .models:
            Color.lifeboard(.accentSecondary)
        case .calendarAndHealth:
            Color.lifeboard(.statusSuccess)
        case .reminders:
            Color.lifeboard(.statusWarning)
        default:
            Color.lifeboard(.accentPrimary)
        }
    }
}

struct SettingsHubHeading: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s8) {
            Text("Settings")
                .lifeboardFont(.screenTitle)
                .foregroundStyle(Color.lifeboard(.textPrimary))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.hub.heading")
    }
}

struct SettingsSetupStatusCard: View {
    let status: SettingsSetupStatus
    let onNavigate: (SettingsDetailRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s12) {
            HStack(alignment: .top, spacing: SwiftUITokens.spacing.s12) {
                Image(systemName: status.items.allSatisfy { $0.state == .healthy } ? "checkmark.circle.fill" : "heart.fill")
                    .lifeboardFont(.title2)
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
                    .frame(width: 36, height: 36)
                    .background(Color.lifeboard(.accentWash), in: Circle())

                VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s4) {
                    Text(status.title)
                        .lifeboardFont(.headline)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    if status.subtitle.isEmpty == false {
                        Text(status.subtitle)
                            .lifeboardFont(.caption1)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            ForEach(status.visibleItems) { item in
                Button {
                    Haptic.pick.play()
                    onNavigate(item.route)
                } label: {
                    HStack(spacing: SwiftUITokens.spacing.s12) {
                        Image(systemName: item.systemImage)
                            .lifeboardFont(.buttonSmall)
                            .foregroundStyle(foreground(for: item.state))
                            .frame(width: 28, height: 28)
                            .background(background(for: item.state), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .lifeboardFont(.bodyStrong)
                                .foregroundStyle(Color.lifeboard(.textPrimary))
                            Text(item.detail)
                                .lifeboardFont(.caption2)
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.lifeboard(.meta))
                            .foregroundStyle(Color.lifeboard(.textQuaternary))
                    }
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.status.\(item.id)")
            }
        }
        .padding(SwiftUITokens.spacing.s16)
        .background(Color.lifeboard(.surfacePrimary), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.lifeboard(.borderSubtle), lineWidth: 1)
        }
        .lifeboardElevation(.e1, cornerRadius: Radius.card, includesBorder: false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.setupStatus")
    }

    private func foreground(for state: SettingsSetupStatus.Item.State) -> Color {
        switch state {
        case .healthy: Color.lifeboard(.statusSuccess)
        case .neutral: Color.lifeboard(.textSecondary)
        case .attention: Color.lifeboard(.statusWarning)
        }
    }

    private func background(for state: SettingsSetupStatus.Item.State) -> Color {
        foreground(for: state).opacity(0.12)
    }
}

struct SettingsCategoryGroup: View {
    let selectedRoute: SettingsDetailRoute?
    let onNavigate: (SettingsDetailRoute) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(SettingsDetailRoute.categories.enumerated()), id: \.element) { index, route in
                SettingsCategoryButton(
                    route: route,
                    isSelected: route == selectedRoute,
                    onNavigate: onNavigate
                )
                if index < SettingsDetailRoute.categories.count - 1 {
                    Divider()
                        .padding(.leading, 64)
                }
            }
        }
        .padding(.horizontal, SwiftUITokens.spacing.s12)
        // `Radius.card` (20), not 24: the 24pt radius is the hero's, and it is
        // what carries a card and the hero it opens into as one silhouette.
        // A settings group is raised clay, so it uses the clay primitive rather
        // than a hand-rolled fill, stroke and elevation.
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.categoryGroup")
    }
}

private struct SettingsCategoryButton: View {
    let route: SettingsDetailRoute
    let isSelected: Bool
    let onNavigate: (SettingsDetailRoute) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bloomTrigger = 0

    var body: some View {
        Button {
            Haptic.pick.play()
            bloomTrigger &+= 1
            if LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) {
                onNavigate(route)
            } else {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(65))
                    onNavigate(route)
                }
            }
        } label: {
            HStack(spacing: SwiftUITokens.spacing.s12) {
                Image(systemName: route.systemImage)
                    .lifeboardFont(.headline)
                    .foregroundStyle(route.tint)
                    .frame(width: 38, height: 38)
                    .background(route.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(route.title)
                        .lifeboardFont(.bodyStrong)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text(route.summary)
                        .lifeboardFont(.caption2)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard(.textQuaternary))
            }
            .padding(.horizontal, SwiftUITokens.spacing.s8)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                isSelected ? route.tint.opacity(0.09) : Color.clear,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .lifeboardClayPressBloom(center: UnitPoint(x: 0.08, y: 0.5), trigger: bloomTrigger, tint: route.tint)
        }
        .buttonStyle(SettingsCategoryPressStyle())
        .lifeBoardTransitionSource(route.transitionID)
        .accessibilityIdentifier("settings.category.\(route.rawValue)")
    }
}

private struct SettingsCategoryPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 1 : 0)
            .animation(reduceMotion ? nil : LifeBoardAnimation.rolePress, value: configuration.isPressed)
    }
}

struct SettingsCategoryHeading: View {
    let route: SettingsDetailRoute

    var body: some View {
        HStack(alignment: .center, spacing: SwiftUITokens.spacing.s12) {
            Image(systemName: route.systemImage)
                .lifeboardFont(.title2)
                .foregroundStyle(route.tint)
                .frame(width: 44, height: 44)
                .background(route.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(route.title)
                    .lifeboardFont(.sectionTitle)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(route.summary)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.detail.heading.\(route.rawValue)")
    }
}

struct SettingsPadWelcome: View {
    let status: SettingsSetupStatus

    var body: some View {
        VStack(spacing: SwiftUITokens.spacing.s12) {
            Image(systemName: "slider.horizontal.3")
                .lifeboardFont(.display)
                .foregroundStyle(Color.lifeboard(.accentPrimary))
                .frame(width: 64, height: 64)
                .background(Color.lifeboard(.accentWash), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Text(status.title)
                .lifeboardFont(.sectionTitle)
                .foregroundStyle(Color.lifeboard(.textPrimary))
            Text("Choose a category.")
                .lifeboardFont(.callout)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SettingsLookAndFeelView: View {
    let preferences: PresentationPreferences
    @Binding var decorativeEffectsEnabled: Bool

    @Environment(\.lifeBoardAtmosphereSnapshot) private var atmosphereSnapshot
    @State private var daypartTrigger = 0

    private var resolvedDaypart: ResolvedDaypart {
        switch preferences.daypartSelection {
        case .automatic: preferences.resolvedDaypart()
        case .morning: .morning
        case .afternoon: .afternoon
        case .evening: .evening
        case .night: .night
        }
    }

    var body: some View {
        @Bindable var preferences = preferences
        VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s20) {
            VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s12) {
                ZStack(alignment: .bottomLeading) {
                    AdaptiveAtmosphere(
                        snapshot: previewSnapshot,
                        placement: .focusedPresentation,
                        requestedTier: preferences.renderingTier,
                        comfortProfile: preferences.comfortProfile
                    )
                    .lifeboardDaypartCrossDissolve(trigger: daypartTrigger, daypart: resolvedDaypart)

                    HStack(spacing: 8) {
                        Image(systemName: resolvedDaypart == .night ? "moon.stars.fill" : "sun.horizon.fill")
                        Text(resolvedDaypart.greeting.replacingOccurrences(of: "!", with: ""))
                    }
                    .font(.lifeboard(.caption1))
                    // The regular glass follows appearance, so its ink must too:
                    // fixed white sat on light glass over the morning preview.
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: false)
                    .padding(12)
                }
                .frame(height: 184)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                }
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Atmosphere preview, \(daypartName)")
                .accessibilityIdentifier("settings.appearance.atmosphere.preview")

                Text("Atmosphere")
                    .lifeboardFont(.headline)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text("Choose a time of day, or Auto.")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))

                // Was a chip row plus a scrub gesture on the preview above,
                // which divided one choice across two controls and got the
                // arithmetic wrong in the gesture: a hardcoded 320pt width, no
                // right-to-left mirroring, no Auto stop, and a Reduce Motion
                // guard that disabled the gesture itself rather than its
                // animation. The shared slider is the whole control.
                AtmosphereSlider(
                    selection: $preferences.daypartSelection,
                    resolvedDaypart: resolvedDaypart,
                    activeOverride: preferences.activeDaypartOverride
                )
                .onChange(of: preferences.daypartSelection) { _, _ in
                    daypartTrigger &+= 1
                }
            }
            .padding(SwiftUITokens.spacing.s16)
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)

            SettingsCard {
                SettingsToggleRow(
                    iconName: "figure.walk.motion",
                    title: "App motion",
                    subtitle: "iOS Reduce Motion always applies.",
                    isOn: $preferences.fullMotionEnabled,
                    accessibilityIdentifier: "settings.appearance.fullMotion.toggle"
                )
            }

            settingsPickerCard(
                title: "Motion",
                subtitle: comfortSubtitle,
                icon: "wind"
            ) {
                // Was `.pickerStyle(.segmented)`, the stock grey segmented control.
                // `OptionRail` is the design system's equivalent and keeps the
                // semantics: one selection, per-value accessibility identifiers,
                // and reflow at accessibility text sizes.
                OptionRail(
                    "Motion",
                    selection: $preferences.comfortProfile,
                    values: [.calm, .balanced, .playful],
                    identifierPrefix: "settings.lookAndFeel.comfort",
                    title: { profile in
                        switch profile {
                        case .calm: "Subtle"
                        case .balanced: "Balanced"
                        case .playful: "Playful"
                        }
                    },
                    showsLabel: false
                )
                .sensoryFeedback(.selection, trigger: preferences.comfortProfile)
            }

            settingsPickerCard(
                title: "Visual detail",
                subtitle: renderingSubtitle,
                icon: "circle.lefthalf.filled"
            ) {
                // Was `.pickerStyle(.segmented)`, the stock grey segmented control.
                // `OptionRail` is the design system's equivalent and keeps the
                // semantics: one selection, per-value accessibility identifiers,
                // and reflow at accessibility text sizes.
                OptionRail(
                    "Visual detail",
                    selection: $preferences.renderingTier,
                    values: [.static, .ambient2D, .enhanced3D],
                    identifierPrefix: "settings.lookAndFeel.rendering",
                    title: { tier in
                        switch tier {
                        case .static: "Still"
                        case .ambient2D: "Atmosphere"
                        case .enhanced3D: "Depth"
                        }
                    },
                    showsLabel: false
                )
                .sensoryFeedback(.selection, trigger: preferences.renderingTier)
            }

            SettingsCard {
                SettingsToggleRow(
                    iconName: "sparkles",
                    title: "Button shimmer",
                    subtitle: nil,
                    isOn: $decorativeEffectsEnabled,
                    accessibilityIdentifier: "settings.appearance.decorativeButtonEffects.toggle"
                )
            }
        }
    }

    private var previewSnapshot: AtmosphereSnapshot {
        let phase: CelestialPhase
        switch resolvedDaypart {
        case .morning: phase = .morning
        case .afternoon: phase = .midday
        case .evening: phase = .goldenHour
        case .night: phase = .night
        }
        return atmosphereSnapshot.replacingPhase(phase)
    }

    /// The daypart as a person says it, for VoiceOver.
    private var daypartName: String {
        switch resolvedDaypart {
        case .morning: String(localized: "Morning")
        case .afternoon: String(localized: "Afternoon")
        case .evening: String(localized: "Evening")
        case .night: String(localized: "Night")
        }
    }

    private var comfortSubtitle: String {
        switch preferences.comfortProfile {
        case .calm: String(localized: "Almost still")
        case .balanced: String(localized: "Smooth")
        case .playful: String(localized: "More bounce and shimmer")
        }
    }

    private var renderingSubtitle: String {
        switch preferences.renderingTier {
        case .static: String(localized: "Lowest energy use")
        case .ambient2D: ""
        case .enhanced3D: String(localized: "On supported devices")
        }
    }

    private func settingsPickerCard<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s12) {
            HStack(alignment: .top, spacing: SwiftUITokens.spacing.s12) {
                Image(systemName: icon)
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
                    .frame(width: 30, height: 30)
                    .background(Color.lifeboard(.accentWash), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .lifeboardFont(.bodyStrong)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    if subtitle.isEmpty == false {
                        Text(subtitle)
                            .lifeboardFont(.caption2)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
                }
            }
            content()
        }
        .padding(SwiftUITokens.spacing.s16)
        .background(Color.lifeboard(.surfacePrimary), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.lifeboard(.borderSubtle), lineWidth: 1)
        }
    }
}
