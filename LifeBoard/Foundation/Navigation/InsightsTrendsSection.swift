import SwiftUI
import UIKit

/// The trends lens's tally: what was recorded in the chosen range, area by
/// area, each counted in its own terms.
///
/// This used to draw one "records per day" line that added water logs, tasks
/// and moods together — a sum with no unit that could rise because someone
/// drank more water and read like a trend in something. The per-area charts
/// with real units live in `InsightsSeriesSection` above; this section keeps
/// the counts separate and labelled instead of charting their sum.
struct InsightsTrendsSection: View {
    let interpretation: InsightsInterpretation
    let sourceCounts: [(domain: String, count: Int)]
    /// The range the charts above are showing, so this tally reads the same
    /// window.
    var rangeDays: Int = InsightsRange.week.days

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("What you recorded", count: sourceCounts.count)
            // A tally states its timeframe and where the numbers came from.
            Text(rangeDays == 1 ? "Today · in LifeBoard" : "Last \(rangeDays) days · in LifeBoard")
                .lifeboardFont(.meta)
                .foregroundStyle(Color.lifeboard(.textSecondary))

            if sourceCounts.isEmpty {
                Text("Nothing recorded yet")
                    .lifeboardFont(.support)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            ForEach(sourceCounts, id: \.domain) { item in
                HStack {
                    Text(InsightsDomainCopy.title(for: item.domain))
                    Spacer()
                    Text(InsightsDomainCopy.count(item.count, for: item.domain))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .monospacedDigit()
                }
                .lifeBoardScrollEntrance(intensity: 0.5)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
    }
}

/// People-facing names for the life-event domain keys ("hydration",
/// "plan"), and a count in each area's own noun.
enum InsightsDomainCopy {
    static func title(for domain: String) -> String {
        switch domain {
        case "hydration": "Water"
        case "habit": "Habits"
        case "tracker": "Trackers"
        case "routine": "Routines"
        case "goal": "Goals"
        case "plan": "Plan"
        case "focus": "Focus"
        case "journal": "Journal"
        case "mood": "Mood"
        case "medication": "Medication"
        case "sleep": "Sleep"
        case "workout": "Workouts"
        case "movement": "Movement"
        case "body": "Body measurements"
        default: domain.localizedCapitalized
        }
    }

    static func count(_ count: Int, for domain: String) -> String {
        let noun: (String, String) = switch domain {
        case "hydration": ("drink logged", "drinks logged")
        case "habit": ("check-in", "check-ins")
        case "routine": ("routine run", "routines run")
        case "goal": ("update", "updates")
        case "plan": ("plan change", "plan changes")
        case "focus": ("focus event", "focus events")
        case "journal": ("entry", "entries")
        case "mood": ("check-in", "check-ins")
        case "medication": ("dose logged", "doses logged")
        case "sleep": ("night", "nights")
        case "workout": ("workout", "workouts")
        case "movement": ("day of movement", "days of movement")
        case "body": ("measurement", "measurements")
        default: ("entry", "entries")
        }
        return "\(count) \(count == 1 ? noun.0 : noun.1)"
    }
}
