//
//  SunriseLensLifeAreasSheet.swift
//  LifeBoard
//
//  Pin, reorder, and create life areas for the Home lens chip row.
//

import SwiftUI

struct SunriseLensLifeAreasSheet: View {
    @Environment(\.dismiss) private var dismiss

    let lifeAreas: [LifeArea]
    let onSave: ([UUID]) -> Void
    let onCreateLifeArea: (_ name: String, _ completion: @escaping @Sendable (Result<LifeArea, Error>) -> Void) -> Void

    @State private var pinned: [UUID]
    @State private var isCreating = false
    @State private var newAreaName = ""
    @State private var createError: String?
    @State private var isSavingCreate = false

    private let maxPins = 5

    init(
        lifeAreas: [LifeArea],
        initialPinnedIDs: [UUID],
        onSave: @escaping ([UUID]) -> Void,
        onCreateLifeArea: @escaping (_ name: String, _ completion: @escaping @Sendable (Result<LifeArea, Error>) -> Void) -> Void
    ) {
        self.lifeAreas = lifeAreas
        self.onSave = onSave
        self.onCreateLifeArea = onCreateLifeArea
        _pinned = State(initialValue: initialPinnedIDs.filter { id in
            lifeAreas.contains { $0.id == id }
        })
    }

    private var selectable: [LifeArea] {
        lifeAreas.filter { !$0.isArchived }
    }

    private var pinnedAreas: [LifeArea] {
        let byID = Dictionary(uniqueKeysWithValues: selectable.map { ($0.id, $0) })
        return pinned.compactMap { byID[$0] }
    }

    private var unpinnedAreas: [LifeArea] {
        selectable
            .filter { pinned.contains($0.id) == false }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var isAtPinLimit: Bool {
        pinned.count >= maxPins
    }

    var body: some View {
        NavigationStack {
            Group {
                if selectable.isEmpty && isCreating == false {
                    emptyState
                } else {
                    areaList
                }
            }
            .navigationTitle("Pin life areas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(pinned)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var areaList: some View {
        List {
            if isCreating {
                createSection
            }

            if pinnedAreas.isEmpty == false {
                Section {
                    ForEach(pinnedAreas, id: \.id) { area in
                        row(for: area)
                    }
                    .onMove(perform: movePinned)
                    .onDelete(perform: deletePinned)
                } header: {
                    Text("\(pinned.count) of \(maxPins) pinned · drag to reorder")
                        .font(.lifeboard(.caption1))
                        .textCase(nil)
                }
            }

            if unpinnedAreas.isEmpty == false {
                Section("All life areas") {
                    ForEach(unpinnedAreas, id: \.id) { area in
                        row(for: area)
                    }
                }
            }

            Section {
                if isCreating == false {
                    Button {
                        withAnimation(LifeBoardAnimation.snappy) {
                            isCreating = true
                            newAreaName = ""
                            createError = nil
                        }
                    } label: {
                        Label("New life area", systemImage: "plus.circle.fill")
                            .font(.lifeboard(.body))
                    }
                    .accessibilityIdentifier("home.lens.manage.newLifeArea")
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, pinnedAreas.isEmpty ? .constant(.inactive) : .constant(.active))
    }

    private var createSection: some View {
        Section {
            TextField("Life area name", text: $newAreaName)
                .font(.lifeboard(.body))
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("home.lens.manage.create.name")

            if let createError {
                Text(createError)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
            }

            Button {
                submitCreate()
            } label: {
                if isSavingCreate {
                    ProgressView()
                } else {
                    Text("Create and pin")
                        .fontWeight(.semibold)
                }
            }
            .disabled(newAreaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingCreate || isAtPinLimit)

            Button("Cancel", role: .cancel) {
                withAnimation(LifeBoardAnimation.snappy) {
                    isCreating = false
                    createError = nil
                }
            }
        } header: {
            Text("New life area")
                .textCase(nil)
        }
    }

    private func row(for area: LifeArea) -> some View {
        let isPinned = pinned.contains(area.id)
        let disabled = isPinned == false && isAtPinLimit
        let accentHex = LifeAreaColorPalette.normalizeOrMap(hex: area.color, for: area.id)
        return Button {
            togglePin(area.id)
        } label: {
            HStack(spacing: LBSpacingTokens.sm) {
                Circle()
                    .fill(Color(lifeboardHex: accentHex))
                    .frame(width: 12, height: 12)
                Image(systemName: area.icon ?? "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .frame(width: 22)
                Text(area.name)
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: LBSpacingTokens.sm)
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isPinned ? Color.lifeboard.accentPrimary : Color.lifeboard.textSecondary.opacity(0.5))
            }
            .contentShape(Rectangle())
            .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityIdentifier("home.lens.manage.lifeArea.\(area.id.uuidString)")
        .accessibilityLabel(area.name)
        .accessibilityValue(isPinned ? "Pinned" : "Not pinned")
        .accessibilityHint(disabled ? "Pin limit reached. Unpin a life area first." : (isPinned ? "Unpins this life area" : "Pins this life area"))
        .accessibilityAddTraits(isPinned ? .isSelected : [])
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No life areas yet",
            systemImage: "square.grid.2x2",
            description: Text("Create a life area to pin it to your Home lens row.")
        )
    }

    private func togglePin(_ id: UUID) {
        if let index = pinned.firstIndex(of: id) {
            pinned.remove(at: index)
        } else if pinned.count < maxPins {
            pinned.append(id)
        }
    }

    private func movePinned(from source: IndexSet, to destination: Int) {
        pinned.move(fromOffsets: source, toOffset: destination)
    }

    private func deletePinned(at offsets: IndexSet) {
        pinned.remove(atOffsets: offsets)
    }

    private func submitCreate() {
        let trimmed = newAreaName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        isSavingCreate = true
        createError = nil
        onCreateLifeArea(trimmed) { result in
            Task { @MainActor in
                isSavingCreate = false
                switch result {
                case .success(let area):
                    if pinned.contains(area.id) == false, pinned.count < maxPins {
                        pinned.append(area.id)
                    }
                    isCreating = false
                    newAreaName = ""
                case .failure(let error):
                    createError = error.localizedDescription
                }
            }
        }
    }
}
