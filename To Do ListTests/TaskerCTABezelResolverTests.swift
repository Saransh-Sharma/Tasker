import XCTest
@testable import To_Do_List

final class TaskerCTABezelResolverTests: XCTestCase {
    private let userDecorativeCTAEffectsKey = "feature.ui.decorative_cta_effects.user_enabled"
    private let remoteDecorativeCTAEffectsKey = "feature.ui.decorative_cta_effects.remote_allowed"
    private let homeBackdropNoiseAmountKey = V2FeatureFlags.homeBackdropNoiseAmountUserKey

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: userDecorativeCTAEffectsKey)
        UserDefaults.standard.removeObject(forKey: remoteDecorativeCTAEffectsKey)
        UserDefaults.standard.removeObject(forKey: homeBackdropNoiseAmountKey)
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

    func testDecorativeButtonEffectsDefaultToDisabled() {
        UserDefaults.standard.removeObject(forKey: userDecorativeCTAEffectsKey)
        UserDefaults.standard.removeObject(forKey: remoteDecorativeCTAEffectsKey)

        XCTAssertFalse(V2FeatureFlags.userDecorativeCTAEffectsEnabled)
        XCTAssertTrue(V2FeatureFlags.remoteDecorativeCTAEffectsAllowed)
        XCTAssertFalse(V2FeatureFlags.liquidMetalCTAEnabled)
    }

    func testDecorativeButtonEffectsStayDisabledWhenUserPrefIsFalseAndRemoteAllows() {
        V2FeatureFlags.userDecorativeCTAEffectsEnabled = false
        V2FeatureFlags.remoteDecorativeCTAEffectsAllowed = true

        XCTAssertFalse(V2FeatureFlags.liquidMetalCTAEnabled)
    }

    func testDecorativeButtonEffectsEnableWhenUserPrefIsTrueAndRemoteAllows() {
        V2FeatureFlags.userDecorativeCTAEffectsEnabled = true
        V2FeatureFlags.remoteDecorativeCTAEffectsAllowed = true

        XCTAssertTrue(V2FeatureFlags.liquidMetalCTAEnabled)
    }

    func testDecorativeButtonEffectsDisableWhenRemoteDisallowsDespiteUserPref() {
        V2FeatureFlags.userDecorativeCTAEffectsEnabled = true
        V2FeatureFlags.remoteDecorativeCTAEffectsAllowed = false

        XCTAssertFalse(V2FeatureFlags.liquidMetalCTAEnabled)
    }

    func testHomeBackdropNoiseDefaultsToTwentyPercent() {
        UserDefaults.standard.removeObject(forKey: homeBackdropNoiseAmountKey)

        XCTAssertEqual(V2FeatureFlags.homeBackdropNoiseAmount, 20)
    }

    func testHomeBackdropNoiseAmountClampsBelowZero() {
        V2FeatureFlags.homeBackdropNoiseAmount = -12

        XCTAssertEqual(V2FeatureFlags.homeBackdropNoiseAmount, 0)
    }

    func testHomeBackdropNoiseAmountClampsAboveHundred() {
        V2FeatureFlags.homeBackdropNoiseAmount = 180

        XCTAssertEqual(V2FeatureFlags.homeBackdropNoiseAmount, 100)
    }

    func testHomeBackdropNoiseOpacityMappingTracksPercentage() {
        XCTAssertEqual(TaskerBackdropNoise.opacity(for: 20), 0.02, accuracy: 0.0001)
        XCTAssertEqual(TaskerBackdropNoise.opacity(for: 100), 0.10, accuracy: 0.0001)
    }
}
