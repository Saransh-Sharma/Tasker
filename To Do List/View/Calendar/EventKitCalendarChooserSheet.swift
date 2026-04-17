import SwiftUI

struct EventKitCalendarChooserSheet: View {
    @ObservedObject var service: CalendarIntegrationService
    let initialSelectedCalendarIDs: [String]
    let onCancel: () -> Void
    let onCommit: ([String]) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    @State private var selectedCalendarIDs: Set<String>

    init(
        service: CalendarIntegrationService,
        initialSelectedCalendarIDs: [String],
        onCancel: @escaping () -> Void,
        onCommit: @escaping ([String]) -> Void
    ) {
        self.service = service
        self.initialSelectedCalendarIDs = initialSelectedCalendarIDs
        self.onCancel = onCancel
        self.onCommit = onCommit
        _selectedCalendarIDs = State(initialValue: Set(initialSelectedCalendarIDs))
    }

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    private var sections: [TaskerCalendarChooserSection] {
        TaskerCalendarPresentation.chooserSections(from: service.snapshot.availableCalendars)
    }

    private var isInitialLoadingStateVisible: Bool {
        service.snapshot.authorizationStatus.isAuthorizedForRead
            && service.snapshot.isLoading
            && service.snapshot.errorMessage?.isEmpty != false
            && service.snapshot.availableCalendars.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: spacing.s16) {
                    chooserHeader

                    if service.snapshot.authorizationStatus.isAuthorizedForRead == false {
                        chooserStateCard(
                            title: String(localized: "Calendar access required"),
                            message: String(localized: "Grant calendar access before choosing sources for schedule insights.")
                        )
                    } else if isInitialLoadingStateVisible {
                        chooserStateCard(
                            title: String(localized: "Loading calendars"),
                            message: String(localized: "Fetching readable calendars for this workspace.")
                        )
                    } else if sections.isEmpty {
                        chooserStateCard(
                            title: String(localized: "No calendars available"),
                            message: String(localized: "No readable calendars were found right now.")
                        )
                    } else {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                Text(section.title)
                                    .font(.tasker(.headline))
                                    .foregroundStyle(Color.tasker.textPrimary)
                                    .accessibilityIdentifier("schedule.chooser.section.\(section.id)")

                                ForEach(section.calendars) { calendar in
                                    chooserRow(calendar)
                                }
                            }
                        }
                    }
                }
                .taskerReadableContent(maxWidth: layoutClass.isPad ? 900 : .infinity, alignment: .center)
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s16)
                .padding(.bottom, spacing.sectionGap)
            }
            .background(Color.tasker.bgCanvas.ignoresSafeArea())
            .navigationTitle(String(localized: "Calendars"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel"), action: onCancel)
                        .accessibilityIdentifier("schedule.chooser.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        onCommit(selectedCalendarIDs.sorted())
                    }
                    .bold()
                    .accessibilityIdentifier("schedule.chooser.done")
                }
            }
        }
        .task {
            if service.snapshot.availableCalendars.isEmpty {
                service.refreshContext(reason: "schedule_chooser_appear")
            }
        }
    }

    private var chooserHeader: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Text(String(localized: "Pick the calendars that should drive Home and the schedule lane."))
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker.textSecondary)

            HStack(spacing: spacing.s12) {
                chooserMetricPill(title: String(localized: "Selected"), value: "\(selectedCalendarIDs.count)")
                chooserMetricPill(title: String(localized: "Available"), value: "\(service.snapshot.availableCalendars.count)")
            }
        }
        .padding(spacing.s16)
        .background(Color.tasker.bgElevated)
        .taskerPremiumSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: Color.tasker.bgElevated,
            strokeColor: Color.tasker.strokeHairline.opacity(0.82),
            accentColor: Color.tasker.accentSecondary,
            level: .e2
        )
    }

    private func chooserMetricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)
            Text(value)
                .font(.tasker(.bodyStrong))
                .foregroundStyle(Color.tasker.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s12)
        .background(Color.tasker.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous))
    }

    private func chooserStateCard(title: String, message: String) -> some View {
        TaskerCard(elevated: true) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text(title)
                    .font(.tasker(.sectionTitle))
                    .foregroundStyle(Color.tasker.textPrimary)

                Text(message)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker.textSecondary)
            }
        }
    }

    private func chooserRow(_ calendar: TaskerCalendarSourceSnapshot) -> some View {
        let isSelected = selectedCalendarIDs.contains(calendar.id)

        return Button {
            if isSelected {
                selectedCalendarIDs.remove(calendar.id)
            } else {
                selectedCalendarIDs.insert(calendar.id)
            }
        } label: {
            TaskerCard(active: isSelected, elevated: true) {
                HStack(alignment: .center, spacing: spacing.s12) {
                    Circle()
                        .fill(TaskerHexColor.color(calendar.colorHex, fallback: Color.tasker.accentPrimary))
                        .frame(width: 14, height: 14)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(calendar.title)
                            .font(.tasker(.headline))
                            .foregroundStyle(Color.tasker.textPrimary)

                        Text(
                            calendar.allowsContentModifications
                                ? String(localized: "Editable source")
                                : String(localized: "Read-only source")
                        )
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                    }

                    Spacer(minLength: 0)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.tasker.actionPrimary)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Color.tasker.textTertiary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("schedule.chooser.calendar.\(calendar.id)")
        .accessibilityValue(isSelected ? String(localized: "selected") : String(localized: "unselected"))
    }
}

struct EventKitCalendarChooserContainerView: View {
    @ObservedObject var service: CalendarIntegrationService
    let initialSelectedCalendarIDs: [String]
    let onCommit: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        EventKitCalendarChooserSheet(
            service: service,
            initialSelectedCalendarIDs: initialSelectedCalendarIDs,
            onCancel: {
                dismiss()
            },
            onCommit: { selectedIDs in
                onCommit(selectedIDs)
                dismiss()
            }
        )
    }
}
