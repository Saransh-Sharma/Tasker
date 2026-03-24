import Foundation

extension HomeChromeSnapshot {
    var homeHeaderDateText: String {
        switch activeScope {
        case .today:
            return selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .customDate(let date):
            return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .upcoming, .overdue, .done, .morning, .evening:
            return Date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
    }

    var homeHeaderSummaryText: String {
        let baseSummary: String
        switch activeScope {
        case .today:
            baseSummary = "Today"
        case .customDate:
            baseSummary = "Selected day"
        case .upcoming:
            baseSummary = "Upcoming"
        case .overdue:
            baseSummary = "Overdue"
        case .done:
            baseSummary = "Done"
        case .morning:
            baseSummary = "Morning"
        case .evening:
            baseSummary = "Evening"
        }

        let filterCount = homeActiveFilterCount
        guard filterCount > 0 else { return baseSummary }
        let filterLabel = filterCount == 1 ? "filter" : "filters"
        return "\(baseSummary) · \(filterCount) \(filterLabel)"
    }

    var shouldShowBackToToday: Bool {
        if case .today = activeScope {
            return false
        }
        return true
    }

    private var homeActiveFilterCount: Int {
        var count = 0
        if activeFilterState.selectedProjectIDs.isEmpty == false {
            count += 1
        }
        if let advancedFilter = activeFilterState.advancedFilter, advancedFilter.isEmpty == false {
            count += 1
        }
        if activeFilterState.showCompletedInline {
            count += 1
        }
        return count
    }
}
