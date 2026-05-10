import SwiftUI

struct LBPermissionCard: View {
    struct Model: Equatable {
        let title: String
        let message: String
        let role: LBRole
        let primaryActionTitle: String
        let secondaryActionTitle: String?
    }

    let model: Model
    let primaryAction: () -> Void
    var secondaryAction: (() -> Void)?

    var body: some View {
        let style = LBColorTokens.role(model.role)
        LBGlassCard(cornerRadius: LBRadiusTokens.card, borderColor: style.border, fill: style.softSurface.opacity(0.78)) {
            HStack(alignment: .top, spacing: LBSpacingTokens.md) {
                LBIconBadge(systemName: style.symbolName, role: model.role)
                VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                    Text(model.title)
                        .font(LBTypographyTokens.cardTitle)
                        .foregroundStyle(LBColorTokens.navy)
                    Text(model.message)
                        .font(LBTypographyTokens.meta)
                        .foregroundStyle(LBColorTokens.navyMuted)
                    HStack(spacing: LBSpacingTokens.sm) {
                        Button(model.primaryActionTitle, action: primaryAction)
                            .font(LBTypographyTokens.meta)
                            .buttonStyle(.plain)
                            .foregroundStyle(style.deep)
                        if let secondary = model.secondaryActionTitle, let secondaryAction {
                            Button(secondary, action: secondaryAction)
                                .font(LBTypographyTokens.meta)
                                .buttonStyle(.plain)
                                .foregroundStyle(LBColorTokens.navyMuted)
                        }
                    }
                    .padding(.top, LBSpacingTokens.xxs)
                }
                Spacer(minLength: 0)
            }
            .padding(LBSpacingTokens.md)
        }
    }
}
