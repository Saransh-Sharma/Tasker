import SwiftUI
import UIKit

/// The date/lens header above Plan's content: day stepping, the capacity
/// one-liner, and undo for the last planning mutation.
///
/// On Day this is the one place the day is named and changed. The canvas used
/// to carry a second ‹ › pair and a "Room in the day" card repeated the
/// capacity line, which put six layers above the first hour; the bar now owns
/// both, and the capacity line is the entry to working hours.
struct PlanOrientationBar: View {
    let store: PlanStore
    let lens: PlanLens
    var onEditWorkingHours: () -> Void = {}
    /// A quiet secondary action, never the hero: Eva over this day.
    var onAskEva: (() -> Void)? = nil
    var presentation: PresentationToggle?
    @State private var showsDatePicker = false

    /// Timeline and Agenda are two views of one day. Plan's root draws its own
    /// header and shows no navigation bar, so a toolbar item would be invisible;
    /// the switch lives here, next to the day it changes.
    struct PresentationToggle {
        let showsAgenda: Bool
        let isForced: Bool
        let toggle: () -> Void
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            if lens == .day {
                stepButton(-1, symbol: "chevron.left", label: "Previous day")
            }
            VStack(alignment: .leading, spacing: 4) {
                if lens == .day {
                    dayTitle
                    capacityLine
                } else {
                    Text(lens.rawValue)
                        .lifeboardFont(.headline)
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                }
            }
            .padding(.leading, lens == .day ? 0 : 12)
            Spacer(minLength: 8)
            if store.lastMutationReceiptID != nil {
                Button { Task { await store.undoLastMutation() } } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 44, height: 44)
                }
                // Not bare "Undo": a receipt's Undo is often on screen at the
                // same time, and two identical labels are indistinguishable.
                .accessibilityLabel("Undo last planning change")
                .accessibilityIdentifier("plan.header.undo")
            }
            if lens == .day {
                if isShowingToday == false {
                    Button("Today") {
                        Haptic.pick.play()
                        Task { await store.select(day: PlanningDay(date: Date())) }
                    }
                    .lifeboardFont(.buttonSmall)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Return to today")
                }
                stepButton(1, symbol: "chevron.right", label: "Next day")
                if let onAskEva {
                    Button {
                        Haptic.pick.play()
                        onAskEva()
                    } label: {
                        Image(systemName: "sparkles")
                            .lifeboardFont(.buttonSmall)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Ask Eva about today")
                    .accessibilityIdentifier("plan.header.askEva")
                }
                if let presentation {
                    Button {
                        Haptic.pick.play()
                        presentation.toggle()
                    } label: {
                        Image(systemName: presentation.showsAgenda ? "calendar.day.timeline.left" : "list.bullet")
                            .lifeboardFont(.buttonSmall)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(presentation.isForced)
                    .accessibilityLabel(presentation.showsAgenda ? "Show as timeline" : "Show as agenda")
                    .accessibilityHint(presentation.isForced ? "Agenda only at this setting" : "")
                    .accessibilityIdentifier("plan.day.presentation.toggle")
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .frame(minHeight: 56)
        // A containing element, so "plan.header" names the bar without being
        // stamped onto the controls inside it. Applied before the ambient
        // artwork, which draws past the bar: after it, the element's frame grew
        // to cover the lens picker above and swallowed its taps.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.header")
        .homeAmbientArtwork(.compactTimeline)
        .lifeBoardGlassSurface(cornerRadius: Radius.card, interactive: true)
    }

    private var dayTitle: some View {
        Button {
            Haptic.pick.play()
            showsDatePicker = true
        } label: {
            Text(PlanCapacityCopy.dayTitle(store.selectedDay))
                .lifeboardFont(.headline)
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .accessibilityHint("Choose a day")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: Task { await store.moveSelection(by: 1) }
            case .decrement: Task { await store.moveSelection(by: -1) }
            @unknown default: break
            }
        }
        .popover(isPresented: $showsDatePicker) {
            DatePicker(
                "Day",
                selection: Binding(
                    get: { store.selectedDay.startDate() ?? Date() },
                    set: { date in
                        showsDatePicker = false
                        Task { await store.select(day: PlanningDay(date: date)) }
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(16)
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityIdentifier("plan.header.day")
    }

    private var capacityLine: some View {
        let capacity = store.daySnapshot?.capacity
        let isOver = (capacity?.overloadDuration ?? 0) > 0
        return Button {
            Haptic.pick.play()
            onEditWorkingHours()
        } label: {
            // Over capacity carries its signal in an apricot glyph beside
            // primary ink: apricot text on grey clay did not reach body-text
            // contrast, so "1h 30m over" was the hardest line to read.
            HStack(spacing: 4) {
                if isOver {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color(SemanticColorTokens.foundationApricotInk))
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
                Text(capacity.map(PlanCapacityCopy.openLabel) ?? String(localized: "Loading…"))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(
                        isOver
                            ? Color(SemanticColorTokens.inkPrimary)
                            : Color(SemanticColorTokens.inkSecondary)
                    )
                    .lineLimit(1)
            }
            .lifeboardFont(.caption1)
            .animation(MotionProfile.localState.animation(reduceMotion: reduceMotion), value: capacity?.remainingKnownCapacity)
            .animation(MotionProfile.localState.animation(reduceMotion: reduceMotion), value: isOver)
        }
        .accessibilityHint("Opens working hours")
        .accessibilityIdentifier("plan.capacity.edit")
    }

    private var isShowingToday: Bool {
        store.selectedDay.startDate().map { Calendar.current.isDateInToday($0) } ?? true
    }

    private func stepButton(_ delta: Int, symbol: String, label: String) -> some View {
        Button {
            Haptic.pick.play()
            Task { await store.moveSelection(by: delta) }
        } label: {
            Image(systemName: symbol)
                .lifeboardFont(.buttonSmall)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

/// Plan-wide actions that have no other home at the root, whose navigation
/// bar is hidden: an open-ended focus session and a project from a template.
/// They sat in a toolbar nobody could see; they now sit beside the lens picker.
struct PlanActionsMenu: View {
    let onStartFocus: () -> Void
    let onNewProjectFromTemplate: () -> Void

    var body: some View {
        Menu {
            Button {
                onStartFocus()
            } label: {
                Label("Start focus", systemImage: "timer")
            }
            .accessibilityIdentifier("plan.focus.startUnscoped")
            Button {
                onNewProjectFromTemplate()
            } label: {
                Label("Project from template", systemImage: "folder.badge.plus")
            }
            .accessibilityIdentifier("plan.projectTemplates.open")
        } label: {
            Image(systemName: "ellipsis.circle")
                .lifeboardFont(.headline)
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More plan actions")
        .accessibilityIdentifier("plan.more")
    }
}

/// The words Plan uses for a day's room. "Known room" was our vocabulary, not
/// the person's; "open" and "over" are what they would say.
enum PlanCapacityCopy {
    static func openLabel(_ capacity: CapacityBudget) -> String {
        if capacity.workingDuration <= 0 { return String(localized: "No working hours set") }
        if capacity.overloadDuration > 0 { return String(localized: "\(duration(capacity.overloadDuration)) over") }
        // An explicit zero is a real answer, not missing data.
        return String(localized: "\(duration(capacity.remainingKnownCapacity)) open")
    }

    /// VoiceOver for the canvas's overload band. The band used to reuse
    /// `openLabel` and read "Over capacity: 1h 20m over past the end…".
    static func overloadAccessibilityLabel(_ capacity: CapacityBudget) -> String {
        let spoken = Duration.seconds(capacity.overloadDuration).formatted(.units(allowed: [.hours, .minutes], width: .wide))
        return String(localized: "\(spoken) past your working hours")
    }

    static func dayTitle(_ day: PlanningDay, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let date = day.startDate(calendar: calendar) else { return "Selected day" }
        let label = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        if calendar.isDate(date, inSameDayAs: now) { return "Today · \(label)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow · \(label)"
        }
        return label
    }

    static func duration(_ seconds: TimeInterval) -> String {
        LifeBoardDuration.text(seconds: max(0, seconds))
    }
}

/// What the slot between the header and the canvas holds, in the same priority
/// the old decision slot used. Resolved as a value so the order is tested
/// rather than implied by a chain of `if`s in a view body.
enum PlanDecisionLineKind: Equatable {
    case activeFocus
    case focusReflection
    case stagedScenario
    case repair(count: Int)
    case overCapacity
    case rescue(count: Int)
    case calendarPrompt
    case none

    static func resolve(
        hasActiveFocus: Bool,
        hasPendingReflection: Bool,
        hasStagedScenario: Bool,
        repairCount: Int,
        isOverCapacityToday: Bool,
        calendarNotRequested: Bool,
        rescueCount: Int = 0
    ) -> PlanDecisionLineKind {
        if hasActiveFocus { return .activeFocus }
        if hasPendingReflection { return .focusReflection }
        if hasStagedScenario { return .stagedScenario }
        if repairCount > 0 { return .repair(count: repairCount) }
        if isOverCapacityToday { return .overCapacity }
        // Work from earlier days comes before asking for calendar access: the
        // person's own unfinished work is the more useful first move. It keys
        // off that work existing, not off an empty plan — a day with one timed
        // task is not "open", but its earlier work still needs a decision.
        if rescueCount > 0 { return .rescue(count: rescueCount) }
        if calendarNotRequested { return .calendarPrompt }
        return .none
    }
}

/// One slim clay line that either acts or opens into the full card beneath it.
///
/// A decision stays one tap away without pushing the canvas below the fold;
/// a staged plan change is the exception and is always shown open, because it
/// is waiting on an answer.
struct PlanDecisionLine<Expanded: View>: View {
    let title: String
    let systemImage: String
    let actionTitle: String
    var isAlwaysExpanded = false
    var actionIdentifier: String?
    var action: (() -> Void)?
    @ViewBuilder let expanded: () -> Expanded
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isAlwaysExpanded == false {
                Button(action: tap) {
                    HStack(spacing: 12) {
                        Image(systemName: systemImage)
                            .foregroundStyle(Color(SemanticColorTokens.foundationApricotInk))
                            .accessibilityHidden(true)
                        Text(title)
                            .lifeboardFont(.support)
                            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                            .lineLimit(2)
                            // "4 things…" rolls to "3 things…" as work is decided.
                            .contentTransition(.numericText())
                            .animation(MotionProfile.localState.animation(reduceMotion: reduceMotion), value: title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(isExpanded ? "Hide" : actionTitle)
                            .lifeboardFont(.buttonSmall)
                            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        Image(systemName: action == nil ? "chevron.down" : "chevron.right")
                            .lifeboardFont(.caption2)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier(actionIdentifier ?? "plan.day.decisionLine.action")
            }
            if isAlwaysExpanded || isExpanded {
                expanded()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.day.decisionLine")
    }

    private func tap() {
        Haptic.pick.play()
        if let action {
            action()
        } else {
            withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
                isExpanded.toggle()
            }
        }
    }
}
