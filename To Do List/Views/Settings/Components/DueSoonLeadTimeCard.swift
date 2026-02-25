import SwiftUI

struct DueSoonLeadTimeCard: View {
    @ObservedObject var viewModel: SettingsViewModel

    private let options: [(minutes: Int, label: String)] = [
        (15, "15m"),
        (30, "30m"),
        (45, "45m"),
        (60, "1h"),
        (90, "1.5h"),
        (120, "2h"),
    ]

    private var disabled: Bool {
        viewModel.isPermissionDenied || !viewModel.preferences.dueSoonEnabled
    }

    var body: some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s12) {
                Text("DUE SOON LEAD TIME")
                    .font(.tasker(.caption2))
                    .foregroundColor(.tasker(.textTertiary))
                    .tracking(0.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TaskerSwiftUITokens.spacing.s8) {
                        ForEach(options, id: \.minutes) { option in
                            TaskerChip(
                                title: option.label,
                                isSelected: viewModel.preferences.dueSoonLeadMinutes == option.minutes,
                                selectedStyle: .filled,
                                action: {
                                    viewModel.updateDueSoonLeadMinutes(option.minutes)
                                }
                            )
                            .disabled(disabled)
                        }
                    }
                }
            }
            .opacity(disabled ? 0.5 : 1.0)
        }
    }
}
