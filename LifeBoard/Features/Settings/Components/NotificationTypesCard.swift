import SwiftUI

struct NotificationTypesCard: View {
    @ObservedObject var viewModel: SettingsViewModel

    private struct NotificationToggleRow: Identifiable {
        let id: String
        let icon: String
        let title: String
        let keyPath: WritableKeyPath<NotificationPreferences, Bool>
    }

    private var rows: [NotificationToggleRow] {
        [
            NotificationToggleRow(id: "reminders", icon: "bell.badge.fill", title: String(localized: "Task reminders"), keyPath: \.taskRemindersEnabled),
            NotificationToggleRow(id: "dueSoon", icon: "clock.badge.exclamationmark", title: String(localized: "Due soon reminders"), keyPath: \.dueSoonEnabled),
            NotificationToggleRow(id: "overdue", icon: "lifepreserver", title: String(localized: "Tasks from earlier"), keyPath: \.overdueNudgesEnabled),
            NotificationToggleRow(id: "morning", icon: "sunrise.fill", title: String(localized: "Morning agenda"), keyPath: \.morningAgendaEnabled),
            NotificationToggleRow(id: "nightly", icon: "moon.stars.fill", title: String(localized: "Close the day"), keyPath: \.nightlyRetrospectiveEnabled),
        ]
    }

    private var disabled: Bool { viewModel.isPermissionDenied }

    var body: some View {
        SurfaceCard {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    toggleRow(row)

                    if index < rows.count - 1 {
                        Divider()
                            .background(Color.lifeboard.strokeHairline)
                    }
                }
            }
            .opacity(disabled ? 0.5 : 1.0)
        }
    }

    @ViewBuilder
    private func toggleRow(_ row: NotificationToggleRow) -> some View {
        HStack(spacing: SwiftUITokens.spacing.s12) {
            Image(systemName: row.icon)
                .font(.lifeboard(.support))
                .foregroundColor(.lifeboard(.accentPrimary))
                .frame(width: 24)

            Text(row.title)
                .font(.lifeboard(.bodyStrong))
                .foregroundColor(.lifeboard(.textPrimary))

            Spacer()

            Toggle("", isOn: Binding(
                get: { viewModel.preferences[keyPath: row.keyPath] },
                set: { viewModel.togglePreference(row.keyPath, value: $0) }
            ))
            .labelsHidden()
            .tint(Color.lifeboard(.accentPrimary))
            .disabled(disabled)
        }
        .padding(.vertical, SwiftUITokens.spacing.s12)
    }
}
