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
            VStack(spacing: LBSpacingTokens.md) {
                IconBadge(systemName: model.systemImage, role: .assistant, size: 52)
                Text(model.title)
                    .font(LBTypographyTokens.sectionTitle)
                    .foregroundStyle(LBColorTokens.navy)
                    .multilineTextAlignment(.center)
                Text(model.message)
                    .font(LBTypographyTokens.body)
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: model.actionTitle, systemImage: model.actionSystemImage, action: action)
            }
            .padding(LBSpacingTokens.xl)
            .frame(maxWidth: .infinity)
        }
    }
}
