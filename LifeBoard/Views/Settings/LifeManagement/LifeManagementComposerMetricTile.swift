import SwiftUI
import UIKit

struct LifeManagementComposerMetricTile: View {
    let metric: LifeManagementComposerPreviewMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.white.opacity(0.72))

            Text(metric.value)
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}
