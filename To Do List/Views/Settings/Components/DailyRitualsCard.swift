import SwiftUI

struct DailyRitualsCard: View {
    @ObservedObject var viewModel: SettingsViewModel

    private var disabled: Bool { viewModel.isPermissionDenied }

    var body: some View {
        TaskerCard {
            VStack(spacing: TaskerSwiftUITokens.spacing.s24) {
                // Morning Agenda
                ritualSection(
                    icon: "sunrise.fill",
                    iconColor: .tasker(.statusWarning),
                    title: "Morning Agenda",
                    isEnabled: Binding(
                        get: { viewModel.preferences.morningAgendaEnabled },
                        set: { viewModel.togglePreference(\.morningAgendaEnabled, value: $0) }
                    ),
                    time: Binding(
                        get: { viewModel.morningTime },
                        set: { viewModel.morningTime = $0 }
                    ),
                    timeLabel: viewModel.formattedTime(
                        hour: viewModel.preferences.morningHour,
                        minute: viewModel.preferences.morningMinute
                    )
                )

                Divider()
                    .background(Color.tasker.strokeHairline)

                // Nightly Retrospective
                ritualSection(
                    icon: "moon.stars.fill",
                    iconColor: .tasker(.accentSecondary),
                    title: "Nightly Retrospective",
                    isEnabled: Binding(
                        get: { viewModel.preferences.nightlyRetrospectiveEnabled },
                        set: { viewModel.togglePreference(\.nightlyRetrospectiveEnabled, value: $0) }
                    ),
                    time: Binding(
                        get: { viewModel.nightlyTime },
                        set: { viewModel.nightlyTime = $0 }
                    ),
                    timeLabel: viewModel.formattedTime(
                        hour: viewModel.preferences.nightlyHour,
                        minute: viewModel.preferences.nightlyMinute
                    )
                )
            }
            .opacity(disabled ? 0.5 : 1.0)
        }
    }

    @ViewBuilder
    private func ritualSection(
        icon: String,
        iconColor: Color,
        title: String,
        isEnabled: Binding<Bool>,
        time: Binding<Date>,
        timeLabel: String
    ) -> some View {
        VStack(spacing: TaskerSwiftUITokens.spacing.s12) {
            // Toggle row
            HStack(spacing: TaskerSwiftUITokens.spacing.s12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 24)

                Text(title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(.tasker(.textPrimary))

                Spacer()

                Toggle("", isOn: isEnabled)
                    .labelsHidden()
                    .tint(Color.tasker(.accentPrimary))
                    .disabled(disabled)
            }

            // Inline time picker (shown when enabled)
            if isEnabled.wrappedValue {
                HStack {
                    Text("Scheduled at")
                        .font(.tasker(.callout))
                        .foregroundColor(.tasker(.textSecondary))

                    Spacer()

                    DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Color.tasker(.accentPrimary))
                        .disabled(disabled)
                }
                .padding(.leading, 36) // Align with text after icon
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(TaskerAnimation.gentle, value: isEnabled.wrappedValue)
    }
}
