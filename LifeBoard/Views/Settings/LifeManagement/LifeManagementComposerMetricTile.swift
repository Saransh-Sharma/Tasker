import SwiftUI
import UIKit

struct LifeManagementComposerMetricTile: View {
    let metric: LifeManagementComposerPreviewMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.secondary, on: .image, imageLuminance: 0.2))

            Text(metric.value)
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.primary, on: .image, imageLuminance: 0.2))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous)
                .fill(LBColorTokens.whiteStroke.opacity(0.12))
        )
    }
}
