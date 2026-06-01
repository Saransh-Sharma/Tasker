import SwiftUI

struct TodayTaskRow: View {
    let index: Int
    let task: DailyPlanTaskOption
    let onSwap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: LBSpacingTokens.sm) {
            Text("\(index + 1)")
                .font(.lifeboard(.caption1).weight(.bold))
                .foregroundStyle(LBColorTokens.role(.focus).deep)
                .frame(width: 28, height: 28)
                .background(ReflectPlanStyle.blueSurface, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navy)
                    .fixedSize(horizontal: false, vertical: true)

                if let projectName = task.projectName, projectName.isEmpty == false {
                    Text(projectName)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(LBColorTokens.navyMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: LBSpacingTokens.sm)

            Button("Swap", action: onSwap)
                .font(.lifeboard(.caption1).weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(LBColorTokens.role(.focus).deep)
                .frame(minWidth: 52, minHeight: 44, alignment: .trailing)
                .accessibilityLabel("Swap task \(index + 1)")
        }
        .padding(.horizontal, LBSpacingTokens.md)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = ["Task \(index + 1)", task.title]
        if let projectName = task.projectName, projectName.isEmpty == false {
            parts.append("Project \(projectName)")
        }
        parts.append("Swap task")
        return parts.joined(separator: ". ")
    }
}
