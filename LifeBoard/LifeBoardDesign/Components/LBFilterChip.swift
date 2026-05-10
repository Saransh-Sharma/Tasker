import SwiftUI

struct LBFilterChip: View {
    struct Model: Identifiable, Equatable {
        let id: String
        let title: String
        let systemImage: String
        let isSelected: Bool
        let accessibilityID: String?
    }

    let model: Model
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LBSpacingTokens.xs) {
                Image(systemName: model.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                Text(model.title)
                    .lineLimit(1)
            }
            .font(LBTypographyTokens.chip)
            .foregroundStyle(model.isSelected ? Color.white : LBColorTokens.navy)
            .frame(minHeight: 44)
            .padding(.horizontal, LBSpacingTokens.sm)
            .background {
                Group {
                    if model.isSelected {
                        LinearGradient(
                            colors: [LBColorTokens.violet, LBColorTokens.violetDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(colors: [LBColorTokens.glassStrong, LBColorTokens.glass], startPoint: .top, endPoint: .bottom)
                    }
                }
                .clipShape(Capsule())
            }
            .overlay {
                Capsule()
                    .stroke(model.isSelected ? Color.white.opacity(0.52) : LBColorTokens.hairline.opacity(0.70), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(model.accessibilityID ?? "home.sunrise.filter.\(model.id)")
    }
}
