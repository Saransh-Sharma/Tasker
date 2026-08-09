import SwiftUI

// Gaps in the day and what the timeline offers to put in them.

// MARK: - TimelineGapExtension

extension TimelineGap {
    var compactDurationText: String {
        TimelineFormatting.durationText(duration)
    }
}

// MARK: - TimelineGapPrompt

struct TimelineGapPrompt: View {
    let gap: TimelineGap
    let row: TimelineRenderableRow
    let suggestedDate: Date
    let onAddTask: () -> Void
    let onPlanBlock: () -> Void
    @Environment(\.lifeboardLayoutClass) var layoutClass

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: gap.emphasis == .quietWindow ? "moon.zzz" : "clock")
                    .font(ClayTypography.meta)
                    .foregroundStyle(TimelineVisualTokens.utilityText)
                    .accessibilityHidden(true)
                timelineGapPromptText(for: gap, row: row)
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Add task", systemImage: "plus", action: onAddTask)
            .buttonStyle(.plain)
            .font(.lifeboard(.caption1).weight(.semibold))
            .foregroundStyle(Color.lifeboard.textSecondary)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minWidth: 44, minHeight: 44)
            .background(Color.lifeboard.surfaceSecondary.opacity(0.58), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.56), lineWidth: 1)
            }
            .contentShape(Capsule())
            .accessibilityLabel("Add task at \(suggestedDate.formatted(date: .omitted, time: .shortened))")
            .accessibilityHint("Opens Add Task with this timeline time.")
            .accessibilityIdentifier("home.timeline.gap.createTask")

            Menu {
                Button("Place inbox with Compass", action: onPlanBlock)
                Button(TimelineGapAction.dismiss.title, role: .destructive) {}
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(ClayTypography.bodyStrong)
                    .foregroundStyle(TimelineVisualTokens.utilityText)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Open time options")
        }
        .padding(.vertical, layoutClass.isPad ? 6 : 8)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - TimelineLongGapIndicator

struct TimelineLongGapIndicator: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(TimelineVisualTokens.utilityText.opacity(0.75))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - TimelinePlacementDock

struct TimelinePlacementDock: View {
    let candidate: TimelinePlacementCandidate
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.lifeboardScrollOptimizedRendering) var scrollOptimizedRendering
    @State var isDragging = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .accessibilityHidden(true)
            Text(candidate.title)
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("Drag to place")
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isDragging ? Color.lifeboard.accentWash.opacity(0.9) : Color.lifeboard.surfaceSecondary, in: Capsule())
        .overlay(
            Capsule()
                .stroke(isDragging ? Color.lifeboard.accentPrimary.opacity(0.42) : Color.lifeboard.strokeHairline.opacity(0.7), lineWidth: 1)
        )
        .scaleEffect(isDragging && reduceMotion == false ? 1.018 : 1)
        .shadow(
            color: Color.lifeboard.accentPrimary.opacity(isDragging && scrollOptimizedRendering == false ? 0.16 : 0),
            radius: isDragging && scrollOptimizedRendering == false ? 14 : 0,
            x: 0,
            y: 8
        )
        .draggable(candidate.taskID.uuidString)
        .simultaneousGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { _ in
                    guard isDragging == false else { return }
                    withAnimation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.feedbackFast) {
                        isDragging = true
                    }
                    HapticFeedback.light()
                }
                .onEnded { _ in
                    withAnimation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.feedbackFast) {
                        isDragging = false
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(candidate.title), drag to place")
        .accessibilityIdentifier("home.needsReplan.placementDock")
    }
}

// MARK: - TimelinePlacementPrompt

struct TimelinePlacementPrompt: View {
    let candidate: TimelinePlacementCandidate
    let selectedDate: Date
    let suggestedTime: Date
    let onPlaceAtSuggestedTime: () -> Void
    let onPlaceAllDay: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void
    let onClearError: () -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeboardTokens) private var tokens
    var spacing: SemanticSpacingTokens { ThemeStore.shared.currentTheme.tokens.spacing }
    var corner: CornerTokens { ThemeStore.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.lifeboard.accentWash, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Place this in your day")
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    Text("Drop on a time or move it to All Day.")
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button("Back", action: onBack)
                    .font(.lifeboard(.support).weight(.semibold))
                    .disabled(candidate.isApplying)
            }

            if candidate.isApplying {
                ProgressView("Scheduling...")
                    .font(.lifeboard(.support).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
            }

            if let errorMessage = candidate.errorMessage {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(errorMessage)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    Spacer(minLength: 0)
                    Button("Dismiss", action: onClearError)
                        .font(.lifeboard(.support).weight(.semibold))
                }
                .padding(10)
                .background(Color.lifeboard.surfacePrimary.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            placementActions
        }
        .padding(14)
        .background(Color.lifeboard.accentWash.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.lifeboard.accentPrimary.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Place \(candidate.title) in \(selectedDate.formatted(.dateTime.weekday(.wide).month().day()))")
        .accessibilityAction(named: Text("Back to Replan")) {
            onBack()
        }
        .accessibilityAction(named: Text("Skip")) {
            onSkip()
        }
        .accessibilityAction(named: Text("Place at suggested time")) {
            onPlaceAtSuggestedTime()
        }
        .accessibilityAction(named: Text("Move to All Day")) {
            onPlaceAllDay()
        }
    }

    @ViewBuilder
    var placementActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                placementButton("Place at \(suggestedTime.formatted(date: .omitted, time: .shortened))", systemImage: "clock.badge.checkmark", emphasized: true, action: onPlaceAtSuggestedTime)
                placementButton("Move to All Day", systemImage: "calendar.badge.plus", emphasized: false, action: onPlaceAllDay)
                placementButton("Skip", systemImage: "forward.end.fill", emphasized: false, action: onSkip)
            }
        } else {
            HStack(spacing: 10) {
                placementButton("Place at \(suggestedTime.formatted(date: .omitted, time: .shortened))", systemImage: "clock.badge.checkmark", emphasized: true, action: onPlaceAtSuggestedTime)
                placementButton("Move to All Day", systemImage: "calendar.badge.plus", emphasized: false, action: onPlaceAllDay)
                placementButton("Skip", systemImage: "forward.end.fill", emphasized: false, action: onSkip)
            }
        }
    }

    func placementButton(_ title: String, systemImage: String, emphasized: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticFeedback.selection()
            action()
        }) {
            Label(title, systemImage: systemImage)
                .font(.lifeboard(.support).weight(.semibold))
                .foregroundStyle(emphasized ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                .frame(minHeight: 42)
                .padding(.horizontal, spacing.s12)
                .background(emphasized ? Color.lifeboard.actionPrimary : Color.lifeboard.surfacePrimary.opacity(0.82), in: RoundedRectangle(cornerRadius: corner.r2, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                        .stroke(emphasized ? Color.lifeboard.actionPrimary.opacity(0.2) : Color.lifeboard.strokeHairline.opacity(0.72), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .disabled(candidate.isApplying)
    }
}

// MARK: - TimelinePlanningShelf

struct TimelinePlanningShelf: View {
    let allDayItems: [TimelinePlanItem]
    let inboxItems: [TimelinePlanItem]
    let placementCandidate: TimelinePlacementCandidate?
    let selectedDate: Date
    let onTaskTap: (TimelinePlanItem) -> Void
    let onScheduleInbox: () -> Void
    let onPlaceReplanAllDay: (TimelinePlacementCandidate, Date) -> Void

    @State var isAllDayTargeted = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let placementCandidate {
                Button {
                    HapticFeedback.selection()
                    onPlaceReplanAllDay(placementCandidate, selectedDate)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isAllDayTargeted ? "calendar.badge.checkmark" : "calendar.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.lifeboard.accentPrimary)
                            .frame(width: 34, height: 34)
                            .background(Color.lifeboard.accentWash, in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isAllDayTargeted ? "Drop for All Day" : "Make All Day")
                                .font(.lifeboard(.support).weight(.semibold))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                            Text(placementCandidate.title)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(isAllDayTargeted ? Color.lifeboard.accentWash.opacity(0.82) : Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isAllDayTargeted ? Color.lifeboard.accentPrimary.opacity(0.46) : Color.lifeboard.strokeHairline.opacity(0.62), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .scaleEffect(isAllDayTargeted && reduceMotion == false ? 1.012 : 1)
                .dropDestination(for: String.self, action: { items, _ in
                    guard items.contains(placementCandidate.taskID.uuidString) else { return false }
                    HapticFeedback.success()
                    onPlaceReplanAllDay(placementCandidate, selectedDate)
                    return true
                }, isTargeted: { newValue in
                    isAllDayTargeted = newValue
                })
                .onChange(of: isAllDayTargeted) { _, newValue in
                    guard newValue else { return }
                    HapticFeedback.selection()
                }
                .accessibilityHint("Places the replanned task in the all-day row for this date.")
                .accessibilityIdentifier("home.needsReplan.hotZone.allDay")
            }

            if allDayItems.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    Text("All-day commitments")
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color.lifeboard.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(allDayItems) { item in
                                TimelineShelfItemCard(item: item) {
                                    onTaskTap(item)
                                }
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .accessibilityLabel("All-day commitments")
                    .accessibilityHint(allDayItems.count > 2 ? "Scroll horizontally to browse all all-day items." : "Double-tap an item to inspect it.")
                    .accessibilityIdentifier("home.timeline.allDayStrip")
                }
            }

            if inboxItems.isEmpty == false {
                TimelineInboxPlanningCard(
                    inboxItems: inboxItems,
                    onTaskTap: onTaskTap
                )
            }
        }
    }
}

// MARK: - TimelineEmptyStateActionTone

@MainActor
enum TimelineEmptyStateActionTone {
    case primary
    case secondary

    var foreground: Color {
        switch self {
        case .primary:
            return Color.lifeboard.accentOnPrimary
        case .secondary:
            return Color.lifeboard.accentPrimary
        }
    }

    var background: Color {
        switch self {
        case .primary:
            return Color.lifeboard.accentPrimary
        case .secondary:
            return Color.lifeboard.accentWash.opacity(0.76)
        }
    }

    var border: Color {
        switch self {
        case .primary:
            return Color.lifeboard.accentPrimary.opacity(0.18)
        case .secondary:
            return Color.lifeboard.accentMuted.opacity(0.34)
        }
    }
}

// MARK: - TimelineEmptyStateCard

struct TimelineEmptyStateCard: View {
    let model: VisualTimelineElement.EmptyStateModel
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Spacer(minLength: 0)

            actionButtons
        }
        .padding(14)
        .background(Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.62), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(model.showsCalendarAction ? "home.timeline.calendarHidden" : "home.timeline.emptyDay")
    }

    @MainActor
    var header: some View {
        HStack(alignment: .top, spacing: 12) {
            DecorImage(
                asset: model.showsCalendarAction ? .happySun : .cloud,
                size: 44,
                opacity: 0.9
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.lifeboard(.headline).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Text(model.subtitle)
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    @MainActor
    var actionButtons: some View {
        if dynamicTypeSize.isAccessibilitySize {
            actionButtonColumn
        } else {
            ViewThatFits(in: .horizontal) {
                actionButtonRow
                actionButtonColumn
            }
        }
    }

    @MainActor
    var actionButtonRow: some View {
        HStack(spacing: 10) {
            emptyStateActionButton(
                title: model.primaryTitle,
                tone: .secondary,
                action: primaryAction
            )
            emptyStateActionButton(
                title: model.secondaryTitle,
                tone: .primary,
                action: secondaryAction
            )
        }
    }

    @MainActor
    var actionButtonColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            emptyStateActionButton(
                title: model.primaryTitle,
                tone: .secondary,
                action: primaryAction
            )
            emptyStateActionButton(
                title: model.secondaryTitle,
                tone: .primary,
                action: secondaryAction
            )
        }
    }

    @MainActor
    func emptyStateActionButton(
        title: String,
        tone: TimelineEmptyStateActionTone,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.lifeboard(.buttonSmall))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .foregroundStyle(tone.foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(minHeight: 34)
                .background(tone.background, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(tone.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}

// MARK: - gapPromptTint

@MainActor
func gapPromptTint(for gap: TimelineGap) -> Color {
    switch gap.emphasis {
    case .openTime:
        return Color.lifeboard.accentPrimary
    case .prepWindow:
        return Color.lifeboard.statusWarning
    case .quietWindow:
        return Color.lifeboard.statusSuccess
    }
}

// MARK: - timelineGapPromptText

@MainActor
func timelineGapPromptText(for gap: TimelineGap, row: TimelineRenderableRow) -> Text {
    let duration = gap.compactDurationText
    let promptSource = gap.supportingText.localizedCaseInsensitiveContains(duration)
        ? gap.supportingText
        : "\(gap.supportingText) \(duration)"
    guard let range = promptSource.range(of: duration) else {
        return Text(promptSource)
    }

    let prefix = String(promptSource[..<range.lowerBound])
    let suffix = String(promptSource[range.upperBound...])
    let emphasizedDuration = Text(duration)
        .foregroundStyle(row.temporalState == .activeGap ? Color.lifeboard.textPrimary : gapPromptTint(for: gap))
        .font(.lifeboard(.callout).weight(.semibold))
    return Text("\(Text(prefix))\(emphasizedDuration)\(Text(suffix))")
}

// MARK: - timelineSuggestedAddDate

func timelineSuggestedAddDate(for gap: TimelineGap, now: Date, calendar: Calendar = .current) -> Date {
    guard gap.startDate <= now, now < gap.endDate else {
        return gap.startDate
    }

    let quarterHour: TimeInterval = 15 * 60
    let roundedInterval = ceil(now.timeIntervalSinceReferenceDate / quarterHour) * quarterHour
    let roundedDate = Date(timeIntervalSinceReferenceDate: roundedInterval)
    let latestInsideGap = gap.endDate.addingTimeInterval(-60)
    return min(max(roundedDate, gap.startDate), latestInsideGap)
}
