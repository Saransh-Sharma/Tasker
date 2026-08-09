import SwiftUI

struct PermissionCard: View {
    struct Model: Equatable {
        let title: String
        let message: String
        let role: ClayRole
        let primaryActionTitle: String
        let secondaryActionTitle: String?
    }

    let model: Model
    let primaryAction: () -> Void
    var secondaryAction: (() -> Void)?

    var body: some View {
        let style = ClayColorTokens.role(model.role)
        GlassCard(cornerRadius: RadiusTokens.card, borderColor: style.border, fill: style.softSurface.opacity(0.78)) {
            HStack(alignment: .top, spacing: ClayLayoutMetrics.md) {
                IconBadge(systemName: style.symbolName, role: model.role)
                VStack(alignment: .leading, spacing: ClayLayoutMetrics.xs) {
                    Text(model.title)
                        .font(ClayTypography.cardTitle)
                        .foregroundStyle(ClayColorTokens.navy)
                    Text(model.message)
                        .font(ClayTypography.meta)
                        .foregroundStyle(ClayColorTokens.navyMuted)
                    HStack(spacing: ClayLayoutMetrics.sm) {
                        Button(model.primaryActionTitle, action: primaryAction)
                            .font(ClayTypography.meta)
                            .buttonStyle(.plain)
                            .foregroundStyle(style.deep)
                        if let secondary = model.secondaryActionTitle, let secondaryAction {
                            Button(secondary, action: secondaryAction)
                                .font(ClayTypography.meta)
                                .buttonStyle(.plain)
                                .foregroundStyle(ClayColorTokens.navyMuted)
                        }
                    }
                    .padding(.top, ClayLayoutMetrics.xxs)
                }
                Spacer(minLength: 0)
            }
            .padding(ClayLayoutMetrics.md)
        }
    }
}
