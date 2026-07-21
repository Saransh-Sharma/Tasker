import SwiftUI

// MARK: - Contract

/// The kinds of stable domain records that can back a goal or routine link. Mirrors
/// `GoalLinkSource` but is reused anywhere the UI must resolve a real record instead of
/// accepting a pasted UUID string.
public enum TypedSourceKind: String, CaseIterable, Hashable, Sendable {
    case task
    case project
    case habit
    case routine
    case trackerMeasure

    public var title: String {
        switch self {
        case .task: "Task"
        case .project: "Project"
        case .habit: "Habit"
        case .routine: "Routine"
        case .trackerMeasure: "Tracker"
        }
    }

    public var systemImage: String {
        switch self {
        case .task: "checkmark.circle"
        case .project: "folder"
        case .habit: "repeat"
        case .routine: "list.bullet.rectangle"
        case .trackerMeasure: "chart.bar"
        }
    }
}

/// A resolved, selectable record. Carries the stable identifier the domain expects plus a
/// human title, so the link editor never has to surface a raw UUID.
public struct TypedSourcePickerItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let kind: TypedSourceKind
    public let title: String
    public let subtitle: String?

    public init(id: UUID, kind: TypedSourceKind, title: String, subtitle: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
    }
}

/// Enumerates real candidate records for a given kind. Implementations degrade gracefully:
/// a missing backing repository yields an empty list rather than an error.
public protocol TypedSourcePickerRepository: Sendable {
    func candidates(for kind: TypedSourceKind, query: String) async throws -> [TypedSourcePickerItem]
}

// MARK: - Composed implementation over existing domain repositories

/// Composes the domain read APIs already present in the shell. No new store; purely derived.
public struct ComposedTypedSourcePickerRepository: TypedSourcePickerRepository {
    private let planningProjection: (any PlanningProjectionRepository)?
    private let trackFoundation: (any TrackFoundationRepository)?
    private let phaseII: (any LifeBoardPhaseIIRepository)?
    private let habitRuntime: (any HabitRuntimeReadRepositoryProtocol)?

    public init(
        planningProjection: (any PlanningProjectionRepository)? = nil,
        trackFoundation: (any TrackFoundationRepository)? = nil,
        phaseII: (any LifeBoardPhaseIIRepository)? = nil,
        habitRuntime: (any HabitRuntimeReadRepositoryProtocol)? = nil
    ) {
        self.planningProjection = planningProjection
        self.trackFoundation = trackFoundation
        self.phaseII = phaseII
        self.habitRuntime = habitRuntime
    }

    public func candidates(for kind: TypedSourceKind, query: String) async throws -> [TypedSourcePickerItem] {
        let items: [TypedSourcePickerItem]
        switch kind {
        case .task: items = try await taskCandidates()
        case .project: items = try await projectCandidates()
        case .habit: items = await habitCandidates()
        case .routine: items = try await routineCandidates()
        case .trackerMeasure: items = try await trackerCandidates()
        }
        return Self.filter(items, query: query)
    }

    private func taskCandidates() async throws -> [TypedSourcePickerItem] {
        guard let planningProjection else { return [] }
        let tasks = try await planningProjection.fetchOpenPlanningTasks()
        return tasks.map { TypedSourcePickerItem(id: $0.id, kind: .task, title: $0.title) }
    }

    private func projectCandidates() async throws -> [TypedSourcePickerItem] {
        var names: [UUID: String] = [:]
        if let planningProjection {
            for project in try await planningProjection.fetchPlanningProjects() where project.isArchived == false {
                names[project.id] = project.name
            }
        }
        for summary in await habitSummaries() {
            if let projectID = summary.projectID, let projectName = summary.projectName, !projectName.isEmpty {
                if names[projectID] == nil { names[projectID] = projectName }
            }
        }
        return names.map { TypedSourcePickerItem(id: $0.key, kind: .project, title: $0.value) }
    }

    private func habitCandidates() async -> [TypedSourcePickerItem] {
        var seen: Set<UUID> = []
        var items: [TypedSourcePickerItem] = []
        for summary in await habitSummaries() where seen.insert(summary.habitID).inserted {
            items.append(TypedSourcePickerItem(id: summary.habitID, kind: .habit, title: summary.title))
        }
        return items
    }

    private func routineCandidates() async throws -> [TypedSourcePickerItem] {
        guard let trackFoundation else { return [] }
        let routines = try await trackFoundation.fetchRoutines().filter { !$0.isArchived }
        return routines.map { TypedSourcePickerItem(id: $0.id, kind: .routine, title: $0.title) }
    }

    private func trackerCandidates() async throws -> [TypedSourcePickerItem] {
        guard let phaseII else { return [] }
        let trackers = try await phaseII.fetchTrackers().filter { !$0.isArchived }
        return trackers.map {
            TypedSourcePickerItem(id: $0.id, kind: .trackerMeasure, title: $0.title, subtitle: $0.unitLabel)
        }
    }

    private func habitSummaries() async -> [HabitOccurrenceSummary] {
        guard let habitRuntime else { return [] }
        return await withCheckedContinuation { continuation in
            habitRuntime.fetchAgendaHabits(for: Date()) { result in
                continuation.resume(returning: (try? result.get()) ?? [])
            }
        }
    }

    private static func filter(_ items: [TypedSourcePickerItem], query: String) -> [TypedSourcePickerItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        guard !trimmed.isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }
}

// MARK: - Picker view

/// Searchable list that resolves a real record. Handles loading, empty, permission-free
/// "nothing yet", and failure states so the caller only ever receives a valid item + id.
public struct TypedSourcePickerView: View {
    public enum LoadState: Equatable {
        case loading
        case loaded([TypedSourcePickerItem])
        case empty
        case failed(String)
    }

    let title: String
    let kinds: [TypedSourceKind]
    let repository: any TypedSourcePickerRepository
    let onSelect: (TypedSourcePickerItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: TypedSourceKind
    @State private var query: String = ""
    @State private var state: LoadState = .loading

    public init(
        title: String,
        kinds: [TypedSourceKind],
        repository: any TypedSourcePickerRepository,
        onSelect: @escaping (TypedSourcePickerItem) -> Void
    ) {
        self.title = title
        self.kinds = kinds.isEmpty ? TypedSourceKind.allCases : kinds
        self.repository = repository
        self.onSelect = onSelect
        _kind = State(initialValue: kinds.first ?? .task)
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ContentUnavailableView(
                        "Nothing to link yet",
                        systemImage: kind.systemImage,
                        description: Text("Create a \(kind.title.lowercased()) first, then link it here.")
                    )
                case .failed(let message):
                    ContentUnavailableView(
                        "Couldn’t load \(kind.title.lowercased())s",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                case .loaded(let items):
                    List(items) { item in
                        Button {
                            onSelect(item)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.kind.systemImage)
                                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                                        Text(subtitle).font(.caption)
                                            .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("sourcePicker.item.\(item.id.uuidString)")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search \(kind.title.lowercased())s")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if kinds.count > 1 {
                    ToolbarItem(placement: .principal) {
                        Picker("Kind", selection: $kind) {
                            ForEach(kinds, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .task(id: kind) { await reload() }
            .task(id: query) { await reload() }
        }
    }

    private func reload() async {
        do {
            let items = try await repository.candidates(for: kind, query: query)
            state = items.isEmpty ? (query.isEmpty ? .empty : .loaded([])) : .loaded(items)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
