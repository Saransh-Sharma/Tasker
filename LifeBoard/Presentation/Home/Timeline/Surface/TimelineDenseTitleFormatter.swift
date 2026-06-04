import SwiftUI

enum TimelineDenseTitleFormatter {
    static func displayTitles(for items: [TimelinePlanItem]) -> [String: String] {
        let basePairs = items.map { item in
            (item.id, compressedTitle(for: item.title, subtitle: item.subtitle))
        }
        let grouped = Dictionary(grouping: basePairs) { $0.1 }
        var result: [String: String] = [:]

        for (title, pairs) in grouped {
            if pairs.count == 1, let id = pairs.first?.0 {
                result[id] = title
            } else {
                for pair in pairs {
                    guard let item = items.first(where: { $0.id == pair.0 }) else {
                        result[pair.0] = title
                        continue
                    }
                    if let start = item.startDate {
                        result[pair.0] = "\(title) \(start.formatted(date: .omitted, time: .shortened))"
                    } else {
                        result[pair.0] = title
                    }
                }
            }
        }

        return result
    }

    static func compressedTitle(for title: String, subtitle: String?) -> String {
        var value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: #"^\[[^\]]+\]\s*"#, with: "", options: .regularExpression)

        if let subtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           subtitle.isEmpty == false,
           value.localizedCaseInsensitiveContains("\(subtitle):") {
            value = value.replacingOccurrences(of: "\(subtitle):", with: "", options: .caseInsensitive)
        }

        let lower = title.lowercased()
        if lower.hasPrefix("[daily]"), value.localizedCaseInsensitiveContains("daily") == false {
            value = "Daily \(value)"
        }
        if lower.hasPrefix("[fortnightly]") {
            value = value.replacingOccurrences(of: "App Review", with: "Review", options: .caseInsensitive)
        }

        value = value.replacingOccurrences(
            of: #"^(.+?)\s*[-:]\s*\1\s+"#,
            with: "$1 ",
            options: [.regularExpression, .caseInsensitive]
        )
        value = value.replacingOccurrences(of: "Consumer App Review", with: "Consumer Review", options: .caseInsensitive)
        value = value.replacingOccurrences(of: "Mobile Release Sync", with: "Mobile Release", options: .caseInsensitive)
        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? title : value
    }
}
