import SwiftUI

struct TodayPlanCard: View {
    let plan: EditableDailyPlan?
    let focusWindowText: String
    let protectedHabitText: String
    let clearFirstText: String
    let planningStatusMessage: String?
    let onSwap: (Int) -> Void
    var onAddTask: (() -> Void)?
    var onChooseFocusWindow: (() -> Void)?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
            header

            if let plan, plan.topTasks.isEmpty == false {
                VStack(spacing: 0) {
                    ForEach(Array(plan.topTasks.prefix(3).enumerated()), id: \.element.id) { index, task in
                        TodayTaskRow(index: index, task: task) {
                            onSwap(index)
                        }
                        if index < min(plan.topTasks.count, 3) - 1 {
                            Divider()
                                .overlay(ReflectPlanStyle.blueBorder.opacity(0.72))
                                .padding(.leading, 42)
                        }
                    }
                }
                .background(ReflectPlanStyle.blueSurfaceStrong.opacity(0.70), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                emptyTasks
            }

            VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
                PlanningSummaryRow(title: "Focus window", value: focusWindowText, systemImage: "clock", actionTitle: focusWindowText == "Not set yet" ? "Choose window" : nil, action: onChooseFocusWindow)
                PlanningSummaryRow(title: "Protected habit", value: protectedHabitText, systemImage: "shield.lefthalf.filled")
                PlanningSummaryRow(title: "Clear first", value: clearFirstText, systemImage: "list.bullet.rectangle")
            }
            .padding(LBSpacingTokens.md)
            .background(ReflectPlanStyle.cream.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            if let planningStatusMessage {
                Text(planningStatusMessage)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LBSpacingTokens.lg)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(ReflectPlanStyle.blueBorder.opacity(0.78), lineWidth: 1)
        )
        .shadow(color: ReflectPlanStyle.shadow, radius: 22, x: 0, y: 12)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: LBSpacingTokens.md) {
            ZStack {
                Circle()
                    .fill(ReflectPlanStyle.blueSurfaceStrong)
                    .frame(width: 42, height: 42)
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LBColorTokens.role(.focus).deep)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.lifeboard(.title2).weight(.bold))
                    .foregroundStyle(LBColorTokens.navy)
                Text("Stay narrow. Finish what moves the needle.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: LBSpacingTokens.sm)

            FocusPill(title: "Focus", value: focusWindowText)
        }
    }

    private var emptyTasks: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
            Text("Today is open.")
                .font(.lifeboard(.headline))
                .foregroundStyle(LBColorTokens.navy)
            Text("Add one clear task to anchor the day.")
                .font(.lifeboard(.callout))
                .foregroundStyle(LBColorTokens.navyMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button("Add task") {
                onAddTask?()
            }
            .font(.lifeboard(.caption1).weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(LBColorTokens.role(.focus).deep)
            .frame(minHeight: 44, alignment: .leading)
            .accessibilityIdentifier("reflection.plan.today.addTask")
        }
        .padding(LBSpacingTokens.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReflectPlanStyle.blueSurfaceStrong.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityIdentifier("reflection.plan.today.empty")
    }

    @ViewBuilder
    private var cardBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(ReflectPlanStyle.blueSurfaceStrong)
        } else {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ReflectPlanStyle.blueSurfaceStrong,
                            ReflectPlanStyle.blueSurface,
                            ReflectPlanStyle.cream
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
    }
}
