import SwiftUI

struct LBIconBadge: View {
    let systemName: String
    var role: LBRole = .neutral
    var size: CGFloat = 42

    var body: some View {
        let style = LBColorTokens.role(role)
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
            .foregroundStyle(style.base)
            .frame(width: size, height: size)
            .background(style.softSurface)
            .clipShape(RoundedRectangle(cornerRadius: min(16, size * 0.34), style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: min(16, size * 0.34), style: .continuous)
                    .stroke(style.border.opacity(0.8), lineWidth: 1)
            }
    }
}
