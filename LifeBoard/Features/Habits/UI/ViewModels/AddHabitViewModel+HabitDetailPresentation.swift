import Foundation

extension HabitDetailViewModel {
    public var detailCalendarWeeks: [HabitDetailCalendarWeek] {
        calendarViewState.weeks.map { week in
            HabitDetailCalendarWeek(
                startDate: week.startDate,
                monthLabel: week.monthLabel,
                cells: week.cells.map(\.cell)
            )
        }
    }

    public var detailCalendarHelperText: String {
        calendarViewState.helperText
    }

    public var availableIconOptions: [HabitIconOption] {
        let cacheKey = IconSearchCacheKey(
            query: draft.iconSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            kind: draft.kind,
            lifeAreaID: draft.lifeAreaID
        )
        if let iconOptionsCache, iconOptionsCache.key == cacheKey {
            return iconOptionsCache.options
        }

        let preferredLifeAreaName = lifeAreas.first(where: { $0.id == draft.lifeAreaID })?.name
        let options = iconCatalog.search(
            query: draft.iconSearchQuery,
            habitKind: draft.kind,
            preferredLifeAreaName: preferredLifeAreaName
        )
        iconOptionsCache = (cacheKey, options)
        return options
    }

    public var selectedIconOption: HabitIconOption? {
        guard let selectedIconSymbolName = draft.selectedIconSymbolName else { return nil }
        return iconCatalog.all.first(where: { $0.symbolName == selectedIconSymbolName })
    }

    public var canSave: Bool {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && draft.lifeAreaID != nil
            && editorReminderWindowValidationError == nil
            && isSaving == false
    }
}
