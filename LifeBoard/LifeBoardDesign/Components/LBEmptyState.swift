import SwiftUI

struct LBEmptyState: View {
    struct Model: Equatable {
        let title: String
        let message: String
        let actionTitle: String
        let systemImage: String
    }

    let model: Model
    let action: () -> Void

    var body: some View {
        LBGlassCard(cornerRadius: LBRadiusTokens.largeCard) {
            VStack(spacing: LBSpacingTokens.md) {
                LBIconBadge(systemName: model.systemImage, role: .assistant, size: 52)
                Text(model.title)
                    .font(LBTypographyTokens.sectionTitle)
                    .foregroundStyle(LBColorTokens.navy)
                    .multilineTextAlignment(.center)
                Text(model.message)
                    .font(LBTypographyTokens.body)
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .multilineTextAlignment(.center)
                LBPrimaryButton(title: model.actionTitle, systemImage: "plus", action: action)
            }
            .padding(LBSpacingTokens.xl)
            .frame(maxWidth: .infinity)
        }
    }
}
