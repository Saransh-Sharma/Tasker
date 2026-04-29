//
//  HomePage.swift
//  To Do ListUITests
//
//  Page Object for Home Screen
//

import XCTest

class HomePage {

    // MARK: - Properties

    private let app: XCUIApplication

    private func missingElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)["missing.\(identifier)"]
    }

    // MARK: - Elements

    var view: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.Home.view]
    }

    var foredropSurface: XCUIElement {
        let predicate = NSPredicate(
            format: "identifier == %@ OR identifier == %@ OR identifier == %@",
            AccessibilityIdentifiers.Home.foredropSurface,
            "home.foredropSurface",
            "homeForedropSurface"
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    var foredropCollapseHint: XCUIElement {
        let byIdentifier = app.buttons[AccessibilityIdentifiers.Home.foredropCollapseHint]
        if byIdentifier.exists {
            return byIdentifier
        }
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.foredropCollapseHint]
    }

    var timelineSurface: XCUIElement {
        let byIdentifier = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.timelineSurface]
        if byIdentifier.exists {
            return byIdentifier
        }
        return app.descendants(matching: .any)["home.timeline.surface"]
    }

    var addTaskButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.addTaskButton]
    }

    var bottomBar: XCUIElement {
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.bottomBar]
    }

    var chartsButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.bottomBarCharts]
    }

    var homeButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.bottomBarHome]
    }

    var settingsButton: XCUIElement {
        let byIdentifier = app.buttons[AccessibilityIdentifiers.Home.settingsButton]
        if byIdentifier.exists {
            return byIdentifier
        }

        let byAnyIdentifier = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.settingsButton]
        if byAnyIdentifier.exists {
            return byAnyIdentifier
        }

        return app.buttons.matching(
            NSPredicate(
                format: "label CONTAINS[c] 'Settings' OR label CONTAINS[c] 'gear' OR identifier CONTAINS[c] 'settings'"
            )
        ).firstMatch
    }

    var backToTodayButton: XCUIElement {
        let byButton = app.buttons[AccessibilityIdentifiers.Home.backToTodayButton]
        if byButton.exists {
            return byButton
        }

        let byAnyIdentifier = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.backToTodayButton]
        if byAnyIdentifier.exists {
            return byAnyIdentifier
        }

        return topChrome.buttons.matching(
            NSPredicate(
                format: "label CONTAINS[c] 'Back to Today' OR identifier == %@",
                AccessibilityIdentifiers.Home.backToTodayButton
            )
        ).firstMatch
    }

    var reflectionReadyButton: XCUIElement {
        let byButton = app.buttons[AccessibilityIdentifiers.Home.reflectionReadyButton]
        if byButton.exists {
            return byButton
        }

        let byAnyIdentifier = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.reflectionReadyButton]
        if byAnyIdentifier.exists {
            return byAnyIdentifier
        }

        return app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS[c] 'Reflect' OR identifier == %@",
                AccessibilityIdentifiers.Home.reflectionReadyButton
            )
        ).firstMatch
    }

    var topChrome: XCUIElement {
        let byOtherElement = app.otherElements["home.topChrome"]
        if byOtherElement.exists {
            return byOtherElement
        }

        return app.descendants(matching: .any)["home.topChrome"]
    }

    var topChromeXPProgress: XCUIElement {
        let byOtherElement = app.otherElements[AccessibilityIdentifiers.Home.topChromeXPProgress]
        if byOtherElement.exists {
            return byOtherElement
        }

        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.topChromeXPProgress]
    }

    var topChromeXPLabel: XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[c] 'XP'")
        let inChrome = topChrome.staticTexts.matching(predicate).firstMatch
        if inChrome.exists {
            return inChrome
        }

        return app.staticTexts.matching(predicate).firstMatch
    }

    var headerDateLabel: XCUIElement {
        let byText = app.staticTexts["home.topChrome.date"]
        if byText.exists {
            return byText
        }

        let byAnyIdentifier = app.descendants(matching: .any)["home.topChrome.date"]
        if byAnyIdentifier.exists {
            return byAnyIdentifier
        }

        let datePattern = NSPredicate(format: "label MATCHES %@", "^[A-Za-z]{3}, [A-Za-z]{3} [0-9]{1,2}$")
        let topChromeDate = topChrome.staticTexts.matching(datePattern).firstMatch
        if topChromeDate.exists {
            return topChromeDate
        }

        return app.descendants(matching: .any)["home.topChrome.date"]
    }

    var searchButton: XCUIElement {
        let legacyIdentifier = app.buttons[AccessibilityIdentifiers.Home.searchButton]
        if legacyIdentifier.exists {
            return legacyIdentifier
        }

        let bottomSearchByLabel = bottomBar.buttons.matching(
            NSPredicate(
                format: "label == 'Search' OR identifier == %@",
                AccessibilityIdentifiers.Home.searchButton
            )
        ).firstMatch
        if bottomSearchByLabel.exists {
            return bottomSearchByLabel
        }

        return app.buttons.matching(
            NSPredicate(
                format: "identifier == %@ OR (label CONTAINS[c] 'Search' AND identifier != %@)",
                AccessibilityIdentifiers.Home.searchButton,
                AccessibilityIdentifiers.Home.topNavSearchButton
            )
        ).firstMatch
    }

    var topNavSearchButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.topNavSearchButton]
    }

    var searchView: XCUIElement {
        app.otherElements[AccessibilityIdentifiers.Search.view]
    }

    var searchChromeContainer: XCUIElement {
        app.otherElements[AccessibilityIdentifiers.Search.chromeContainer]
    }

    var searchContentContainer: XCUIElement {
        let identified = app.scrollViews[AccessibilityIdentifiers.Search.contentContainer]
        if identified.exists {
            return identified
        }
        return app.otherElements[AccessibilityIdentifiers.Search.contentContainer]
    }

    var searchField: XCUIElement {
        let searchFieldByIdentifier = app.searchFields[AccessibilityIdentifiers.Search.searchField]
        if searchFieldByIdentifier.exists {
            return searchFieldByIdentifier
        }

        let textFieldByIdentifier = app.textFields[AccessibilityIdentifiers.Search.searchField]
        if textFieldByIdentifier.exists {
            return textFieldByIdentifier
        }

        return app.textFields.matching(
            NSPredicate(
                format: "identifier == %@ OR placeholderValue CONTAINS[c] 'Search tasks'",
                AccessibilityIdentifiers.Search.searchField
            )
        ).firstMatch
    }

    var searchResultsList: XCUIElement {
        let identified = app.scrollViews[AccessibilityIdentifiers.Search.resultsList]
        if identified.exists {
            return identified
        }
        return app.otherElements[AccessibilityIdentifiers.Search.resultsList]
    }

    var searchBackChip: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Search.backChip]
    }

    var statusBar: XCUIElement {
        app.statusBars.firstMatch
    }

    var searchStatusAllChip: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Search.statusAll]
    }

    var searchStatusTodayChip: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Search.statusToday]
    }

    var searchPriorityP2Chip: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Search.priorityP2]
    }

    var topNavContainer: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.Home.topNavContainer]
    }

    var topNavActionRow: XCUIElement {
        app.otherElements[AccessibilityIdentifiers.Home.topNavActionRow]
    }

    var chatButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.chatButton]
    }

    var inboxButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.inboxButton]
    }

    var projectFilterButton: XCUIElement {
        let quickMenu = app.buttons[AccessibilityIdentifiers.Home.quickFilterMenuButton]
        if quickMenu.exists {
            return quickMenu
        }

        let quickMenuAny = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.quickFilterMenuButton]
        if quickMenuAny.exists {
            return quickMenuAny
        }

        let legacyProjectFilter = app.buttons["home.projectFilterButton"]
        if legacyProjectFilter.exists {
            return legacyProjectFilter
        }

        let legacyProjectFilterAny = app.descendants(matching: .any)["home.projectFilterButton"]
        if legacyProjectFilterAny.exists {
            return legacyProjectFilterAny
        }

        let navMenuButton = app.buttons["home.focus.menu.button.nav"]
        if navMenuButton.exists {
            return navMenuButton
        }

        let navMenuAny = app.descendants(matching: .any)["home.focus.menu.button.nav"]
        if navMenuAny.exists {
            return navMenuAny
        }

        let filterButton = app.buttons["home.focus.filterButton.nav"]
        if filterButton.exists {
            return filterButton
        }

        let filterButtonAny = app.descendants(matching: .any)["home.focus.filterButton.nav"]
        if filterButtonAny.exists {
            return filterButtonAny
        }

        let currentViewMenu = topChrome.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH[c] 'Current view,'")
        ).firstMatch
        if currentViewMenu.exists {
            return currentViewMenu
        }

        return topChrome.buttons.matching(
            NSPredicate(format: "label BEGINSWITH[c] 'Current view,'")
        ).firstMatch
    }

    var quickFilterMenuContainer: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.Home.quickFilterMenuContainer]
    }

    var quickFilterAdvancedButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.quickFilterMenuAdvancedButton]
    }

    var primaryWidgetRail: XCUIElement {
        let rail = app.otherElements[AccessibilityIdentifiers.Home.primaryWidgetRail]
        if rail.exists {
            return rail
        }
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.primaryWidgetRail]
    }

    var primaryWidgetIndicator: XCUIElement {
        let indicator = app.otherElements[AccessibilityIdentifiers.Home.primaryWidgetIndicator]
        if indicator.exists {
            return indicator
        }
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.primaryWidgetIndicator]
    }

    var primaryWidgetPageFocusNow: XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.Home.primaryWidgetPageFocusNow]
    }

    var primaryWidgetPageWeeklyOperating: XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.Home.primaryWidgetPageWeeklyOperating]
    }

    var primaryWidgetIndicatorFocusNow: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.primaryWidgetIndicatorFocusNow]
    }

    var primaryWidgetIndicatorWeeklyOperating: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.primaryWidgetIndicatorWeeklyOperating]
    }

    var weeklySummaryCard: XCUIElement {
        let card = app.otherElements.matching(
            NSPredicate(format: "identifier == %@", AccessibilityIdentifiers.Home.weeklySummaryCard)
        ).firstMatch
        if card.exists {
            return card
        }
        return app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", AccessibilityIdentifiers.Home.weeklySummaryCard)
        ).firstMatch
    }

    var dailyReflectionEntryCompact: XCUIElement {
        let card = app.otherElements.matching(
            NSPredicate(format: "identifier == %@", AccessibilityIdentifiers.Home.dailyReflectionEntryCompact)
        ).firstMatch
        if card.exists {
            return card
        }
        return app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", AccessibilityIdentifiers.Home.dailyReflectionEntryCompact)
        ).firstMatch
    }

    var calendarCard: XCUIElement {
        let card = app.otherElements.matching(
            NSPredicate(format: "identifier == %@", AccessibilityIdentifiers.Home.calendarCard)
        ).firstMatch
        if card.exists {
            return card
        }
        return app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", AccessibilityIdentifiers.Home.calendarCard)
        ).firstMatch
    }

    var passiveTrackingRail: XCUIElement {
        let rail = app.otherElements.matching(
            NSPredicate(format: "identifier == %@", AccessibilityIdentifiers.Home.passiveTrackingRail)
        ).firstMatch
        if rail.exists {
            return rail
        }
        return app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", AccessibilityIdentifiers.Home.passiveTrackingRail)
        ).firstMatch
    }

    var focusStrip: XCUIElement {
        let predicate = NSPredicate(
            format: "identifier == %@ OR identifier == %@ OR identifier == %@",
            AccessibilityIdentifiers.Home.focusStrip,
            "home.focusZone",
            AccessibilityIdentifiers.Home.focusDropZone
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    var focusDropZone: XCUIElement {
        let predicate = NSPredicate(
            format: "identifier == %@ OR identifier == %@ OR identifier == %@",
            AccessibilityIdentifiers.Home.focusDropZone,
            "home.focusZone",
            AccessibilityIdentifiers.Home.focusStrip
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    var focusTitleTap: XCUIElement {
        let byButton = app.buttons[AccessibilityIdentifiers.Home.focusTitleTap]
        if byButton.exists {
            return byButton
        }
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.focusTitleTap]
    }

    var focusShuffleButton: XCUIElement {
        app.buttons["home.focus.shuffle"]
    }

    var focusDetailShuffleButton: XCUIElement {
        app.buttons["home.focus.detail.shuffle"]
    }

    func swipePrimaryWidgetRailLeft() {
        primaryWidgetRail.swipeLeft()
    }

    func swipePrimaryWidgetRailRight() {
        primaryWidgetRail.swipeRight()
    }

    var rescueSection: XCUIElement {
        let identifiedSections = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", AccessibilityIdentifiers.Home.rescueSection)
        )
        for index in 0..<identifiedSections.count {
            let candidate = identifiedSections.element(boundBy: index)
            guard candidate.exists else { continue }

            let actionButtons = candidate.descendants(matching: .button).matching(
                NSPredicate(format: "label CONTAINS[c] 'Start' OR label CONTAINS[c] 'Expand' OR label CONTAINS[c] 'Collapse'")
            )
            if actionButtons.count > 0 {
                return candidate
            }

            let headerText = candidate.descendants(matching: .staticText).matching(
                NSPredicate(format: "label == 'Rescue'")
            )
            if headerText.count > 0 {
                return candidate
            }
        }

        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueSection]
    }

    var rescueHeader: XCUIElement {
        let byAny = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueHeader]
        if byAny.exists {
            return byAny
        }

        let exactLabel = app.staticTexts["Rescue"]
        if exactLabel.exists {
            return exactLabel
        }

        let fallback = app.descendants(matching: .staticText).matching(
            NSPredicate(
                format: "identifier == %@ AND label CONTAINS[c] 'Rescue' AND NOT label MATCHES '^[0-9]+$' AND NOT label BEGINSWITH 'Task:'",
                AccessibilityIdentifiers.Home.rescueSection
            )
        ).firstMatch
        if fallback.exists {
            return fallback
        }
        return missingElement(AccessibilityIdentifiers.Home.rescueHeader)
    }

    var rescueOpenButton: XCUIElement {
        let byButton = app.buttons[AccessibilityIdentifiers.Home.rescueOpen]
        if byButton.exists {
            return byButton
        }

        let fallback = rescueSection.buttons.matching(
            NSPredicate(format: "identifier == %@ OR label == 'Rescue'", AccessibilityIdentifiers.Home.rescueOpen)
        ).firstMatch
        if fallback.exists {
            return fallback
        }

        return missingElement(AccessibilityIdentifiers.Home.rescueOpen)
    }

    var rescueStartButton: XCUIElement {
        let byButton = app.buttons[AccessibilityIdentifiers.Home.rescueStart]
        if byButton.exists {
            return byButton
        }

        let fallback = app.buttons.matching(
            NSPredicate(
                format: "(identifier == %@ OR identifier == %@) AND label CONTAINS[c] 'Start'",
                AccessibilityIdentifiers.Home.rescueStart,
                AccessibilityIdentifiers.Home.rescueSection
            )
        ).firstMatch
        if fallback.exists {
            return fallback
        }

        return missingElement(AccessibilityIdentifiers.Home.rescueStart)
    }

    var quietTrackingSummary: XCUIElement {
        let button = app.buttons[AccessibilityIdentifiers.Home.quietTrackingSummary]
        if button.exists {
            return button
        }
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.quietTrackingSummary]
    }

    var habitsSection: XCUIElement {
        let section = app.otherElements.matching(
            NSPredicate(format: "identifier == %@", AccessibilityIdentifiers.Home.habitsSection)
        ).firstMatch
        if section.exists {
            return section
        }
        return app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", AccessibilityIdentifiers.Home.habitsSection)
        ).firstMatch
    }

    var habitsRecoverySection: XCUIElement {
        let section = app.otherElements.matching(
            NSPredicate(format: "identifier == %@", AccessibilityIdentifiers.Home.habitsRecoverySection)
        ).firstMatch
        if section.exists {
            return section
        }
        return app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", AccessibilityIdentifiers.Home.habitsRecoverySection)
        ).firstMatch
    }

    var habitsSectionAction: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.habitsSectionAction]
    }

    var quietTrackingSheet: XCUIElement {
        let otherElement = app.otherElements[AccessibilityIdentifiers.Home.quietTrackingSheet]
        if otherElement.exists {
            return otherElement
        }
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.quietTrackingSheet]
    }

    var quietTrackingSheetScroll: XCUIElement {
        let scrollView = app.scrollViews[AccessibilityIdentifiers.Home.quietTrackingSheetScroll]
        if scrollView.exists {
            return scrollView
        }
        return app.otherElements[AccessibilityIdentifiers.Home.quietTrackingSheetScroll]
    }

    var quietTrackingSheetSaveButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.quietTrackingSheetSave]
    }

    var quietTrackingSheetOutcomeLapseButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.quietTrackingSheetOutcomeLapse]
    }

    var quietTrackingSheetOutcomeProgressButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.quietTrackingSheetOutcomeProgress]
    }

    var quietTrackingSheetTodayButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.quietTrackingSheetDateToday]
    }

    var quietTrackingSheetYesterdayButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.quietTrackingSheetDateYesterday]
    }

    var rescueExpandButton: XCUIElement {
        let byButton = app.buttons[AccessibilityIdentifiers.Home.rescueExpand]
        if byButton.exists {
            return byButton
        }

        let fallback = app.buttons.matching(
            NSPredicate(
                format: "(identifier == %@ OR identifier == %@) AND (label CONTAINS[c] 'Expand' OR label CONTAINS[c] 'Collapse')",
                AccessibilityIdentifiers.Home.rescueExpand,
                AccessibilityIdentifiers.Home.rescueSection
            )
        ).firstMatch
        if fallback.exists {
            return fallback
        }

        return missingElement(AccessibilityIdentifiers.Home.rescueExpand)
    }

    var rescueSheet: XCUIElement {
        let byOther = app.otherElements[AccessibilityIdentifiers.Home.rescueSheet]
        if byOther.exists {
            return byOther
        }

        let fallback = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ OR label CONTAINS[c] 'Rescue'", AccessibilityIdentifiers.Home.rescueSheet)
        ).firstMatch
        if fallback.exists {
            return fallback
        }

        return missingElement(AccessibilityIdentifiers.Home.rescueSheet)
    }

    var listDropZone: XCUIElement {
        let predicate = NSPredicate(
            format: "identifier == %@ OR identifier == %@",
            AccessibilityIdentifiers.Home.listDropZone,
            AccessibilityIdentifiers.Home.taskListScrollView
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    var morningTasksList: XCUIElement {
        return app.tables[AccessibilityIdentifiers.Home.morningTasksList]
    }

    var eveningTasksList: XCUIElement {
        return app.tables[AccessibilityIdentifiers.Home.eveningTasksList]
    }

    var dailyScoreLabel: XCUIElement {
        return app.staticTexts[AccessibilityIdentifiers.Home.dailyScoreLabel]
    }

    var streakLabel: XCUIElement {
        return app.staticTexts[AccessibilityIdentifiers.Home.streakLabel]
    }

    var completionRateLabel: XCUIElement {
        return app.staticTexts[AccessibilityIdentifiers.Home.completionRateLabel]
    }

    var chartView: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.Home.chartView]
    }

    var radarChartView: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.Home.radarChartView]
    }

    var weeklyCalendar: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.Home.weeklyCalendar]
    }

    var navXpPieChart: XCUIElement {
        let byIdentifier = app.otherElements[AccessibilityIdentifiers.Home.navXpPieChart]
        if byIdentifier.exists {
            return byIdentifier
        }

        let predicate = NSPredicate(
            format: "identifier == %@ OR identifier == %@",
            AccessibilityIdentifiers.Home.navXpPieChart,
            "home.navXpPieChart.button"
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    var navXpPieChartButton: XCUIElement {
        let byButtonQuery = app.buttons["home.navXpPieChart.button"]
        if byButtonQuery.exists {
            return byButtonQuery
        }
        let byOtherElementsQuery = app.otherElements["home.navXpPieChart.button"]
        if byOtherElementsQuery.exists {
            return byOtherElementsQuery
        }
        return app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", "home.navXpPieChart.button")
        ).firstMatch
    }

    var taskListScrollView: XCUIElement {
        let identifiedScrollView = app.scrollViews[AccessibilityIdentifiers.Home.taskListScrollView]
        if identifiedScrollView.exists {
            return identifiedScrollView
        }

        let fallbackOtherElement = app.otherElements[AccessibilityIdentifiers.Home.taskListScrollView]
        if fallbackOtherElement.exists {
            return fallbackOtherElement
        }

        let firstScrollView = app.scrollViews.firstMatch
        if firstScrollView.exists {
            return firstScrollView
        }

        return app.tables.firstMatch
    }

    var insightsContainer: XCUIElement {
        app.otherElements[AccessibilityIdentifiers.Home.insightsContainer]
    }

    var insightsTodayTab: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.insightsTabToday]
    }

    var insightsWeekTab: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.insightsTabWeek]
    }

    var insightsSystemsTab: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.insightsTabSystems]
    }

    var insightsScrollView: XCUIElement {
        let identified = app.scrollViews[AccessibilityIdentifiers.Home.insightsScroll]
        if identified.exists {
            return identified
        }
        return app.scrollViews.firstMatch
    }

    // MARK: - Initialization

    init(app: XCUIApplication) {
        self.app = app
    }

    private var taskRowQuery: XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskRow.'")
        )
    }

    private func tapElement(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func firstHittableElement(in query: XCUIElementQuery) -> XCUIElement? {
        for index in 0..<query.count {
            let candidate = query.element(boundBy: index)
            if candidate.exists && candidate.isHittable {
                return candidate
            }
        }
        return nil
    }

    private func rowMatchesTitle(_ row: XCUIElement, title: String) -> Bool {
        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard normalizedTitle.isEmpty == false else {
            return false
        }

        if row.label.lowercased().contains(normalizedTitle) {
            return true
        }

        // When accessibility grouping changes, debugDescription still includes
        // descendant text and remains stable enough for UI test matching.
        return row.debugDescription.lowercased().contains(normalizedTitle)
    }

    // MARK: - Actions

    /// Tap the add task button to open task creation screen
    @discardableResult
    func tapAddTask() -> AddTaskPage {
        let addTaskPage = AddTaskPage(app: app)
        for _ in 0..<3 {
            let byButtonID = app.buttons[AccessibilityIdentifiers.Home.addTaskButton]
            if byButtonID.waitForExistence(timeout: 1) {
                if byButtonID.isHittable {
                    byButtonID.tap()
                } else {
                    byButtonID.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                if addTaskPage.verifyIsDisplayed(timeout: 2) {
                    return addTaskPage
                }
            }

            let byAnyID = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.addTaskButton]
            if byAnyID.waitForExistence(timeout: 1) {
                byAnyID.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                if addTaskPage.verifyIsDisplayed(timeout: 2) {
                    return addTaskPage
                }
            }

            let addTaskByLabel = app.buttons["Add Task"]
            if addTaskByLabel.exists {
                addTaskByLabel.tap()
                if addTaskPage.verifyIsDisplayed(timeout: 2) {
                    return addTaskPage
                }
            }

            // Avoid tapping an ambiguous "home.bottomBar" query because multiple
            // bottom-bar buttons can share that identifier in UI test snapshots.
            // The explicit Add Task button paths above are the only safe fallbacks.
        }

        XCTFail("Add Task button should exist before tapping")
        return addTaskPage
    }

    /// Tap settings button to open settings
    @discardableResult
    func tapSettings() -> SettingsPage {
        let settingsPage = SettingsPage(app: app)
        let candidates: [XCUIElement] = [
            app.buttons[AccessibilityIdentifiers.Home.settingsButton],
            app.descendants(matching: .any)[AccessibilityIdentifiers.Home.settingsButton],
            app.buttons.matching(
                NSPredicate(
                    format: "label CONTAINS[c] 'Settings' OR label CONTAINS[c] 'gear' OR identifier CONTAINS[c] 'settings'"
                )
            ).firstMatch
        ]

        for candidate in candidates {
            guard candidate.waitForExistence(timeout: 2) else { continue }
            if candidate.isHittable {
                candidate.tap()
            } else {
                candidate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }

            if settingsPage.verifyIsDisplayed(timeout: 2) {
                return settingsPage
            }
        }

        XCTFail("Failed to tap \(AccessibilityIdentifiers.Home.settingsButton)")
        return settingsPage
    }

    /// Tap search button
    func tapSearch() {
        let button = searchButton
        XCTAssertTrue(button.waitForExistence(timeout: 3), "Search button should exist before tapping")
        tapElement(button)
    }

    /// Tap charts button
    func tapCharts() {
        chartsButton.tap()
    }

    /// Tap home button
    func tapHome() {
        homeButton.tap()
    }

    func tapSearchBackChip() {
        searchBackChip.tap()
    }

    @discardableResult
    func waitForSearchFaceOpen(timeout: TimeInterval = 3) -> Bool {
        guard waitForForedropState("fullReveal", timeout: timeout) else { return false }
        return searchView.waitForExistence(timeout: timeout)
    }

    func topSafeAreaBoundary() -> CGFloat {
        let statusBarElement = statusBar
        if statusBarElement.exists, statusBarElement.frame.height > 0 {
            return statusBarElement.frame.maxY
        }
        return app.windows.element(boundBy: 0).frame.minY + 20
    }

    func typeSearchQuery(_ query: String) {
        let field = searchField
        XCTAssertTrue(field.waitForExistence(timeout: 3), "Search field should exist before typing")
        field.tap()

        let currentValue = (field.value as? String) ?? ""
        if !currentValue.isEmpty, currentValue != "Search tasks..." {
            let deleteText = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            field.typeText(deleteText)
        }

        if !query.isEmpty {
            field.typeText(query)
        }
    }

    /// Tap chat button
    func tapChat() {
        chatButton.tap()
    }

    /// Tap inbox button
    func tapInbox() {
        inboxButton.tap()
    }

    /// Tap floating nav XP pie chart.
    func tapNavXpPieChart() {
        let chartButton = navXpPieChartButton
        if chartButton.waitForExistence(timeout: 3) {
            chartButton.tap()
            return
        }

        let chart = navXpPieChart
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "Navigation XP pie chart should exist before tapping")
        chart.tap()
    }

    func isToolSelected(_ element: XCUIElement) -> Bool {
        let rawValue = element.value as? String
        return rawValue == "selected"
    }

    @discardableResult
    func waitForToolSelection(_ element: XCUIElement, timeout: TimeInterval = 2) -> Bool {
        let predicate = NSPredicate(format: "value == %@", "selected")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Tap project filter button
    func tapProjectFilter() {
        projectFilterButton.tap()
    }

    /// Navigate home screen to a specific date using the date picker
    func navigateToDate(_ date: Date) {
        // Find the home date picker element
        let datePicker = app.otherElements[AccessibilityIdentifiers.Home.datePicker]

        if datePicker.waitForExistence(timeout: 2) {
            // FSCalendar in week mode - use coordinate-based tapping
            let calendar = Calendar.current
            let dayOfWeek = calendar.component(.weekday, from: date) // 1=Sunday, 7=Saturday

            let calendarFrame = datePicker.frame
            let dayWidth = calendarFrame.width / 7.0

            // Calculate X position: center of the day's column
            let xOffset = (CGFloat(dayOfWeek) - 0.5) * dayWidth

            // Calculate Y position: tap in the date number area
            let yOffset = calendarFrame.height * 0.6

            // Tap the date
            let tapCoordinate = datePicker.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: xOffset, dy: yOffset))
            tapCoordinate.tap()

            // Wait for view to update
            Thread.sleep(forTimeInterval: 0.5)

            print("📅 Navigated home view to: \(date)")
        } else {
            print("⚠️ Warning: Home date picker not found - navigation skipped")
        }
    }

    /// Get task cell at index
    func taskCell(at index: Int) -> XCUIElement {
        let taskRow = taskRowQuery.element(boundBy: index)
        if taskRow.exists {
            return taskRow
        }

        return app.tables.cells.element(boundBy: index)
    }

    /// Get task checkbox at index
    func taskCheckbox(at index: Int) -> XCUIElement {
        let identifier = AccessibilityIdentifiers.Home.taskCheckbox(index: index)
        let legacyCheckbox = app.buttons[identifier]
        if legacyCheckbox.exists {
            return legacyCheckbox
        }

        let row = taskCell(at: index)
        let rowCheckbox = row.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskCheckbox.'")
        ).firstMatch
        if rowCheckbox.exists {
            return rowCheckbox
        }

        return app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskCheckbox.'")
        ).element(boundBy: index)
    }

    /// Get SwiftUI task row by title using stable row accessibility identifiers.
    func taskRow(containingTitle title: String) -> XCUIElement {
        let rowsContainingTitle = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskRow.'")
        ).containing(.staticText, identifier: title)
        if let hittableRow = firstHittableElement(in: rowsContainingTitle) {
            return hittableRow
        }

        let rowContainingTitle = rowsContainingTitle.firstMatch
        if rowContainingTitle.exists {
            return rowContainingTitle
        }

        let genericContainingRows = app.otherElements.containing(.staticText, identifier: title)
        if let hittableGenericRow = firstHittableElement(in: genericContainingRows) {
            return hittableGenericRow
        }

        let genericContainingRow = genericContainingRows.firstMatch
        if genericContainingRow.exists {
            return genericContainingRow
        }

        let rowsByLabel = taskRowQuery.matching(
            NSPredicate(format: "label CONTAINS[c] %@", title)
        )
        if let hittableRowByLabel = firstHittableElement(in: rowsByLabel) {
            return hittableRowByLabel
        }

        let rowByLabel = rowsByLabel.firstMatch
        if rowByLabel.exists {
            return rowByLabel
        }

        let rows = taskRowQuery
        for index in 0..<rows.count {
            let row = rows.element(boundBy: index)
            if rowMatchesTitle(row, title: title) {
                return row
            }
        }

        let fallbackByLabel = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskRow.' AND label CONTAINS[c] %@", title)
        ).firstMatch
        if fallbackByLabel.exists {
            return fallbackByLabel
        }

        return missingElement("home.taskRow.\(title)")
    }

    func focusTaskCard(containingTitle title: String) -> XCUIElement {
        let explicitButton = focusStrip.buttons[title]
        if explicitButton.exists {
            return explicitButton
        }

        let explicitRows = focusStrip.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.focus.task.'")
        ).containing(.staticText, identifier: title)
        if let hittableExplicitRow = firstHittableElement(in: explicitRows) {
            return hittableExplicitRow
        }

        let rowsContainingTitle = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.focus.task.'")
        ).containing(.staticText, identifier: title)
        if let hittableRow = firstHittableElement(in: rowsContainingTitle) {
            return hittableRow
        }

        let labeledCompactRows = focusStrip.otherElements.matching(
            NSPredicate(format: "identifier == 'home.focusZone.taskList' AND label CONTAINS[c] %@", title)
        )
        if let hittableCompactRow = firstHittableElement(in: labeledCompactRows) {
            return hittableCompactRow
        }

        let firstMatch = rowsContainingTitle.firstMatch
        if firstMatch.exists {
            return firstMatch
        }

        let rowByLabel = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH 'home.focus.task.' AND label CONTAINS[c] %@",
                title
            )
        ).firstMatch
        if rowByLabel.exists {
            return rowByLabel
        }

        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.focus.task.'")
        )
        for index in 0..<rows.count {
            let row = rows.element(boundBy: index)
            if rowMatchesTitle(row, title: title) {
                return row
            }
        }

        let compactRowFallback = labeledCompactRows.firstMatch
        if compactRowFallback.exists {
            return compactRowFallback
        }

        return missingElement("home.focus.task.\(title)")
    }

    func focusTaskCard(taskID: UUID) -> XCUIElement {
        app.descendants(matching: .any)["home.focus.task.\(taskID.uuidString)"]
    }

    func passiveTrackingCard(id: String) -> XCUIElement {
        let identifier = AccessibilityIdentifiers.Home.passiveTrackingCard(id)
        let button = app.buttons[identifier]
        if button.exists {
            return button
        }
        return app.descendants(matching: .any)[identifier]
    }

    func focusPinButton(taskID: UUID) -> XCUIElement {
        app.buttons["home.focus.pin.\(taskID.uuidString)"]
    }

    func focusPinButton(containingTitle title: String) -> XCUIElement {
        let card = focusTaskCard(containingTitle: title)
        let pinButton = card.descendants(matching: .button).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.focus.pin.'")
        ).firstMatch
        if pinButton.exists {
            return pinButton
        }

        let buttons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home.focus.pin.'"))
        for index in 0..<buttons.count {
            let candidate = buttons.element(boundBy: index)
            if candidate.exists && card.exists && candidate.frame.intersects(card.frame) {
                return candidate
            }
        }

        return missingElement("home.focus.pin.\(title)")
    }

    func rescueRow(containingTitle title: String) -> XCUIElement {
        let rowsContainingTitle = rescueSection.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskRow.'")
        ).containing(.staticText, identifier: title)
        if let hittableRow = firstHittableElement(in: rowsContainingTitle) {
            return hittableRow
        }

        let firstMatch = rowsContainingTitle.firstMatch
        if firstMatch.exists {
            return firstMatch
        }

        let rowByLabel = rescueSection.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskRow.' AND label CONTAINS[c] %@", title)
        ).firstMatch
        if rowByLabel.exists {
            return rowByLabel
        }

        let visibleText = rescueSection.staticTexts[title]
        if visibleText.exists {
            return visibleText
        }

        return missingElement("home.rescue.row.\(title)")
    }

    func tapRescueExpand() {
        tapElement(rescueExpandButton)
    }

    func tapRescueOpen() {
        tapElement(rescueOpenButton)
    }

    func tapStartRescue() {
        tapElement(rescueStartButton)
    }

    @discardableResult
    func dragTaskToFocus(title: String, duration: TimeInterval = 0.8) -> Bool {
        let row = taskRow(containingTitle: title)
        guard row.waitForExistence(timeout: 4), focusDropZone.waitForExistence(timeout: 4) else {
            return false
        }
        row.press(forDuration: duration, thenDragTo: focusDropZone)
        return true
    }

    @discardableResult
    func dragFocusTaskToList(title: String, duration: TimeInterval = 0.8) -> Bool {
        let card = focusTaskCard(containingTitle: title)
        guard card.waitForExistence(timeout: 4), listDropZone.waitForExistence(timeout: 4) else {
            return false
        }
        card.press(forDuration: duration, thenDragTo: listDropZone)
        return true
    }

    /// Get SwiftUI task checkbox by title using stable checkbox accessibility identifiers.
    func taskCheckbox(containingTitle title: String) -> XCUIElement {
        let row = taskRow(containingTitle: title)
        if row.exists, row.identifier.hasPrefix("home.taskRow.") {
            let taskID = String(row.identifier.dropFirst("home.taskRow.".count))
            let rowScopedCheckboxIdentifier = "home.taskCheckbox.\(taskID)"

            let rowScopedMatches = row.buttons.matching(
                NSPredicate(format: "identifier == %@", rowScopedCheckboxIdentifier)
            )
            if let hittableRowScopedCheckbox = firstHittableElement(in: rowScopedMatches) {
                return hittableRowScopedCheckbox
            }

            let rowScopedCheckbox = rowScopedMatches.firstMatch
            if rowScopedCheckbox.exists {
                return rowScopedCheckbox
            }

            let directMatches = app.buttons.matching(
                NSPredicate(format: "identifier == %@", rowScopedCheckboxIdentifier)
            )
            if let hittableDirectCheckbox = firstHittableElement(in: directMatches) {
                return hittableDirectCheckbox
            }

            let directCheckbox = directMatches.firstMatch
            if directCheckbox.exists {
                return directCheckbox
            }
        }

        let checkboxesByLabel = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskCheckbox.' AND label CONTAINS[c] %@", title)
        )
        if let hittableCheckboxByLabel = firstHittableElement(in: checkboxesByLabel) {
            return hittableCheckboxByLabel
        }

        let checkboxByLabel = checkboxesByLabel.firstMatch
        if checkboxByLabel.exists {
            return checkboxByLabel
        }
        let checkboxPredicate = NSPredicate(format: "identifier BEGINSWITH 'home.taskCheckbox.'")
        let checkboxesInRow = row.buttons.matching(checkboxPredicate)
        if let hittableCheckboxInRow = firstHittableElement(in: checkboxesInRow) {
            return hittableCheckboxInRow
        }

        let checkboxInRow = checkboxesInRow.firstMatch
        if checkboxInRow.exists {
            return checkboxInRow
        }

        let rows = taskRowQuery
        for index in 0..<rows.count {
            let candidateRow = rows.element(boundBy: index)
            guard rowMatchesTitle(candidateRow, title: title) else { continue }
            let candidateCheckbox = candidateRow.buttons.matching(checkboxPredicate).firstMatch
            if candidateCheckbox.exists {
                return candidateCheckbox
            }
        }

        return app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskCheckbox.'")
        ).firstMatch
    }

    /// Read row state accessibility value ("open" / "done") for a task title.
    func taskRowStateValue(containingTitle title: String) -> String? {
        taskRow(containingTitle: title).value as? String
    }

    /// Wait for a task row state value ("open" / "done") for a given title.
    func waitForTaskRowState(_ expectedState: String, title: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { _, _ in
            guard let value = self.taskRowStateValue(containingTitle: title) else {
                return false
            }
            return value.caseInsensitiveCompare(expectedState) == .orderedSame
        }

        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Complete task at index by tapping checkbox
    func completeTask(at index: Int) {
        let checkbox = taskCheckbox(at: index)
        if checkbox.exists {
            tapElement(checkbox)
            return
        }

        // Last-resort fallback for runtimes where checkbox IDs are not projected.
        if !checkbox.exists {
            let cell = taskCell(at: index)
            let fallbackCheckbox = cell.buttons.matching(
                NSPredicate(format: "identifier CONTAINS[c] 'checkbox' OR label CONTAINS[c] 'complete'")
            ).firstMatch
            if fallbackCheckbox.exists {
                tapElement(fallbackCheckbox)
                return
            }
        }
    }

    /// Complete task by title by tapping checkbox inside the matching row.
    func completeTask(containingTitle title: String) {
        let checkbox = taskCheckbox(containingTitle: title)
        if checkbox.waitForExistence(timeout: 2) {
            tapElement(checkbox)
            return
        }

        let titleElement = app.staticTexts.matching(
            NSPredicate(format: "label == %@", title)
        ).firstMatch
        if titleElement.waitForExistence(timeout: 1.5) {
            let titleFrame = titleElement.frame
            let targetX = max(8, titleFrame.minX - 30)
            let targetY = titleFrame.midY
            app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: targetX, dy: targetY))
                .tap()
            return
        }

        let row = taskRow(containingTitle: title)
        let fallbackCheckbox = row.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH 'home.taskCheckbox.' OR label CONTAINS[c] 'complete' OR label CONTAINS[c] %@",
                title
            )
        ).firstMatch
        if fallbackCheckbox.exists {
            tapElement(fallbackCheckbox)
            return
        }

        if row.exists {
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)).tap()
        }
    }

    /// Uncomplete task at index
    func uncompleteTask(at index: Int) {
        completeTask(at: index) // Same action - toggle
    }

    /// Uncomplete task by title.
    func uncompleteTask(containingTitle title: String) {
        completeTask(containingTitle: title) // Same action - toggle
    }

    /// Tap task cell to open detail view
    func tapTask(at index: Int) {
        let row = taskCell(at: index)
        if row.exists {
            tapElement(row)
            return
        }

        let visibleTaskTitles = app.staticTexts.matching(
            NSPredicate(format: "label.length > 0 AND identifier == ''")
        )
        let fallbackTitle = visibleTaskTitles.element(boundBy: index)
        if fallbackTitle.exists {
            tapElement(fallbackTitle)
        }
    }

    /// Tap task row by title to open detail view.
    func tapTask(containingTitle title: String) {
        let row = taskRow(containingTitle: title)
        if row.waitForExistence(timeout: 3) {
            tapElement(row)
            return
        }

        let titleElement = app.staticTexts.matching(
            NSPredicate(format: "label == %@", title)
        ).firstMatch
        if titleElement.waitForExistence(timeout: 2) {
            tapElement(titleElement)
        }
    }

    /// Swipe to delete task at index
    func deleteTask(at index: Int) {
        let cell = taskCell(at: index)
        cell.swipeLeft()

        // Tap delete button
        let deleteButton = cell.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()
        }
    }

    // MARK: - Verifications

    /// Verify home screen is displayed
    @discardableResult
    func verifyIsDisplayed(timeout: TimeInterval = 5) -> Bool {
        // Check for navigation bar or tab bar
        let navBar = app.navigationBars.firstMatch
        let tabBar = app.tabBars.firstMatch

        return navBar.waitForExistence(timeout: timeout) || tabBar.waitForExistence(timeout: timeout)
    }

    @discardableResult
    func verifyBottomBarExists(timeout: TimeInterval = 5) -> Bool {
        if bottomBar.waitForExistence(timeout: timeout) {
            return true
        }
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.bottomBar]
            .waitForExistence(timeout: timeout)
    }

    @discardableResult
    func waitForBottomBarState(_ expectedState: String, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expectedState)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: bottomBar)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    @discardableResult
    func waitForForedropState(_ expectedState: String, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expectedState)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: foredropSurface)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Verify task exists with title
    func verifyTaskExists(withTitle title: String) -> Bool {
        let taskText = app.staticTexts[title]
        if taskText.exists {
            return true
        }
        return taskRow(containingTitle: title).exists
    }

    /// Verify task does not exist
    func verifyTaskDoesNotExist(withTitle title: String) -> Bool {
        let taskText = app.staticTexts[title]
        return !taskText.exists && !taskRow(containingTitle: title).exists
    }

    /// Get task count in table
    func getTaskCount() -> Int {
        let rowCount = taskRowQuery.count
        if rowCount > 0 {
            return rowCount
        }
        return app.tables.cells.count
    }

    /// Verify task count
    func verifyTaskCount(_ expectedCount: Int, file: StaticString = #file, line: UInt = #line) {
        let actualCount = getTaskCount()
        XCTAssertEqual(
            actualCount,
            expectedCount,
            "Expected \(expectedCount) tasks, found \(actualCount)",
            file: file,
            line: line
        )
    }

    /// Verify daily score
    func verifyDailyScore(_ expectedScore: Int, file: StaticString = #file, line: UInt = #line) -> Bool {
        let scoreText = dailyScoreLabel.label

        // Score might be displayed as "Score: 10" or just "10"
        let containsScore = scoreText.contains("\(expectedScore)")

        if !containsScore {
            XCTFail(
                "Expected daily score \(expectedScore), found '\(scoreText)'",
                file: file,
                line: line
            )
        }

        return containsScore
    }

    /// Verify streak
    func verifyStreak(_ expectedStreak: Int, file: StaticString = #file, line: UInt = #line) -> Bool {
        let streakText = streakLabel.label

        // Streak might be displayed as "Streak: 5" or "5 days"
        let containsStreak = streakText.contains("\(expectedStreak)")

        if !containsStreak {
            XCTFail(
                "Expected streak \(expectedStreak), found '\(streakText)'",
                file: file,
                line: line
            )
        }

        return containsStreak
    }

    /// Verify completion rate
    func verifyCompletionRate(_ expectedRate: Int, file: StaticString = #file, line: UInt = #line) -> Bool {
        let rateText = completionRateLabel.label

        // Rate might be displayed as "60%" or "Completion: 60%"
        let containsRate = rateText.contains("\(expectedRate)")

        if !containsRate {
            XCTFail(
                "Expected completion rate \(expectedRate)%, found '\(rateText)'",
                file: file,
                line: line
            )
        }

        return containsRate
    }

    /// Verify chart is visible
    func verifyChartIsVisible() -> Bool {
        return chartView.exists
    }

    /// Verify floating nav XP pie chart is visible.
    func verifyNavXpPieChartIsVisible(timeout: TimeInterval = 5) -> Bool {
        navXpPieChart.waitForExistence(timeout: timeout)
    }

    /// Verify floating nav XP pie chart is hidden.
    func verifyNavXpPieChartIsHidden(timeout: TimeInterval = 2) -> Bool {
        !navXpPieChart.waitForExistence(timeout: timeout)
    }

    /// Verify floating nav XP pie chart can be interacted with.
    @discardableResult
    func verifyNavXpPieChartIsHittable(file: StaticString = #file, line: UInt = #line) -> Bool {
        let chartButton = navXpPieChartButton
        let isHittable = chartButton.exists ? chartButton.isHittable : navXpPieChart.isHittable
        if !isHittable {
            XCTFail("Navigation XP pie chart should be hittable", file: file, line: line)
        }
        return isHittable
    }

    /// Verify floating nav XP pie chart size is approximately expected.
    @discardableResult
    func verifyNavXpPieChartSize(
        expected: CGFloat = 44,
        tolerance: CGFloat = 8,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let frame = navXpPieChart.frame
        let widthMatches = abs(frame.width - expected) <= tolerance
        let heightMatches = abs(frame.height - expected) <= tolerance
        let matches = widthMatches && heightMatches

        if !matches {
            XCTFail(
                "Expected nav XP pie chart size near \(expected)x\(expected), got \(frame.width)x\(frame.height)",
                file: file,
                line: line
            )
        }

        return matches
    }

    /// Verify floating nav XP pie chart frame is fully within the visible app window.
    @discardableResult
    func verifyNavXpPieChartIsFullyVisibleInWindow(file: StaticString = #file, line: UInt = #line) -> Bool {
        verifyElementIsFullyVisibleInWindow(
            navXpPieChart,
            description: "Navigation XP pie chart",
            file: file,
            line: line
        )
    }

    /// Verify an element's frame is fully within the visible app window.
    @discardableResult
    func verifyElementIsFullyVisibleInWindow(
        _ element: XCUIElement,
        description: String,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let elementFrame = element.frame
        let windowFrame = app.windows.firstMatch.frame
        let isFullyVisible = windowFrame.contains(elementFrame)

        if !isFullyVisible {
            XCTFail(
                "Expected \(description) frame \(elementFrame) to be fully inside window frame \(windowFrame)",
                file: file,
                line: line
            )
        }

        return isFullyVisible
    }

    /// Verify nav pie chart is horizontally aligned with settings button and positioned above it.
    @discardableResult
    func verifyNavXpPieChartAlignedWithSettingsButton(
        horizontalTolerance: CGFloat = 16,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let chartExists = navXpPieChart.waitForExistence(timeout: 5)
        let settingsExists = settingsButton.waitForExistence(timeout: 5)
        guard chartExists, settingsExists else {
            XCTFail("Expected nav pie chart and settings button to exist for alignment check", file: file, line: line)
            return false
        }

        let chartFrame = navXpPieChart.frame
        let settingsFrame = settingsButton.frame
        let isHorizontallyAligned = abs(chartFrame.midX - settingsFrame.midX) <= horizontalTolerance
        let isAboveSettings = chartFrame.midY < settingsFrame.midY
        let isAligned = isHorizontallyAligned && isAboveSettings

        if !isAligned {
            XCTFail(
                "Expected nav pie chart aligned above settings. chart=\(chartFrame), settings=\(settingsFrame), tolerance=\(horizontalTolerance)",
                file: file,
                line: line
            )
        }
        return isAligned
    }

    /// Verify weekly calendar starts below (or at) the end of the top nav container.
    @discardableResult
    func verifyWeeklyCalendarStartsAfterTopNav(
        tolerance: CGFloat = 4,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let calendarExists = weeklyCalendar.waitForExistence(timeout: 5)
        let topNavExists = topNavContainer.waitForExistence(timeout: 5)
        guard calendarExists, topNavExists else {
            XCTFail(
                "Expected weekly calendar and top nav container to exist for position check",
                file: file,
                line: line
            )
            return false
        }

        let isBelow = weeklyCalendar.frame.minY >= topNavContainer.frame.maxY - tolerance
        if !isBelow {
            XCTFail(
                "Expected weekly calendar to start below top nav. calendar=\(weeklyCalendar.frame), topNav=\(topNavContainer.frame)",
                file: file,
                line: line
            )
        }
        return isBelow
    }

    /// Verify weekly calendar appears below the top nav controls.
    @discardableResult
    func verifyWeeklyCalendarBelowTopNav(
        tolerance: CGFloat = 4,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        verifyWeeklyCalendarStartsAfterTopNav(tolerance: tolerance, file: file, line: line)
    }

    /// Verify nav XP pie chart button/container is absent.
    @discardableResult
    func verifyNavXpPieChartButtonIsAbsent(file: StaticString = #file, line: UInt = #line) -> Bool {
        let isAbsent = !navXpPieChartButton.exists
        if !isAbsent {
            XCTFail("Navigation XP pie chart button should be absent", file: file, line: line)
        }
        return isAbsent
    }

    /// Verify nav XP pie chart button/container is present.
    @discardableResult
    func verifyNavXpPieChartButtonIsPresent(timeout: TimeInterval = 3, file: StaticString = #file, line: UInt = #line) -> Bool {
        let isPresent = navXpPieChartButton.waitForExistence(timeout: timeout)
        if !isPresent {
            XCTFail("Navigation XP pie chart button should be present", file: file, line: line)
        }
        return isPresent
    }

    /// Verify empty state (no tasks)
    func verifyEmptyState() -> Bool {
        return getTaskCount() == 0
    }

    // MARK: - Wait Helpers

    /// Wait for task to appear
    @discardableResult
    func waitForTask(withTitle title: String, timeout: TimeInterval = 5) -> Bool {
        let taskText = app.staticTexts[title]
        if taskText.waitForExistence(timeout: timeout) {
            return true
        }
        return taskRow(containingTitle: title).waitForExistence(timeout: timeout)
    }

    /// Wait for task count to match expected
    @discardableResult
    func waitForTaskCount(_ expectedCount: Int, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate { _, _ in
            return self.getTaskCount() == expectedCount
        }

        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

        return result == .completed
    }

    /// Wait for daily score to update
    @discardableResult
    func waitForDailyScoreUpdate(to expectedScore: Int, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate { _, _ in
            let scoreText = self.dailyScoreLabel.label
            return scoreText.contains("\(expectedScore)")
        }

        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

        return result == .completed
    }

    enum InsightsTab {
        case today
        case week
        case systems
    }

    @discardableResult
    func switchInsightsTab(_ tab: InsightsTab, timeout: TimeInterval = 2.0) -> Bool {
        let tabElement: XCUIElement
        switch tab {
        case .today:
            tabElement = insightsTodayTab
        case .week:
            tabElement = insightsWeekTab
        case .systems:
            tabElement = insightsSystemsTab
        }

        guard tabElement.waitForExistence(timeout: timeout) else {
            return false
        }

        tapElement(tabElement)
        return true
    }

    @discardableResult
    func scrollInsightsTab(_ tab: InsightsTab, swipeCount: Int = 5) -> Bool {
        guard switchInsightsTab(tab) else { return false }
        let scrollView = insightsScrollView
        guard scrollView.waitForExistence(timeout: 2.0) else { return false }

        for _ in 0..<swipeCount {
            scrollView.swipeUp()
        }
        for _ in 0..<swipeCount {
            scrollView.swipeDown()
        }
        return true
    }

    func swipeTimelineLeft() {
        timelineSurface.swipeLeft()
    }

    func swipeTimelineRight() {
        timelineSurface.swipeRight()
    }
}
