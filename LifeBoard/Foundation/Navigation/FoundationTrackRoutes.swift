import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

struct RoutineRouteView: View {
    private struct Snapshot {
        let definition: RoutineDefinition?
        let runs: [RoutineRun]
    }

    let id: UUID
    let repository: CoreDataTrackFoundationRepository?
    let router: AppRouter
    @State private var state: RouteLoadState<Snapshot> = .loading

    var body: some View {
        EntityRouteScaffold(title: "Routine", systemImage: "figure.mind.and.body", state: state) { snapshot in
            VStack(alignment: .leading, spacing: 14) {
                if let routine = snapshot.definition {
                    Text(routine.title).font(.title2.weight(.semibold))
                    LabeledContent("Version", value: "\(routine.version)")
                    ForEach(routine.steps.sorted(by: { $0.ordinal < $1.ordinal })) { step in
                        Label(step.title, systemImage: "circle")
                    }
                } else {
                    Label("Definition removed", systemImage: "archivebox")
                        .font(.headline)
                    Text("Historical runs remain readable with their saved routine version.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()
                Text("Run history").font(.headline)
                if snapshot.runs.isEmpty {
                    Text("No runs recorded yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.runs.prefix(30)) { run in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Label(run.status.rawValue.capitalized, systemImage: routineStatusSymbol(run.status))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Version \(run.versionSnapshot.version) · \(run.events.count)/\(run.versionSnapshot.steps.count) steps · \(routineDuration(run))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(SemanticColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
                Button("Open in Track", systemImage: "chart.bar.fill") { router.select(.track) }
                    .buttonStyle(.borderedProminent).tint(Color(SemanticColorTokens.inkPrimary))
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        guard let repository else { state = .failed("Routine data is unavailable."); return }
        do {
            async let routines = repository.fetchRoutines()
            async let runs = repository.fetchRoutineRuns(routineID: id)
            let (definitions, history) = try await (routines, runs)
            let definition = definitions.first(where: { $0.id == id })
            guard definition != nil || history.isEmpty == false else { state = .missing; return }
            state = .loaded(Snapshot(
                definition: definition,
                runs: history.sorted { $0.startedAt > $1.startedAt }
            ))
        }
        catch { state = .failed(error.localizedDescription) }
    }

    private func routineDuration(_ run: RoutineRun) -> String {
        let seconds = max(
            0,
            (run.endedAt ?? run.updatedAt).timeIntervalSince(run.startedAt)
                - run.effectivePausedDuration
        )
        let minutes = max(1, Int((seconds / 60).rounded()))
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }

    private func routineStatusSymbol(_ status: RoutineRunStatus) -> String {
        switch status {
        case .running: "play.circle"
        case .paused: "pause.circle"
        case .interrupted: "exclamationmark.circle"
        case .completed: "checkmark.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .abandoned: "xmark.circle"
        case .skipped: "forward.circle"
        }
    }
}

struct GoalRouteView: View {
    private struct ResolvedLink: Identifiable {
        let link: GoalLink
        let source: TypedSourcePickerItem?
        var id: UUID { link.id }
    }

    private struct HistoryPoint: Identifiable {
        let date: Date
        let progress: GoalProgressSnapshot
        var id: TimeInterval { date.timeIntervalSinceReferenceDate }
    }

    private struct Snapshot {
        let goal: GoalDefinition
        let links: [ResolvedLink]
        let current: GoalProgressSnapshot?
        let history: [HistoryPoint]
    }

    let id: UUID
    let repository: CoreDataTrackFoundationRepository?
    let sampleProvider: (any GoalSampleRepository)?
    let sourceRepository: any TypedSourcePickerRepository
    let router: AppRouter
    @State private var state: RouteLoadState<Snapshot> = .loading
    @State private var repairingLink: GoalLink?
    @State private var loadedGoal: GoalDefinition?
    @State private var showsEditor = false
    @State private var showsLinker = false
    @State private var confirmsDeletion = false
    @State private var actionError: String?

    var body: some View {
        EntityRouteScaffold(title: "Goal", systemImage: "target", state: state) { snapshot in
            VStack(alignment: .leading, spacing: 14) {
                let goal = snapshot.goal
                Text(goal.title).font(.title2.weight(.semibold))
                LabeledContent("Type", value: goal.type.rawValue.capitalized)
                LabeledContent("Target", value: goal.targetValue.map { "\($0.formatted()) \(goal.unitLabel ?? "")" } ?? "Completion")
                LabeledContent("Target date", value: goal.targetDate?.formatted(date: .abbreviated, time: .omitted) ?? "Flexible")

                Button(
                    snapshot.links.isEmpty ? "Link progress source" : "Link another source",
                    systemImage: "link.badge.plus"
                ) {
                    showsLinker = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .accessibilityIdentifier("goal.primaryAction")

                HStack(spacing: 10) {
                    Button("Edit goal", systemImage: "pencil") { showsEditor = true }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    Menu {
                        goalStatusActions(goal)
                        Button("Delete goal", systemImage: "trash", role: .destructive) {
                            confirmsDeletion = true
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                            .frame(minHeight: 44)
                    }
                }

                if let progress = snapshot.current {
                    Divider()
                    Text("Progress").font(.headline)
                    if let fraction = progress.progressFraction {
                        ProgressView(value: fraction)
                            .accessibilityValue(fraction.formatted(.percent.precision(.fractionLength(0))))
                        Text("\(fraction.formatted(.percent.precision(.fractionLength(0)))) · confidence \(progress.confidence.formatted(.percent.precision(.fractionLength(0))))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Progress is partial because linked evidence is missing.")
                            .foregroundStyle(.secondary)
                    }
                    Text(progress.nextUsefulAction)
                        .font(.subheadline)
                }

                Divider()
                Text("Linked sources").font(.headline)
                if snapshot.links.isEmpty {
                    Text("No sources linked yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.links) { resolved in
                        HStack(spacing: 10) {
                            Image(systemName: sourceKind(resolved.link.source).systemImage)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(resolved.source?.title ?? "Linked source unavailable")
                                    .font(.subheadline.weight(.medium))
                                Text(resolved.link.source.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if resolved.source == nil {
                                Button("Repair") { repairingLink = resolved.link }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }

                if snapshot.history.isEmpty == false {
                    Divider()
                    Text("30-day history").font(.headline)
                    ForEach(snapshot.history) { point in
                        HStack {
                            Text(point.date.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(point.progress.progressFraction?.formatted(.percent.precision(.fractionLength(0))) ?? "Partial")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .task(id: id) { await load() }
        .sheet(item: $repairingLink) { link in
            TypedSourcePickerView(
                title: "Repair linked source",
                kinds: [sourceKind(link.source)],
                repository: sourceRepository
            ) { source in
                Task { await repair(link, with: source) }
            }
        }
        .sheet(isPresented: $showsEditor) {
            if let loadedGoal {
                GoalComposer(existing: loadedGoal) { draft in
                    await save(goal: loadedGoal, draft: draft)
                }
            }
        }
        .sheet(isPresented: $showsLinker) {
            if let loadedGoal {
                GoalLinkComposer(goal: loadedGoal, sourcePickerRepository: sourceRepository) { source, sourceID in
                    Task {
                        do {
                            try await repository?.saveGoalLink(.init(goalID: loadedGoal.id, source: source, sourceID: sourceID))
                            SystemSurfaceRefresher.requestRefreshSoon()
                            await load()
                        } catch {
                            actionError = error.localizedDescription
                        }
                    }
                }
            }
        }
        .confirmationDialog("Delete this goal?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete goal", role: .destructive) { deleteGoal() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The goal and its progress links are removed. Linked source records are unchanged.")
        }
        .alert("Goal needs attention", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    private func load() async {
        guard let repository else { state = .failed("Goal data is unavailable."); return }
        do {
            async let goals = repository.fetchGoals()
            async let links = repository.fetchGoalLinks(goalID: id)
            let (definitions, resolvedLinks) = try await (goals, links)
            guard let goal = definitions.first(where: { $0.id == id }) else { state = .missing; return }
            loadedGoal = goal

            var candidates: [TypedSourceKind: [TypedSourcePickerItem]] = [:]
            for kind in Set(resolvedLinks.map { sourceKind($0.source) }) {
                candidates[kind] = (try? await sourceRepository.candidates(for: kind, query: "")) ?? []
            }
            let displayLinks = resolvedLinks.map { link in
                ResolvedLink(
                    link: link,
                    source: candidates[sourceKind(link.source)]?.first(where: { $0.id == link.sourceID })
                )
            }

            var current: GoalProgressSnapshot?
            var history: [HistoryPoint] = []
            if let sampleProvider {
                let service = DefaultGoalProgressService()
                let samples = try await sampleProvider.samples(for: resolvedLinks, asOf: Date())
                current = service.progress(for: goal, links: resolvedLinks, samples: samples)
                history = await progressHistory(goal: goal, links: resolvedLinks, provider: sampleProvider, service: service)
            }
            state = .loaded(Snapshot(goal: goal, links: displayLinks, current: current, history: history))
        }
        catch { state = .failed(error.localizedDescription) }
    }

    private func progressHistory(
        goal: GoalDefinition,
        links: [GoalLink],
        provider: any GoalSampleRepository,
        service: DefaultGoalProgressService
    ) async -> [HistoryPoint] {
        await withTaskGroup(of: HistoryPoint?.self) { group in
            let calendar = Calendar.current
            for offset in 0..<30 {
                guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
                group.addTask {
                    guard let samples = try? await provider.samples(for: links, asOf: date) else { return nil }
                    return HistoryPoint(date: date, progress: service.progress(for: goal, links: links, samples: samples))
                }
            }
            var values: [HistoryPoint] = []
            for await point in group {
                if let point { values.append(point) }
            }
            return values.sorted { $0.date > $1.date }
        }
    }

    private func repair(_ link: GoalLink, with source: TypedSourcePickerItem) async {
        guard let repository else { return }
        var repaired = link
        repaired.sourceID = source.id
        do {
            try await repository.saveGoalLink(repaired)
            repairingLink = nil
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func sourceKind(_ source: GoalLinkSource) -> TypedSourceKind {
        switch source {
        case .project: .project
        case .task: .task
        case .habit: .habit
        case .routine: .routine
        case .trackerMeasure: .trackerMeasure
        }
    }

    @ViewBuilder
    private func goalStatusActions(_ goal: GoalDefinition) -> some View {
        switch goal.effectiveStatus {
        case .active, .revised:
            Button("Pause goal", systemImage: "pause.circle") { transition(goal, to: .paused) }
            Button("Complete goal", systemImage: "checkmark.circle") { transition(goal, to: .completed) }
        case .paused:
            Button("Resume goal", systemImage: "play.circle") { transition(goal, to: .active) }
        case .completed, .archived:
            Button("Reactivate goal", systemImage: "arrow.uturn.backward.circle") { transition(goal, to: .active) }
        }
        if goal.effectiveStatus != .archived {
            Button("Archive goal", systemImage: "archivebox") { transition(goal, to: .archived) }
        }
    }

    private func save(goal: GoalDefinition, draft: GoalDraft) async -> Bool {
        guard let repository else { return false }
        do {
            _ = try await GoalLifecycleService(repository: repository).save(draft: draft, existing: goal)
            SystemSurfaceRefresher.requestRefreshSoon()
            await load()
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    private func transition(_ goal: GoalDefinition, to status: GoalStatus) {
        guard let repository else { return }
        Task {
            do {
                _ = try await GoalLifecycleService(repository: repository)
                    .transition(goal, to: status, reason: "Changed by user")
                SystemSurfaceRefresher.requestRefreshSoon()
                await load()
            } catch {
                actionError = error.localizedDescription
            }
        }
    }

    private func deleteGoal() {
        guard let repository else { return }
        Task {
            do {
                try await repository.deleteGoal(id: id)
                SystemSurfaceRefresher.requestRefreshSoon()
                router.pop(in: .track)
            } catch {
                actionError = error.localizedDescription
            }
        }
    }
}
