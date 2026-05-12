//
//  HomeAdvancedFilterSheetView.swift
//  LifeBoard
//
//  Advanced composable filter sheet for Home Focus Engine.
//

import SwiftUI

struct HomeAdvancedFilterSheetView: View {
    let initialFilter: HomeAdvancedFilter?
    let initialShowCompletedInline: Bool
    let savedViews: [SavedHomeView]
    let activeSavedViewID: UUID?
    let onApply: (HomeAdvancedFilter?, Bool) -> Void
    let onClear: () -> Void
    let onSaveNamedView: (HomeAdvancedFilter?, Bool, String) -> Void
    let onApplySavedView: (UUID) -> Void
    let onDeleteSavedView: (UUID) -> Void

    /// Initializes a new instance.
    @Environment(\.dismiss) private var dismiss
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    @State private var selectedPriorities: Set<TaskPriority>
    @State private var selectedCategories: Set<TaskCategory>
    @State private var selectedContexts: Set<TaskContext>
    @State private var selectedEnergyLevels: Set<TaskEnergy>
    @State private var showCompletedInline: Bool
    @State private var requireDueDate: Bool
    @State private var hasEstimateState: TriState = .any
    @State private var hasDependenciesState: TriState = .any
    @State private var tagsText: String
    @State private var tagMatchMode: HomeTagMatchMode
    @State private var useDateRange: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var saveViewName: String = ""

    init(
        initialFilter: HomeAdvancedFilter?,
        initialShowCompletedInline: Bool,
        savedViews: [SavedHomeView],
        activeSavedViewID: UUID?,
        onApply: @escaping (HomeAdvancedFilter?, Bool) -> Void,
        onClear: @escaping () -> Void,
        onSaveNamedView: @escaping (HomeAdvancedFilter?, Bool, String) -> Void,
        onApplySavedView: @escaping (UUID) -> Void,
        onDeleteSavedView: @escaping (UUID) -> Void
    ) {
        self.initialFilter = initialFilter
        self.initialShowCompletedInline = initialShowCompletedInline
        self.savedViews = savedViews
        self.activeSavedViewID = activeSavedViewID
        self.onApply = onApply
        self.onClear = onClear
        self.onSaveNamedView = onSaveNamedView
        self.onApplySavedView = onApplySavedView
        self.onDeleteSavedView = onDeleteSavedView

        _selectedPriorities = State(initialValue: Set(initialFilter?.priorities ?? []))
        _selectedCategories = State(initialValue: Set(initialFilter?.categories ?? []))
        _selectedContexts = State(initialValue: Set(initialFilter?.contexts ?? []))
        _selectedEnergyLevels = State(initialValue: Set(initialFilter?.energyLevels ?? []))
        _showCompletedInline = State(initialValue: initialShowCompletedInline)
        _requireDueDate = State(initialValue: initialFilter?.requireDueDate ?? false)
        _hasEstimateState = State(initialValue: TriState.from(initialFilter?.hasEstimate))
        _hasDependenciesState = State(initialValue: TriState.from(initialFilter?.hasDependencies))
        _tagsText = State(initialValue: (initialFilter?.tags ?? []).joined(separator: ", "))
        _tagMatchMode = State(initialValue: initialFilter?.tagMatchMode ?? .any)
        _useDateRange = State(initialValue: initialFilter?.dateRange != nil)
        _startDate = State(initialValue: initialFilter?.dateRange?.start ?? Date())
        _endDate = State(initialValue: initialFilter?.dateRange?.end ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Precision filters")
                            .font(.lifeboard(.headline))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                        Text("Save named slices for the moments when the default board is still too broad.")
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, spacing.s4)
                    .padding(.vertical, spacing.s8)
                    .lifeboardPremiumSurface(
                        cornerRadius: 20,
                        fillColor: Color.lifeboard.surfacePrimary,
                        strokeColor: Color.lifeboard.strokeHairline,
                        accentColor: Color.lifeboard.accentSecondary,
                        level: .e1
                    )
                }

                Section {
                    Toggle("Show completed inline", isOn: $showCompletedInline)
                } header: {
                    sectionHeader("Completion", index: 0)
                }

                Section {
                    MultiToggleList(TaskPriority.uiOrder, selection: $selectedPriorities) { priority in
                        "\(priority.displayName) (\(priority.code))"
                    }
                } header: {
                    sectionHeader("Priority", index: 1)
                }

                Section {
                    MultiToggleList(TaskCategory.allCases, selection: $selectedCategories) { $0.displayName }
                } header: {
                    sectionHeader("Categories", index: 2)
                }

                Section {
                    MultiToggleList(TaskContext.allCases, selection: $selectedContexts) { $0.displayName }
                } header: {
                    sectionHeader("Contexts", index: 3)
                }

                Section {
                    MultiToggleList(TaskEnergy.allCases, selection: $selectedEnergyLevels) { $0.displayName }
                } header: {
                    sectionHeader("Energy", index: 4)
                }

                Section {
                    TextField("work, deep-focus, errands", text: $tagsText)
                    Picker("Tag match", selection: $tagMatchMode) {
                        Text("Any").tag(HomeTagMatchMode.any)
                        Text("All").tag(HomeTagMatchMode.all)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    sectionHeader("Tags", index: 5)
                }

                Section {
                    Toggle("Require due date", isOn: $requireDueDate)

                    Picker("Has estimate", selection: $hasEstimateState) {
                        ForEach(TriState.allCases, id: \.self) { state in
                            Text(state.title).tag(state)
                        }
                    }

                    Picker("Has dependencies", selection: $hasDependenciesState) {
                        ForEach(TriState.allCases, id: \.self) { state in
                            Text(state.title).tag(state)
                        }
                    }
                } header: {
                    sectionHeader("Attributes", index: 6)
                }

                Section {
                    Toggle("Enable range", isOn: $useDateRange)
                    if useDateRange {
                        DatePicker("Start", selection: $startDate, displayedComponents: .date)
                        DatePicker("End", selection: $endDate, displayedComponents: .date)
                    }
                } header: {
                    sectionHeader("Date Range", index: 7)
                }

                Section {
                    if savedViews.isEmpty {
                        Text("No saved views yet")
                            .foregroundColor(Color.lifeboard.textSecondary)
                    } else {
                        ForEach(savedViews) { saved in
                            HStack(spacing: spacing.s12) {
                                LifeBoardFilterRow(
                                    title: saved.name,
                                    subtitle: activeSavedViewID == saved.id ? "Active" : "Saved view",
                                    isSelected: activeSavedViewID == saved.id
                                ) {
                                    onApplySavedView(saved.id)
                                    dismiss()
                                }

                                Button(role: .destructive) {
                                    onDeleteSavedView(saved.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.lifeboard.statusDanger)
                                        .frame(width: 36, height: 36)
                                        .lifeboardChromeSurface(
                                            cornerRadius: 18,
                                            accentColor: Color.lifeboard.statusDanger,
                                            level: .e1
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    TextField("New saved view name", text: $saveViewName)
                    Button("Save current view") {
                        let draft = buildDraftFilter()
                        onSaveNamedView(draft, showCompletedInline, saveViewName)
                        saveViewName = ""
                    }
                    .disabled(saveViewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    sectionHeader("Saved Views", index: 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.lifeboard.bgCanvas)
            .listRowBackground(Color.lifeboard.surfacePrimary)
            .navigationTitle("Advanced Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear") {
                        onClear()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(buildDraftFilter(), showCompletedInline)
                        dismiss()
                    }
                }
            }
        }
    }

    /// Executes buildDraftFilter.
    private func buildDraftFilter() -> HomeAdvancedFilter? {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let range: HomeDateRange?
        if useDateRange {
            let start = min(startDate, endDate)
            let end = max(startDate, endDate)
            range = HomeDateRange(start: start, end: end)
        } else {
            range = nil
        }

        let draft = HomeAdvancedFilter(
            priorities: Array(selectedPriorities),
            categories: Array(selectedCategories),
            contexts: Array(selectedContexts),
            energyLevels: Array(selectedEnergyLevels),
            tags: tags,
            hasEstimate: hasEstimateState.boolValue,
            hasDependencies: hasDependenciesState.boolValue,
            requireDueDate: requireDueDate,
            dateRange: range,
            tagMatchMode: tagMatchMode
        )

        return draft.isEmpty ? nil : draft
    }

    private func sectionHeader(_ title: String, index: Int) -> some View {
        LifeBoardFilterSectionHeader(title: title, index: index)
            .textCase(nil)
    }
}

private enum TriState: CaseIterable {
    case any
    case yes
    case no

    var title: String {
        switch self {
        case .any: return "Any"
        case .yes: return "Yes"
        case .no: return "No"
        }
    }

    var boolValue: Bool? {
        switch self {
        case .any: return nil
        case .yes: return true
        case .no: return false
        }
    }

    /// Executes from.
    static func from(_ value: Bool?) -> TriState {
        switch value {
        case nil: return .any
        case .some(true): return .yes
        case .some(false): return .no
        }
    }
}

private struct MultiToggleList<T: Hashable>: View {
    let allValues: [T]
    @Binding var selection: Set<T>
    let title: (T) -> String

    /// Initializes a new instance.
    init(_ allValues: [T], selection: Binding<Set<T>>, title: @escaping (T) -> String) {
        self.allValues = allValues
        self._selection = selection
        self.title = title
    }

    var body: some View {
        ForEach(Array(allValues.enumerated()), id: \.offset) { _, value in
            Toggle(isOn: binding(for: value)) {
                Text(title(value))
            }
        }
    }

    /// Executes binding.
    private func binding(for value: T) -> Binding<Bool> {
        Binding<Bool>(
            get: { selection.contains(value) },
            set: { isSelected in
                if isSelected {
                    selection.insert(value)
                } else {
                    selection.remove(value)
                }
            }
        )
    }
}
