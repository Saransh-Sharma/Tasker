import SwiftUI
import UIKit

/// The `day` lens of `PlanRootView`.
///
/// Composed of one decision card, a presentation control, either the canvas or
/// the agenda, and the planned/unscheduled lists. Every piece of state stays
/// owned by the root and arrives as a `@Binding`, so switching lenses does not
/// reset it.
struct PlanDaySection: View {
    let store: PlanStore
    let lens: PlanLens
    @Binding var dayPresentation: PlanDayPresentation
    @Binding var scheduleGrouping: PlanScheduleGrouping
    @Binding var showsBlockComposer: Bool
    @Binding var showsWorkingHours: Bool
    @Binding var selectedTaskIDs: Set<UUID>
    @Binding var pendingBacklogDeletionTaskIDs: Set<UUID>
    @Binding var showsBacklogDeletionConfirmation: Bool
    @Binding var pendingFocusSetup: FocusSetupContext?
    @Binding var pendingFocusEndOutcome: FocusCompletionOutcome?
    @Binding var focusReflectionEnergy: Int
    @Binding var focusReflectionNote: String
    let onAskEva: () -> Void
    let onMakeItFit: () -> Void
    let onOpenTask: (UUID) -> Void
    let onOpenOverdueRescue: (OverdueRescueLaunchContext) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Restated from the root's `LazyVStack(spacing: 16)`; see the `-Onone`
        // note at the foot of `PlanRootView.swift` for why these
        // children live behind a struct at all.
        LazyVStack(spacing: 16) {
            if store.isLoading && store.daySnapshot == nil {
                StatusSurface(
                    state: .loading,
                    title: "Building your day",
                    message: "Gathering commitments, blocks, and the next usable window."
                )
            } else if let errorMessage = store.errorMessage, store.daySnapshot == nil {
                StatusSurface(
                    state: .recoverableError,
                    title: "Your plan is still safe",
                    message: errorMessage,
                    actionTitle: "Try again",
                    action: { Task { await store.load() } }
                )
            } else if let snapshot = store.daySnapshot {
                decisionSlot(snapshot)
                PlanCalendarStateSection(store: store, snapshot: snapshot)

                dayPresentationControl
                if effectiveDayPresentation == .canvas {
                    PlanDayTimeCanvas(
                        snapshot: snapshot,
                        taskForID: store.task(for:),
                        createBlock: { title, start, duration, taskID in
                            Task { await store.createBlock(title: title, start: start, duration: duration, taskID: taskID) }
                        },
                        moveBlock: { block, minutes in Task { await store.moveBlock(block, minutesDelta: minutes) } },
                        resizeBlock: { block, minutes in Task { await store.resizeBlock(block, minutesDelta: minutes) } },
                        resizeBlockEdges: { block, start, end in
                            Task {
                                await store.resizeBlockEdges(
                                    block,
                                    startMinutesDelta: start,
                                    endMinutesDelta: end
                                )
                            }
                        },
                        splitBlock: { block in Task { await store.splitBlock(block) } },
                        deleteBlock: { block in Task { await store.deleteBlock(block) } },
                        startFocus: { block in
                            pendingFocusSetup = .init(
                                taskID: block.taskID,
                                timeBlockID: block.id,
                                title: block.title,
                                suggestedDuration: block.duration,
                                subtaskID: nil
                            )
                        }
                    )
                } else {
                    PlanScheduleSection(
                        store: store,
                        snapshot: snapshot,
                        scheduleGrouping: $scheduleGrouping,
                        showsBlockComposer: $showsBlockComposer,
                        pendingFocusSetup: $pendingFocusSetup
                    )
                }

                PlanSectionHeader("Planned work", systemImage: "checklist")
                if snapshot.plannedTasks.isEmpty {
                    PlanOpenDayRescueCard(store: store, onOpenOverdueRescue: onOpenOverdueRescue)
                } else {
                    ForEach(snapshot.plannedTasks) { taskCard($0, planned: true).lifeBoardScrollEntrance() }
                }

                PlanSectionHeader("Unscheduled", systemImage: "tray")
                ForEach(snapshot.unscheduledTasks.prefix(8)) { taskCard($0, planned: false).lifeBoardScrollEntrance() }
            }
        }
    }

    /// One decision at a time.
    ///
    /// These five could all render at once — an active focus session, a
    /// reflection waiting to be filed, a staged scenario, drifted work, and an
    /// overloaded capacity budget — giving Plan five competing prominent cards,
    /// several with their own primary button. Ordered by what is most immediate
    /// to the person rather than by what is most interesting to the app, the
    /// same shape `rebuildHero` already uses on Home.
    ///
    /// Nothing is lost by not drawing: capacity still reads in the header, the
    /// staged scenario stays staged, and drifted work is still listed below.
    /// Only the *ask* is deferred.
    @ViewBuilder
    private func decisionSlot(_ snapshot: PlanDaySnapshot) -> some View {
        if let session = store.activeFocusSession {
            PlanActiveFocusCard(
                store: store,
                session: session,
                pendingFocusEndOutcome: $pendingFocusEndOutcome
            )
        } else if let receipt = store.pendingFocusReflection {
            PlanFocusReflectionCard(
                store: store,
                receipt: receipt,
                focusReflectionEnergy: $focusReflectionEnergy,
                focusReflectionNote: $focusReflectionNote
            )
        } else if store.pendingScenario != nil {
            PlanMinimumViableDayCard(store: store)
        } else if store.repairProposals.isEmpty == false {
            PlanRepairDeck(proposals: store.repairProposals) { action, proposal in
                HapticFeedback.light()
                if action == .askEva {
                    onAskEva()
                } else if let proposal {
                    store.previewRepair(proposal, action: action)
                }
            }
        } else {
            // Always drawn once the other four are quiet, overloaded or not:
            // the capacity card holds the only entry to the working-hours
            // composer, so hiding it on a calm day would strand the editor for
            // the very inputs capacity is computed from.
            PlanCapacityCard(
                capacity: snapshot.capacity,
                showsWorkingHours: $showsWorkingHours,
                onMakeItFit: onMakeItFit
            )
        }
    }

    private var dayPresentationControl: some View {
        VStack(alignment: .leading, spacing: 7) {
            Picker("Day presentation", selection: $dayPresentation) {
                ForEach(PlanDayPresentation.allCases) { presentation in
                    Text(presentation.rawValue).tag(presentation)
                }
            }
            .pickerStyle(.segmented)
            .disabled(requiresAgendaPresentation)
            .accessibilityIdentifier("plan.day.presentation")
            if requiresAgendaPresentation {
                Text("Agenda keeps every block linear and operable.")
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
        }
    }

    private var requiresAgendaPresentation: Bool {
        voiceOverEnabled || dynamicTypeSize.isAccessibilitySize || reduceMotion
    }

    private var effectiveDayPresentation: PlanDayPresentation {
        requiresAgendaPresentation ? .agenda : dayPresentation
    }

    private func taskCard(_ task: PlanningTaskSummary, planned: Bool) -> some View {
        PlanTaskCard(
            store: store,
            task: task,
            planned: planned,
            lens: lens,
            selectedTaskIDs: $selectedTaskIDs,
            pendingBacklogDeletionTaskIDs: $pendingBacklogDeletionTaskIDs,
            showsBacklogDeletionConfirmation: $showsBacklogDeletionConfirmation,
            pendingFocusSetup: $pendingFocusSetup,
            onOpenTask: onOpenTask
        )
    }
}

/// Shown in place of the planned list when a day has nothing on it: the entry
/// point into Overdue Rescue.
struct PlanOpenDayRescueCard: View {
    let store: PlanStore
    let onOpenOverdueRescue: (OverdueRescueLaunchContext) -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                Image(decorative: AtmosphereDescriptor.descriptor(for: .midday).celestialAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("This day is open")
                        .font(.headline)
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    Text("Choose overdue work that still deserves a place.")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .foundationClayCard()
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .hoverEffect(.highlight)
        .accessibilityIdentifier("plan.day.openRescue")
        .accessibilityLabel("Plan this day with Overdue Rescue")
        .accessibilityHint("Review overdue tasks and keep, move, edit, or remove them.")
    }

    private func open() {
        let metadataByTaskID = Dictionary(uniqueKeysWithValues: store.tasks.map { ($0.id, $0.metadata) })
        let context = OverdueRescueLaunchContext.plan(
            selectedDay: store.selectedDay,
            planningMetadataByTaskID: metadataByTaskID
        )
        onOpenOverdueRescue(context)
        HapticFeedback.light()
    }
}
