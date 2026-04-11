import SwiftUI

struct QuietTrackingComposerView: View {
    let snapshot: QuietTrackingComposerSnapshot
    let onClose: () -> Void
    let onSave: (QuietTrackingComposerSaveRequest) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    @State private var selectedHabitID: String?
    @State private var selectedEntry: QuietTrackingComposerEntry?
    @State private var selectedDate: Date
    @State private var outcome: QuietTrackingOutcome

    init(
        snapshot: QuietTrackingComposerSnapshot,
        onClose: @escaping () -> Void,
        onSave: @escaping (QuietTrackingComposerSaveRequest) -> Void
    ) {
        self.snapshot = snapshot
        self.onClose = onClose
        self.onSave = onSave

        let initialSelectedHabitID = snapshot.resolvedSelectedHabitID(snapshot.initialSelectedHabitID)
        _selectedHabitID = State(initialValue: initialSelectedHabitID)
        _selectedEntry = State(initialValue: snapshot.entry(for: initialSelectedHabitID))
        _selectedDate = State(initialValue: snapshot.initialDate)
        _outcome = State(initialValue: snapshot.initialOutcome)
    }

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var heroSubtitle: String { snapshot.heroSubtitle(for: selectedEntry) }
    private var progressTitle: String { snapshot.progressTitle(for: selectedEntry) }
    private var progressDetail: String { snapshot.progressDetail(for: selectedEntry) }
    private var footerTitle: String { snapshot.footerTitle(for: selectedEntry, outcome: outcome) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: spacing.s16) {
                    heroCard
                    pickerCard
                    outcomeCard
                    dateCard
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s12)
                .padding(.bottom, spacing.s24)
            }
            .accessibilityIdentifier("home.quietTracking.sheet.scroll")
            .background(Color.tasker.bgCanvas)
            .navigationTitle("Quiet Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                        .accessibilityIdentifier("home.quietTracking.sheet.cancel")
                }
            }
            .safeAreaInset(edge: .bottom) {
                footerBar
            }
        }
        .accessibilityIdentifier("home.quietTracking.sheet")
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(TaskerTheme.CornerRadius.xl)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                ZStack {
                    RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg)
                        .fill(Color.tasker.accentSecondary.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: selectedEntry?.iconSymbolName ?? "heart.text.square.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.tasker.accentSecondary)
                }

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(selectedEntry?.title ?? "Choose a habit")
                        .font(.tasker(.title3))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .lineLimit(2)

                    Text(heroSubtitle)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if let selectedEntry {
                HStack(spacing: spacing.s8) {
                    HabitBoardStripView(
                        cells: selectedEntry.historyCells,
                        family: selectedEntry.colorFamily,
                        mode: .compact
                    )

                    Spacer(minLength: 0)

                    Text("\(selectedEntry.currentStreak)d streak")
                        .font(.tasker(.caption1).weight(.semibold))
                        .foregroundStyle(Color.tasker.accentSecondary)
                        .padding(.horizontal, spacing.s8)
                        .padding(.vertical, spacing.s4)
                        .background(Color.tasker.accentSecondary.opacity(0.10))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(spacing.s16)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: Color.tasker.surfacePrimary
        )
    }

    private var pickerCard: some View {
        QuietTrackingSectionCard(
            title: "Habit",
            subtitle: "Quiet habits stay out of the main list until you need to log the day.",
            iconSystemName: "square.stack.3d.up"
        ) {
            LazyVStack(spacing: spacing.s8) {
                ForEach(snapshot.entries) { entry in
                    QuietTrackingHabitPickerRow(
                        entry: entry,
                        isSelected: selectedHabitID == entry.id,
                        onSelect: { selectHabit(entry.id) }
                    )
                    .equatable()
                }
            }
            .accessibilityIdentifier("home.quietTracking.sheet.habitList")
        }
    }

    private var outcomeCard: some View {
        QuietTrackingSectionCard(
            title: "Outcome",
            subtitle: "Use the clean state for a stable day, or record the lapse on the day it happened.",
            iconSystemName: "checkmark.circle.badge.questionmark"
        ) {
            HStack(spacing: spacing.s8) {
                outcomeButton(
                    .progress,
                    title: progressTitle,
                    detail: progressDetail,
                    identifier: "home.quietTracking.sheet.outcome.progress"
                )
                outcomeButton(
                    .lapse,
                    title: "Lapsed",
                    detail: "Record the slip for the selected day.",
                    identifier: "home.quietTracking.sheet.outcome.lapse"
                )
            }
        }
    }

    private var dateCard: some View {
        QuietTrackingSectionCard(
            title: "Day",
            subtitle: "Default to today, but you can repair the timeline for another date when needed.",
            iconSystemName: "calendar"
        ) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                HStack(spacing: spacing.s8) {
                    dateShortcutButton("Today", date: Date(), identifier: "home.quietTracking.sheet.date.today")
                    dateShortcutButton(
                        "Yesterday",
                        date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                        identifier: "home.quietTracking.sheet.date.yesterday"
                    )
                }

                HStack(spacing: spacing.s8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected day")
                            .font(.tasker(.caption2))
                            .foregroundStyle(Color.tasker.textSecondary)
                        Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.tasker(.callout).weight(.semibold))
                            .foregroundStyle(Color.tasker.textPrimary)
                            .accessibilityIdentifier("home.quietTracking.sheet.date.selected")
                    }

                    Spacer(minLength: 0)

                    DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                        .environment(\.timeZone, .current)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .accessibilityIdentifier("home.quietTracking.sheet.datePicker")
                }
                .padding(spacing.s12)
                .taskerDenseSurface(
                    cornerRadius: TaskerTheme.CornerRadius.md,
                    fillColor: Color.tasker.surfacePrimary
                )
            }
        }
    }

    private var footerBar: some View {
        VStack(spacing: spacing.s8) {
            Divider()

            HStack(spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(footerTitle)
                        .font(.tasker(.caption1).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                    Text(selectedDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.tasker(.caption2))
                        .foregroundStyle(Color.tasker.textSecondary)
                }

                Spacer(minLength: 0)

                Button(action: save) {
                    Text("Save")
                        .font(.tasker(.body).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .padding(.horizontal, spacing.s16)
                        .frame(height: 48)
                        .background(Color.tasker.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
                }
                .buttonStyle(.plain)
                .disabled(selectedEntry == nil)
                .opacity(selectedEntry == nil ? 0.45 : 1)
                .accessibilityIdentifier("home.quietTracking.sheet.save")
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)
            .padding(.bottom, spacing.s12)
        }
        .background(Color.tasker.surfacePrimary)
    }

    private func outcomeButton(
        _ candidate: QuietTrackingOutcome,
        title: String,
        detail: String,
        identifier: String
    ) -> some View {
        Button {
            outcome = candidate
        } label: {
            VStack(alignment: .leading, spacing: spacing.s8) {
                HStack(spacing: spacing.s4) {
                    Image(systemName: outcome == candidate ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(outcome == candidate ? Color.tasker.accentPrimary : Color.tasker.strokeHairline)
                    Text(title)
                        .font(.tasker(.callout).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                }

                Text(detail)
                    .font(.tasker(.caption2))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(spacing.s12)
            .taskerDenseSurface(
                cornerRadius: TaskerTheme.CornerRadius.md,
                fillColor: outcome == candidate ? Color.tasker.accentWash.opacity(0.75) : Color.tasker.surfacePrimary,
                strokeColor: outcome == candidate ? Color.tasker.accentPrimary.opacity(0.34) : Color.tasker.strokeHairline.opacity(0.75)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func dateShortcutButton(_ title: String, date: Date, identifier: String) -> some View {
        let isSelected = Calendar.current.isDate(selectedDate, inSameDayAs: date)

        return Button {
            selectedDate = date
        } label: {
            Text(title)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(isSelected ? Color.tasker.accentPrimary : Color.tasker.textSecondary)
                .padding(.horizontal, spacing.s12)
                .frame(height: 34)
                .background(isSelected ? Color.tasker.accentWash.opacity(0.88) : Color.tasker.surfacePrimary)
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.tasker.accentPrimary.opacity(0.30) : Color.tasker.strokeHairline.opacity(0.8),
                            lineWidth: 1
                        )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func selectHabit(_ habitID: String) {
        selectedHabitID = snapshot.resolvedSelectedHabitID(habitID)
        selectedEntry = snapshot.entry(for: selectedHabitID)
    }

    private func save() {
        guard let habitID = snapshot.resolvedSelectedHabitID(selectedHabitID) else { return }
        onSave(
            QuietTrackingComposerSaveRequest(
                habitID: habitID,
                date: selectedDate,
                outcome: outcome
            )
        )
    }
}

private struct QuietTrackingHabitPickerRow: View, Equatable {
    let entry: QuietTrackingComposerEntry
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    static func == (lhs: QuietTrackingHabitPickerRow, rhs: QuietTrackingHabitPickerRow) -> Bool {
        lhs.entry == rhs.entry && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: spacing.s12) {
                ZStack {
                    Circle()
                        .fill(Color.tasker.accentSecondary.opacity(isSelected ? 0.18 : 0.10))
                        .frame(width: 34, height: 34)

                    Image(systemName: entry.iconSymbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.tasker.accentSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.tasker(.callout).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .lineLimit(2)
                    Text(entry.lifeAreaName)
                        .font(.tasker(.caption2))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if entry.currentStreak > 0 {
                    Text("\(entry.currentStreak)d")
                        .font(.tasker(.caption2).weight(.semibold))
                        .foregroundStyle(Color.tasker.accentSecondary)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.tasker.accentPrimary : Color.tasker.strokeHairline)
            }
            .padding(spacing.s12)
            .taskerDenseSurface(
                cornerRadius: TaskerTheme.CornerRadius.md,
                fillColor: isSelected ? Color.tasker.accentWash.opacity(0.75) : Color.tasker.surfacePrimary,
                strokeColor: isSelected ? Color.tasker.accentPrimary.opacity(0.32) : Color.tasker.strokeHairline.opacity(0.75)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.quietTracking.sheet.habit.\(entry.id)")
    }
}

private struct QuietTrackingSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let iconSystemName: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        iconSystemName: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.content = content()
    }

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.tasker.accentSecondary.opacity(0.10))
                        .frame(width: 32, height: 32)

                    Image(systemName: iconSystemName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.tasker.accentSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker.textPrimary)
                    Text(subtitle)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(spacing.s16)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: Color.tasker.surfacePrimary
        )
    }
}
