import SwiftUI
import LifeBoardDomain

/// Seven bars, one per weekday, from `HabitWeekdayStatistics`. Each bar has a
/// text equivalent ("4 of 5") in its accessibility value, the reveal sweep
/// plays once when the numbers first arrive, and the line under it only
/// speaks when there are enough days to say something kind and true.
struct HabitWeekdayBarsSection: View {
    let statistics: HabitWeekdayStatistics
    let accent: Color

    @Environment(\.lifeboardTokens) private var tokens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealProgress: Double = 0

    private var spacing: SemanticSpacingTokens { tokens.spacing }
    private var calendar: Calendar { .current }
    private var hasData: Bool { statistics.weekdays.contains { $0.scheduled > 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("By weekday")
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
            if hasData {
                HStack(alignment: .bottom, spacing: spacing.s8) {
                    ForEach(statistics.weekdays) { weekday in
                        bar(for: weekday)
                    }
                }
                .frame(height: 96)
                .lifeboardChartRevealSweep(progress: revealProgress)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("habitDetail.weekday.bars")
                Text(statistics.summary(calendar: calendar) ?? String(localized: "Needs a few more weeks."))
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("habitDetail.weekday.summary")
            } else {
                Text("No check-ins yet.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: hasData, initial: true) { _, has in
            // Once, when the bars first have something to show.
            guard has, revealProgress == 0 else { return }
            if reduceMotion {
                revealProgress = 1
            } else {
                withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) { revealProgress = 1 }
            }
        }
    }

    private func bar(for weekday: HabitWeekdayStatistics.Weekday) -> some View {
        let rate = weekday.rate ?? 0
        let symbol = calendar.veryShortStandaloneWeekdaySymbols[(weekday.weekday - 1) % 7]
        return VStack(spacing: spacing.s4) {
            GeometryReader { proxy in
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(weekday.scheduled == 0 ? Color.lifeboard.textSecondary.opacity(0.16) : accent.opacity(0.35 + 0.65 * rate))
                        .frame(height: max(4, proxy.size.height * (weekday.scheduled == 0 ? 0.06 : max(0.06, rate))))
                }
            }
            Text(symbol)
                .font(.lifeboard(.caption2))
                .foregroundStyle(Color.lifeboard.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(calendar.standaloneWeekdaySymbols[(weekday.weekday - 1) % 7])
        .accessibilityValue(HabitWeekdayStatistics.barText(weekday))
        .accessibilityIdentifier("habitDetail.weekday.\(weekday.weekday)")
    }
}
