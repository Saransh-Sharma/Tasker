import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

struct HabitRouteView: View {
    let id: UUID
    let repository: (any HabitRuntimeReadRepositoryProtocol)?
    let router: AppRouter
    @State private var state: RouteLoadState<HabitLibraryRow> = .loading

    var body: some View {
        EntityRouteScaffold(title: String(localized: "Habit"), systemImage: "repeat.circle", state: state) { habit in
            VStack(alignment: .leading, spacing: 16) {
                Text(habit.title).font(.title2.weight(.semibold))
                LabeledContent("Area", value: habit.lifeAreaName)
                LabeledContent("Current streak", value: Self.days(habit.currentStreak))
                LabeledContent("Best streak", value: Self.days(habit.bestStreak))
                Label(habit.isPaused ? "Paused" : "Active", systemImage: habit.isPaused ? "pause.circle" : "checkmark.circle")
                if let notes = habit.notes, notes.isEmpty == false { Text(notes).font(.body).foregroundStyle(Color.lifeboard(.textSecondary)) }
                Button("Open in Track", systemImage: "chart.bar.fill") { router.select(.track) }
                    .buttonStyle(.lifeBoardPrimaryCompact)
                    .tint(Color(SemanticColorTokens.inkPrimary))
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        guard let repository else { state = .failed(String(localized: "Couldn’t load habit.")); return }
        do {
            let row = try await withCheckedThrowingContinuation { continuation in
                repository.fetchHabitDetailSummary(habitID: id, includeArchived: true) { continuation.resume(with: $0) }
            }
            state = row.map(RouteLoadState.loaded) ?? .missing
        } catch { state = .failed(error.localizedDescription) }
    }

    private static func days(_ count: Int) -> String {
        count == 1 ? String(localized: "1 day") : String(localized: "\(count) days")
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
