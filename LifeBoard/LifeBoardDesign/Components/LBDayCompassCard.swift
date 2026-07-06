import SwiftUI

struct LBDayCompassCard: View {
    let model: DayCompassCardModel
    let onPrimary: (DayCompassState) -> Void
    let onSnooze: (DayCompassFlow) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var allClearSealScale: CGFloat = 1

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UI_TESTING")
            || ProcessInfo.processInfo.arguments.contains("-DISABLE_ANIMATIONS")
    }

    var body: some View {
        let copy = copy(for: model.state)
        let style = LBColorTokens.role(copy.role)

        ZStack {
            LBGlassCard(
                cornerRadius: LBRadiusTokens.largeCard,
                borderColor: style.border,
                fill: style.softSurface.opacity(0.88)
            ) {
                HStack(alignment: .top, spacing: 0) {
                    Capsule()
                        .fill(style.base)
                        .frame(width: 4)
                        .padding(.vertical, LBSpacingTokens.xs)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
                        HStack(alignment: .top, spacing: LBSpacingTokens.sm) {
                            iconWell(copy, style: style)

                            VStack(alignment: .leading, spacing: LBSpacingTokens.xxs) {
                                Text(copy.eyebrow)
                                    .font(LBTypographyTokens.meta)
                                    .foregroundStyle(style.deep)
                                    .textCase(.uppercase)
                                Text(copy.title)
                                    .font(LBTypographyTokens.cardTitle)
                                    .foregroundStyle(LBColorTokens.navy)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(copy.subtitle)
                                    .font(LBTypographyTokens.body)
                                    .foregroundStyle(LBColorTokens.navyMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)

                            if let count = countBadge(for: model.state) {
                                Text("\(count)")
                                    .font(LBTypographyTokens.meta)
                                    .foregroundStyle(style.deep)
                                    .padding(.horizontal, LBSpacingTokens.sm)
                                    .padding(.vertical, LBSpacingTokens.xxs)
                                    .background(style.base.opacity(0.14), in: Capsule())
                                    .accessibilityHidden(true)
                            }
                        }

                        if copy.isActionable {
                            actionRow(copy)
                        }
                    }
                    .padding(.leading, LBSpacingTokens.md)
                }
                .padding(LBSpacingTokens.md)
            }
            .id(model.state.flow)
            .transition(stateChangeTransition)
        }
        .animation(stateChangeAnimation, value: model.state.flow)
        .offset(x: dragOffset)
        .opacity(dragFadeOpacity)
        .gesture(dismissGesture)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: dragOffset)
        .contentShape(Rectangle())
        .onTapGesture {
            guard copy.isActionable == false else { return }
            onPrimary(model.state)
        }
        .onAppear {
            playAllClearMomentIfNeeded()
        }
        .onChange(of: model.state.flow) { _, _ in
            playAllClearMomentIfNeeded()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(copy.title). \(copy.subtitle)")
        .accessibilityHint(copy.isActionable ? Text(copy.primaryTitle) : Text(""))
        .accessibilityAction(named: Text(copy.isActionable ? copy.primaryTitle : String(localized: "Dismiss"))) {
            onPrimary(model.state)
        }
        .accessibilityAction(named: Text("Not now")) {
            guard copy.isActionable else { return }
            onSnooze(model.state.flow)
        }
        .accessibilityIdentifier("home.sunrise.dayCompass")
    }

    private func iconWell(_ copy: Copy, style: LBRoleStyle) -> some View {
        Image(systemName: copy.symbolName)
            .font(LBTypographyTokens.cardTitle)
            .foregroundStyle(style.deep)
            .frame(width: 42, height: 42)
            .background(style.base.opacity(0.16), in: Circle())
            .scaleEffect(isAllClear ? allClearSealScale : 1)
            .accessibilityHidden(true)
    }

    private var isAllClear: Bool {
        if case .allClear = model.state { return true }
        return false
    }

    /// The all-clear seal settles in with a small spring and a success haptic —
    /// one gentle reward, skipped under Reduce Motion and UI tests.
    private func playAllClearMomentIfNeeded() {
        guard isAllClear else { return }
        LifeBoardFeedback.success()
        guard reduceMotion == false, isUITesting == false else {
            allClearSealScale = 1
            return
        }
        allClearSealScale = 0.6
        withAnimation(.spring(duration: 0.45, bounce: 0.4)) {
            allClearSealScale = 1
        }
    }

    private var stateChangeTransition: AnyTransition {
        if reduceMotion || isUITesting {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 6)),
            removal: .opacity
        )
    }

    private var stateChangeAnimation: Animation? {
        if isUITesting { return nil }
        if reduceMotion { return .easeOut(duration: 0.12) }
        return .easeOut(duration: 0.24)
    }

    private var dragFadeOpacity: Double {
        guard dragOffset > 0 else { return 1 }
        return max(0.35, 1 - Double(dragOffset / 88) * 0.65)
    }

    private func countBadge(for state: DayCompassState) -> Int? {
        switch state {
        case .replan(let count, _) where count > 1:
            return count
        case .rescue(let count) where count > 1:
            return count
        case .inbox(let count) where count > 1:
            return count
        default:
            return nil
        }
    }

    @ViewBuilder
    private func actionRow(_ copy: Copy) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                primaryButton(copy)
                snoozeButton
            }
        } else {
            HStack(spacing: LBSpacingTokens.sm) {
                primaryButton(copy)
                snoozeButton
                Spacer(minLength: 0)
            }
        }
    }

    private func primaryButton(_ copy: Copy) -> some View {
        LBPrimaryButton(title: copy.primaryTitle, systemImage: copy.primarySymbol) {
            LifeBoardFeedback.medium()
            onPrimary(model.state)
        }
        .accessibilityIdentifier("home.sunrise.dayCompass.primary")
    }

    private var snoozeButton: some View {
        Button {
            LifeBoardFeedback.light()
            onSnooze(model.state.flow)
        } label: {
            Text("Not now")
                .font(LBTypographyTokens.chip)
                .foregroundStyle(LBColorTokens.navyMuted)
                .frame(minHeight: 48)
                .padding(.horizontal, LBSpacingTokens.md)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier("home.sunrise.dayCompass.snooze")
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard value.translation.width > 0 else { return }
                dragOffset = min(value.translation.width, 88)
            }
            .onEnded { value in
                if value.translation.width > 72 {
                    LifeBoardFeedback.light()
                    onSnooze(model.state.flow)
                }
                dragOffset = 0
            }
    }

    private func copy(for state: DayCompassState) -> Copy {
        switch state {
        case .replan(let count, let earliestTitle):
            let title = count == 1
                ? String(localized: "One item needs a place")
                : String(localized: "\(count) items need a place")
            let subtitle = earliestTitle.map { String(localized: "Start with \($0), then keep sorting what still matters.") }
                ?? String(localized: "Place unscheduled or displaced work before it competes with the rest of today.")
            return Copy(
                eyebrow: String(localized: "Replan"),
                title: title,
                subtitle: subtitle,
                primaryTitle: String(localized: "Start replan"),
                primarySymbol: "arrow.triangle.branch",
                symbolName: "arrow.triangle.2.circlepath",
                role: .warning
            )
        case .morningPlan(let openCount):
            let subtitle = openCount == 1
                ? String(localized: "Choose the one task that gives today a clear start.")
                : String(localized: "Choose the first few tasks before the day starts filling itself in.")
            return Copy(
                eyebrow: String(localized: "Morning"),
                title: String(localized: "Shape today"),
                subtitle: subtitle,
                primaryTitle: String(localized: "Plan the day"),
                primarySymbol: "list.bullet",
                symbolName: "sun.max.fill",
                role: .routine
            )
        case .eveningReview(let doneCount, let openCount):
            let doneText = doneCount == 1
                ? String(localized: "1 done")
                : String(localized: "\(doneCount) done")
            let openText = openCount == 1
                ? String(localized: "1 still open")
                : String(localized: "\(openCount) still open")
            return Copy(
                eyebrow: String(localized: "Evening"),
                title: String(localized: "Close the loop"),
                subtitle: String(localized: "\(doneText) today, \(openText). Reflect once and keep tomorrow lighter."),
                primaryTitle: String(localized: "Review"),
                primarySymbol: "checkmark.circle",
                symbolName: "moon.stars.fill",
                role: .windDown
            )
        case .rescue(let count):
            let subtitle = count == 1
                ? String(localized: "One overdue task needs a quick recovery decision.")
                : String(localized: "\(count) overdue tasks need quick recovery decisions.")
            return Copy(
                eyebrow: String(localized: "Recovery"),
                title: String(localized: "Sort what still matters"),
                subtitle: subtitle,
                primaryTitle: String(localized: "Open rescue"),
                primarySymbol: "lifepreserver",
                symbolName: "lifepreserver.fill",
                role: .warning
            )
        case .inbox(let count):
            let subtitle = count == 1
                ? String(localized: "One inbox task is ready to place.")
                : String(localized: "\(count) inbox tasks are ready to place.")
            return Copy(
                eyebrow: String(localized: "Inbox"),
                title: String(localized: "Give backlog a place"),
                subtitle: subtitle,
                primaryTitle: String(localized: "Place inbox"),
                primarySymbol: "tray.and.arrow.down",
                symbolName: "tray.full.fill",
                role: .task
            )
        case .resumeTask(let title, let minutes, _):
            return Copy(
                eyebrow: String(localized: "Resume"),
                title: String(localized: "Pick up where you left off"),
                subtitle: String(localized: "\(title) paused \(minutes) min ago."),
                primaryTitle: String(localized: "Resume"),
                primarySymbol: "play.fill",
                symbolName: "arrow.uturn.left.circle.fill",
                role: .focus
            )
        case .allClear(let flow):
            return Copy(
                eyebrow: String(localized: "Compass"),
                title: String(localized: "All clear"),
                subtitle: allClearSubtitle(after: flow),
                primaryTitle: "",
                primarySymbol: nil,
                symbolName: "checkmark.seal.fill",
                role: .task,
                isActionable: false
            )
        }
    }

    private func allClearSubtitle(after flow: DayCompassFlow) -> String {
        switch flow {
        case .replan:
            return String(localized: "Replan is tucked away for now.")
        case .morningPlan:
            return String(localized: "Today has a plan.")
        case .eveningReview:
            return String(localized: "The day is closed cleanly.")
        case .rescue:
            return String(localized: "Recovery is handled for now.")
        case .inbox:
            return String(localized: "Inbox placement is handled.")
        case .resumeTask:
            return String(localized: "Focus is back on the board.")
        }
    }
}

private struct Copy {
    let eyebrow: String
    let title: String
    let subtitle: String
    let primaryTitle: String
    let primarySymbol: String?
    let symbolName: String
    let role: LBRole
    var isActionable = true
}
