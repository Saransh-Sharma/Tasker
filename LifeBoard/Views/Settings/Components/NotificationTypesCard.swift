import SwiftUI

struct NotificationTypesCard: View {
    @ObservedObject var viewModel: SettingsViewModel

    private struct NotificationToggleRow: Identifiable {
        let id: String
        let icon: String
        let title: String
        let keyPath: WritableKeyPath<TaskerNotificationPreferences, Bool>
    }

    private var rows: [NotificationToggleRow] {
        [
            NotificationToggleRow(id: "reminders", icon: "bell.badge.fill", title: "Task Reminders", keyPath: \.taskRemindersEnabled),
            NotificationToggleRow(id: "dueSoon", icon: "clock.badge.exclamationmark", title: "Due Soon Nudges", keyPath: \.dueSoonEnabled),
            NotificationToggleRow(id: "overdue", icon: "exclamationmark.triangle.fill", title: "Overdue Nudges", keyPath: \.overdueNudgesEnabled),
            NotificationToggleRow(id: "morning", icon: "sunrise.fill", title: "Morning Agenda", keyPath: \.morningAgendaEnabled),
            NotificationToggleRow(id: "nightly", icon: "moon.stars.fill", title: "Nightly Retrospective", keyPath: \.nightlyRetrospectiveEnabled),
        ]
    }

    private var disabled: Bool { viewModel.isPermissionDenied }

    var body: some View {
        TaskerCard {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    toggleRow(row)

                    if index < rows.count - 1 {
                        Divider()
                            .background(Color.tasker.strokeHairline)
                    }
                }
            }
            .opacity(disabled ? 0.5 : 1.0)
        }
    }

    @ViewBuilder
    private func toggleRow(_ row: NotificationToggleRow) -> some View {
        HStack(spacing: TaskerSwiftUITokens.spacing.s12) {
            Image(systemName: row.icon)
                .font(.tasker(.support))
                .foregroundColor(.tasker(.accentPrimary))
                .frame(width: 24)

            Text(row.title)
                .font(.tasker(.bodyStrong))
                .foregroundColor(.tasker(.textPrimary))

            Spacer()

            Toggle("", isOn: Binding(
                get: { viewModel.preferences[keyPath: row.keyPath] },
                set: { viewModel.togglePreference(row.keyPath, value: $0) }
            ))
            .labelsHidden()
            .tint(Color.tasker(.accentPrimary))
            .disabled(disabled)
        }
        .padding(.vertical, TaskerSwiftUITokens.spacing.s12)
    }
}
