//
//  NeedsReplanCardOverlay.swift
//  LifeBoard
//

import SwiftUI
import UIKit

private enum ReplanHotZone: String, CaseIterable {
    case planToday
    case moveToInbox
    case complete
    case delete

    var title: String {
        switch self {
        case .planToday: return "Plan Today"
        case .moveToInbox: return "Inbox"
        case .complete: return "Complete"
        case .delete: return "Delete"
        }
    }

    var subtitle: String {
        switch self {
        case .planToday: return "Drop to place"
        case .moveToInbox: return "Clear date"
        case .complete: return "Done"
        case .delete: return "Remove"
        }
    }

    var systemImage: String {
        switch self {
        case .planToday: return "calendar.badge.plus"
        case .moveToInbox: return "tray.fill"
        case .complete: return "checkmark.circle.fill"
        case .delete: return "trash.fill"
        }
    }

    @MainActor
    var tint: Color {
        switch self {
        case .planToday: return Color.lifeboard.accentPrimary
        case .moveToInbox: return Color.lifeboard.stateInfo
        case .complete: return Color.lifeboard.statusSuccess
        case .delete: return Color.lifeboard.statusDanger
        }
    }

    var accessibilityIdentifier: String {
        "home.needsReplan.hotZone.\(rawValue)"
    }
}

private struct ReplanHotZoneTarget: View {
    let zone: ReplanHotZone
    let axis: Axis
    let isVisible: Bool
    let acceptsTaskID: UUID
    let onDrop: (ReplanHotZone) -> Void

    @Binding var isTargeted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        zoneContent
            .frame(maxWidth: axis == .horizontal ? nil : .infinity)
            .frame(width: axis == .horizontal ? 82 : nil)
            .frame(minHeight: axis == .horizontal ? 184 : 70)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible && isTargeted && reduceMotion == false ? 1.035 : 1)
            .background(backgroundShape)
            .overlay(borderShape)
            .allowsHitTesting(isVisible)
            .dropDestination(for: String.self, action: { items, _ in
                guard items.contains(acceptsTaskID.uuidString) else { return false }
                onDrop(zone)
                return true
            }, isTargeted: { newValue in
                isTargeted = newValue
            })
            .onChange(of: isTargeted) { _, newValue in
                guard newValue else { return }
                LifeBoardFeedback.selection()
            }
            .animation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.feedbackFast, value: isVisible)
            .animation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.feedbackFast, value: isTargeted)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(zone.title), \(zone.subtitle)")
            .accessibilityIdentifier(zone.accessibilityIdentifier)
    }

    private var zoneContent: some View {
        VStack(spacing: 5) {
            Image(systemName: zone.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .scaleEffect(isTargeted && reduceMotion == false ? 1.08 : 1)
            Text(zone.title)
                .font(.lifeboard(.caption1).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(zone.subtitle)
                .font(.lifeboard(.caption2))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(zone.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(zone.tint.opacity(isTargeted ? 0.18 : 0.1))
    }

    private var borderShape: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(
                differentiateWithoutColor || isTargeted ? zone.tint.opacity(0.72) : zone.tint.opacity(0.24),
                style: StrokeStyle(lineWidth: isTargeted ? 1.5 : 1, dash: differentiateWithoutColor ? [5, 4] : [])
            )
    }
}

struct NeedsReplanCardOverlay: View {
    let state: HomeReplanSessionState
    let onUndo: () -> Void
    let onSkip: () -> Void
    let onMoveToInbox: () -> Void
    let onReschedule: () -> Void
    let onCheckOff: () -> Void
    let onDelete: () -> Void
    let onClearError: () -> Void
    let onFeedback: (String) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDraggingTask = false
    @State private var planTargeted = false
    @State private var inboxTargeted = false
    @State private var completeTargeted = false
    @State private var deleteTargeted = false

    var body: some View {
        if let candidate = state.currentCandidate {
            ZStack {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("home.needsReplan.card")

                if dynamicTypeSize.isAccessibilitySize == false {
                    hotZoneLayer(for: candidate)
                }

                cardContent(for: candidate)
                    .scaleEffect(isDraggingTask && reduceMotion == false ? 1.018 : 1)
                    .shadow(color: Color.lifeboard.accentPrimary.opacity(isDraggingTask ? 0.16 : 0), radius: isDraggingTask ? 18 : 0, x: 0, y: 10)
                    .draggable(candidate.task.id.uuidString) {
                        dragPreview(for: candidate)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 3)
                            .onChanged { _ in
                                guard isDraggingTask == false else { return }
                                withAnimation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.panelIn) {
                                    isDraggingTask = true
                                }
                                LifeBoardFeedback.light()
                            }
                            .onEnded { _ in
                                resetDragState()
                            }
                    )
            }
        }
    }

    private func cardContent(for candidate: HomeReplanCandidate) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button("Undo", action: onUndo)
                            .disabled(state.canUndo == false || state.isApplying)
                        Spacer()
                        Text("\(max(state.candidateIndex, 1)) of \(max(state.candidateTotal, 1))")
                            .font(.lifeboard(.support).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                        Button("Skip", action: onSkip)
                            .disabled(state.isApplying)
                    }
                    .font(.lifeboard(.support).weight(.semibold))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(candidate.task.title)
                            .font(.lifeboard(.title2).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 3)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(originalLine(for: candidate))
                            .font(.lifeboard(.body))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .lineLimit(2)

                        if let projectName = candidate.projectName, projectName.isEmpty == false {
                            Text("Project: \(projectName)")
                                .font(.lifeboard(.support))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                                .lineLimit(2)
                        }

                        if candidate.task.replanCount >= 3 {
                            Text("Replanned \(candidate.task.replanCount)x")
                                .font(.lifeboard(.support).weight(.semibold))
                                .foregroundStyle(Color.lifeboard.statusWarning)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.lifeboard.statusWarning.opacity(0.12), in: Capsule())
                            Text("This keeps slipping. Consider shrinking it.")
                                .font(.lifeboard(.support))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                                .lineSpacing(1)
                        }
                    }

                    if state.isApplying {
                        ProgressView(applyingMessage)
                            .font(.lifeboard(.support).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                    }

                    if let errorMessage = state.errorMessage {
                        errorBanner(errorMessage)
                    }

                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 10) {
                            fullWidthAction("Reschedule", systemImage: "calendar.badge.clock", disabled: state.isApplying, action: onReschedule)
                            fullWidthAction("Move to Inbox", systemImage: "tray.fill", disabled: state.isApplying, action: onMoveToInbox)
                            fullWidthAction("Check Off", systemImage: "checkmark.circle.fill", disabled: state.isApplying, action: onCheckOff)
                            fullWidthAction("Delete", systemImage: "trash.fill", role: .destructive, disabled: state.isApplying, action: onDelete)
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            compactAction("Move to Inbox", systemImage: "tray.fill", disabled: state.isApplying, action: onMoveToInbox)
                            compactAction("Reschedule", systemImage: "calendar.badge.clock", emphasized: true, disabled: state.isApplying, action: onReschedule)
                            compactAction("Check Off", systemImage: "checkmark.circle.fill", disabled: state.isApplying, action: onCheckOff)
                            compactAction("Delete", systemImage: "trash.fill", role: .destructive, disabled: state.isApplying, action: onDelete)
                        }
                    }
                }
                .padding(18)
            }
            .frame(maxHeight: maxCardHeight)
            .background(Color.lifeboard.surfacePrimary.opacity(0.96), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 12)
            .accessibilityIdentifier("home.needsReplan.dragSource")
    }

    private func hotZoneLayer(for candidate: HomeReplanCandidate) -> some View {
        VStack(spacing: 10) {
            ReplanHotZoneTarget(
                zone: .planToday,
                axis: .vertical,
                isVisible: isDraggingTask,
                acceptsTaskID: candidate.task.id,
                onDrop: performDrop,
                isTargeted: $planTargeted
            )

            HStack {
                ReplanHotZoneTarget(
                    zone: .moveToInbox,
                    axis: .horizontal,
                    isVisible: isDraggingTask,
                    acceptsTaskID: candidate.task.id,
                    onDrop: performDrop,
                    isTargeted: $inboxTargeted
                )
                Spacer(minLength: 112)
                ReplanHotZoneTarget(
                    zone: .complete,
                    axis: .horizontal,
                    isVisible: isDraggingTask,
                    acceptsTaskID: candidate.task.id,
                    onDrop: performDrop,
                    isTargeted: $completeTargeted
                )
            }

            ReplanHotZoneTarget(
                zone: .delete,
                axis: .vertical,
                isVisible: isDraggingTask,
                acceptsTaskID: candidate.task.id,
                onDrop: performDrop,
                isTargeted: $deleteTargeted
            )
        }
        .padding(.horizontal, 4)
        .zIndex(2)
    }

    private func dragPreview(for candidate: HomeReplanCandidate) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.lifeboard.textSecondary)
            Text(candidate.task.title)
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.lifeboard.surfacePrimary, in: Capsule())
        .overlay(Capsule().stroke(Color.lifeboard.accentPrimary.opacity(0.26), lineWidth: 1))
    }

    private func performDrop(_ zone: ReplanHotZone) {
        resetDragState()
        switch zone {
        case .planToday:
            LifeBoardFeedback.selection()
            onFeedback("Drag into a time or All Day.")
            onReschedule()
        case .moveToInbox:
            LifeBoardFeedback.success()
            onFeedback("Moved to Inbox")
            onMoveToInbox()
        case .complete:
            LifeBoardFeedback.success()
            onFeedback("Marked complete")
            onCheckOff()
        case .delete:
            LifeBoardFeedback.warning()
            onFeedback("Deleted")
            onDelete()
        }
    }

    private func resetDragState() {
        withAnimation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.feedbackFast) {
            isDraggingTask = false
            planTargeted = false
            inboxTargeted = false
            completeTargeted = false
            deleteTargeted = false
        }
    }

    private var maxCardHeight: CGFloat {
        min(UIScreen.main.bounds.height * (dynamicTypeSize.isAccessibilitySize ? 0.72 : 0.58), dynamicTypeSize.isAccessibilitySize ? 620 : 470)
    }

    private var applyingMessage: String {
        switch state.applyingAction {
        case .moveToInbox:
            return "Moving to Inbox..."
        case .reschedule:
            return "Scheduling..."
        case .checkOff:
            return "Marking complete..."
        case .delete:
            return "Deleting..."
        case .undo:
            return "Undoing..."
        case nil:
            return "Updating..."
        }
    }

    private func originalLine(for candidate: HomeReplanCandidate) -> String {
        switch candidate.kind {
        case .pastDue:
            guard let anchorDate = candidate.anchorDate else { return "Due date needs a plan" }
            if candidate.task.isAllDay || isDateOnly(anchorDate) {
                return "Due \(anchorDate.formatted(.dateTime.weekday(.wide).month().day()))"
            }
            return "Due \(anchorDate.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))"
        case .scheduledCarryOver:
            guard let anchorDate = candidate.anchorDate else { return "Scheduled on a past day" }
            if candidate.task.isAllDay || isDateOnly(anchorDate) {
                return "Scheduled \(anchorDate.formatted(.dateTime.weekday(.wide).month().day()))"
            }
            return "Scheduled \(anchorDate.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))"
        case .unscheduledBacklog:
            return "No due date or time • Added \(candidate.task.createdAt.formatted(.dateTime.weekday(.wide).month().day()))"
        }
    }

    private func isDateOnly(_ date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) == 0 && (components.minute ?? 0) == 0 && (components.second ?? 0) == 0
    }

    private func fullWidthAction(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.lifeboard(.buttonSmall))
                .foregroundStyle(role == .destructive ? Color.lifeboard.statusDanger : Color.lifeboard.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(minHeight: 46)
                .background(actionFill(role: role, emphasized: title == "Reschedule"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(actionStroke(role: role, emphasized: title == "Reschedule"), lineWidth: 1)
                )
                .accessibilityIdentifier(actionAccessibilityIdentifier(title))
        }
        .accessibilityIdentifier(actionAccessibilityIdentifier(title))
        .buttonStyle(.plain)
        .scaleOnPress()
        .disabled(disabled)
    }

    private func compactAction(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        emphasized: Bool = false,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            if emphasized {
                Button(role: role, action: action) {
                    Label(title, systemImage: systemImage)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.accentOnPrimary)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.lifeboard.actionPrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityIdentifier(actionAccessibilityIdentifier(title))
                }
                .buttonStyle(.plain)
            } else {
                Button(role: role, action: action) {
                    Label(title, systemImage: systemImage)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(role == .destructive ? Color.lifeboard.statusDanger : Color.lifeboard.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(actionFill(role: role, emphasized: false), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(actionStroke(role: role, emphasized: false), lineWidth: 1)
                        )
                        .accessibilityIdentifier(actionAccessibilityIdentifier(title))
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityIdentifier(actionAccessibilityIdentifier(title))
        .disabled(disabled)
        .scaleOnPress()
    }

    private func actionFill(role: ButtonRole?, emphasized: Bool) -> Color {
        if emphasized { return Color.lifeboard.actionPrimary }
        if role == .destructive { return Color.lifeboard.statusDanger.opacity(0.1) }
        return Color.lifeboard.surfaceSecondary
    }

    private func actionStroke(role: ButtonRole?, emphasized: Bool) -> Color {
        if emphasized { return Color.lifeboard.actionPrimary.opacity(0.24) }
        if role == .destructive { return Color.lifeboard.statusDanger.opacity(0.28) }
        return Color.lifeboard.strokeHairline.opacity(0.78)
    }

    private func actionAccessibilityIdentifier(_ title: String) -> String {
        switch title {
        case "Move to Inbox": return "home.needsReplan.action.inbox"
        case "Reschedule": return "home.needsReplan.action.planToday"
        case "Check Off": return "home.needsReplan.action.complete"
        case "Delete": return "home.needsReplan.action.delete"
        default: return "home.needsReplan.action.\(title)"
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.lifeboard.statusWarning)
                .accessibilityHidden(true)
            Text(message)
                .font(.lifeboard(.support))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Dismiss", action: onClearError)
                .font(.lifeboard(.support).weight(.semibold))
        }
        .padding(12)
        .background(Color.lifeboard.surfaceSecondary.opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
