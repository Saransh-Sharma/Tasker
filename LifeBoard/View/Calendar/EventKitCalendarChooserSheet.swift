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
                                    .font(.tasker(.caption1))
                                    .foregroundStyle(Color.tasker.textSecondary)
                                    .textCase(.uppercase)
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

    private func chooserStateCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text(title)
                .font(.tasker(.sectionTitle))
                .foregroundStyle(Color.tasker.textPrimary)

            Text(message)
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker.textSecondary)
        }
        .padding(spacing.s12)
        .background(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                .fill(Color.tasker.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                .stroke(Color.tasker.strokeHairline.opacity(0.7), lineWidth: 1)
        )
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
            HStack(alignment: .center, spacing: spacing.s12) {
                Circle()
                    .fill(TaskerHexColor.color(calendar.colorHex, fallback: Color.tasker.accentPrimary))
                    .frame(width: 12, height: 12)

                Text(calendar.title)
                    .font(.tasker(.bodyStrong))
                    .foregroundStyle(Color.tasker.textPrimary)

                Spacer(minLength: 0)

                Text(isSelected ? String(localized: "On") : String(localized: "Off"))
                    .font(.tasker(.caption1))
                    .foregroundStyle(isSelected ? Color.tasker.actionPrimary : Color.tasker.textSecondary)
                    .padding(.horizontal, spacing.s12)
                    .padding(.vertical, spacing.s4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.tasker.accentWash : Color.tasker.surfaceSecondary)
                    )
            }
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s12)
            .background(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                    .fill(Color.tasker.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.tasker.actionPrimary.opacity(0.36)
                            : Color.tasker.strokeHairline.opacity(0.7),
                        lineWidth: 1
                    )
            )
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
