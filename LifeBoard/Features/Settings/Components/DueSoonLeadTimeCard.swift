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
        SurfaceCard {
            VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s12) {
                Text("DUE SOON LEAD TIME")
                    .font(.lifeboard(.caption2))
                    .foregroundColor(.lifeboard(.textTertiary))
                    .tracking(0.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SwiftUITokens.spacing.s8) {
                        ForEach(options, id: \.minutes) { option in
                            Chip(
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
