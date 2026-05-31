import SwiftUI

struct TimelineRoutineAnchorCard: View {
    let style: TimelineRoutineAnchorVisualStyle
    let timeText: String
    let onTap: () -> Void
    var minimumHeight: CGFloat = 96
    var leadingArtworkReserve: CGFloat = 92
    var accessibilityHint: String?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lifeboardScrollOptimizedRendering) private var scrollOptimizedRendering

    var body: some View {
        Button(action: onTap) {
            ZStack {
                imageLayer
                readabilityLayer
                textLayer
            }
            .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .center)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(style.borderColor.opacity(0.74), lineWidth: 1)
        }
        .shadow(
            color: scrollOptimizedRendering ? .clear : LBColorTokens.elevationShadow.opacity(0.08),
            radius: scrollOptimizedRendering ? 0 : 10,
            x: 0,
            y: scrollOptimizedRendering ? 0 : 5
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(style.accessibilityLabel(timeText: timeText))
        .accessibilityHint(accessibilityHint ?? "Edit timeline anchor time")
    }

    private var cornerRadius: CGFloat { 24 }

    private var imageLayer: some View {
        GeometryReader { proxy in
            Image(decorative: style.assetName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }

    private var readabilityLayer: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.20),
                .init(color: style.scrimColor.opacity(reduceTransparency ? 0.64 : 0.34), location: 0.54),
                .init(color: style.scrimColor.opacity(reduceTransparency ? 0.72 : 0.42), location: 1.00)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .accessibilityHidden(true)
    }

    private var textLayer: some View {
        HStack(alignment: .center, spacing: 0) {
            Color.clear
                .frame(width: leadingArtworkReserve)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(style.displayTitle)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(style.titleColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                Text(style.subtitleText(timeText: timeText))
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(style.subtitleColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.trailing, 16)
        .padding(.vertical, 14)
    }
}
