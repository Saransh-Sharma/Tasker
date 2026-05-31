import CoreGraphics
import Foundation

struct TimelineAnchorRitualTimeOption: Equatable, Identifiable {
    let id: Int
    let date: Date
    let hourText: String
    let meridiemText: String
    let accessibilityText: String
    let isSelected: Bool
}

struct TimelineAnchorRitualModel: Equatable {
    let selection: TimelineAnchorSelection
    let title: String
    let subtitle: String
    let selectedTimeText: String
    let sectionTitle: String
    let footerText: String
    let selectedAccessibilityText: String
    let timeOptions: [TimelineAnchorRitualTimeOption]

    init(
        selection: TimelineAnchorSelection,
        selectedDate: Date,
        calendar: Calendar = .current
    ) {
        self.selection = selection
        self.title = selection.title
        self.subtitle = selection.subtitle
        self.selectedTimeText = Self.formatted(selectedDate, format: "h:mm a", calendar: calendar)
        self.sectionTitle = selection == .wake ? "Select start time" : "Select end time"
        self.footerText = selection == .wake
            ? "A beautiful day begins with intention."
            : "Rest well. Tomorrow is a new beginning."
        self.selectedAccessibilityText = selection == .wake
            ? "selected start time"
            : "selected end time"
        self.timeOptions = Self.options(
            centeredOn: selectedDate,
            selection: selection,
            calendar: calendar
        )
    }

    var modalAccessibilityLabel: String {
        "\(title). \(subtitle) Selected time, \(selectedTimeText)."
    }

    static func options(
        centeredOn selectedDate: Date,
        selection: TimelineAnchorSelection,
        calendar: Calendar = .current
    ) -> [TimelineAnchorRitualTimeOption] {
        (-2...2).enumerated().compactMap { index, offset in
            guard let date = calendar.date(byAdding: .minute, value: offset * 15, to: selectedDate) else {
                return nil
            }
            return TimelineAnchorRitualTimeOption(
                id: index,
                date: date,
                hourText: Self.formatted(date, format: "h:mm", calendar: calendar),
                meridiemText: Self.formatted(date, format: "a", calendar: calendar),
                accessibilityText: "\(Self.formatted(date, format: "h:mm a", calendar: calendar)), \(offset == 0 ? selectedAccessibilityText(for: selection) : selectableAccessibilityText(for: selection)).",
                isSelected: offset == 0
            )
        }
    }

    static func save(
        selectedDate: Date,
        selection: TimelineAnchorSelection,
        to preferencesStore: LifeBoardWorkspacePreferencesStore,
        calendar: Calendar = .current
    ) {
        selection.save(time: selectedDate, to: preferencesStore, calendar: calendar)
    }

    private static func selectedAccessibilityText(for selection: TimelineAnchorSelection) -> String {
        selection == .wake ? "selected start time" : "selected end time"
    }

    private static func selectableAccessibilityText(for selection: TimelineAnchorSelection) -> String {
        selection == .wake ? "start time option" : "end time option"
    }

    private static func formatted(_ date: Date, format: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

struct TimelineAnchorRitualLayoutMetrics: Equatable {
    enum ChipLayoutMode: Equatable {
        case fixed
        case scrolling
    }

    let sheetWidth: CGFloat
    let contentInset: CGFloat
    let contentWidth: CGFloat
    let selectorCardWidth: CGFloat
    let ctaWidth: CGFloat
    let selectorHorizontalPadding: CGFloat
    let selectorInnerWidth: CGFloat
    let chipSpacing: CGFloat
    let chipWidth: CGFloat
    let chipVisualHeight: CGFloat
    let chipRowWidth: CGFloat
    let chipLayoutMode: ChipLayoutMode
    let selectorCardHeight: CGFloat
    let ctaHeight: CGFloat
}

enum TimelineAnchorRitualLayoutPolicy {
    static let contentInset: CGFloat = 24
    static let selectorHorizontalPadding: CGFloat = 16
    static let chipSpacing: CGFloat = 12
    static let minimumFixedChipWidth: CGFloat = 56
    static let minimumScrollingChipWidth: CGFloat = 76
    static let maximumChipWidth: CGFloat = 78

    static func metrics(
        sheetWidth: CGFloat,
        isAccessibilitySize: Bool = false
    ) -> TimelineAnchorRitualLayoutMetrics {
        let boundedSheetWidth = max(0, sheetWidth)
        let contentWidth = max(0, boundedSheetWidth - contentInset * 2)
        let selectorInnerWidth = max(0, contentWidth - selectorHorizontalPadding * 2)
        let totalSpacing = chipSpacing * 4
        let proposedFixedChipWidth = max(0, (selectorInnerWidth - totalSpacing) / 5)
        let canUseFixedChips = proposedFixedChipWidth >= minimumFixedChipWidth && isAccessibilitySize == false
        let chipWidth = canUseFixedChips
            ? min(maximumChipWidth, proposedFixedChipWidth)
            : minimumScrollingChipWidth
        let chipRowWidth = chipWidth * 5 + totalSpacing

        return TimelineAnchorRitualLayoutMetrics(
            sheetWidth: boundedSheetWidth,
            contentInset: contentInset,
            contentWidth: contentWidth,
            selectorCardWidth: contentWidth,
            ctaWidth: contentWidth,
            selectorHorizontalPadding: selectorHorizontalPadding,
            selectorInnerWidth: selectorInnerWidth,
            chipSpacing: chipSpacing,
            chipWidth: chipWidth,
            chipVisualHeight: isAccessibilitySize ? 64 : 56,
            chipRowWidth: chipRowWidth,
            chipLayoutMode: canUseFixedChips ? .fixed : .scrolling,
            selectorCardHeight: isAccessibilitySize ? 198 : 164,
            ctaHeight: isAccessibilitySize ? 64 : 60
        )
    }
}
