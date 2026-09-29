import SwiftUI

// MARK: - Habit board lenses (Day / Week / Graph) + grouping

/// The three viewing lenses on the habit board, mirroring the best-in-class
/// habit trackers: Day for action, Week for the pinned matrix, Graph for the
/// long-run heatmap. `week` is the app's existing flagship matrix.
enum HabitBoardMode: String, CaseIterable, Identifiable {
    case day
    case week
    case graph

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return String(localized: "Day")
        case .week: return String(localized: "Week")
        case .graph: return String(localized: "Graph")
        }
    }

    var symbolName: String {
        switch self {
        case .day: return "sun.max"
        case .week: return "square.grid.3x3"
        case .graph: return "chart.dots.scatter"
        }
    }
}

/// How Day/Graph lenses partition habits into sections. Grounded in real habit
/// metadata — no invented dimensions.
enum HabitBoardGrouping: String, CaseIterable, Identifiable {
    case timeOfDay
    case list
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeOfDay: return String(localized: "Time of day")
        case .list: return String(localized: "Area")
        case .none: return String(localized: "None")
        }
    }
}

/// A daypart bucket derived from a habit's reminder window start ("HH:mm").
enum HabitDaypartBucket: Int, CaseIterable, Identifiable {
    case anytime
    case morning
    case afternoon
    case evening

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .anytime: return String(localized: "Any time")
        case .morning: return String(localized: "Morning")
        case .afternoon: return String(localized: "Afternoon")
        case .evening: return String(localized: "Evening")
        }
    }

    var symbolName: String {
        switch self {
        case .anytime: return "clock"
        case .morning: return "sunrise"
        case .afternoon: return "sun.max"
        case .evening: return "moon.stars"
        }
    }

    /// Parses a reminder-window start string; `nil`/unparseable → Any time.
    static func bucket(forReminderStart start: String?) -> HabitDaypartBucket {
        guard let start, let hour = hour(from: start) else { return .anytime }
        switch hour {
        case 0..<12: return .morning
        case 12..<17: return .afternoon
        default: return .evening
        }
    }

    private static func hour(from value: String) -> Int? {
        let parts = value.split(separator: ":")
        guard let first = parts.first, let hour = Int(first), (0...23).contains(hour) else { return nil }
        return hour
    }
}

/// A resolved section of habits under the active grouping.
struct HabitBoardGroupedSection: Identifiable {
    let id: String
    let title: String
    let symbolName: String?
    let rows: [HabitBoardRowPresentation]

    static func build(
        rows: [HabitBoardRowPresentation],
        grouping: HabitBoardGrouping,
        libraryRow: (UUID) -> HabitLibraryRow?
    ) -> [HabitBoardGroupedSection] {
        guard rows.isEmpty == false else { return [] }

        switch grouping {
        case .none:
            return [HabitBoardGroupedSection(id: "all", title: "All habits", symbolName: nil, rows: rows)]

        case .timeOfDay:
            var buckets: [HabitDaypartBucket: [HabitBoardRowPresentation]] = [:]
            for row in rows {
                let bucket = HabitDaypartBucket.bucket(forReminderStart: libraryRow(row.habitID)?.reminderWindowStart)
                buckets[bucket, default: []].append(row)
            }
            return HabitDaypartBucket.allCases.compactMap { bucket in
                guard let bucketRows = buckets[bucket], bucketRows.isEmpty == false else { return nil }
                return HabitBoardGroupedSection(
                    id: "daypart-\(bucket.rawValue)",
                    title: bucket.title,
                    symbolName: bucket.symbolName,
                    rows: bucketRows
                )
            }

        case .list:
            var order: [String] = []
            var buckets: [String: [HabitBoardRowPresentation]] = [:]
            for row in rows {
                let name = libraryRow(row.habitID)?.lifeAreaName ?? String(localized: "No area")
                if buckets[name] == nil { order.append(name) }
                buckets[name, default: []].append(row)
            }
            return order.map { name in
                HabitBoardGroupedSection(
                    id: "list-\(name)",
                    title: name,
                    symbolName: "folder",
                    rows: buckets[name] ?? []
                )
            }
        }
    }
}
