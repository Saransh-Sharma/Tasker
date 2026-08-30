import XCTest
@testable import LifeBoard

final class LifeBoardCTABezelResolverTests: XCTestCase {
    private let userDecorativeCTAEffectsKey = "feature.ui.decorative_cta_effects.user_enabled"
    private let remoteDecorativeCTAEffectsKey = "feature.ui.decorative_cta_effects.remote_allowed"

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: userDecorativeCTAEffectsKey)
        UserDefaults.standard.removeObject(forKey: remoteDecorativeCTAEffectsKey)
    }

    func testOnboardingHighlightMovesPastCreatedTemplate() {
        let highlighted = PrimaryActionResolver.highlightedOnboardingTemplateID(
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
        let highlighted = PrimaryActionResolver.highlightedOnboardingTemplateID(
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
            PrimaryActionResolver.dailySummaryPrimaryCTAIdentifier(for: morning),
            "home.dailySummary.cta.startToday"
        )
        XCTAssertEqual(
            PrimaryActionResolver.dailySummaryPrimaryCTAIdentifier(for: nightly),
            "home.dailySummary.cta.planTomorrow"
        )
    }

    /// The default is **on**. These used to assert against
    /// `liquidMetalCTAEnabled`, whose only consumer was the liquid-metal CTA
    /// bezel; with that removed the user preference had no consumer at all, so
    /// it now gates `signatureShadersEnabled` — the effects layer the setting
    /// was always presented as governing. The remote kill-switch is unchanged.
    func testDecorativeButtonEffectsDefaultToEnabled() {
        UserDefaults.standard.removeObject(forKey: userDecorativeCTAEffectsKey)
        UserDefaults.standard.removeObject(forKey: remoteDecorativeCTAEffectsKey)

        XCTAssertTrue(V2FeatureFlags.userDecorativeCTAEffectsEnabled)
        XCTAssertTrue(V2FeatureFlags.remoteDecorativeCTAEffectsAllowed)
        XCTAssertTrue(V2FeatureFlags.signatureShadersEnabled)
    }

    /// The remote flag must still be able to kill it regardless of the default.
    func testRemoteKillSwitchStillDisablesDecorativeEffectsAtDefault() {
        UserDefaults.standard.removeObject(forKey: userDecorativeCTAEffectsKey)
        V2FeatureFlags.remoteDecorativeCTAEffectsAllowed = false

        XCTAssertFalse(V2FeatureFlags.signatureShadersEnabled)
    }

    func testDecorativeButtonEffectsStayDisabledWhenUserPrefIsFalseAndRemoteAllows() {
        V2FeatureFlags.userDecorativeCTAEffectsEnabled = false
        V2FeatureFlags.remoteDecorativeCTAEffectsAllowed = true

        XCTAssertFalse(V2FeatureFlags.signatureShadersEnabled)
    }

    func testDecorativeButtonEffectsEnableWhenUserPrefIsTrueAndRemoteAllows() {
        V2FeatureFlags.userDecorativeCTAEffectsEnabled = true
        V2FeatureFlags.remoteDecorativeCTAEffectsAllowed = true

        XCTAssertTrue(V2FeatureFlags.signatureShadersEnabled)
    }

    func testDecorativeButtonEffectsDisableWhenRemoteDisallowsDespiteUserPref() {
        V2FeatureFlags.userDecorativeCTAEffectsEnabled = true
        V2FeatureFlags.remoteDecorativeCTAEffectsAllowed = false

        XCTAssertFalse(V2FeatureFlags.signatureShadersEnabled)
    }

}
