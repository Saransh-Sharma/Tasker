import SwiftUI

struct IconBadge: View {
    let systemName: String
    var role: ClayRole = .neutral
    var size: CGFloat = 42

    /// The badge and its glyph grow together with Dynamic Type (capped at
    /// +30%), so the glyph never outgrows its tile and the row's text still
    /// leads at accessibility sizes.
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    var body: some View {
        let style = ClayColorTokens.role(role)
        let size = self.size * min(max(typeScale, 1), 1.3)
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
            .foregroundStyle(style.deep) // `base` glyphs sat at 1.4–2.7:1 on `softSurface`
            .frame(width: size, height: size)
            .background(style.softSurface)
            .clipShape(RoundedRectangle(cornerRadius: min(16, size * 0.34), style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: min(16, size * 0.34), style: .continuous)
                    .stroke(style.border.opacity(0.8), lineWidth: 1)
            }
    }
}
