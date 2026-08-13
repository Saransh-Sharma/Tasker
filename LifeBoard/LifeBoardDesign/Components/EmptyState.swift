import SwiftUI

struct EmptyState: View {
    struct Model: Equatable {
        let title: String
        let message: String
        let actionTitle: String
        let systemImage: String
        var actionSystemImage: String = "plus"
    }

    let model: Model
    let action: () -> Void

    var body: some View {
        GlassCard(cornerRadius: RadiusTokens.largeCard) {
            VStack(spacing: ClayLayoutMetrics.md) {
                IconBadge(systemName: model.systemImage, role: .assistant, size: 52)
                Text(model.title)
                    .font(ClayTypography.sectionTitle)
                    .foregroundStyle(ClayColorTokens.navy)
                    .multilineTextAlignment(.center)
                Text(model.message)
                    .font(ClayTypography.body)
                    .foregroundStyle(ClayColorTokens.navyMuted)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: model.actionTitle, systemImage: model.actionSystemImage, action: action)
            }
            .padding(ClayLayoutMetrics.xl)
            .frame(maxWidth: .infinity)
        }
    }
}
