import SwiftUI

struct DueSoonLeadTimeCard: View {
    @ObservedObject var viewModel: SettingsViewModel

    private let options: [(minutes: Int, label: String)] = [
        (15, String(localized: "15 min")),
        (30, String(localized: "30 min")),
        (45, String(localized: "45 min")),
        (60, String(localized: "1 hr")),
        (90, String(localized: "90 min")),
        (120, String(localized: "2 hr")),
    ]

    private var disabled: Bool {
        viewModel.isPermissionDenied || !viewModel.preferences.dueSoonEnabled
    }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s12) {
                Text("Lead time")
                    .font(.lifeboard(.caption2))
                    .foregroundColor(.lifeboard(.textTertiary))

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
