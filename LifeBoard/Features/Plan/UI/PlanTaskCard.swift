import SwiftUI
import UIKit

/// A task row.
///
/// This is the highest-leverage of the section extractions: it is rendered once
/// per task, so as a computed property it inlined its whole view value into the
/// parent's frame N times over. As a struct each row gets its own frame.
struct PlanTaskCard: View {
    let store: PlanStore
    let task: PlanningTaskSummary
    let planned: Bool
    let lens: PlanLens
    @Binding var selectedTaskIDs: Set<UUID>
    @Binding var pendingBacklogDeletionTaskIDs: Set<UUID>
    @Binding var showsBacklogDeletionConfirmation: Bool
    @Binding var pendingFocusSetup: FocusSetupContext?
    let onOpenTask: (UUID) -> Void

    private var metadataLine: String {
        var values: [String] = [task.estimatedDuration.map(PlanSectionCopy.duration) ?? "Estimate incomplete"]
        if let due = task.dueDate { values.append("Due \(due.formatted(date: .abbreviated, time: .omitted))") }
        if task.metadata.availability != .actionable { values.append(task.metadata.availability.rawValue.capitalized) }
        if !task.dependenciesReady { values.append("Waiting on dependency") }
        return values.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
            if V2FeatureFlags.lifeBoardDailyLoopV1Enabled {
                // `tasks` comes from `fetchOpenPlanningTasks()`, so a row on
                // screen is always incomplete; the control's job here is to
                // make it complete, and the row leaves on the next load.
                CompletionControl(
                    isComplete: false,
                    title: task.title,
                    isEnabled: task.dependenciesReady
                ) { _ in
                    Task { await store.setCompletion(task, to: true) }
                }
                .padding(.leading, -11)
            } else {
                Image(systemName: task.dependenciesReady ? "circle" : "lock.circle")
                    .foregroundStyle(
                        task.dependenciesReady
                            ? Color(SemanticColorTokens.inkTertiary)
                            : Color(SemanticColorTokens.foundationApricotAccent)
                    )
            }
            // The body opens the task. It previously did nothing at all: the card
            // was a plain `VStack`, the menu offered no Open, and `onOpenTask` was
            // reachable only from the task-library sheet — so Plan could not reach
            // the canonical task route despite the Stage 2 ledger claiming every
            // row did. Being a real control is also what lets the backlog test's
            // `app.buttons["plan.task.*"]` query resolve.
            Button {
                onOpenTask(task.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(task.title).font(.body.weight(.medium)).lineLimit(2)
                        if task.metadata.commitmentLevel == .mustDo {
                            Text("MUST DO").font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Color(SemanticColorTokens.foundationApricotAccent).opacity(0.22), in: Capsule())
                        }
                    }
                    Text(metadataLine)
                        .font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("plan.task.\(task.id.uuidString)")
            .accessibilityHint("Opens the task")
            Menu {
                if lens == .backlog {
                    Button(selectedTaskIDs.contains(task.id) ? "Deselect" : "Select", systemImage: selectedTaskIDs.contains(task.id) ? "checkmark.circle.fill" : "circle") {
                        if selectedTaskIDs.contains(task.id) { selectedTaskIDs.remove(task.id) }
                        else { selectedTaskIDs.insert(task.id) }
                    }
                }
                Button(planned ? "Remove from day" : "Plan for this day", systemImage: "calendar") {
                    Task { await store.updateTask(task, planningDay: planned ? nil : store.selectedDay) }
                }
                Button(task.metadata.commitmentLevel == .mustDo ? "Make standard" : "Mark Must Do", systemImage: "exclamationmark.circle") {
                    Task { await store.updateTask(task, preserveDay: true, commitment: task.metadata.commitmentLevel == .mustDo ? .standard : .mustDo) }
                }
                Button("Waiting", systemImage: "hourglass") { Task { await store.updateTask(task, preserveDay: true, availability: .waiting) } }
                Button("Paused", systemImage: "pause.circle") { Task { await store.updateTask(task, preserveDay: true, availability: .paused) } }
                if task.metadata.unscheduledDisposition == .archived {
                    Button("Restore to inbox", systemImage: "tray.and.arrow.up") {
                        Task { await store.bulkUpdate([task.id], disposition: .inbox) }
                    }
                } else {
                    Button("Archive", systemImage: "archivebox") {
                        Task { await store.bulkUpdate([task.id], disposition: .archived) }
                    }
                }
                if lens == .backlog {
                    Divider()
                    Button("Delete from LifeBoard", systemImage: "trash", role: .destructive) {
                        pendingBacklogDeletionTaskIDs = [task.id]
                        showsBacklogDeletionConfirmation = true
                    }
                }
                Button("Start focus", systemImage: "timer") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    pendingFocusSetup = .init(
                        taskID: task.id,
                        timeBlockID: nil,
                        title: task.title,
                        suggestedDuration: task.estimatedDuration ?? 25 * 60,
                        subtaskID: nil
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Actions for \(task.title)")
            .accessibilityIdentifier("plan.taskMenu.\(task.id.uuidString)")
            }
            if let suggestion = store.calibrationSuggestions[task.id] {
                PlanCalibrationSuggestionRow(store: store, suggestion: suggestion)
            }
        }
        // An open row, not a card. DESIGN.md reserves cards for one decision,
        // one summary, or one independently movable widget; a task row is none
        // of those, and a ten-task day rendered as ten raised cards leaves no
        // canvas at all — the exact "card wall" the redesign calls out.
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // `.foundationClayCard()` used to supply both the hit region and the
        // full-width frame that `.draggable` and the day canvas's drop targets
        // depend on. Without a surface behind it, the row has to say so itself
        // or dragging only starts from the glyphs.
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(SemanticColorTokens.foundationHairline))
                .frame(height: 1)
        }
        .draggable(task.id.uuidString)
        // Pairs with the `lifeBoardZoomDestination` already on the canonical task
        // route, so opening a task grows out of the card you tapped rather than
        // sliding in from the edge as an unrelated screen.
        .lifeBoardTransitionSource("route.task.\(task.id.uuidString)")
    }
}

// MARK: - Week lens
