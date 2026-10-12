import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// Where habit reminders, widgets, deep links and Eva references land, so it
/// opens the full habit screen. It used to be a read-only summary whose only
/// action switched to the Track tab without opening the habit.
struct HabitRouteView: View {
    let id: UUID
    let repository: (any HabitRuntimeReadRepositoryProtocol)?
    @Environment(\.habitViewModelFactory) private var habitViewModelFactory
    @State private var state: RouteLoadState<HabitLibraryRow> = .loading
    /// Made once per load. Building it in `body` would make a throwaway view
    /// model on every render, since only the first reaches the `@StateObject`.
    @State private var detailViewModel: HabitDetailViewModel?

    var body: some View {
        Group {
            if let detailViewModel {
                HabitDetailScreen(viewModel: detailViewModel, onMutation: {})
                    .environment(\.habitDetailShowsCloseButton, false)
                    .navigationTitle(String(localized: "Habit"))
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                EntityRouteScaffold(
                    title: String(localized: "Habit"),
                    systemImage: "repeat.circle",
                    state: state,
                    retry: { Task { await load() } }
                ) { _ in EmptyView() }
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        guard let repository else { state = .failed(String(localized: "Couldn’t load habit.")); return }
        state = .loading
        do {
            let row = try await withCheckedThrowingContinuation { continuation in
                repository.fetchHabitDetailSummary(habitID: id, includeArchived: true) { continuation.resume(with: $0) }
            }
            state = row.map(RouteLoadState.loaded) ?? .missing
            if let row {
                // A revisit re-runs this task; the screen's `@StateObject`
                // would ignore a second view model anyway.
                if detailViewModel == nil {
                    detailViewModel = habitViewModelFactory.makeHabitDetailViewModel(row: row)
                }
            } else {
                detailViewModel = nil
            }
        } catch {
            // An already-open habit stays open; the error shows only when
            // there is nothing to show instead.
            state = .failed(error.localizedDescription)
        }
    }
}

struct TrackerRouteView: View {
    private struct Snapshot {
        let definition: TrackerDefinitionValue
        let entries: [TrackerEntryValue]
    }

    let id: UUID
    let repository: (any PhaseIIRepository)?
    @State private var state: RouteLoadState<Snapshot> = .loading

    var body: some View {
        EntityRouteScaffold(title: String(localized: "Tracker"), systemImage: "chart.bar.doc.horizontal", state: state) { snapshot in
            VStack(alignment: .leading, spacing: 16) {
                Text(snapshot.definition.title).font(.title2.weight(.semibold))
                LabeledContent("Type", value: snapshot.definition.kind.trackDisplayName)
                if let unit = snapshot.definition.unitLabel, unit.isEmpty == false {
                    LabeledContent("Unit", value: unit)
                }
                if let target = snapshot.definition.targetValue {
                    LabeledContent("Target", value: target.formatted())
                }
                if snapshot.entries.isEmpty {
                    StatusSurface(
                        state: .noRecord,
                        title: String(localized: "No entries yet"),
                        message: ""
                    )
                } else {
                    Text("Recent entries").font(.headline)
                    ForEach(snapshot.entries.prefix(30)) { entry in
                        HStack {
                            Text(Self.value(entry, unit: snapshot.definition.unitLabel))
                            Spacer()
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        guard let repository else { state = .failed(String(localized: "Couldn’t load tracker.")); return }
        do {
            async let definitions = repository.fetchTrackers()
            async let entries = repository.fetchTrackerEntries(trackerID: id)
            let (loadedDefinitions, loadedEntries) = try await (definitions, entries)
            guard let definition = loadedDefinitions.first(where: { $0.id == id }) else {
                state = .missing
                return
            }
            state = .loaded(Snapshot(definition: definition, entries: loadedEntries))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private static func value(_ entry: TrackerEntryValue, unit: String?) -> String {
        if let numeric = entry.numericValue {
            return [numeric.formatted(), unit].compactMap { $0 }.joined(separator: " ")
        }
        if let boolean = entry.booleanValue { return boolean ? String(localized: "Done") : String(localized: "Not done") }
        return String(localized: "Logged")
    }
}
