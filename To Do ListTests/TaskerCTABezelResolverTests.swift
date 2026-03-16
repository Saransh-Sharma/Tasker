import XCTest
@testable import To_Do_List

final class TaskerCTABezelResolverTests: XCTestCase {
    private let liquidMetalCTAKey = "feature.ui.liquid_metal_cta"

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: liquidMetalCTAKey)
    }

    func testOnboardingHighlightMovesPastCreatedTemplate() {
        let highlighted = TaskerCTABezelResolver.highlightedOnboardingTemplateID(
            primarySuggestionIDs: ["first", "second", "third"],
            taskTemplateStates: [
                "first": .created(UUID()),
                "second": .idle,
                "third": .idle
            ]
        )

        XCTAssertEqual(highlighted, "second")
    }

    func testOnboardingHighlightReturnsNilWhenAllPrimarySuggestionsAreCreated() {
        let highlighted = TaskerCTABezelResolver.highlightedOnboardingTemplateID(
            primarySuggestionIDs: ["first", "second"],
            taskTemplateStates: [
                "first": .created(UUID()),
                "second": .created(UUID())
            ]
        )

        XCTAssertNil(highlighted)
    }

    func testDailySummaryPrimaryCTAIdentifierMatchesSummaryVariant() {
        let morning = DailySummaryModalData.morning(
            MorningPlanSummary(
                date: Date(timeIntervalSince1970: 0),
                openTodayCount: 3,
                highPriorityCount: 1,
                overdueCount: 0,
                potentialXP: 24,
                focusTasks: [],
                blockedCount: 0,
                longTaskCount: 0,
                morningPlannedCount: 2,
                eveningPlannedCount: 1
            )
        )
        let nightly = DailySummaryModalData.nightly(
            NightlyRetrospectiveSummary(
                date: Date(timeIntervalSince1970: 0),
                completedCount: 5,
                totalCount: 7,
                xpEarned: 80,
                completionRate: 0.71,
                streakCount: 6,
                biggestWins: [],
                carryOverDueTodayCount: 0,
                carryOverOverdueCount: 1,
                tomorrowPreview: [],
                morningCompletedCount: 2,
                eveningCompletedCount: 3
            )
        )

        XCTAssertEqual(
            TaskerCTABezelResolver.dailySummaryPrimaryCTAIdentifier(for: morning),
            "home.dailySummary.cta.startToday"
        )
        XCTAssertEqual(
            TaskerCTABezelResolver.dailySummaryPrimaryCTAIdentifier(for: nightly),
            "home.dailySummary.cta.planTomorrow"
        )
    }

    func testLiquidMetalCTAFeatureDefaultsToEnabled() {
        UserDefaults.standard.removeObject(forKey: liquidMetalCTAKey)
        XCTAssertTrue(V2FeatureFlags.liquidMetalCTAEnabled)
    }
}
