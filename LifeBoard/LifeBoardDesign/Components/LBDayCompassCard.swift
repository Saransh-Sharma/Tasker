import SwiftUI

struct LBDayCompassCard: View {
    let model: DayCompassCardModel
    let onPrimary: (DayCompassState) -> Void
    let onSnooze: (DayCompassFlow) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        let copy = copy(for: model.state)
        let style = LBColorTokens.role(copy.role)

        LBGlassCard(
            cornerRadius: LBRadiusTokens.largeCard,
            borderColor: style.border,
            fill: style.softSurface.opacity(0.88)
        ) {
            VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
                HStack(alignment: .top, spacing: LBSpacingTokens.sm) {
                    Image(systemName: copy.symbolName)
                        .font(LBTypographyTokens.cardTitle)
                        .foregroundStyle(style.deep)
                        .frame(width: 34, height: 34)
                        .background(style.base.opacity(0.14), in: Circle())
                        .accessibilityHidden(true)

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
                }

                if copy.isActionable {
                    actionRow(copy)
                }
            }
            .padding(LBSpacingTokens.md)
        }
        .offset(x: dragOffset)
        .gesture(dismissGesture)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: dragOffset)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(copy.title). \(copy.subtitle)")
        .accessibilityAction(named: Text(copy.primaryTitle)) {
            guard copy.isActionable else { return }
            onPrimary(model.state)
        }
        .accessibilityAction(named: Text("Not now")) {
            guard copy.isActionable else { return }
            onSnooze(model.state.flow)
        }
        .accessibilityIdentifier("home.dayCompass.card")
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
            onPrimary(model.state)
        }
        .accessibilityIdentifier("home.dayCompass.primary")
    }

    private var snoozeButton: some View {
        Button {
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
        .accessibilityIdentifier("home.dayCompass.snooze")
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard value.translation.width > 0 else { return }
                dragOffset = min(value.translation.width, 88)
            }
            .onEnded { value in
                if value.translation.width > 72 {
                    onSnooze(model.state.flow)
                }
                dragOffset = 0
            }
    }

    private func copy(for state: DayCompassState) -> Copy {
        switch state {
        case .replan(let count, let earliestTitle):
            let title = count == 1 ? "One item needs a place" : "\(count) items need a place"
            let subtitle = earliestTitle.map { "Start with \($0), then keep sorting what still matters." }
                ?? "Place unscheduled or displaced work before it competes with the rest of today."
            return Copy(
                eyebrow: "Compass",
                title: title,
                subtitle: subtitle,
                primaryTitle: "Start replan",
                primarySymbol: "arrow.triangle.branch",
                symbolName: "safari.fill",
                role: .assistant
            )
        case .morningPlan(let openCount):
            let subtitle = openCount == 1
                ? "Choose the one task that gives today a clear start."
                : "Choose the first few tasks before the day starts filling itself in."
            return Copy(
                eyebrow: "Morning",
                title: "Shape today",
                subtitle: subtitle,
                primaryTitle: "Plan the day",
                primarySymbol: "list.bullet",
                symbolName: "sun.max.fill",
                role: .routine
            )
        case .eveningReview(let doneCount, let openCount):
            let doneText = doneCount == 1 ? "1 done" : "\(doneCount) done"
            let openText = openCount == 1 ? "1 still open" : "\(openCount) still open"
            return Copy(
                eyebrow: "Evening",
                title: "Close the loop",
                subtitle: "\(doneText) today, \(openText). Reflect once and keep tomorrow lighter.",
                primaryTitle: "Review",
                primarySymbol: "checkmark.circle",
                symbolName: "moon.stars.fill",
                role: .windDown
            )
        case .rescue(let count):
            let subtitle = count == 1
                ? "One overdue task needs a quick recovery decision."
                : "\(count) overdue tasks need quick recovery decisions."
            return Copy(
                eyebrow: "Recovery",
                title: "Sort what still matters",
                subtitle: subtitle,
                primaryTitle: "Open rescue",
                primarySymbol: "lifepreserver",
                symbolName: "lifepreserver.fill",
                role: .warning
            )
        case .inbox(let count):
            let subtitle = count == 1
                ? "One inbox task is ready to place."
                : "\(count) inbox tasks are ready to place."
            return Copy(
                eyebrow: "Inbox",
                title: "Give backlog a place",
                subtitle: subtitle,
                primaryTitle: "Place inbox",
                primarySymbol: "tray.and.arrow.down",
                symbolName: "tray.full.fill",
                role: .task
            )
        case .resumeTask(let title, let minutes, _):
            return Copy(
                eyebrow: "Resume",
                title: "Pick up where you left off",
                subtitle: "\(title) paused \(minutes) min ago.",
                primaryTitle: "Resume",
                primarySymbol: "play.fill",
                symbolName: "arrow.uturn.left.circle.fill",
                role: .focus
            )
        case .allClear(let flow):
            return Copy(
                eyebrow: "Compass",
                title: "All clear",
                subtitle: allClearSubtitle(after: flow),
                primaryTitle: "",
                primarySymbol: nil,
                symbolName: "checkmark.circle.fill",
                role: .neutral,
                isActionable: false
            )
        }
    }

    private func allClearSubtitle(after flow: DayCompassFlow) -> String {
        switch flow {
        case .replan:
            return "Replan is tucked away for now."
        case .morningPlan:
            return "Today has a plan."
        case .eveningReview:
            return "The day is closed cleanly."
        case .rescue:
            return "Recovery is handled for now."
        case .inbox:
            return "Inbox placement is handled."
        case .resumeTask:
            return "Focus is back on the board."
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
