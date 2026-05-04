import SwiftUI

struct QuietHoursCard: View {
    @ObservedObject var viewModel: SettingsViewModel

    private var disabled: Bool { viewModel.isPermissionDenied }
    private var isEnabled: Bool { viewModel.preferences.quietHoursEnabled }

    var body: some View {
        LifeBoardCard {
            VStack(spacing: LifeBoardSwiftUITokens.spacing.s16) {
                // Header toggle row
                HStack(spacing: LifeBoardSwiftUITokens.spacing.s12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.lifeboard(.sectionTitle))
                        .foregroundColor(.lifeboard(.accentPrimary))
                        .frame(width: 24)

                    Text("Quiet Hours")
                        .font(.lifeboard(.bodyStrong))
                        .foregroundColor(.lifeboard(.textPrimary))

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { isEnabled },
                        set: { viewModel.togglePreference(\.quietHoursEnabled, value: $0) }
                    ))
                    .labelsHidden()
                    .tint(Color.lifeboard(.accentPrimary))
                    .disabled(disabled)
                }

                // Expanded content
                if isEnabled {
                    VStack(spacing: LifeBoardSwiftUITokens.spacing.s16) {
                        // Visual time bar
                        QuietHoursTimeBar(
                            startHour: viewModel.preferences.quietHoursStartHour,
                            startMinute: viewModel.preferences.quietHoursStartMinute,
                            endHour: viewModel.preferences.quietHoursEndHour,
                            endMinute: viewModel.preferences.quietHoursEndMinute
                        )

                        // Time pickers
                        HStack {
                            VStack(alignment: .leading, spacing: LifeBoardSwiftUITokens.spacing.s4) {
                                Text("Start")
                                    .font(.lifeboard(.caption2))
                                    .foregroundColor(.lifeboard(.textTertiary))
                                DatePicker("", selection: Binding(
                                    get: { viewModel.quietHoursStartTime },
                                    set: { viewModel.quietHoursStartTime = $0 }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(Color.lifeboard(.accentPrimary))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: LifeBoardSwiftUITokens.spacing.s4) {
                                Text("End")
                                    .font(.lifeboard(.caption2))
                                    .foregroundColor(.lifeboard(.textTertiary))
                                DatePicker("", selection: Binding(
                                    get: { viewModel.quietHoursEndTime },
                                    set: { viewModel.quietHoursEndTime = $0 }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(Color.lifeboard(.accentPrimary))
                            }
                        }

                        Divider()
                            .background(Color.lifeboard.strokeHairline)

                        // Scope chips
                        VStack(alignment: .leading, spacing: LifeBoardSwiftUITokens.spacing.s8) {
                            Text("APPLIES TO")
                                .font(.lifeboard(.caption2))
                                .foregroundColor(.lifeboard(.textTertiary))
                                .tracking(0.5)

                            HStack(spacing: LifeBoardSwiftUITokens.spacing.s8) {
                                LifeBoardChip(
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

                                LifeBoardChip(
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
            .animation(LifeBoardAnimation.gentle, value: isEnabled)
        }
    }
}
