import SwiftUI

extension ProjectManagementView {
    func quickActionButton(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    func planningBucketChip(_ bucket: TaskPlanningBucket) -> some View {
        statusChip(bucket.displayName, tint: bucketColor(bucket), systemImage: bucket.systemImageName)
    }

    func statusChip(_ title: String, tint: Color, systemImage: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.08), in: Capsule())
    }

    private func bucketColor(_ bucket: TaskPlanningBucket) -> Color {
        switch bucket {
        case .today:
            return Color.lifeboard.statusSuccess
        case .thisWeek:
            return Color.lifeboard.accentPrimary
        case .nextWeek:
            return Color.lifeboard.statusWarning
        case .later, .someday:
            return Color.lifeboard.textSecondary
        }
    }
}
