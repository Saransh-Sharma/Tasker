import SwiftUI

struct TimelineCapsule: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let palette: TimelinePalette
    @Environment(\.lifeboardLayoutClass) var layoutClass

    var body: some View {
        GeometryReader { proxy in
            let capsuleShape = RoundedRectangle(cornerRadius: proxy.size.width / 2, style: .continuous)
            let progress = min(max(row.progressRatio, 0), 1)
            let progressHeight = proxy.size.height * progress
            let transitionHeight = min(12, max(6, proxy.size.height * 0.10))
            let isCompleted = row.temporalState == .pastCompleted
            let isCurrent = row.temporalState == .currentTask
            let isPastIncomplete = row.temporalState == .pastIncomplete
            let isExpandedPad = layoutClass == .padRegular || layoutClass == .padExpanded
            let baseFill: Color = {
                if isCompleted {
                    return palette.progress.opacity(0.92)
                }
                if isPastIncomplete {
                    return palette.fill.opacity(0.28)
                }
                return TimelineVisualTokens.futureCapsule
            }()
            let iconColor: Color = {
                if isCompleted || isCurrent {
                    return Color.white.opacity(0.96)
                }
                if isPastIncomplete {
                    return palette.icon.opacity(0.9)
                }
                return palette.icon
            }()

            ZStack(alignment: .top) {
                capsuleShape
                    .fill(baseFill)

                if isCurrent, progressHeight > 0 {
                    VStack(spacing: 0) {
                        capsuleShape
                            .fill(palette.progress)
                            .frame(height: progressHeight)
                        Spacer(minLength: 0)
                    }
                    .clipShape(capsuleShape)

                    if progressHeight < proxy.size.height {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        palette.progress.opacity(0),
                                        palette.halo.opacity(isExpandedPad ? 0.54 : 0.82),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: transitionHeight)
                            .offset(y: max(0, progressHeight - (transitionHeight / 2)))
                            .clipShape(capsuleShape)
                    }
                }

                Image(systemName: item.systemImageName)
                    .font(.system(size: proxy.size.width >= 56 ? 22 : (proxy.size.width >= 48 ? 20 : 18), weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .overlay {
                capsuleShape
                    .stroke(
                        isCurrent
                            ? palette.halo.opacity(isExpandedPad ? 0.74 : 0.9)
                            : (isCompleted
                                ? palette.halo.opacity(0.22)
                                : (layoutClass.isPad ? TimelineVisualTokens.futureCapsuleStroke : palette.halo.opacity(0.58))),
                        lineWidth: isCurrent ? 1.25 : 1
                    )
            }
        }
    }
}
