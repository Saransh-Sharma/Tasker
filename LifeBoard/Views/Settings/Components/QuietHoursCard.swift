import SwiftUI

struct QuietHoursCard: View {
    @ObservedObject var viewModel: SettingsViewModel

    private var disabled: Bool { viewModel.isPermissionDenied }
    private var isEnabled: Bool { viewModel.preferences.quietHoursEnabled }

    var body: some View {
        TaskerCard {
            VStack(spacing: TaskerSwiftUITokens.spacing.s16) {
                // Header toggle row
                HStack(spacing: TaskerSwiftUITokens.spacing.s12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.tasker(.sectionTitle))
                        .foregroundColor(.tasker(.accentPrimary))
                        .frame(width: 24)

                    Text("Quiet Hours")
                        .font(.tasker(.bodyStrong))
                        .foregroundColor(.tasker(.textPrimary))

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { isEnabled },
                        set: { viewModel.togglePreference(\.quietHoursEnabled, value: $0) }
                    ))
                    .labelsHidden()
                    .tint(Color.tasker(.accentPrimary))
                    .disabled(disabled)
                }

                // Expanded content
                if isEnabled {
                    VStack(spacing: TaskerSwiftUITokens.spacing.s16) {
                        // Visual time bar
                        QuietHoursTimeBar(
                            startHour: viewModel.preferences.quietHoursStartHour,
                            startMinute: viewModel.preferences.quietHoursStartMinute,
                            endHour: viewModel.preferences.quietHoursEndHour,
                            endMinute: viewModel.preferences.quietHoursEndMinute
                        )

                        // Time pickers
                        HStack {
                            VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s4) {
                                Text("Start")
                                    .font(.tasker(.caption2))
                                    .foregroundColor(.tasker(.textTertiary))
                                DatePicker("", selection: Binding(
                                    get: { viewModel.quietHoursStartTime },
                                    set: { viewModel.quietHoursStartTime = $0 }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(Color.tasker(.accentPrimary))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: TaskerSwiftUITokens.spacing.s4) {
                                Text("End")
                                    .font(.tasker(.caption2))
                                    .foregroundColor(.tasker(.textTertiary))
                                DatePicker("", selection: Binding(
                                    get: { viewModel.quietHoursEndTime },
                                    set: { viewModel.quietHoursEndTime = $0 }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(Color.tasker(.accentPrimary))
                            }
                        }

                        Divider()
                            .background(Color.tasker.strokeHairline)

                        // Scope chips
                        VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s8) {
                            Text("APPLIES TO")
                                .font(.tasker(.caption2))
                                .foregroundColor(.tasker(.textTertiary))
                                .tracking(0.5)

                            HStack(spacing: TaskerSwiftUITokens.spacing.s8) {
                                TaskerChip(
                                    title: "Task Alerts",
                                    isSelected: viewModel.preferences.quietHoursAppliesToTaskAlerts,
                                    selectedStyle: .tinted,
                                    action: {
                                        viewModel.togglePreference(
                                            \.quietHoursAppliesToTaskAlerts,
                                            value: !viewModel.preferences.quietHoursAppliesToTaskAlerts
                                        )
                                    }
                                )

                                TaskerChip(
                                    title: "Daily Summaries",
                                    isSelected: viewModel.preferences.quietHoursAppliesToDailySummaries,
                                    selectedStyle: .tinted,
                                    action: {
                                        viewModel.togglePreference(
                                            \.quietHoursAppliesToDailySummaries,
                                            value: !viewModel.preferences.quietHoursAppliesToDailySummaries
                                        )
                                    }
                                )
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .opacity(disabled ? 0.5 : 1.0)
            .animation(TaskerAnimation.gentle, value: isEnabled)
        }
    }
}
