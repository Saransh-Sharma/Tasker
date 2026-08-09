import SwiftUI

// Colour, capsule geometry, and the text formatting the timeline
// shares across every row and card.

// MARK: - TimelinePalette

struct TimelinePalette {
    let base: Color
    let fill: Color
    let progress: Color
    let icon: Color
    let ring: Color
    let halo: Color

    @MainActor
    static func resolve(from tintHex: String?) -> TimelinePalette {
        let base: Color
        if let tintHex {
            base = Color(uiColor: UIColor(lifeboardHex: tintHex))
        } else {
            base = Color.lifeboard.accentPrimary
        }
        return TimelinePalette(
            base: base,
            fill: base.opacity(0.16),
            progress: base.opacity(0.74),
            icon: base.opacity(0.96),
            ring: base.opacity(0.88),
            halo: base.opacity(0.12)
        )
    }
}

// MARK: - TimelineVisualTokens

enum TimelineVisualTokens {
    @MainActor
    static var neutralStem: Color { Color.lifeboard.strokeHairline.opacity(0.42) }

    @MainActor
    static var gapPastStem: Color { Color.lifeboard.accentPrimary.opacity(0.18) }

    @MainActor
    static var futureCapsule: Color { Color.lifeboard.surfacePrimary.opacity(0.9) }

    @MainActor
    static var futureCapsuleStroke: Color { Color.lifeboard.strokeHairline.opacity(0.58) }

    @MainActor
    static var anchorCapsuleFill: Color { Color.lifeboard.surfacePrimary.opacity(0.94) }

    @MainActor
    static var metaText: Color { Color.lifeboard.textSecondary }

    @MainActor
    static var utilityText: Color { Color.lifeboard.textTertiary }
}

// MARK: - TimelineItemVisuals

enum TimelineItemVisuals {
    @MainActor
    static func metaColor(for item: TimelinePlanItem) -> Color {
        item.isComplete ? Color.lifeboard.textTertiary.opacity(0.68) : Color.lifeboard.textSecondary
    }

    @MainActor
    static func titleColor(for item: TimelinePlanItem) -> Color {
        item.isComplete ? Color.lifeboard.textSecondary.opacity(0.72) : Color.lifeboard.textPrimary
    }

    @MainActor
    static func accessoryColor(for item: TimelinePlanItem, isActive: Bool) -> Color {
        if item.isComplete {
            return Color.lifeboard.textSecondary.opacity(0.62)
        }
        return isActive ? Color.lifeboard.accentPrimary : Color.lifeboard.textSecondary
    }
}

// MARK: - TimelineCapsule

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
                    return Color.lifeboard(.textInverse).opacity(0.96)
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

// MARK: - timelineCapsuleHeight

func timelineCapsuleHeight(for duration: TimeInterval?) -> CGFloat {
    let minutes = Int(max(1, (duration ?? 30 * 60) / 60))
    switch minutes {
    case ..<23:
        return 64
    case ..<38:
        return 90
    case ..<53:
        return 110
    case ..<76:
        return 128
    case ..<106:
        return 168
    default:
        return 176
    }
}

// MARK: - TimelineFormatting

enum TimelineFormatting {
    static func durationText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(max(minutes, 1))m"
    }

    static func timeRangeText(start: Date, end: Date) -> String {
        "\(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened))"
    }
}

// MARK: - TimelineDenseTitleFormatter

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

// MARK: - TimelineRoutineTextFormatter

enum TimelineRoutineTextFormatter {
    static func subtitle(for anchor: TimelineAnchorItem, subtitle: String?, calendar: Calendar = .current) -> String {
        let timeText = TimelineRailTimeFormatter.railText(for: anchor.time, kind: .exact, calendar: calendar)
        guard let subtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              subtitle.isEmpty == false else {
            return timeText
        }
        return "\(timeText) · \(subtitle)"
    }
}

// MARK: - timelineMetaColor

@MainActor
func timelineMetaColor(for row: TimelineRenderableRow) -> Color {
    switch row.temporalState {
    case .pastCompleted:
        return Color.lifeboard.textTertiary.opacity(0.72)
    case .pastIncomplete:
        return Color.lifeboard.statusWarning.opacity(0.92)
    case .currentTask:
        return Color.lifeboard.textPrimary.opacity(0.92)
    default:
        return TimelineVisualTokens.metaText
    }
}

// MARK: - timelineMetaText

func timelineMetaText(for row: TimelineRenderableRow, item: TimelinePlanItem? = nil, anchor: TimelineAnchorItem? = nil) -> String {
    switch row.metadataMode {
    case .remainingTime(let minutes):
        return "\(minutes)m remaining"
    case .done:
        guard let item, let start = item.startDate, let end = item.endDate else { return "Done" }
        let durationText = TimelineFormatting.durationText(max(0, end.timeIntervalSince(start)))
        return "\(TimelineFormatting.timeRangeText(start: start, end: end)) · \(durationText) · Done"
    case .scheduled, .none:
        if let anchor {
            return anchor.time.formatted(date: .omitted, time: .shortened)
        }
        guard let item, let start = item.startDate, let end = item.endDate else { return "All day" }
        let durationText = TimelineFormatting.durationText(max(0, end.timeIntervalSince(start)))
        return "\(TimelineFormatting.timeRangeText(start: start, end: end)) · \(durationText)"
    }
}

// MARK: - timelineRingColor

@MainActor
func timelineRingColor(for row: TimelineRenderableRow, palette: TimelinePalette) -> Color {
    switch row.temporalState {
    case .pastCompleted:
        return palette.progress
    case .pastIncomplete:
        return palette.base.opacity(0.74)
    case .currentTask:
        return palette.progress
    default:
        return palette.ring
    }
}

// MARK: - timelineStemColor

@MainActor
func timelineStemColor(for state: TimelineStemSegmentState, fallbackPalette: TimelinePalette) -> Color {
    switch state {
    case .pastCompletedSegment(let tintHex):
        return TimelinePalette.resolve(from: tintHex).progress
    case .pastIncompleteSegment(let tintHex):
        return TimelinePalette.resolve(from: tintHex).progress.opacity(0.46)
    case .currentElapsedSegment(let tintHex, _):
        return TimelinePalette.resolve(from: tintHex).progress
    case .currentRemainingSegment, .futureSegment, .gapFutureSegment:
        return TimelineVisualTokens.neutralStem
    case .gapPastSegment:
        return TimelineVisualTokens.gapPastStem
    }
}

// MARK: - timelineTitleColor

@MainActor
func timelineTitleColor(for row: TimelineRenderableRow, item: TimelinePlanItem? = nil) -> Color {
    switch row.temporalState {
    case .pastCompleted:
        return Color.lifeboard.textSecondary.opacity(0.72)
    case .pastIncomplete:
        return Color.lifeboard.textPrimary.opacity(0.92)
    case .currentTask:
        return Color.lifeboard.textPrimary
    default:
        if let item {
            return TimelineItemVisuals.titleColor(for: item)
        }
        return Color.lifeboard.textPrimary
    }
}

// MARK: - timelineAccessibilityIdentifier

func timelineAccessibilityIdentifier(for item: TimelinePlanItem) -> String {
    if let eventID = item.eventID {
        return "home.timeline.event.\(eventID)"
    }
    if let taskID = item.taskID {
        return "home.timeline.task.\(taskID.uuidString)"
    }
    return "home.timeline.item.\(item.id)"
}

// MARK: - timelineAccessibilityLabel

func timelineAccessibilityLabel(for row: TimelineRenderableRow, item: TimelinePlanItem) -> String {
    var parts = [item.title, timelineMetaText(for: row, item: item)]
    if row.utilityItems.isEmpty == false {
        parts.append(row.utilityItems.map(\.accessibilityLabel).joined(separator: ", "))
    }
    return parts.joined(separator: ", ")
}
