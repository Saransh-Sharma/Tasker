import CoreData
import JournalFoundation
import KnowledgeGraphKit
import ReflectionKit
import UIKit
import XCTest
@testable import LifeBoard

final class LifeOSFoundationContractTests: XCTestCase {
    func testVisualFixtureCatalogCoversEveryRootAndReleaseState() {
        let fixtures = LifeBoardVisualFixture.catalog
        XCTAssertEqual(
            fixtures.count,
            LifeBoardVisualFixtureRoot.allCases.count * LifeBoardVisualFixtureState.allCases.count
        )
        XCTAssertEqual(Set(fixtures.map(\.id)).count, fixtures.count)

        for fixture in fixtures {
            XCTAssertEqual(LifeBoardVisualFixture(arguments: [fixture.launchArgument]), fixture)
        }
        XCTAssertNil(LifeBoardVisualFixture(arguments: ["-LIFEBOARD_VISUAL_FIXTURE=home:not-real"]))
    }

    func testVisualAppearanceFixturesRoundTripEveryReleaseComfortMode() {
        XCTAssertEqual(LifeBoardVisualAppearanceFixture.allCases.count, 7)
        for appearance in LifeBoardVisualAppearanceFixture.allCases {
            XCTAssertEqual(
                LifeBoardVisualAppearanceFixture(arguments: [appearance.launchArgument]),
                appearance
            )
        }
        XCTAssertNil(
            LifeBoardVisualAppearanceFixture(arguments: ["-LIFEBOARD_VISUAL_APPEARANCE=not-real"])
        )
        XCTAssertTrue(LifeBoardVisualAppearanceFixture.highContrastLight.usesHighContrast)
        XCTAssertTrue(LifeBoardVisualAppearanceFixture.highContrastDark.usesHighContrast)
        XCTAssertTrue(LifeBoardVisualAppearanceFixture.reducedTransparency.usesReducedTransparency)
        XCTAssertTrue(LifeBoardVisualAppearanceFixture.reducedMotion.usesReducedMotion)
        XCTAssertTrue(LifeBoardVisualAppearanceFixture.grayscale.usesGrayscale)
    }

    func testDashboardResponsiveSpansPreserveSemanticDensityAcrossFourEightAndTwelveColumns() {
        XCTAssertEqual(DashboardResponsiveSpanResolver.columns(for: .standard, columnCount: 4), 2)
        XCTAssertEqual(DashboardResponsiveSpanResolver.columns(for: .standard, columnCount: 8), 4)
        XCTAssertEqual(DashboardResponsiveSpanResolver.columns(for: .standard, columnCount: 12), 6)
        XCTAssertEqual(DashboardResponsiveSpanResolver.columns(for: .wide, columnCount: 4), 4)
        XCTAssertEqual(DashboardResponsiveSpanResolver.columns(for: .wide, columnCount: 8), 8)
        XCTAssertEqual(DashboardResponsiveSpanResolver.columns(for: .wide, columnCount: 12), 12)
        XCTAssertEqual(DashboardResponsiveSpanResolver.columns(for: .expanded, columnCount: 1), 1)
    }

    func testPlanLensRestorationIsStableAndRejectsMalformedValues() throws {
        let suite = "LifeOSFoundationContractTests.plan-lens.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(PlanLensRestoration.load(from: defaults), .day)
        PlanLensRestoration.save(.week, to: defaults)
        XCTAssertEqual(PlanLensRestoration.load(from: defaults), .week)

        defaults.set("not-a-plan-lens", forKey: PlanLensRestoration.key)
        XCTAssertEqual(PlanLensRestoration.load(from: defaults), .day)
    }

    func testHomeSignalProgressRendersOnlyForAvailableData() throws {
        let available = HomeSignalSlot(
            id: "hydration",
            title: "Hydration",
            valueText: "1.4 L",
            progress: 0.7,
            systemImage: "drop",
            availability: .available,
            sourceID: UUID()
        )
        XCTAssertEqual(try XCTUnwrap(available.progress), 0.7, accuracy: 0.0001)

        for state in HomeSignalState.allCases where state != .available {
            let signal = HomeSignalSlot(
                id: "steps-\(state.rawValue)",
                title: "Steps",
                valueText: "Unavailable",
                progress: 0.42,
                systemImage: "figure.walk",
                availability: state,
                sourceID: nil
            )
            XCTAssertNil(signal.progress, "\(state) must not render numeric progress")
            XCTAssertFalse(state.permitsProgressRendering)
        }
    }

    func testNightDaypartDoesNotForceDarkFunctionalAppearance() {
        let light = LifeBoardDaypartTokens.functionalPalette(for: .night, colorScheme: .light)
        XCTAssertEqual(light.canvas, "#FFF7D8")
        XCTAssertEqual(light.foreground, "#2B2118")
        XCTAssertEqual(light.celestialCore, LifeBoardDaypartTokens.night.celestialCore)

        let dark = LifeBoardDaypartTokens.functionalPalette(for: .morning, colorScheme: .dark)
        XCTAssertEqual(dark.canvas, LifeBoardDaypartTokens.night.canvas)
        XCTAssertEqual(dark.foreground, LifeBoardDaypartTokens.night.foreground)
    }

    func testAutomaticDaypartBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))

        XCTAssertEqual(LifeBoardDaypartResolver.resolve(at: date(hour: 4, minute: 59, calendar: calendar), calendar: calendar), .night)
        XCTAssertEqual(LifeBoardDaypartResolver.resolve(at: date(hour: 5, minute: 0, calendar: calendar), calendar: calendar), .morning)
        XCTAssertEqual(LifeBoardDaypartResolver.resolve(at: date(hour: 11, minute: 59, calendar: calendar), calendar: calendar), .morning)
        XCTAssertEqual(LifeBoardDaypartResolver.resolve(at: date(hour: 12, minute: 0, calendar: calendar), calendar: calendar), .afternoon)
        XCTAssertEqual(LifeBoardDaypartResolver.resolve(at: date(hour: 16, minute: 59, calendar: calendar), calendar: calendar), .afternoon)
        XCTAssertEqual(LifeBoardDaypartResolver.resolve(at: date(hour: 17, minute: 0, calendar: calendar), calendar: calendar), .evening)
        XCTAssertEqual(LifeBoardDaypartResolver.resolve(at: date(hour: 20, minute: 59, calendar: calendar), calendar: calendar), .evening)
        XCTAssertEqual(LifeBoardDaypartResolver.resolve(at: date(hour: 21, minute: 0, calendar: calendar), calendar: calendar), .night)
    }

    func testApprovedScreenshotSwatchesRemainExact() {
        XCTAssertEqual(LifeBoardDaypartTokens.morning.canvas, "#FFF7D8")
        XCTAssertEqual(LifeBoardDaypartTokens.morning.celestialPrimary, "#F0CD87")
        XCTAssertEqual(LifeBoardDaypartTokens.afternoon.canvas, "#FFF7D8")
        XCTAssertEqual(LifeBoardDaypartTokens.afternoon.celestialPrimary, "#F0CD87")
        XCTAssertEqual(LifeBoardDaypartTokens.evening.foreground, "#2B2118")
        XCTAssertEqual(LifeBoardDaypartTokens.night.canvas, "#151B2D")
        XCTAssertEqual(LifeBoardDaypartTokens.night.foreground, "#F7F1E7")
    }

    func testEveryDaypartDefinesEverySemanticRole() {
        for daypart in ResolvedDaypart.allCases {
            for role in LifeBoardDaypartColorRole.allCases {
                XCTAssertTrue(LifeBoardDaypartTokens.palette(for: daypart).hex(for: role).hasPrefix("#"))
            }
        }
    }

    func testFunctionalDaypartTextMeetsWCAGContrast() throws {
        for daypart in ResolvedDaypart.allCases {
            let palette = LifeBoardDaypartTokens.palette(for: daypart)
            let canvas = try rgbComponents(from: palette.canvas)

            XCTAssertGreaterThanOrEqual(
                contrastRatio(try rgbComponents(from: palette.foreground), canvas),
                4.5,
                "Primary text must remain readable in the \(daypart.rawValue) atmosphere"
            )
            XCTAssertGreaterThanOrEqual(
                contrastRatio(try rgbComponents(from: palette.foregroundSecondary), canvas),
                4.5,
                "Secondary text must remain readable in the \(daypart.rawValue) atmosphere"
            )
        }
    }

    func testAdaptiveFunctionalSurfaceTextMeetsWCAGContrast() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection(mutations: {
                    $0.userInterfaceStyle = style
                    $0.accessibilityContrast = contrast
                })
                let ink = try rgbComponents(from: LifeBoardColorTokens.inkPrimary.resolvedColor(with: traits))
                let surface = try rgbComponents(from: LifeBoardColorTokens.foundationSurfaceSolid.resolvedColor(with: traits))
                XCTAssertGreaterThanOrEqual(contrastRatio(ink, surface), 4.5)
            }
        }
    }

    func testCelestialAccentControlsUseVerifiedCocoaForeground() throws {
        let foreground = try rgbComponents(from: LifeBoardColorTokens.foundationOnCelestialAccent)
        for daypart in ResolvedDaypart.allCases {
            let background = try rgbComponents(
                from: LifeBoardDaypartTokens.palette(for: daypart).celestialCore
            )
            XCTAssertGreaterThanOrEqual(
                contrastRatio(foreground, background),
                4.5,
                "Celestial controls must remain readable in the \(daypart.rawValue) palette"
            )
        }
    }

    func testSettingsHeroUsesAStableReadableForeground() throws {
        let foreground = try rgbComponents(from: LifeBoardColorTokens.foundationOnSettingsHero)
        for backgroundColor in [
            LifeBoardColorTokens.foundationSettingsHeroStart,
            LifeBoardColorTokens.foundationSettingsHeroMiddle,
            LifeBoardColorTokens.foundationSettingsHeroEnd
        ] {
            XCTAssertGreaterThanOrEqual(
                contrastRatio(foreground, try rgbComponents(from: backgroundColor)),
                4.5
            )
        }
    }

    func testReleaseGateLegibilityPairsPassInEveryAppearance() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for accessibilityContrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection(mutations: {
                    $0.userInterfaceStyle = style
                    $0.accessibilityContrast = accessibilityContrast
                })
                for pair in LifeBoardLegibilityPair.releaseGate {
                    let foreground = try rgbComponents(
                        from: UIColor.lifeboard(pair.foreground).resolvedColor(with: traits)
                    )
                    let background = try rgbComponents(
                        from: UIColor.lifeboard(pair.background).resolvedColor(with: traits)
                    )
                    XCTAssertGreaterThanOrEqual(
                        contrastRatio(foreground, background),
                        pair.minimumContrast,
                        "\(pair.foreground.rawValue) on \(pair.background.rawValue) failed in \(style) / \(accessibilityContrast)"
                    )
                }
            }
        }
    }

    func testImageReadabilityPolicyIsBoundedAndDeterministic() {
        XCTAssertEqual(LifeBoardImageReadabilityPolicy.foregroundStyle(forLuminance: 0.1), .lightContent)
        XCTAssertEqual(LifeBoardImageReadabilityPolicy.foregroundStyle(forLuminance: 0.9), .darkContent)
        XCTAssertGreaterThan(
            LifeBoardImageReadabilityPolicy.scrimOpacity(forLuminance: 0.5),
            LifeBoardImageReadabilityPolicy.scrimOpacity(forLuminance: 0.05)
        )
        for luminance in stride(from: CGFloat(-0.2), through: CGFloat(1.2), by: 0.1) {
            let opacity = LifeBoardImageReadabilityPolicy.scrimOpacity(forLuminance: luminance)
            XCTAssertTrue((0...1).contains(opacity))
        }
    }

    func testRenderingPolicyHonorsComfortAndAccessibility() {
        let reduced = AmbientRenderingPolicy.resolve(
            requestedTier: .enhanced3D,
            comfortProfile: .playful,
            reduceMotion: true,
            lowPowerMode: false,
            thermalState: .nominal
        )
        XCTAssertEqual(reduced.effectiveTier, .static)
        XCTAssertEqual(reduced.maximumParallax, 0)
        XCTAssertFalse(reduced.allowsIdleMotion)

        let balanced = AmbientRenderingPolicy.resolve(
            requestedTier: .ambient2D,
            comfortProfile: .balanced,
            reduceMotion: false,
            lowPowerMode: false,
            thermalState: .nominal
        )
        XCTAssertEqual(balanced.maximumParallax, 4)
        XCTAssertTrue(balanced.allowsIdleMotion)
    }

    func testSharedMotionPolicyDisablesPremiumEffectsUnderEveryConstraint() {
        let nominal = LifeBoardMotionPolicy.resolve(
            reduceMotion: false,
            reduceTransparency: false,
            lowPowerMode: false,
            thermalState: .nominal,
            sceneIsActive: true,
            supportsCustomShaders: true,
            isCatalyst: false
        )
        XCTAssertTrue(nominal.allowsCustomShaders)
        XCTAssertTrue(nominal.allowsIdleMotion)
        XCTAssertFalse(nominal.usesOpaqueSurfaces)

        let constrained: [LifeBoardMotionPolicy] = [
            .resolve(reduceMotion: true, reduceTransparency: false, lowPowerMode: false, thermalState: .nominal, sceneIsActive: true),
            .resolve(reduceMotion: false, reduceTransparency: true, lowPowerMode: false, thermalState: .nominal, sceneIsActive: true),
            .resolve(reduceMotion: false, reduceTransparency: false, lowPowerMode: true, thermalState: .nominal, sceneIsActive: true),
            .resolve(reduceMotion: false, reduceTransparency: false, lowPowerMode: false, thermalState: .serious, sceneIsActive: true),
            .resolve(reduceMotion: false, reduceTransparency: false, lowPowerMode: false, thermalState: .nominal, sceneIsActive: false),
            .resolve(reduceMotion: false, reduceTransparency: false, lowPowerMode: false, thermalState: .nominal, sceneIsActive: true, isCatalyst: true)
        ]
        XCTAssertTrue(constrained.allSatisfy { $0.allowsCustomShaders == false })
        XCTAssertEqual(constrained[0].transitionDuration, 0)
        XCTAssertTrue(constrained[1].usesOpaqueSurfaces)
        XCTAssertFalse(constrained[2].allowsIdleMotion)
        XCTAssertFalse(constrained[3].allowsIdleMotion)
        XCTAssertFalse(constrained[4].allowsIdleMotion)
    }

    func testAsyncActionPhaseCarriesRealProgressReceiptAndRecovery() {
        let receipt = UUID()
        let phases: [AsyncActionPhase<UUID>] = [
            .idle,
            .running(progress: 0.42),
            .success(receipt: receipt),
            .recoverableFailure(.init(message: "The export was interrupted.", recovery: .retry)),
            .cancelled
        ]
        XCTAssertEqual(phases[1], .running(progress: 0.42))
        XCTAssertEqual(phases[2], .success(receipt: receipt))
        XCTAssertEqual(phases[3], .recoverableFailure(.init(message: "The export was interrupted.", recovery: .retry)))
    }

    func testCaptureOrbDragSelectionRequiresAVisibleTargetHit() {
        let task = CaptureOrbDragTarget(kind: .task, frame: CGRect(x: 20, y: 20, width: 120, height: 44))
        let journal = CaptureOrbDragTarget(kind: .journal, frame: CGRect(x: 150, y: 20, width: 120, height: 44))

        XCTAssertEqual(
            CaptureOrbDragSelectionPolicy.selection(
                at: CGPoint(x: 151, y: 42),
                targets: [task, journal]
            ),
            .journal,
            "Overlapping hit slop must resolve to the closest visible control."
        )
        XCTAssertNil(
            CaptureOrbDragSelectionPolicy.selection(
                at: CGPoint(x: 300, y: 180),
                targets: [task, journal]
            ),
            "A release away from the menu must never create data accidentally."
        )
    }

    @MainActor
    func testWeeklyOperatingRoutesAreDistinctAndPopDeterministically() throws {
        let suite = "LifeOSFoundationTests.WeeklyRoutes.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let router = LifeBoardAppRouter(defaults: defaults)

        router.push(.weeklyPlanner, in: .plan)
        router.push(.weeklyReview, in: .plan)
        XCTAssertEqual(router.path(for: .plan), [.weeklyPlanner, .weeklyReview])

        router.pop(in: .plan)
        XCTAssertEqual(router.path(for: .plan), [.weeklyPlanner])
        router.pop(in: .plan)
        router.pop(in: .plan)
        XCTAssertTrue(router.path(for: .plan).isEmpty)
    }

    @MainActor
    func testRootActivationPreservesInactiveStacksAndPopsTheActiveStack() throws {
        let suite = "LifeOSFoundationTests.RootActivation.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let router = LifeBoardAppRouter(defaults: defaults)

        router.push(.taskDetail(UUID()), in: .home)
        router.push(.planDay, in: .plan)
        XCTAssertEqual(router.selectedDestination, .plan)

        router.activateRoot(.home)
        XCTAssertEqual(router.selectedDestination, .home)
        XCTAssertEqual(router.path(for: .home).count, 1)
        XCTAssertEqual(router.path(for: .plan), [.planDay])

        router.activateRoot(.home)
        XCTAssertTrue(router.path(for: .home).isEmpty)
        XCTAssertEqual(router.path(for: .plan), [.planDay])
    }

    @MainActor
    func testInteractiveCrossRootNavigationSelectsThenAppendsTypedLeaf() async throws {
        let suite = "LifeOSFoundationTests.InteractiveNavigation.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let router = LifeBoardAppRouter(defaults: defaults)

        let transition = router.navigate(.careLibrary, in: .track)
        XCTAssertEqual(router.selectedDestination, .track)
        XCTAssertTrue(router.path(for: .track).isEmpty)

        await transition.value
        XCTAssertEqual(router.selectedDestination, .track)
        XCTAssertEqual(router.path(for: .track), [.careLibrary])
    }

    @MainActor
    func testInteractiveSameRootNavigationDefersUntilRootPopSettles() async throws {
        let suite = "LifeOSFoundationTests.InteractiveSameRootNavigation.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let router = LifeBoardAppRouter(defaults: defaults)

        router.push(.journalSearch, in: .home)
        router.activateRoot(.home)
        XCTAssertTrue(router.path(for: .home).isEmpty)

        let transition = router.navigate(.weeklyReflection(Date(timeIntervalSince1970: 0)), in: .home)
        XCTAssertTrue(router.path(for: .home).isEmpty)

        await transition.value
        XCTAssertEqual(router.path(for: .home), [.weeklyReflection(Date(timeIntervalSince1970: 0))])
    }

    func testJournalPrivacyPolicyDefaultsPrivateAndRecoversMalformedStorage() throws {
        let suite = "LifeOSFoundationTests.JournalPrivacy.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let initial = JournalPrivacyPolicyPersistence.load(from: defaults)
        XCTAssertFalse(initial.requiresAuthentication)
        XCTAssertTrue(initial.shieldsAppSwitcher)
        XCTAssertTrue(initial.excludesSensitiveEntriesFromExport)
        XCTAssertFalse(initial.permitsJournalEvidenceForEva)

        var saved = initial
        saved.requiresAuthentication = true
        saved.permitsJournalEvidenceForEva = true
        try JournalPrivacyPolicyPersistence.save(saved, to: defaults)
        XCTAssertEqual(JournalPrivacyPolicyPersistence.load(from: defaults), saved)

        defaults.set(Data("not-json".utf8), forKey: JournalPrivacyPolicyPersistence.defaultsKey)
        XCTAssertEqual(JournalPrivacyPolicyPersistence.load(from: defaults), JournalPrivacyPolicy())
    }

    @MainActor
    func testRouterRestoresTypedStateAndCoalescesCapture() throws {
        let suite = "LifeOSFoundationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = LifeBoardPresentationPreferences(defaults: defaults)
        preferences.daypartSelection = .evening
        let captureRouter = CaptureRouter()
        let router = LifeBoardAppRouter(defaults: defaults, preferences: preferences, captureRouter: captureRouter)
        router.select(.plan)
        router.push(.weeklyPlanner)
        router.persist()

        let draftID = UUID()
        XCTAssertTrue(captureRouter.request(.init(kind: .task, source: .widget, draftID: draftID)))
        XCTAssertFalse(captureRouter.request(.init(kind: .task, source: .deepLink, draftID: draftID)))

        let restored = LifeBoardAppRouter(defaults: defaults, preferences: preferences)
        XCTAssertEqual(restored.selectedDestination, .plan)
        XCTAssertEqual(restored.path(for: .plan), [.weeklyPlanner])
        XCTAssertEqual(restored.restorationSnapshot().daypartSelection, .evening)
        XCTAssertEqual(restored.captureRouter.recoverableDraftID, draftID)
        XCTAssertNil(restored.captureRouter.activeRequest)
    }

    @MainActor
    func testCaptureRouterQueuesDistinctDraftsAndAdvancesDeterministically() {
        let router = CaptureRouter()
        let firstDraftID = UUID()
        let secondDraftID = UUID()

        XCTAssertTrue(router.request(.init(kind: .task, source: .widget, draftID: firstDraftID)))
        XCTAssertFalse(router.request(.init(kind: .task, source: .deepLink, draftID: firstDraftID)))
        XCTAssertTrue(router.request(.init(kind: .task, source: .appIntent, draftID: secondDraftID)))
        XCTAssertEqual(router.pendingRequests.compactMap(\.draftID), [secondDraftID])
        XCTAssertEqual(router.recoverableDraftID, firstDraftID)

        router.completeActiveRequest()
        XCTAssertEqual(router.activeRequest?.draftID, secondDraftID)
        XCTAssertEqual(router.recoverableDraftID, secondDraftID)

        router.cancelActiveRequest()
        XCTAssertNil(router.activeRequest)
        XCTAssertNil(router.recoverableDraftID)
    }

    @MainActor
    func testDeepLinksResolveDeterministically() {
        let suite = "LifeOSFoundationDeepLinkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let router = LifeBoardAppRouter(defaults: defaults)

        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://weekly/review")!))
        XCTAssertEqual(router.selectedDestination, .plan)
        XCTAssertEqual(router.path(for: .plan), [.weeklyReview])
        XCTAssertFalse(router.handle(url: URL(string: "https://example.com")!))
    }

    @MainActor
    func testProtectedJournalDeepLinkDefersExactIdentityUntilUnlockAndRelocksSafely() throws {
        let suite = "LifeOSFoundationProtectedJournalRouteTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var policy = JournalPrivacyPolicy()
        policy.requiresAuthentication = true
        try JournalPrivacyPolicyPersistence.save(policy, to: defaults)

        let dayID = UUID()
        let router = LifeBoardAppRouter(defaults: defaults)
        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://journal/\(dayID.uuidString)")!))
        XCTAssertFalse(router.isJournalAccessUnlocked)
        XCTAssertEqual(router.path(for: .track), [.journalSearch])
        XCTAssertEqual(
            router.deferredProtectedRoute,
            DeferredProtectedRoute(route: .journalDay(dayID), destination: .track)
        )

        let lockedSnapshotData = try XCTUnwrap(
            defaults.data(forKey: LifeBoardFoundationPreferenceKey.restorationState)
        )
        let lockedSnapshot = try JSONDecoder().decode(LifeBoardRestorationState.self, from: lockedSnapshotData)
        XCTAssertEqual(lockedSnapshot.paths[.track], [.journalSearch])

        router.journalDidUnlock()
        XCTAssertTrue(router.isJournalAccessUnlocked)
        XCTAssertNil(router.deferredProtectedRoute)
        XCTAssertEqual(router.path(for: .track), [.journalDay(dayID)])

        router.journalDidLock()
        XCTAssertFalse(router.isJournalAccessUnlocked)
        XCTAssertEqual(router.path(for: .track), [.journalSearch])
        XCTAssertEqual(router.deferredProtectedRoute?.route, .journalDay(dayID))

        let restored = LifeBoardAppRouter(defaults: defaults)
        XCTAssertFalse(restored.isJournalAccessUnlocked)
        XCTAssertEqual(restored.path(for: .track), [.journalSearch])
        XCTAssertTrue(restored.restorationSnapshot().paths.values.flatMap { $0 }.contains(.journalDay(dayID)) == false)
    }

    @MainActor
    func testPhaseOneThroughFourLeafDeepLinksResolveToTypedRoutes() throws {
        let suite = "LifeOSFoundationLeafDeepLinkTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let router = LifeBoardAppRouter(defaults: defaults)
        let focusID = UUID()
        let trackerID = UUID()

        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://habits")!))
        XCTAssertEqual(router.selectedDestination, .track)
        XCTAssertEqual(router.path(for: .track), [.habitBoard])

        router.popToRoot(in: .plan)
        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://focus/\(focusID.uuidString)")!))
        XCTAssertEqual(router.selectedDestination, .plan)
        XCTAssertEqual(router.path(for: .plan), [.focusSession(focusID)])

        router.popToRoot(in: .track)
        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://journal")!))
        XCTAssertEqual(router.path(for: .track), [.journalSearch])

        router.popToRoot(in: .track)
        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://tracker/\(trackerID.uuidString)")!))
        XCTAssertEqual(router.path(for: .track), [.trackerDetail(trackerID)])

        router.popToRoot(in: .track)
        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://reflection?weekStart=2026-07-13")!))
        guard case .weeklyReflection(let weekStart) = router.path(for: .track).last else {
            return XCTFail("Expected a typed weekly reflection route")
        }
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: weekStart), DateComponents(year: 2026, month: 7, day: 13))
    }

    func testEveryPhaseOneThroughFourRouteRoundTripsThroughCodable() throws {
        let id = UUID()
        let routes: [AppRoute] = [
            .taskDetail(id), .habitBoard, .habitLibrary, .habitDetail(id), .trackerDetail(id), .careLibrary,
            .project(id), .routine(id), .goal(id), .journalDay(id), .journalSearch,
            .weeklyReflection(Date(timeIntervalSince1970: 1_789_344_000)), .note(id),
            .knowledgeFolder(id), .planDay, .planWeek, .backlog, .focusSession(id),
            .focusSession(nil), .weeklyPlanner, .weeklyReview, .settings, .tokenGallery,
            .referenceDashboard
        ]

        let encoded = try JSONEncoder().encode(routes)
        XCTAssertEqual(try JSONDecoder().decode([AppRoute].self, from: encoded), routes)
    }

    @MainActor
    func testWidgetAndLegacyURLsTranslateToTypedRoutesWithDeterministicFallbacks() throws {
        let suite = "LifeOSFoundationBoundaryRoutes.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let router = LifeBoardAppRouter(defaults: defaults)
        let projectID = UUID()

        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://habits/library")!))
        XCTAssertEqual(router.selectedDestination, .track)
        XCTAssertEqual(router.path(for: .track), [.habitLibrary])

        router.popToRoot(in: .plan)
        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://tasks/project/\(projectID.uuidString)")!))
        XCTAssertEqual(router.selectedDestination, .plan)
        XCTAssertEqual(router.path(for: .plan), [.project(projectID)])

        router.popToRoot(in: .plan)
        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://tasks/upcoming")!))
        XCTAssertEqual(router.path(for: .plan), [.planDay])

        router.popToRoot(in: .plan)
        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://tasks/overdue")!))
        XCTAssertEqual(router.path(for: .plan), [.backlog])

        router.popToRoot(in: .plan)
        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://calendar/schedule")!))
        XCTAssertEqual(router.path(for: .plan), [.planDay])

        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://tasks/project/not-a-uuid")!))
        XCTAssertEqual(router.selectedDestination, .home)
        XCTAssertTrue(router.paths.values.allSatisfy(\.isEmpty))
        XCTAssertEqual(router.activeAlert?.title, "Opened Home")

        XCTAssertFalse(router.handle(url: URL(string: "https://example.com/tasks/today")!))
    }

    func testSpotlightJournalIdentifierTranslatesWithoutExposingMalformedRoutes() throws {
        let dayID = UUID()
        let url = try XCTUnwrap(
            LifeBoardSpotlightRouteTranslator.url(
                for: "\(LifeBoardSpotlightRouteTranslator.journalPrefix)\(dayID.uuidString)"
            )
        )
        XCTAssertEqual(url.absoluteString, "lifeboard://journal/\(dayID.uuidString)")
        XCTAssertNil(LifeBoardSpotlightRouteTranslator.url(for: "lifeboard-journal-not-a-uuid"))
        XCTAssertNil(LifeBoardSpotlightRouteTranslator.url(for: "third-party-result"))
    }

    @MainActor
    func testNotificationRoutesTranslateDirectlyIntoFoundationDestinations() throws {
        let suite = "LifeOSFoundationNotificationRoutes.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let router = LifeBoardAppRouter(defaults: defaults)
        let taskID = UUID()

        router.handle(notificationRoute: .taskDetail(taskID: taskID))
        XCTAssertEqual(router.selectedDestination, .home)
        XCTAssertEqual(router.path(for: .home), [.taskDetail(taskID)])

        router.handle(notificationRoute: .weeklyPlanner)
        XCTAssertEqual(router.selectedDestination, .plan)
        XCTAssertEqual(router.path(for: .plan), [.weeklyPlanner])

        router.popToRoot(in: .plan)
        router.handle(notificationRoute: .dayCompass(flow: .rescue, dateStamp: "20260716"))
        XCTAssertEqual(router.path(for: .plan), [.backlog])

        router.handle(notificationRoute: .dailySummary(kind: .nightly, dateStamp: nil))
        XCTAssertEqual(router.selectedDestination, .insights)

        router.handle(notificationRoute: .homeToday(taskID: nil))
        XCTAssertEqual(router.selectedDestination, .home)
    }

    @MainActor
    func testMalformedObjectDeepLinksFallBackToHome() {
        let suite = "LifeOSFoundationMalformedDeepLinkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let router = LifeBoardAppRouter(defaults: defaults)
        router.push(.weeklyPlanner, in: .plan)

        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://task/not-a-uuid")!))
        XCTAssertEqual(router.selectedDestination, .home)
        XCTAssertTrue(router.paths.values.allSatisfy(\.isEmpty))
        XCTAssertNotNil(router.activeAlert)

        router.activeAlert = nil
        XCTAssertTrue(router.handle(url: URL(string: "lifeboard://habit/not-a-uuid")!))
        XCTAssertEqual(router.selectedDestination, .home)
        XCTAssertNotNil(router.activeAlert)
    }

    func testLifeOSModelVersionContainsCloudSyncedLayoutEntities() throws {
        let model = try XCTUnwrap(
            NSManagedObjectModel.mergedModel(from: [Bundle.main, Bundle(for: Self.self)])
        )
        XCTAssertNotNil(model.entitiesByName["DashboardLayout"])
        XCTAssertNotNil(model.entitiesByName["DashboardWidgetPlacement"])
        let cloudEntities = try XCTUnwrap(model.entities(forConfigurationName: "CloudSync"))
        let cloudEntityNames = Set(cloudEntities.compactMap(\.name))
        XCTAssertTrue(cloudEntityNames.contains("DashboardLayout"))
        XCTAssertTrue(cloudEntityNames.contains("DashboardWidgetPlacement"))
    }

    func testPhaseIIModelKeepsPrivateAndDerivedDataInTheCorrectStores() throws {
        let model = try XCTUnwrap(NSManagedObjectModel.mergedModel(from: [Bundle.main, Bundle(for: Self.self)]))
        let cloud = Set(try XCTUnwrap(model.entities(forConfigurationName: "CloudSync")).compactMap(\.name))
        let local = Set(try XCTUnwrap(model.entities(forConfigurationName: "LocalOnly")).compactMap(\.name))

        for name in [
            "TrackerDefinition", "TrackerEntry", "MoodEnergyCheckIn", "MedicationDefinition",
            "MedicationSchedule", "MedicationEvent", "FastingSession", "JournalDay", "JournalBlock",
            "JournalMediaAttachment", "KnowledgeSpace", "KnowledgeFolder", "KnowledgeNote",
            "KnowledgeBlock", "KnowledgeTag", "KnowledgeNoteTagLink", "KnowledgeLink", "KnowledgeAttachment"
        ] {
            XCTAssertTrue(cloud.contains(name), "\(name) must be in CloudSync")
        }
        for name in ["JournalDerivedIndex", "JournalDraft", "KnowledgeGraphPosition"] {
            XCTAssertTrue(local.contains(name), "\(name) must be LocalOnly")
            XCTAssertFalse(cloud.contains(name), "\(name) must never enter CloudSync")
        }
    }

    @MainActor
    func testEveryPreviousModelMigratesToCurrentModelWithoutChangingStableIDs() throws {
        let previousModelNames = [
            "TaskModelV3",
            "TaskModelV3_Gamification",
            "TaskModelV3_Habits",
            "TaskModelV3_PulseProgress",
            "TaskModelV3_TaskIcons",
            "TaskModelV3_Timeline",
            "TaskModelV3_WeeklyPlanning",
            "TaskModelV3_LifeOSFoundation",
            "TaskModelV3_AdaptiveHome",
            "TaskModelV3_Trackers",
            "TaskModelV3_Journal",
            "TaskModelV3_KnowledgeNotes",
            "TaskModelV3_PlanningCore",
            "TaskModelV3_TrackFoundations",
            "TaskModelV3_JournalParity",
            "TaskModelV3_WellnessCore",
            "TaskModelV3_Nutrition"
        ]
        let modelBundleURL = try taskModelBundleURL()
        let destinationModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelBundleURL))

        for modelName in previousModelNames {
            XCTContext.runActivity(named: "Migrate \(modelName)") { _ in
                do {
                    try assertLightweightMigration(
                        from: modelName,
                        modelBundleURL: modelBundleURL,
                        destinationModel: destinationModel
                    )
                } catch {
                    XCTFail("\(modelName) could not migrate to the current TaskModelV3: \(error)")
                }
            }
        }
    }

    func testUnknownWidgetKindSurvivesDeterministicMigration() throws {
        let model = NSManagedObjectModel()
        let container = NSPersistentContainer(name: "MigrationContract", managedObjectModel: model)
        let repository = CoreDataDashboardLayoutRepository(container: container)
        let unknown = DashboardWidgetPlacementValue(
            widgetKind: "future.module.widget",
            semanticSize: .tall,
            ordinal: 7,
            configuration: .init(version: 9, payload: Data([1, 2, 3]))
        )
        let migrated = try repository.migrate(.init(mode: .smart, placements: [unknown]))
        XCTAssertEqual(migrated.placements.first?.widgetKind, "future.module.widget")
        XCTAssertEqual(migrated.placements.first?.configuration.version, 9)
        XCTAssertEqual(migrated.placements.first?.configuration.payload, Data([1, 2, 3]))
    }

    func testDashboardLayoutRepositoryRoundTrip() async throws {
        let model = try XCTUnwrap(
            NSManagedObjectModel.mergedModel(from: [Bundle.main, Bundle(for: Self.self)])
        )
        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.configuration = "CloudSync"
        container.persistentStoreDescriptions = [description]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        let expectedPlacement = DashboardWidgetPlacementValue(
            widgetKind: "future.module.widget",
            semanticSize: .wide,
            ordinal: 0,
            configuration: .init(version: 3, payload: Data([4, 5, 6]))
        )
        let expected = DashboardLayoutValue(mode: .smart, placements: [expectedPlacement])
        let repository = CoreDataDashboardLayoutRepository(container: container)

        try await repository.saveHome(expected)
        let fetched = try await repository.fetchHome()

        XCTAssertEqual(fetched?.id, expected.id)
        XCTAssertEqual(fetched?.placements.first?.widgetKind, expectedPlacement.widgetKind)
        XCTAssertEqual(fetched?.placements.first?.configuration, expectedPlacement.configuration)
    }

    func testLegacyHeroPresetDecodesAsTallAndEncodesOnlyTall() throws {
        let legacy = Data("\"hero\"".utf8)
        let decoded = try JSONDecoder().decode(WidgetSizePreset.self, from: legacy)
        XCTAssertEqual(decoded, .tall)
        let encoded = try JSONEncoder().encode(decoded)
        XCTAssertEqual(String(decoding: encoded, as: UTF8.self), "\"tall\"")
    }

    func testManualDaypartOverrideExpiresAtNextNaturalBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let activated = date(hour: 15, minute: 30, calendar: calendar)
        var controller = DaypartOverrideController()

        controller.select(.morning, at: activated, calendar: calendar)

        XCTAssertEqual(controller.activeOverride?.daypart, .morning)
        XCTAssertEqual(
            controller.activeOverride?.expiresAt,
            date(hour: 17, minute: 0, calendar: calendar)
        )
        XCTAssertEqual(
            controller.resolvedSelection(at: date(hour: 16, minute: 59, calendar: calendar), calendar: calendar),
            .morning
        )
        XCTAssertEqual(
            controller.resolvedSelection(at: date(hour: 17, minute: 0, calendar: calendar), calendar: calendar),
            .automatic
        )
        XCTAssertNil(controller.activeOverride)
    }

    @MainActor
    func testPhaseILegacyManualDaypartIsPromotedToExpiringOverride() throws {
        let suite = "LifeOSLegacyDaypart.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let capturedCalendar = calendar
        let now = date(hour: 15, minute: 30, calendar: calendar)
        defaults.set(DaypartSelection.morning.rawValue, forKey: LifeBoardFoundationPreferenceKey.daypartSelection)

        let preferences = LifeBoardPresentationPreferences(
            defaults: defaults,
            now: { now },
            calendar: { capturedCalendar }
        )

        XCTAssertEqual(preferences.daypartSelection, .morning)
        XCTAssertEqual(preferences.activeDaypartOverride?.expiresAt, date(hour: 17, minute: 0, calendar: calendar))
    }

    func testHomeLayoutDraftIsTransactionalAndRespectsSemanticSizes() throws {
        let original = DashboardLayoutValue(
            mode: .smart,
            placements: CoreDataDashboardLayoutRepository.curatedHomePlacements()
        )
        var draft = HomeLayoutDraft(layout: original)
        let focus = try XCTUnwrap(draft.current.placements.first)

        draft.resize(id: focus.id, to: .tall, registry: DefaultDashboardWidgetRegistry.shared)
        draft.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        draft.setVisible(false, id: focus.id)

        XCTAssertTrue(draft.hasChanges)
        XCTAssertEqual(draft.current.placements.first(where: { $0.id == focus.id })?.semanticSize, .tall)
        XCTAssertFalse(try XCTUnwrap(draft.current.placements.first(where: { $0.id == focus.id })).isVisible)
        draft.cancel()
        XCTAssertEqual(draft.current, original)
        XCTAssertFalse(draft.hasChanges)
    }

    func testSmartPolicyKeepsActiveFocusThenUsesDeclaredPriority() {
        let policy = DeterministicSmartHomePolicy()
        let now = Date(timeIntervalSince1970: 10_000)
        let safety = SmartPromotionCandidate(
            id: UUID(), kind: .safetySensitiveCare, title: "Medication follow-up", reason: "Care"
        )
        let active = SmartPromotionCandidate(
            id: UUID(), kind: .activeContext, title: "Current focus", reason: "Started", isUserStartedActiveFocus: true
        )
        XCTAssertEqual(policy.decide(candidates: [safety, active], now: now)?.id, active.id)

        let inactive = SmartPromotionCandidate(
            id: UUID(), kind: .activeContext, title: "Current context", reason: "Context"
        )
        XCTAssertEqual(policy.decide(candidates: [inactive, safety], now: now)?.id, safety.id)
    }

    func testCuratedSharedLayoutFollowsNarrativeOrder() {
        XCTAssertEqual(
            CoreDataDashboardLayoutRepository.curatedHomePlacements().map(\.widgetKind),
            [
                DashboardWidgetKind.focusNow.rawValue,
                DashboardWidgetKind.lifeSnapshot.rawValue,
                DashboardWidgetKind.care.rawValue,
                DashboardWidgetKind.tasks.rawValue,
                DashboardWidgetKind.routines.rawValue,
                DashboardWidgetKind.scheduleCapacity.rawValue,
                DashboardWidgetKind.quickCapture.rawValue,
                DashboardWidgetKind.compactTimeline.rawValue,
                DashboardWidgetKind.journal.rawValue,
                DashboardWidgetKind.progressReflection.rawValue
            ]
        )
    }

    func testDefaultDashboardMigrationAddsPhaseIIHierarchyWithoutReplacingStablePlacements() throws {
        let stableCareID = UUID()
        let legacy = DashboardLayoutValue(
            mode: .smart,
            schemaVersion: 2,
            isDefault: true,
            placements: [
                DashboardWidgetPlacementValue(widgetKind: DashboardWidgetKind.focusNow.rawValue, semanticSize: .wide, ordinal: 0),
                DashboardWidgetPlacementValue(id: stableCareID, widgetKind: DashboardWidgetKind.care.rawValue, semanticSize: .tall, ordinal: 1),
                DashboardWidgetPlacementValue(widgetKind: DashboardWidgetKind.progressReflection.rawValue, semanticSize: .standard, ordinal: 2)
            ]
        )

        let container = NSPersistentContainer(
            name: "DashboardMigrationContract",
            managedObjectModel: NSManagedObjectModel()
        )
        let migrated = try CoreDataDashboardLayoutRepository(container: container).migrate(legacy)

        XCTAssertEqual(migrated.schemaVersion, LifeOSFoundationSchema.dashboardLayoutVersion)
        XCTAssertEqual(migrated.placements.first(where: { $0.widgetKind == DashboardWidgetKind.care.rawValue })?.id, stableCareID)
        XCTAssertEqual(migrated.placements.first(where: { $0.widgetKind == DashboardWidgetKind.care.rawValue })?.semanticSize, .tall)
        XCTAssertTrue(migrated.placements.contains { $0.widgetKind == DashboardWidgetKind.tasks.rawValue })
        XCTAssertTrue(migrated.placements.contains { $0.widgetKind == DashboardWidgetKind.routines.rawValue })
        XCTAssertTrue(migrated.placements.contains { $0.widgetKind == DashboardWidgetKind.journal.rawValue })
    }

    func testNamespacedOffRecordMoodAssetsAreAvailableToJournal() {
        for mood in LifeBoardJournalMood.allCases {
            XCTAssertNotNil(UIImage(named: mood.largeAssetName), "Missing large artwork for \(mood.title)")
            XCTAssertNotNil(UIImage(named: mood.faceAssetName), "Missing dial face for \(mood.title)")
            XCTAssertNotNil(UIImage(named: mood.glowAssetName), "Missing glow artwork for \(mood.title)")
        }
    }

    func testJournalInsightsAreDeterministicAndEvidenceLinked() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let firstID = UUID()
        let secondID = UUID()
        let days = [
            LifeBoardJournalDayValue(
                id: firstID,
                day: today,
                blocks: [
                    .init(dayID: firstID, kind: .text, text: "A gentle useful day", ordinal: 0),
                    .init(dayID: firstID, kind: .mood, mood: .calm, energy: 4, ordinal: 1)
                ]
            ),
            LifeBoardJournalDayValue(
                id: secondID,
                day: yesterday,
                blocks: [
                    .init(dayID: secondID, kind: .text, text: "Made one thing", ordinal: 0),
                    .init(dayID: secondID, kind: .mood, mood: .calm, energy: 2, ordinal: 1)
                ]
            )
        ]

        let snapshot = LifeBoardJournalInsightEngine.makeSnapshot(days: days, now: now, calendar: calendar)
        XCTAssertEqual(snapshot.daysWritten, 2)
        XCTAssertEqual(snapshot.currentStreak, 2)
        XCTAssertEqual(snapshot.totalWords, 7)
        XCTAssertEqual(snapshot.dominantMood, .calm)
        XCTAssertEqual(snapshot.averageEnergy, 3)
        XCTAssertEqual(Set(snapshot.evidenceDayIDs), Set([firstID, secondID]))
    }

    func testJournalDerivedIndexSupportsHybridSearchUpdateDeleteAndInvalidation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let index = try LocalJournalDerivedIndexRepository(databaseURL: directory.appendingPathComponent("journal.sqlite"))
        let firstID = UUID()
        let secondID = UUID()
        let first = JournalEntrySnapshot(
            id: firstID,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            title: nil,
            text: "A quiet walk by the lake helped me release the pressure from work.",
            mood: .calm,
            energy: 4,
            isStarred: true,
            attachments: [],
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let second = JournalEntrySnapshot(
            id: secondID,
            date: Date(timeIntervalSince1970: 1_699_000_000),
            title: nil,
            text: "Dinner with family was warm and funny.",
            mood: .happy,
            energy: 5,
            isStarred: false,
            attachments: [],
            updatedAt: Date(timeIntervalSince1970: 1_699_000_100)
        )

        try await index.rebuild(entries: [first, second])
        let lakeResults = try await index.search(query: "quiet walk", limit: 5)
        XCTAssertEqual(lakeResults.first?.entryID, firstID)
        XCTAssertEqual(lakeResults.first?.matchReason, .exact)

        var updated = second
        updated.text = "Dinner ended with a memorable cardamom dessert."
        try await index.upsert(entry: updated)
        let updatedResults = try await index.search(query: "cardamom dessert", limit: 5)
        XCTAssertEqual(updatedResults.first?.entryID, secondID)

        try await index.remove(entryID: firstID)
        let removedResults = try await index.search(query: "quiet lake", limit: 5)
        XCTAssertFalse(removedResults.contains { $0.entryID == firstID })

        try await index.invalidate()
        let invalidatedResults = try await index.search(query: "cardamom", limit: 5)
        XCTAssertTrue(invalidatedResults.isEmpty)
    }

    func testJournalDerivedIndexRecoversFromMalformedSidecar() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("journal.sqlite")
        try Data("not a sqlite database".utf8).write(to: databaseURL, options: .atomic)

        let index = try LocalJournalDerivedIndexRepository(databaseURL: databaseURL)
        let entry = JournalEntrySnapshot(
            id: UUID(),
            date: Date(),
            title: nil,
            text: "Recovered private search",
            mood: nil,
            energy: nil,
            isStarred: false,
            attachments: [],
            updatedAt: Date()
        )
        try await index.rebuild(entries: [entry])
        let recoveredResults = try await index.search(query: "recovered private", limit: 3)
        XCTAssertEqual(recoveredResults.first?.entryID, entry.id)
    }

    func testWeeklyReflectionUsesMondaySundayThresholdsEvidenceAndVersions() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let reference = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12)))
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 13)))
        let outside = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20)))

        let empty = WeeklyReflectionEngine.makeReport(entries: [], weekContaining: reference, calendar: calendar)
        XCTAssertEqual(empty.density, .empty)
        XCTAssertTrue(calendar.isDate(empty.weekStart, inSameDayAs: monday))

        // Canonical JournalKit eligibility is empty below 150 words, then full
        // at three entries or 600 words. Keep this fixture exactly on the
        // visible boundary so host-app tests enforce the shared contract.
        let repeatedWords = Array(repeating: "grounded", count: 50).joined(separator: " ")
        let entries = [0, 1, 2].map { offset in
            JournalEntrySnapshot(
                id: UUID(),
                date: calendar.date(byAdding: .day, value: offset, to: monday) ?? monday,
                title: nil,
                text: repeatedWords,
                mood: .calm,
                energy: 4,
                isStarred: offset == 0,
                attachments: [],
                updatedAt: reference
            )
        }
        let outsideEntry = JournalEntrySnapshot(
            id: UUID(), date: outside, title: nil, text: repeatedWords, mood: .sad, energy: 1,
            isStarred: false, attachments: [], updatedAt: outside
        )
        let full = WeeklyReflectionEngine.makeReport(entries: entries + [outsideEntry], weekContaining: reference, calendar: calendar)
        XCTAssertEqual(full.density, .full)
        XCTAssertEqual(full.sourceSelection.includedEntryIDs, Set(entries.map(\.id)))
        XCTAssertFalse(full.sourceSelection.includedEntryIDs.contains(outsideEntry.id))
        XCTAssertTrue(full.summary.contains("Calm"))

        let regenerated = WeeklyReflectionEngine.makeReport(
            entries: entries,
            weekContaining: reference,
            calendar: calendar,
            previousVersions: [full]
        )
        XCTAssertEqual(regenerated.version, 2)
        XCTAssertEqual(regenerated.weekStart, full.weekStart)
    }

    func testProactiveReflectionFeedbackRoundTripsInProtectedDerivedStore() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LifeBoardProactiveReflectionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try LocalProactiveReflectionRepository(rootURL: root)
        let feedback = ReflectionCardFeedback(
            insightID: "mood-association:focus",
            saved: true,
            snoozedUntil: Date(timeIntervalSince1970: 2_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let followUp = DecisionFollowUpState(
            id: "followup-1",
            decisionID: "decision-1",
            sourceEntryID: UUID(),
            phraseHash: "stable-hash",
            state: .prompted,
            firstSeenAt: Date(timeIntervalSince1970: 900),
            lastPromptedAt: Date(timeIntervalSince1970: 1_000),
            resolvedAt: nil
        )

        try await repository.save(.init(
            feedback: [feedback.insightID: feedback],
            followUps: [followUp]
        ))
        let restored = try await repository.load()

        XCTAssertEqual(restored.feedback[feedback.insightID], feedback)
        XCTAssertEqual(restored.followUps, [followUp])
    }

    func testWeeklyReflectionHistoryPersistsVersionsAndExportRedactsSensitiveFields() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12)))
        let entry = JournalEntrySnapshot(
            id: UUID(),
            date: date,
            title: "Private day",
            text: "I made room for a quieter afternoon.",
            mood: .calm,
            energy: 4,
            isStarred: true,
            attachments: [.init(
                id: UUID(),
                kind: .audio,
                localRelativePath: "private/audio.m4a",
                duration: 12,
                transcription: "sensitive spoken detail",
                syncPolicy: .protectedLocalOnly,
                createdAt: date
            )],
            updatedAt: date
        )
        var first = WeeklyReflectionEngine.makeReport(entries: [entry], weekContaining: date, calendar: calendar)
        first.takeaway = "Keep the afternoon spacious."
        let second = WeeklyReflectionEngine.makeReport(
            entries: [entry],
            weekContaining: date,
            calendar: calendar,
            previousVersions: [first]
        )

        let historyURL = directory.appendingPathComponent("history", isDirectory: true)
        let history = try LocalWeeklyReflectionHistoryRepository(rootURL: historyURL, calendar: calendar)
        try await history.save(first)
        try await history.save(second)
        let relaunched = try LocalWeeklyReflectionHistoryRepository(rootURL: historyURL, calendar: calendar)
        let versions = try await relaunched.reports(weekContaining: date)
        XCTAssertEqual(versions.map(\.version), [2, 1])
        XCTAssertEqual(versions.last?.takeaway, first.takeaway)

        let exporter = try LocalJournalExportService(rootURL: directory.appendingPathComponent("exports", isDirectory: true))
        let redacted = try await exporter.export(.init(
            report: first,
            entries: [entry],
            format: .json,
            includesSensitiveFields: false
        ))
        let redactedText = try String(contentsOf: redacted.fileURL, encoding: .utf8)
        XCTAssertTrue(redacted.redactedSensitiveFields)
        XCTAssertTrue(redactedText.contains(entry.text))
        XCTAssertFalse(redactedText.contains("private/audio.m4a"))
        XCTAssertFalse(redactedText.contains("sensitive spoken detail"))
        XCTAssertFalse(redactedText.contains("\"mood\""))
        XCTAssertFalse(redactedText.contains("\"energy\""))

        let sensitive = try await exporter.export(.init(
            report: first,
            entries: [entry],
            format: .markdown,
            includesSensitiveFields: true
        ))
        let sensitiveText = try String(contentsOf: sensitive.fileURL, encoding: .utf8)
        XCTAssertFalse(sensitive.redactedSensitiveFields)
        XCTAssertTrue(sensitiveText.contains("Mood: calm"))
        XCTAssertTrue(sensitiveText.contains("sensitive spoken detail"))
        XCTAssertFalse(sensitiveText.contains("private/audio.m4a"))

        try await relaunched.delete(id: first.id)
        let remaining = try await relaunched.reports(weekContaining: date)
        XCTAssertEqual(remaining.map(\.id), [second.id])
    }

    @MainActor
    func testJournalMediaReconciliationAndPhotoEditingPreserveStableIdentity() throws {
        let dayID = UUID()
        let keptMedia = LifeBoardJournalMediaValue(
            dayID: dayID,
            kind: .photo,
            payload: Data("kept".utf8),
            syncPolicy: .privateCloud
        )
        let orphanMedia = LifeBoardJournalMediaValue(
            dayID: dayID,
            kind: .audio,
            relativePath: "orphan.m4a",
            syncPolicy: .protectedLocalOnly
        )
        let keptBlock = LifeBoardJournalBlockValue(dayID: dayID, kind: .photo, mediaID: keptMedia.id, ordinal: 4)
        let missingBlock = LifeBoardJournalBlockValue(dayID: dayID, kind: .audio, mediaID: UUID(), ordinal: 9)
        let value = LifeBoardJournalDayValue(
            id: dayID,
            day: Date(),
            blocks: [keptBlock, missingBlock],
            media: [keptMedia, orphanMedia]
        )
        let reconciliation = JournalMediaReconciler.reconcile(value)
        XCTAssertEqual(reconciliation.day.id, dayID)
        XCTAssertEqual(reconciliation.day.blocks.map(\.id), [keptBlock.id])
        XCTAssertEqual(reconciliation.day.blocks.map(\.ordinal), [0])
        XCTAssertEqual(reconciliation.day.media.map(\.id), [keptMedia.id])
        XCTAssertEqual(reconciliation.removedMedia.map(\.id), [orphanMedia.id])

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80), format: format).image { context in
            UIColor.systemOrange.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
        }
        let sourceData = try XCTUnwrap(source.pngData())
        let squareData = try XCTUnwrap(JournalPhotoProcessor.edit(
            payload: sourceData,
            clockwiseQuarterTurns: 0,
            cropMode: .square
        ))
        let square = try XCTUnwrap(UIImage(data: squareData))
        XCTAssertEqual(square.size.width, square.size.height, accuracy: 1)

        let rotatedData = try XCTUnwrap(JournalPhotoProcessor.edit(
            payload: sourceData,
            clockwiseQuarterTurns: 1,
            cropMode: .original
        ))
        let rotated = try XCTUnwrap(UIImage(data: rotatedData))
        XCTAssertEqual(rotated.size.width, 80, accuracy: 1)
        XCTAssertEqual(rotated.size.height, 120, accuracy: 1)
    }

    func testEncryptedJournalBackupRejectsTamperingAndImportsAtomically() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let audioRoot = root.appendingPathComponent("audio", isDirectory: true)
        let backupRoot = root.appendingPathComponent("backups", isDirectory: true)
        let reflectionRoot = root.appendingPathComponent("reflections", isDirectory: true)
        try FileManager.default.createDirectory(at: audioRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let dayID = UUID()
        let audioID = UUID()
        let audioName = "source.m4a"
        let audioData = Data("protected audio fixture".utf8)
        try audioData.write(to: audioRoot.appendingPathComponent(audioName), options: .atomic)
        let media = LifeBoardJournalMediaValue(
            id: audioID,
            dayID: dayID,
            kind: .audio,
            relativePath: audioName,
            duration: 4,
            syncPolicy: .protectedLocalOnly
        )
        let day = LifeBoardJournalDayValue(
            id: dayID,
            day: Date(),
            blocks: [.init(dayID: dayID, kind: .audio, mediaID: audioID)],
            media: [media]
        )
        let report = WeeklyReflectionEngine.makeReport(entries: [JournalEntrySnapshot(day: day)])
        let service = try LocalJournalBackupService(
            rootURL: backupRoot,
            audioRootURL: audioRoot,
            kdfIterations: 100
        )
        let backup = try await service.createBackup(
            days: [day],
            reflections: [report],
            passphrase: "correct horse"
        )
        XCTAssertEqual(backup.dayCount, 1)
        XCTAssertEqual(backup.audioCount, 1)

        let modelBundleURL = try taskModelBundleURL()
        let modelURL = modelBundleURL.appendingPathComponent("TaskModelV3_KnowledgeNotes.mom")
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
        let container = NSPersistentContainer(name: "JournalBackupImport", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            container.loadPersistentStores { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
        let repository = CoreDataLifeBoardPhaseIIRepository(container: container)
        let reflections = try LocalWeeklyReflectionHistoryRepository(rootURL: reflectionRoot)
        let receipt = try await service.restoreBackup(
            from: backup.fileURL,
            passphrase: "correct horse",
            duplicatePolicy: .keepExisting,
            applyingTo: repository,
            reflectionRepository: reflections
        )
        XCTAssertEqual(receipt.insertedDayIDs, [dayID])
        let restoredDays = try await repository.fetchJournalDays(search: nil, starredOnly: false, mood: nil)
        let restored = try XCTUnwrap(restoredDays.first)
        XCTAssertEqual(restored.id, dayID)
        let restoredPath = try XCTUnwrap(restored.media.first?.relativePath)
        XCTAssertNotEqual(restoredPath, audioName)
        XCTAssertEqual(try Data(contentsOf: audioRoot.appendingPathComponent(restoredPath)), audioData)
        let reflectionIDs = try await reflections.reports(weekContaining: nil).map(\.id)
        XCTAssertEqual(reflectionIDs, [report.id])

        let duplicate = try await service.restoreBackup(
            from: backup.fileURL,
            passphrase: "correct horse",
            duplicatePolicy: .keepExisting,
            applyingTo: repository,
            reflectionRepository: reflections
        )
        XCTAssertEqual(duplicate.skippedDayIDs, [dayID])
        let duplicateDays = try await repository.fetchJournalDays(search: nil, starredOnly: false, mood: nil)
        XCTAssertEqual(duplicateDays.count, 1)

        do {
            _ = try await service.restoreBackup(
                from: backup.fileURL,
                passphrase: "wrong password",
                duplicatePolicy: .replaceExisting,
                applyingTo: repository,
                reflectionRepository: reflections
            )
            XCTFail("An incorrect passphrase must not decrypt a Journal backup")
        } catch let error as JournalBackupFailure {
            XCTAssertEqual(error, .authenticationFailed)
        }

        var envelopeText = try String(contentsOf: backup.fileURL, encoding: .utf8)
        let marker = "\"sealedPayload\" : \""
        let payloadStart = try XCTUnwrap(envelopeText.range(of: marker)?.upperBound)
        let replacementEnd = envelopeText.index(after: payloadStart)
        envelopeText.replaceSubrange(payloadStart..<replacementEnd, with: envelopeText[payloadStart] == "A" ? "B" : "A")
        let tamperedURL = root.appendingPathComponent("tampered.lifeboardjournal")
        try Data(envelopeText.utf8).write(to: tamperedURL, options: .atomic)
        do {
            _ = try await service.restoreBackup(
                from: tamperedURL,
                passphrase: "correct horse",
                duplicatePolicy: .replaceExisting,
                applyingTo: repository,
                reflectionRepository: reflections
            )
            XCTFail("Authenticated encryption must reject a modified backup")
        } catch let error as JournalBackupFailure {
            XCTAssertTrue([.authenticationFailed, .malformedArchive].contains(error))
        }
    }

    func testUnresolvedMedicationDoesNotContributeToAdherence() {
        XCTAssertFalse(LifeBoardMedicationEventStatus.unresolved.contributesToAdherence)
        XCTAssertFalse(LifeBoardMedicationEventStatus.scheduled.contributesToAdherence)
        XCTAssertTrue(LifeBoardMedicationEventStatus.taken.contributesToAdherence)
        XCTAssertTrue(LifeBoardMedicationEventStatus.skipped.contributesToAdherence)
    }

    func testKnowledgeBlockPayloadMigratesLegacyValuesAndRoundTripsTypedMetadata() throws {
        let noteID = UUID()
        let linkedNoteID = UUID()
        let legacyTable = LifeBoardKnowledgeBlockValue(
            noteID: noteID,
            kind: .table,
            text: "Name,Status\nJournal,Ready"
        )
        let tablePayload = KnowledgeBlockPayload.decode(from: legacyTable)
        XCTAssertEqual(tablePayload.table?.rows, [["Name", "Status"], ["Journal", "Ready"]])

        var encodedTable = legacyTable
        encodedTable.metadata = tablePayload.encoded()
        XCTAssertEqual(KnowledgeBlockPayload.decode(from: encodedTable), tablePayload)

        let legacyNoteLink = LifeBoardKnowledgeBlockValue(
            noteID: noteID,
            kind: .noteLink,
            text: linkedNoteID.uuidString
        )
        XCTAssertEqual(KnowledgeBlockPayload.decode(from: legacyNoteLink).noteLink?.noteID, linkedNoteID)

        let bookmarkURL = try XCTUnwrap(URL(string: "https://example.com/reference"))
        let bookmarkPayload = KnowledgeBlockPayload(bookmark: .init(
            url: bookmarkURL,
            title: "Reference",
            summary: "A durable preview"
        ))
        let encoded = try XCTUnwrap(bookmarkPayload.encoded())
        let bookmarkBlock = LifeBoardKnowledgeBlockValue(
            noteID: noteID,
            kind: .bookmark,
            text: bookmarkURL.absoluteString,
            metadata: encoded
        )
        XCTAssertEqual(KnowledgeBlockPayload.decode(from: bookmarkBlock), bookmarkPayload)

        let attachmentID = UUID()
        let attachmentPayload = KnowledgeBlockPayload(attachment: .init(
            attachmentID: attachmentID,
            fileName: "reference.pdf"
        ))
        let attachmentBlock = LifeBoardKnowledgeBlockValue(
            noteID: noteID,
            kind: .file,
            text: "reference.pdf",
            metadata: attachmentPayload.encoded()
        )
        XCTAssertEqual(KnowledgeBlockPayload.decode(from: attachmentBlock).attachment?.attachmentID, attachmentID)
    }

    func testKnowledgeFolderHierarchyBuildsBreadcrumbsAndPreventsCycles() {
        let spaceID = UUID()
        let root = LifeBoardKnowledgeFolderValue(spaceID: spaceID, title: "Projects")
        let child = LifeBoardKnowledgeFolderValue(spaceID: spaceID, parentFolderID: root.id, title: "LifeBoard")
        let grandchild = LifeBoardKnowledgeFolderValue(spaceID: spaceID, parentFolderID: child.id, title: "Research")
        let folders = [grandchild, root, child]

        XCTAssertEqual(KnowledgeFolderHierarchy.path(to: grandchild.id, in: folders).map(\.id), [root.id, child.id, grandchild.id])
        XCTAssertTrue(KnowledgeFolderHierarchy.canMove(folderID: grandchild.id, to: root.id, in: folders))
        XCTAssertFalse(KnowledgeFolderHierarchy.canMove(folderID: root.id, to: root.id, in: folders))
        XCTAssertFalse(KnowledgeFolderHierarchy.canMove(folderID: root.id, to: grandchild.id, in: folders))
        XCTAssertTrue(KnowledgeFolderHierarchy.canMove(folderID: root.id, to: nil, in: folders))

        let cyclicRoot = LifeBoardKnowledgeFolderValue(
            id: root.id,
            spaceID: spaceID,
            parentFolderID: grandchild.id,
            title: root.title
        )
        XCTAssertLessThanOrEqual(
            KnowledgeFolderHierarchy.path(to: grandchild.id, in: [cyclicRoot, child, grandchild]).count,
            3
        )
    }

    func testProtectedKnowledgeAttachmentFilesRecoverMissingCopiesAndDeleteCleanly() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("KnowledgeAttachmentTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = ProtectedKnowledgeAttachmentFiles(rootURL: root)
        let attachment = LifeBoardKnowledgeAttachmentValue(
            noteID: UUID(),
            kind: "txt",
            fileName: "Private Reflection.txt",
            payload: Data("kept locally".utf8)
        )

        let firstURL = try await files.persist(attachment)
        XCTAssertEqual(try Data(contentsOf: firstURL), attachment.payload)
        try FileManager.default.removeItem(at: firstURL)

        let recoveredURL = try await files.resolvedURL(for: attachment)
        XCTAssertEqual(recoveredURL, firstURL)
        XCTAssertEqual(try Data(contentsOf: recoveredURL), attachment.payload)

        try await files.deleteFile(for: attachment)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recoveredURL.path))
    }

    func testBookmarkMetadataParserPrefersOpenGraphAndDecodesReadableText() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/article"))
        let html = """
        <html><head>
        <title>Fallback title</title>
        <meta content="A private &amp; useful summary" name="description">
        <meta property="og:title" content="LifeBoard &amp; Notes">
        </head></html>
        """
        let bookmark = URLSessionKnowledgeBookmarkMetadataFetcher.parseHTML(Data(html.utf8), url: url)
        XCTAssertEqual(bookmark.url, url)
        XCTAssertEqual(bookmark.title, "LifeBoard & Notes")
        XCTAssertEqual(bookmark.summary, "A private & useful summary")
    }

    func testTrackerReminderPolicyUsesStableWeekdayRequestsAndCancelsArchivedTrackers() {
        let trackerID = UUID()
        let tracker = LifeBoardTrackerDefinitionValue(
            id: trackerID,
            title: "Blood pressure",
            kind: .quantity,
            schedule: [2, 4, 6],
            reminderMinutes: 8 * 60 + 15
        )
        let requests = TrackerReminderPolicy.requests(for: tracker)
        XCTAssertEqual(requests.map(\.weekday), [2, 4, 6])
        XCTAssertEqual(requests.map(\.hour), [8, 8, 8])
        XCTAssertEqual(requests.map(\.minute), [15, 15, 15])
        XCTAssertEqual(requests.first?.identifier, "lifeboard.tracker.\(trackerID.uuidString).2")

        var archived = tracker
        archived.isArchived = true
        XCTAssertTrue(TrackerReminderPolicy.requests(for: archived).isEmpty)
        XCTAssertEqual(TrackerReminderPolicy.identifiers(for: trackerID).count, 7)
    }

    func testMedicationReminderPolicyHonorsScheduleAndArchiveState() {
        let medication = LifeBoardMedicationDefinitionValue(name: "Vitamin D", dosageText: "1 tablet")
        let schedule = LifeBoardMedicationScheduleValue(
            medicationID: medication.id,
            windowStartMinutes: 18 * 60 + 30,
            windowEndMinutes: 19 * 60,
            weekdays: [1, 7],
            reminderEnabled: true
        )
        let requests = MedicationReminderPolicy.requests(medication: medication, schedule: schedule)
        XCTAssertEqual(requests.map(\.weekday), [1, 7])
        XCTAssertEqual(requests.map(\.hour), [18, 18])
        XCTAssertEqual(requests.map(\.minute), [30, 30])
        XCTAssertEqual(MedicationReminderPolicy.identifiers(for: schedule.id).count, 7)

        var archived = medication
        archived.isArchived = true
        XCTAssertTrue(MedicationReminderPolicy.requests(medication: archived, schedule: schedule).isEmpty)
        var disabled = schedule
        disabled.reminderEnabled = false
        XCTAssertTrue(MedicationReminderPolicy.requests(medication: medication, schedule: disabled).isEmpty)
    }

    func testPhaseIIRepositoryRoundTripsTrackerJournalAndKnowledgeValues() async throws {
        let modelBundleURL = try taskModelBundleURL()
        let modelURL = modelBundleURL.appendingPathComponent("TaskModelV3_KnowledgeNotes.mom")
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
        let container = NSPersistentContainer(name: "PhaseIIRoundTrip", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            container.loadPersistentStores { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }

        let repository = CoreDataLifeBoardPhaseIIRepository(container: container)

        let tracker = LifeBoardTrackerDefinitionValue(title: "Water", kind: .quantity, unitLabel: "ml")
        try await repository.saveTracker(tracker)
        let trackerEntry = LifeBoardTrackerEntryValue(trackerID: tracker.id, numericValue: 450)
        try await repository.saveTrackerEntry(trackerEntry)
        let fetchedTrackers = try await repository.fetchTrackers()
        let fetchedEntries = try await repository.fetchTrackerEntries(trackerID: tracker.id)
        XCTAssertEqual(fetchedTrackers.map(\.id), [tracker.id])
        XCTAssertEqual(fetchedEntries.first?.numericValue, 450)
        var correctedTrackerEntry = trackerEntry
        correctedTrackerEntry.numericValue = 500
        correctedTrackerEntry.note = "Corrected from the bottle"
        try await repository.saveTrackerEntry(correctedTrackerEntry)
        let correctedTrackerEntries = try await repository.fetchTrackerEntries(trackerID: tracker.id)
        XCTAssertEqual(correctedTrackerEntries.count, 1)
        XCTAssertEqual(correctedTrackerEntries.first?.numericValue, 500)
        XCTAssertEqual(correctedTrackerEntries.first?.note, "Corrected from the bottle")

        var archivedTracker = tracker
        archivedTracker.isArchived = true
        try await repository.saveTracker(archivedTracker)
        let archivedTrackers = try await repository.fetchTrackers()
        XCTAssertTrue(archivedTrackers.isEmpty)
        try await repository.deleteTracker(id: tracker.id)
        let deletedTrackerEntries = try await repository.fetchTrackerEntries(trackerID: tracker.id)
        XCTAssertTrue(deletedTrackerEntries.isEmpty)

        let medication = LifeBoardMedicationDefinitionValue(name: "Vitamin D")
        let medicationSchedule = LifeBoardMedicationScheduleValue(
            medicationID: medication.id,
            windowStartMinutes: 480,
            windowEndMinutes: 540
        )
        try await repository.saveMedication(medication)
        try await repository.saveMedicationSchedule(medicationSchedule)
        var medicationEvent = LifeBoardMedicationEventValue(
            medicationID: medication.id,
            scheduledAt: journalDateForRepositoryTest()
        )
        try await repository.saveMedicationEvent(medicationEvent)
        medicationEvent.status = .taken
        medicationEvent.resolvedAt = medicationEvent.scheduledAt.addingTimeInterval(300)
        medicationEvent.note = "Corrected after review"
        try await repository.saveMedicationEvent(medicationEvent)
        let medicationEvents = try await repository.fetchMedicationEvents(
            from: medicationEvent.scheduledAt.addingTimeInterval(-1),
            to: medicationEvent.scheduledAt.addingTimeInterval(600)
        )
        XCTAssertEqual(medicationEvents.count, 1)
        XCTAssertEqual(medicationEvents.first?.status, .taken)
        XCTAssertEqual(medicationEvents.first?.note, "Corrected after review")
        try await repository.deleteMedication(id: medication.id)
        let deletedMedications = try await repository.fetchMedications()
        let deletedMedicationSchedules = try await repository.fetchMedicationSchedules(medicationID: medication.id)
        let deletedMedicationEvents = try await repository.fetchMedicationEvents(
            from: medicationEvent.scheduledAt.addingTimeInterval(-1),
            to: medicationEvent.scheduledAt.addingTimeInterval(600)
        )
        XCTAssertTrue(deletedMedications.isEmpty)
        XCTAssertTrue(deletedMedicationSchedules.isEmpty)
        XCTAssertTrue(deletedMedicationEvents.isEmpty)

        var moodCheckIn = LifeBoardMoodEnergyCheckInValue(mood: .calm, energy: 3)
        try await repository.saveMoodCheckIn(moodCheckIn)
        moodCheckIn.mood = .grateful
        moodCheckIn.energy = 4
        try await repository.saveMoodCheckIn(moodCheckIn)
        let correctedMoodCheckIns = try await repository.fetchMoodCheckIns(from: nil, to: nil)
        XCTAssertEqual(correctedMoodCheckIns.count, 1)
        XCTAssertEqual(correctedMoodCheckIns.first?.mood, .grateful)
        XCTAssertEqual(correctedMoodCheckIns.first?.energy, 4)
        try await repository.deleteMoodCheckIn(id: moodCheckIn.id)
        let deletedMoodCheckIns = try await repository.fetchMoodCheckIns(from: nil, to: nil)
        XCTAssertTrue(deletedMoodCheckIns.isEmpty)

        let dayID = UUID()
        let journal = LifeBoardJournalDayValue(
            id: dayID,
            day: Calendar.current.startOfDay(for: Date()),
            blocks: [
                .init(dayID: dayID, kind: .text, text: "A private reflection", ordinal: 0),
                .init(dayID: dayID, kind: .mood, mood: .calm, energy: 4, ordinal: 1)
            ]
        )
        try await repository.saveJournalDay(journal)
        let optionalJournal = try await repository.fetchJournalDay(containing: journal.day)
        let fetchedJournal = try XCTUnwrap(optionalJournal)
        XCTAssertEqual(fetchedJournal.displayText, "A private reflection")
        XCTAssertEqual(fetchedJournal.latestMood, .calm)

        let draft = LifeBoardJournalDraftValue(
            dayID: dayID,
            day: journal.day,
            text: "Recovered after interruption",
            mood: .calm,
            energy: 4,
            photoPayloads: [Data([1, 2, 3])],
            audioRelativePaths: ["JournalAudio/recording.m4a"],
            promptID: "continue",
            editPosition: 12
        )
        try await repository.saveJournalDraft(draft)
        let recoveredDraft = try await repository.fetchJournalDraft(dayID: dayID)
        XCTAssertEqual(recoveredDraft, draft)
        try await repository.deleteJournalDraft(id: draft.id)
        let deletedDraft = try await repository.fetchJournalDraft(dayID: dayID)
        XCTAssertNil(deletedDraft)

        let space = LifeBoardKnowledgeSpaceValue(title: "Personal")
        try await repository.saveKnowledgeSpace(space)
        let noteID = UUID()
        let note = LifeBoardKnowledgeNoteValue(
            id: noteID,
            spaceID: space.id,
            title: "Useful idea",
            blocks: [.init(noteID: noteID, kind: .paragraph, text: "Keep this", ordinal: 0)]
        )
        try await repository.saveKnowledgeNote(note)
        let fetchedNotes = try await repository.fetchKnowledgeNotes(search: nil, spaceID: space.id)
        XCTAssertEqual(fetchedNotes.first?.id, note.id)
        XCTAssertEqual(fetchedNotes.first?.plainText, "Keep this")
    }

    func testMoodTrendRequiresEvidenceAndGroupsDailyCheckIns() throws {
        XCTAssertEqual(MoodTrendProjector.project([]), .empty)
        XCTAssertEqual(
            MoodTrendProjector.project([.init(mood: .calm, energy: 3)]),
            .light(sampleCount: 1)
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 9)))
        let secondDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: firstDay))
        let state = MoodTrendProjector.project([
            .init(mood: .sad, energy: 2, createdAt: firstDay),
            .init(mood: .calm, energy: nil, createdAt: firstDay.addingTimeInterval(3600)),
            .init(mood: .happy, energy: 5, createdAt: secondDay)
        ], calendar: calendar)
        guard case let .ready(summary) = state else { return XCTFail("Expected an evidence-backed trend") }
        XCTAssertEqual(summary.sampleCount, 3)
        XCTAssertEqual(summary.dailyPoints.count, 2)
        XCTAssertEqual(try XCTUnwrap(summary.averageEnergy), 3.5, accuracy: 0.0001)
        XCTAssertEqual(summary.dailyPoints.first?.sampleCount, 2)
    }

    func testJournalMediaProcessingStatesRemainCodableAndExplicit() throws {
        for state in JournalMediaAttachment.ProcessingState.allCases {
            let encoded = try JSONEncoder().encode(state)
            XCTAssertEqual(try JSONDecoder().decode(JournalMediaAttachment.ProcessingState.self, from: encoded), state)
        }

        let dayID = UUID()
        let mediaID = UUID()
        let media = LifeBoardJournalMediaValue(
            id: mediaID,
            dayID: dayID,
            kind: .audio,
            relativePath: "saved-first.m4a",
            duration: 42,
            syncPolicy: .protectedLocalOnly
        )
        let queued = JournalEntrySnapshot(day: .init(
            id: dayID,
            day: Date(),
            blocks: [.init(dayID: dayID, kind: .audio, mediaID: mediaID)],
            media: [media]
        ))
        XCTAssertEqual(queued.attachments.first?.processingState, .ready)
        XCTAssertNil(queued.attachments.first?.transcription)

        let completed = JournalEntrySnapshot(day: .init(
            id: dayID,
            day: Date(),
            blocks: [.init(dayID: dayID, kind: .audio, text: "Recovered words", mediaID: mediaID)],
            media: [media]
        ))
        XCTAssertEqual(completed.attachments.first?.processingState, .transcriptionComplete)
        XCTAssertEqual(completed.attachments.first?.transcription, "Recovered words")
    }

    func testJournalMediaMapsIntoSharedAttachmentLifecycle() {
        let dayID = UUID()
        let local = LifeBoardJournalMediaValue(
            dayID: dayID,
            kind: .audio,
            relativePath: "voice.m4a",
            duration: 12,
            syncPolicy: .protectedLocalOnly
        ).journalAttachmentSnapshot
        XCTAssertEqual(local.kind, .audio)
        XCTAssertEqual(local.availability, .locallyAvailable)
        XCTAssertEqual(local.fileName, "voice.m4a")
        XCTAssertEqual(local.duration, 12)

        let missing = LifeBoardJournalMediaValue(
            dayID: dayID,
            kind: .photo,
            syncPolicy: .privateCloud
        ).journalAttachmentSnapshot
        XCTAssertEqual(missing.kind, .image)
        XCTAssertEqual(missing.availability, .unavailable)
        XCTAssertTrue(missing.fileName.hasSuffix(".jpg"))
    }

    func testAdaptiveHomePackingAssignsStableNonOverlappingPositions() throws {
        let placements = [
            DashboardWidgetPlacementValue(widgetKind: DashboardWidgetKind.tasks.rawValue, semanticSize: .compact, ordinal: 0),
            DashboardWidgetPlacementValue(widgetKind: DashboardWidgetKind.routines.rawValue, semanticSize: .compact, ordinal: 1),
            DashboardWidgetPlacementValue(widgetKind: DashboardWidgetKind.journal.rawValue, semanticSize: .wide, ordinal: 2),
            DashboardWidgetPlacementValue(widgetKind: DashboardWidgetKind.care.rawValue, semanticSize: .expanded, ordinal: 3)
        ]

        let packed = HomeGridPackingEngine.normalized(placements)

        XCTAssertEqual(packed.map(\.ordinal), [0, 1, 2, 3])
        XCTAssertEqual(try XCTUnwrap(packed[0].gridPosition), HomeGridPosition(column: 0, row: 0))
        XCTAssertEqual(try XCTUnwrap(packed[1].gridPosition), HomeGridPosition(column: 2, row: 0))
        XCTAssertEqual(try XCTUnwrap(packed[2].gridPosition), HomeGridPosition(column: 0, row: 1))
        XCTAssertEqual(try XCTUnwrap(packed[3].gridPosition), HomeGridPosition(column: 0, row: 3))
        XCTAssertEqual(HomeGridPackingEngine.normalized(packed), packed)
    }

    func testAdaptiveHomePackingRemainsCollisionFreeAtFourEightAndTwelveColumns() throws {
        let sizes: [WidgetSizePreset] = [.compact, .standard, .wide, .tall, .expanded, .compact, .wide]
        let placements = sizes.enumerated().map { index, size in
            DashboardWidgetPlacementValue(
                widgetKind: "fixture-\(index)",
                semanticSize: size,
                ordinal: index
            )
        }

        for columns in [4, 8, 12] {
            let packed = HomeGridPackingEngine.normalized(placements, columns: columns)
            var occupied = Set<HomeGridPosition>()
            for placement in packed {
                let origin = try XCTUnwrap(placement.gridPosition)
                let span = placement.semanticSize.canonicalGridSpan
                let width = min(columns, span.columns)
                XCTAssertGreaterThanOrEqual(origin.column, 0)
                XCTAssertLessThanOrEqual(origin.column + width, columns)
                for row in origin.row..<(origin.row + span.rows) {
                    for column in origin.column..<(origin.column + width) {
                        XCTAssertTrue(
                            occupied.insert(.init(column: column, row: row)).inserted,
                            "\(columns)-column layout overlaps at \(column),\(row)"
                        )
                    }
                }
            }
            XCTAssertEqual(HomeGridPackingEngine.normalized(packed, columns: columns), packed)
        }
    }

    func testHomeConfigurationWrapsLegacyDomainPayloadWithoutLosingIt() {
        let payload = Data([7, 8, 9])
        var placement = DashboardWidgetPlacementValue(
            widgetKind: DashboardWidgetKind.tasks.rawValue,
            semanticSize: .standard,
            ordinal: 0,
            configuration: .init(version: 1, payload: payload)
        )

        placement.updateHomeConfiguration { configuration in
            configuration.source = .init(destination: .plan, sourceID: "today")
            configuration.placement.ownership = .smart
            configuration.placement.smartSlot = .init(
                allowedDestinations: [.plan],
                schedule: .workday
            )
        }

        XCTAssertEqual(placement.homeConfiguration.domainPayload, payload)
        XCTAssertEqual(placement.homeConfiguration.source?.destination, .plan)
        XCTAssertEqual(placement.ownership, .smart)
        XCTAssertEqual(placement.smartSlot?.schedule, .workday)
    }

    func testContextPolicyIsPrivateStableAndLimitedToTwoCards() {
        let now = Date(timeIntervalSince1970: 20_000)
        let active = HomeContextCandidate(
            id: "active", widgetKind: .focusNow, title: "Focus",
            reason: .init(message: "Started by you", signal: "active focus"),
            destination: .plan, priority: 400, relevantFrom: now,
            isUserStartedActiveState: true
        )
        let medication = HomeContextCandidate(
            id: "medication", widgetKind: .care, title: "Medication",
            reason: .init(message: "Needs a decision", signal: "care"),
            destination: .track, sensitivity: .privateSensitive,
            priority: 700, relevantFrom: now
        )
        let next = HomeContextCandidate(
            id: "next", widgetKind: .compactTimeline, title: "Next",
            reason: .init(message: "Starts soon", signal: "calendar"),
            destination: .plan, priority: 300, relevantFrom: now
        )
        let lower = HomeContextCandidate(
            id: "lower", widgetKind: .tasks, title: "Tasks",
            reason: .init(message: "Review", signal: "tasks"),
            destination: .plan, priority: 200, relevantFrom: now
        )
        let policy = DeterministicHomeContextPolicy()

        let privateSelection = policy.select(
            candidates: [medication, lower, next, active],
            dispositions: [:],
            permitsSensitiveHomeContent: false,
            now: now
        )
        XCTAssertEqual(privateSelection.candidates.map(\.id), ["active", "next"])

        let permittedSelection = policy.select(
            candidates: [medication, lower, next, active],
            dispositions: ["medication": .suggestLess],
            permitsSensitiveHomeContent: true,
            now: now
        )
        XCTAssertEqual(permittedSelection.candidates.map(\.id), ["active", "next"])
    }

    func testSmartSlotOwnershipRemainsTransactional() throws {
        let original = DashboardLayoutValue(
            mode: .smart,
            placements: CoreDataDashboardLayoutRepository.curatedHomePlacements()
        )
        var draft = HomeLayoutDraft(layout: original)
        let placement = try XCTUnwrap(draft.current.placements.first)

        draft.setOwnership(
            .smart,
            smartSlot: .init(allowedDestinations: [.plan, .track], schedule: .morning),
            id: placement.id
        )

        XCTAssertEqual(draft.current.placements.first?.ownership, .smart)
        XCTAssertEqual(draft.current.placements.first?.smartSlot?.schedule, .morning)
        draft.cancel()
        XCTAssertEqual(draft.current, original)
    }

    func testLifeThreadContractsRoundTripWithoutDomainDuplication() throws {
        let item = LifeThreadItem(
            artifact: .init(
                kind: .actionReceipt,
                title: "Plan updated",
                body: "Moved reading to 4:00 PM.",
                sourceReference: "task:123",
                destination: .plan
            )
        )
        let data = try JSONEncoder().encode(item)
        XCTAssertEqual(try JSONDecoder().decode(LifeThreadItem.self, from: data), item)
    }

    @MainActor
    func testHomeContextEngineFreezesAndHonorsMinimumDisplayTime() async {
        let now = Date(timeIntervalSince1970: 30_000)
        let focus = HomeContextCandidate(
            id: "focus", widgetKind: .focusNow, title: "Focus",
            reason: .init(message: "Active", signal: "focus"),
            destination: .plan, priority: 500, relevantFrom: now,
            isUserStartedActiveState: true
        )
        let fast = HomeContextCandidate(
            id: "fast", widgetKind: .fasting, title: "Fast",
            reason: .init(message: "Active", signal: "fast"),
            destination: .track, priority: 600, relevantFrom: now,
            isUserStartedActiveState: true
        )
        let engine = HomeContextEngine(minimumDisplayDuration: 60)

        let initial = engine.reevaluate(
            candidates: [focus], dispositions: [:],
            permitsSensitiveHomeContent: true, now: now, force: true
        )
        XCTAssertEqual(initial.candidates.map(\.id), ["focus"])

        engine.setFrozen(true, reason: "scroll")
        let frozen = engine.reevaluate(
            candidates: [fast], dispositions: [:],
            permitsSensitiveHomeContent: true, now: now.addingTimeInterval(120)
        )
        XCTAssertEqual(frozen.candidates.map(\.id), ["focus"])

        engine.setFrozen(false, reason: "scroll")
        let updated = engine.reevaluate(
            candidates: [fast], dispositions: [:],
            permitsSensitiveHomeContent: true, now: now.addingTimeInterval(120)
        )
        XCTAssertEqual(updated.candidates.map(\.id), ["fast"])
    }

    @MainActor
    func testHomeContextFeedbackPersistsSuppressionConsentAndCooldown() async throws {
        let suite = "LifeOSFoundationTests.HomeContextFeedback.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 9)))
        let store = HomeContextFeedbackStore(defaults: defaults)

        store.hideToday(candidateID: "water", now: now, calendar: calendar)
        XCTAssertEqual(store.record(for: "water", now: now).disposition, .hiddenToday)
        XCTAssertEqual(
            store.record(for: "water", now: now.addingTimeInterval(86_400)).disposition,
            .available
        )
        store.setSensitiveContentPermission(true, for: .journal)
        XCTAssertTrue(store.permitsSensitiveContent(for: .journal))

        store.markShown(candidateID: "water", at: now)
        let candidate = HomeContextCandidate(
            id: "water",
            widgetKind: .lifeSnapshot,
            title: "Water",
            reason: .init(message: "You often log water now.", signal: "tracker-timing"),
            destination: .track,
            priority: 100,
            relevantFrom: now
        )
        let engine = HomeContextEngine(minimumDisplayDuration: 0, repetitionCooldown: 1_800)
        let cooledDown = engine.reevaluate(
            candidates: [candidate],
            dispositions: store.dispositions(now: now),
            permitsSensitiveHomeContent: false,
            feedback: ["water": store.record(for: "water", now: now)],
            now: now,
            force: true
        )
        XCTAssertTrue(cooledDown.candidates.isEmpty)
        let eligibleAgain = engine.reevaluate(
            candidates: [candidate],
            dispositions: store.dispositions(now: now.addingTimeInterval(1_801)),
            permitsSensitiveHomeContent: false,
            feedback: ["water": store.record(for: "water", now: now.addingTimeInterval(1_801))],
            now: now.addingTimeInterval(1_801),
            force: true
        )
        XCTAssertEqual(eligibleAgain.candidates.map(\.id), ["water"])
    }

    func testFastingSessionElapsedUsesAbsoluteDatesAndClampsCorrections() {
        let start = Date(timeIntervalSince1970: 40_000)
        let session = LifeBoardFastingSessionValue(
            startedAt: start,
            endedAt: start.addingTimeInterval(7_200),
            targetDuration: 10_800
        )
        XCTAssertEqual(session.elapsed(at: start.addingTimeInterval(99_999)), 7_200)

        let future = LifeBoardFastingSessionValue(startedAt: start.addingTimeInterval(100))
        XCTAssertEqual(future.elapsed(at: start), 0)
        XCTAssertTrue(DefaultDashboardWidgetRegistry.shared
            .descriptor(for: .fasting)?.supportedSizes.contains(.expanded) == true)
    }

    func testFastingTimerStoreEnforcesOneActiveSessionAndPersistsCompletionMeaning() async throws {
        let start = Date(timeIntervalSince1970: 80_000)
        let repository = FastingSessionRepositoryFixture()
        let store = FastingTimerStore(repository: repository, now: { start })

        let active = try await store.start(
            targetDuration: 12 * 3_600,
            reminderOffsets: [11 * 3_600, -1, 11 * 3_600, 15 * 3_600],
            note: "  Personal target  "
        )
        XCTAssertEqual(active.targetEnd, start.addingTimeInterval(12 * 3_600))
        XCTAssertEqual(active.reminderOffsets, [11 * 3_600])
        XCTAssertEqual(active.note, "Personal target")

        do {
            _ = try await store.start(targetDuration: nil)
            XCTFail("A second active timer must be rejected")
        } catch {
            XCTAssertEqual(error as? FastingTimerStoreError, .alreadyActive)
        }

        let finished = try await store.finish(at: start.addingTimeInterval(10 * 3_600))
        XCTAssertEqual(finished.completionKind, .early)
        XCTAssertEqual(finished.elapsed(), 10 * 3_600)
        let noActiveSession = try await store.activeSession()
        XCTAssertNil(noActiveSession)
    }

    func testFastingTimerStoreRecoversLegacyDuplicateActiveSessionsDeterministically() async throws {
        let now = Date(timeIntervalSince1970: 140_000)
        let older = LifeBoardFastingSessionValue(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            startedAt: now.addingTimeInterval(-7_200)
        )
        let newer = LifeBoardFastingSessionValue(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            startedAt: now.addingTimeInterval(-3_600)
        )
        let repository = FastingSessionRepositoryFixture(seed: [older, newer])
        let store = FastingTimerStore(repository: repository, now: { now })

        let recovered = try await store.sessions()
        XCTAssertEqual(recovered.filter { $0.endedAt == nil }.map(\.id), [newer.id])
        let recoveredOlder = try XCTUnwrap(recovered.first(where: { $0.id == older.id }))
        XCTAssertEqual(recoveredOlder.endedAt, newer.startedAt)
        XCTAssertEqual(recoveredOlder.completionKind, .cancelled)

        let persisted = await repository.all()
        XCTAssertEqual(persisted.filter { $0.endedAt == nil }.map(\.id), [newer.id])
    }

    func testHomeCardProviderRegistryOwnsLookupSizingAndRedaction() async throws {
        let provider = HomeCardProviderFixture(kind: .journal, sensitivity: .privateSensitive)
        let registry = try HomeCardProviderRegistry(providers: [provider])
        let date = Date(timeIntervalSince1970: 50_000)

        let redacted = try await registry.snapshot(
            for: .journal,
            context: .init(
                date: date,
                timeZone: try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata")),
                semanticSize: .wide
            )
        )
        XCTAssertEqual(redacted.availability, .redacted)
        XCTAssertNil(redacted.value)
        XCTAssertTrue(redacted.actions.isEmpty)

        let revealed = try await registry.snapshot(
            for: .journal,
            context: .init(
                date: date,
                semanticSize: .wide,
                permittedSensitivities: Set(DataSensitivity.allCases)
            )
        )
        XCTAssertEqual(revealed.availability, .ready)
        XCTAssertEqual(revealed.value, "Wide")
        XCTAssertEqual(revealed.actions.map(\.id), ["open-source"])

        do {
            _ = try await registry.snapshot(
                for: .journal,
                context: .init(date: date, semanticSize: .expanded)
            )
            XCTFail("Unsupported semantic sizes must not reach a provider")
        } catch {
            XCTAssertEqual(
                error as? HomeCardProviderRegistryError,
                .unsupportedSize(.journal, .expanded)
            )
        }
    }

    func testHomeCardProviderRegistryRejectsDuplicateStableKinds() async throws {
        let registry = try HomeCardProviderRegistry(providers: [HomeCardProviderFixture(kind: .tasks)])
        do {
            try await registry.register(HomeCardProviderFixture(kind: .tasks))
            XCTFail("A stable card kind must have exactly one provider")
        } catch {
            XCTAssertEqual(
                error as? HomeCardProviderRegistryError,
                .duplicateProvider(.tasks)
            )
        }
    }

    func testHomeCardSnapshotDecodesPreActionEnvelope() throws {
        let updatedAt = Date(timeIntervalSince1970: 60_000)
        let legacy = """
        {"availability":"empty","title":"Journal","updatedAt":\(updatedAt.timeIntervalSinceReferenceDate)}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(HomeCardSnapshot.self, from: legacy)
        XCTAssertEqual(decoded.availability, .empty)
        XCTAssertTrue(decoded.actions.isEmpty)
    }

    func testLifeThreadProjectionIsDeterministicAndPermissionBound() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12)))
        let earlierID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let laterID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let sources = [
            LifeThreadProjectionSource(
                projectionID: laterID,
                timestamp: day.addingTimeInterval(60),
                artifactKind: .journalMoment,
                body: "Private reflection",
                sourceReference: "journal:2",
                destination: .track,
                sensitivity: .privateSensitive
            ),
            LifeThreadProjectionSource(
                projectionID: earlierID,
                timestamp: day,
                artifactKind: .planChange,
                body: "Plan changed",
                sourceReference: "task:1",
                destination: .plan
            )
        ]
        let service = LifeThreadProjectionService()

        let publicProjection = service.project(
            sources,
            on: day,
            calendar: calendar,
            permittedSensitivities: [.privateStandard]
        )
        XCTAssertEqual(publicProjection.map(\.id), [earlierID])

        let completeProjection = service.project(sources, on: day, calendar: calendar)
        XCTAssertEqual(completeProjection.map(\.id), [earlierID, laterID])
        XCTAssertEqual(completeProjection, service.project(Array(sources.reversed()), on: day, calendar: calendar))
    }

    func testIntentResolverHasExactlySafeFourOutcomeBoundary() async {
        let resolver = LifeThreadIntentResolver(adapters: [JournalIntentAdapterFixture()])
        let capture = await resolver.resolve(.init(text: "/journal A good day", destination: .home))
        guard case let .captureDraft(draft) = capture else {
            return XCTFail("The domain adapter should return a reviewable capture")
        }
        XCTAssertEqual(draft.kind, .journal)

        let fallback = await resolver.resolve(.init(text: "What matters today?", destination: .plan))
        guard case let .answer(request) = fallback else {
            return XCTFail("Unrecognized input must remain a non-mutating answer request")
        }
        XCTAssertEqual(request.destination, .plan)
    }

    func testMutationCoordinatorAppliesAndUndoesTheSamePreparedCommand() async throws {
        let recorder = MutationRecorderFixture()
        let preview = LifeBoardTransactionPreview(
            destination: .plan,
            summary: "Move one task",
            changes: ["Reading: 3:00 PM → 4:00 PM"],
            origin: .conversation
        )
        let coordinator = LifeBoardMutationCoordinator()
        _ = await coordinator.prepare(
            LifeBoardMutationCommand(
                preview: preview,
                apply: {
                    await recorder.recordApply()
                    return "Reading moved to 4:00 PM."
                },
                undo: { await recorder.recordUndo() }
            )
        )

        let receipt = try await coordinator.apply(previewID: preview.id)
        XCTAssertEqual(receipt.transactionID, preview.id)
        let appliedCounts = await recorder.counts()
        XCTAssertEqual(appliedCounts, [1, 0])
        try await coordinator.undo(receiptID: receipt.id)
        let undoneCounts = await recorder.counts()
        XCTAssertEqual(undoneCounts, [1, 1])
    }

    func testMutationIntentAdapterOnlyExposesAnExecutablePreview() async throws {
        let recorder = MutationRecorderFixture()
        let coordinator = LifeBoardMutationCoordinator()
        let resolver = LifeThreadIntentResolver(
            mutationAdapters: [PlanMutationIntentAdapterFixture(recorder: recorder)],
            mutationCoordinator: coordinator
        )

        let resolution = await resolver.resolve(.init(text: "move reading", destination: .plan))
        guard case let .transactionPreview(preview) = resolution else {
            return XCTFail("A recognized mutation should remain a reviewable preview")
        }
        let isPrepared = await coordinator.isPrepared(previewID: preview.id)
        XCTAssertTrue(isPrepared)
        let receipt = try await coordinator.apply(previewID: preview.id)
        XCTAssertEqual(receipt.transactionID, preview.id)
        let counts = await recorder.counts()
        XCTAssertEqual(counts, [1, 0])
    }

    @MainActor
    func testComposerPreservesDraftAndAttachmentsAcrossRootChanges() {
        let coordinator = LifeThreadComposerCoordinator(destination: .home)
        coordinator.focus()
        coordinator.draftText = "Remember this"
        coordinator.addAttachment(.init(displayName: "Photo", localIdentifier: "asset:1"))
        coordinator.move(to: .insights)

        XCTAssertEqual(coordinator.destination, .insights)
        XCTAssertEqual(coordinator.draftText, "Remember this")
        XCTAssertEqual(coordinator.attachments.count, 1)
        coordinator.dismissDraft()
        XCTAssertFalse(coordinator.hasDraft)
        XCTAssertEqual(coordinator.state, .resting)
    }

    func testPhraseSettlerUsesPunctuationLengthAndTimeWithoutReanimatingOldText() async {
        let start = Date(timeIntervalSince1970: 70_000)
        let settler = PhraseSettler(policy: .init(maximumGraphemes: 8, maximumDelay: 0.14), now: start)
        let first = await settler.append("Hello", at: start)
        XCTAssertTrue(first.isEmpty)
        let punctuated = await settler.append(" world. More", at: start)
        XCTAssertEqual(punctuated, ["Hello world."])
        let pending = await settler.uncommittedText()
        XCTAssertEqual(pending, " More")
        let lengthBound = await settler.append(" text", at: start)
        XCTAssertEqual(lengthBound, [" More te"])
        let flushed = await settler.flush(at: start)
        XCTAssertEqual(flushed, "xt")

        let timed = PhraseSettler(now: start)
        let beforeDeadline = await timed.append("Still working", at: start)
        XCTAssertTrue(beforeDeadline.isEmpty)
        let afterDeadline = await timed.append("", at: start.addingTimeInterval(0.14))
        XCTAssertEqual(afterDeadline, ["Still working"])
    }

    func testCumulativePhraseSettlerPublishesOnlyNewPhrasesAndStopDropsTheTail() {
        let start = Date(timeIntervalSince1970: 75_000)
        var settler = CumulativePhraseSettler(
            policy: .init(maximumGraphemes: 72, maximumDelay: 0.14),
            now: start
        )

        let buffered = settler.ingest(cumulativeText: "A calm start", at: start)
        XCTAssertEqual(buffered.displayText, "")
        XCTAssertEqual(settler.uncommittedText, "A calm start")

        let first = settler.ingest(cumulativeText: "A calm start. Next", at: start)
        XCTAssertEqual(first.displayText, "A calm start.")
        XCTAssertEqual(first.newlySettledText, "A calm start.")

        let second = settler.ingest(
            cumulativeText: "A calm start. Next thought",
            at: start.addingTimeInterval(0.14)
        )
        XCTAssertEqual(second.displayText, "A calm start. Next thought")
        XCTAssertEqual(second.newlySettledText, " Next thought")

        _ = settler.ingest(
            cumulativeText: "A calm start. Next thought unfinished tail",
            at: start.addingTimeInterval(0.15)
        )
        let stopped = settler.stopDiscardingUncommitted(at: start.addingTimeInterval(0.16))
        XCTAssertEqual(stopped, "A calm start. Next thought")
        XCTAssertEqual(settler.uncommittedText, "")
    }

    func testSystemSurfaceSnapshotsRedactAndRecoverFromBackup() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LifeBoardSystemSnapshotTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LifeBoardSystemSnapshotStore(directoryURL: directory)
        let privateSnapshot = LifeBoardSystemSurfaceSnapshot(
            id: UUID(),
            title: "Mood",
            primaryValue: "Overwhelmed",
            secondaryValue: "Private journal context",
            systemImage: "face.smiling",
            sensitivity: .privateSensitive,
            isExplicitlyAuthorized: false,
            deepLinkPath: "lifeboard://track/journal",
            updatedAt: Date(timeIntervalSince1970: 90_000)
        )
        let first = LifeBoardSystemSnapshotEnvelope(
            domain: .journal,
            generatedAt: Date(timeIntervalSince1970: 90_000),
            snapshots: [privateSnapshot]
        )
        try await store.write(first)
        let primaryAfterFirstWrite = directory.appendingPathComponent("lifeboard-journal-snapshot-v1.json")
        let attributes = try FileManager.default.attributesOfItem(atPath: primaryAfterFirstWrite.path)
        if let protection = attributes[.protectionKey] as? FileProtectionType {
            XCTAssertEqual(protection, .complete)
        }
        let redacted = try await store.load(.journal)
        XCTAssertEqual(redacted?.snapshots.first?.title, "LifeBoard")
        XCTAssertEqual(redacted?.snapshots.first?.primaryValue, "Open LifeBoard to view")
        XCTAssertNil(redacted?.snapshots.first?.secondaryValue)

        let second = LifeBoardSystemSnapshotEnvelope(
            domain: .journal,
            generatedAt: Date(timeIntervalSince1970: 90_100),
            snapshots: []
        )
        try await store.write(second)
        let primary = directory.appendingPathComponent("lifeboard-journal-snapshot-v1.json")
        try Data("corrupt".utf8).write(to: primary, options: .atomic)
        let recovered = try await store.load(.journal)
        XCTAssertEqual(recovered?.generatedAt, first.generatedAt)
        XCTAssertEqual(recovered?.snapshots.count, 1)
    }

    func testSystemSurfaceEnvelopeDeduplicatesAndOrdersNewestFirst() throws {
        let duplicateID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let secondID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000102"))
        let older = LifeBoardSystemSurfaceSnapshot(
            id: duplicateID,
            title: "Older",
            primaryValue: "1",
            systemImage: "circle",
            sensitivity: .shareEligible,
            isExplicitlyAuthorized: true,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let newest = LifeBoardSystemSurfaceSnapshot(
            id: duplicateID,
            title: "Newest",
            primaryValue: "2",
            systemImage: "circle.fill",
            sensitivity: .shareEligible,
            isExplicitlyAuthorized: true,
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        let middle = LifeBoardSystemSurfaceSnapshot(
            id: secondID,
            title: "Middle",
            primaryValue: "3",
            systemImage: "circle",
            sensitivity: .shareEligible,
            isExplicitlyAuthorized: true,
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let envelope = LifeBoardSystemSnapshotEnvelope(
            domain: .goals,
            generatedAt: Date(timeIntervalSince1970: 400),
            snapshots: [older, middle, newest]
        )
        XCTAssertEqual(envelope.snapshots.map(\.id), [duplicateID, secondID])
        XCTAssertEqual(envelope.snapshots.map(\.title), ["Newest", "Middle"])
    }

    func testSystemSurfaceReaderAcceptsLegacyAndRejectsFutureSchemaAndWrongDomain() throws {
        func data(for envelope: LifeBoardSystemSnapshotEnvelope) throws -> Data {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            return try encoder.encode(envelope)
        }

        let legacy = LifeBoardSystemSnapshotEnvelope(schemaVersion: 0, domain: .routines, snapshots: [])
        let decodedLegacy = try LifeBoardSystemSnapshotReader.decode(
            data(for: legacy),
            expectedDomain: .routines
        )
        XCTAssertEqual(decodedLegacy.schemaVersion, legacy.schemaVersion)
        XCTAssertEqual(decodedLegacy.domain, legacy.domain)
        XCTAssertEqual(decodedLegacy.snapshots, legacy.snapshots)
        XCTAssertEqual(decodedLegacy.generatedAt.timeIntervalSince1970,
                       legacy.generatedAt.timeIntervalSince1970,
                       accuracy: 0.001)

        let future = LifeBoardSystemSnapshotEnvelope(
            schemaVersion: LifeBoardSystemSnapshotEnvelope.currentSchemaVersion + 1,
            domain: .routines,
            snapshots: []
        )
        XCTAssertThrowsError(
            try LifeBoardSystemSnapshotReader.decode(data(for: future), expectedDomain: .routines)
        ) { error in
            XCTAssertEqual(
                error as? LifeBoardSystemSnapshotStoreError,
                .incompatibleSchema(
                    found: LifeBoardSystemSnapshotEnvelope.currentSchemaVersion + 1,
                    supported: LifeBoardSystemSnapshotEnvelope.currentSchemaVersion
                )
            )
        }

        XCTAssertThrowsError(
            try LifeBoardSystemSnapshotReader.decode(data(for: legacy), expectedDomain: .goals)
        ) { error in
            XCTAssertEqual(error as? LifeBoardSystemSnapshotStoreError, .domainMismatch)
        }
    }

    func testSystemSurfaceStoreIsFullyLocalAndReturnsNilWhileOfflineWithoutFiles() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LifeBoardSystemSnapshotOfflineTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LifeBoardSystemSnapshotStore(directoryURL: directory)

        let loadedEnvelope = try await store.load(.nutrition)
        XCTAssertNil(loadedEnvelope)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testWellnessBodyMetricNormalizesUnitsAndPreservesCaptureTimezone() throws {
        let kolkata = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        var sample = try BodyMetricSample(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000071")!,
            kind: .bodyMass,
            value: 220.46226218,
            unit: .pounds,
            observedAt: Date(timeIntervalSince1970: 100_000),
            capturedTimeZone: kolkata,
            createdAt: Date(timeIntervalSince1970: 99_000),
            updatedAt: Date(timeIntervalSince1970: 100_000)
        )
        XCTAssertEqual(sample.normalizedValue, 100, accuracy: 0.0001)
        XCTAssertEqual(sample.capturedTimeZoneIdentifier, "Asia/Kolkata")
        XCTAssertEqual(try sample.value(in: .pounds), 220.46226218, accuracy: 0.0001)

        try sample.correct(
            value: 98.5,
            unit: .kilograms,
            at: Date(timeIntervalSince1970: 101_000)
        )
        XCTAssertEqual(sample.normalizedValue, 98.5, accuracy: 0.0001)
        XCTAssertEqual(sample.updatedAt, Date(timeIntervalSince1970: 101_000))
        XCTAssertThrowsError(try sample.value(in: .percent)) { error in
            XCTAssertEqual(error as? WellnessRepositoryError, .incompatibleUnit)
        }
    }

    func testWellnessRepositoryCRUDExportAndStableOrdering() async throws {
        let older = try BodyMetricSample(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000072")!,
            kind: .bodyMass,
            value: 80,
            unit: .kilograms,
            observedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = try BodyMetricSample(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000073")!,
            kind: .bodyMass,
            value: 79.5,
            unit: .kilograms,
            observedAt: Date(timeIntervalSince1970: 200)
        )
        let repository = InMemoryWellnessRepository()
        await repository.save(older)
        await repository.save(newer)
        let samples = await repository.bodyMetricSamples(kind: .bodyMass)
        XCTAssertEqual(samples.map(\.id), [newer.id, older.id])

        let export = try await WellnessExportEncoder.encode(
            repository: repository,
            at: Date(timeIntervalSince1970: 500)
        )
        let text = String(decoding: export, as: UTF8.self)
        XCTAssertTrue(text.contains("bodyMass"))
        XCTAssertTrue(text.contains("79.5"))

        try await repository.delete(kind: .bodyMetric, id: older.id)
        let remaining = await repository.bodyMetricSamples(kind: nil)
        XCTAssertEqual(remaining.map(\.id), [newer.id])
        do {
            try await repository.delete(kind: .bodyMetric, id: older.id)
            XCTFail("Deleting a missing record should fail honestly")
        } catch {
            XCTAssertEqual(error as? WellnessRepositoryError, .recordNotFound)
        }
    }

    func testWellnessHomeCardRequiresPermissionAndChangesDensity() async throws {
        let sample = try BodyMetricSample(
            kind: .bodyMass,
            value: 72.4,
            unit: .kilograms,
            observedAt: Date(timeIntervalSince1970: 10_000),
            updatedAt: Date(timeIntervalSince1970: 10_001)
        )
        let repository = InMemoryWellnessRepository(bodyMetrics: [sample])
        let definition = try XCTUnwrap(DefaultDashboardWidgetRegistry.shared.descriptor(for: .bodyMetric))
        let provider = WellnessHomeCardProvider(
            definition: definition,
            focus: .bodyMetric(.bodyMass),
            repository: repository
        )

        let hidden = await provider.snapshot(context: .init(semanticSize: .wide))
        XCTAssertEqual(hidden.availability, .redacted)

        let visibleContext = HomeCardSnapshotContext(
            semanticSize: .wide,
            permittedSensitivities: Set(DataSensitivity.allCases)
        )
        let visible = await provider.snapshot(context: visibleContext)
        XCTAssertEqual(visible.availability, .ready)
        XCTAssertEqual(visible.value, "72.4 kg")
        XCTAssertNotNil(visible.detail)

        let glance = await provider.snapshot(
            context: .init(
                semanticSize: .compact,
                permittedSensitivities: Set(DataSensitivity.allCases)
            )
        )
        XCTAssertNil(glance.detail)
    }

    func testWellnessNormalizedEventIsSensitiveAndUsesCaptureDay() throws {
        let kolkata = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let observed = Date(timeIntervalSince1970: 1711911600) // 2024-04-01 locally, 2024-03-31 UTC.
        let sample = try BodyMetricSample(
            kind: .bodyMass,
            value: 70,
            unit: .kilograms,
            observedAt: observed,
            capturedTimeZone: kolkata
        )
        let event = WellnessNormalizedEventProjector().bodyMetric(sample, now: observed)
        XCTAssertEqual(event.domain, "wellness")
        XCTAssertEqual(event.sensitivity, .privateSensitive)
        XCTAssertEqual(event.localDay, PlanningDay(date: observed, timeZone: kolkata))
        XCTAssertEqual(event.evidence.first?.sourceID, sample.id)
    }

    func testWellnessOutlierPolicyRequiresReviewWithoutDiagnosing() {
        let policy = WellnessOutlierPolicy()
        XCTAssertEqual(policy.review(kind: .bodyMass, normalizedValue: 70), .accepted)
        guard case .requiresConfirmation(let message) = policy.review(kind: .bodyMass, normalizedValue: 700) else { return XCTFail("Expected confirmation") }
        XCTAssertTrue(message.contains("Confirm"))
        XCTAssertFalse(message.lowercased().contains("danger"))
        XCTAssertFalse(message.lowercased().contains("unhealthy"))
    }

    func testWellnessCoreModelPlacesAdditiveEntitiesInCloudSync() throws {
        let model = try XCTUnwrap(NSManagedObjectModel.mergedModel(from: [Bundle.main, Bundle(for: Self.self)]))
        let cloud = Set(try XCTUnwrap(model.entities(forConfigurationName: "CloudSync")).compactMap(\.name))
        for name in ["BodyMetricSample", "WorkoutRecord", "SleepNote", "MovementContextRecord"] {
            XCTAssertNotNil(model.entitiesByName[name])
            XCTAssertTrue(cloud.contains(name), "\(name) must be part of CloudSync")
        }
        let fasting = try XCTUnwrap(model.entitiesByName["FastingSession"])
        XCTAssertNotNil(fasting.attributesByName["completionKindRaw"])
        XCTAssertNotNil(fasting.attributesByName["updatedAt"])
    }

    func testCoreDataWellnessRepositoryRoundTripsAndDeletesCanonicalValues() async throws {
        let model = try XCTUnwrap(NSManagedObjectModel.mergedModel(from: [Bundle.main, Bundle(for: Self.self)]))
        let container = NSPersistentContainer(name: "WellnessCoreRoundTrip", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.configuration = "CloudSync"
        container.persistentStoreDescriptions = [description]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            container.loadPersistentStores { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }

        let repository = CoreDataWellnessRepository(container: container)
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let metric = try BodyMetricSample(
            kind: .bodyMass,
            value: 154.324,
            unit: .pounds,
            observedAt: Date(timeIntervalSince1970: 500_000),
            capturedTimeZone: timeZone,
            source: .manual,
            note: "Morning"
        )
        let workout = try WorkoutRecord(
            activityKind: "Walking",
            startedAt: Date(timeIntervalSince1970: 499_000),
            endedAt: Date(timeIntervalSince1970: 499_900),
            distanceMeters: 1_200,
            source: .manual
        )
        let sleep = try SleepNote(
            startedAt: Date(timeIntervalSince1970: 470_000),
            endedAt: Date(timeIntervalSince1970: 498_000),
            quality: 4,
            source: .manual,
            capturedTimeZone: timeZone
        )
        let movement = try MovementContextRecord(
            startedAt: Date(timeIntervalSince1970: 490_000),
            endedAt: Date(timeIntervalSince1970: 500_000),
            steps: 3_200,
            distanceMeters: 2_400,
            activeEnergyKilocalories: 180,
            source: .healthKit,
            sourceIdentifier: "health-day-1"
        )
        try await repository.save(metric)
        try await repository.save(workout)
        try await repository.save(sleep)
        try await repository.save(movement)

        let restoredMetrics = try await repository.bodyMetricSamples(kind: .bodyMass)
        let restoredMetric = try XCTUnwrap(restoredMetrics.first)
        XCTAssertEqual(restoredMetric.id, metric.id)
        XCTAssertEqual(restoredMetric.normalizedValue, 70, accuracy: 0.01)
        XCTAssertEqual(restoredMetric.displayUnit, .pounds)
        XCTAssertEqual(restoredMetric.capturedTimeZoneIdentifier, "Asia/Kolkata")
        let restoredWorkouts = try await repository.workoutRecords()
        let restoredSleep = try await repository.sleepNotes()
        let restoredMovement = try await repository.movementRecords()
        XCTAssertEqual(restoredWorkouts.first?.id, workout.id)
        XCTAssertEqual(restoredSleep.first?.quality, 4)
        XCTAssertEqual(restoredMovement.first?.steps, 3_200)

        try await repository.delete(kind: .bodyMetric, id: metric.id)
        let remainingMetrics = try await repository.bodyMetricSamples(kind: nil)
        XCTAssertTrue(remainingMetrics.isEmpty)
    }

    func testCoreDataFastingRoundTripPreservesCompletionMeaningAndCorrectionTime() async throws {
        let model = try XCTUnwrap(
            NSManagedObjectModel.mergedModel(from: [Bundle.main, Bundle(for: Self.self)])
        )
        let container = NSPersistentContainer(name: "FastingCompletionRoundTrip", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            container.loadPersistentStores { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }

        let startedAt = Date(timeIntervalSince1970: 1_721_430_000)
        let correctedAt = startedAt.addingTimeInterval(7_200)
        let expected = LifeBoardFastingSessionValue(
            startedAt: startedAt,
            endedAt: correctedAt,
            targetDuration: 5_400,
            reminderOffsets: [1_800],
            note: "Adjusted after review",
            completionKind: .corrected,
            updatedAt: correctedAt
        )
        let repository = CoreDataLifeBoardPhaseIIRepository(container: container)

        try await repository.saveFastingSession(expected)
        let sessions = try await repository.fetchFastingSessions(limit: 1)
        let fetched = try XCTUnwrap(sessions.first)

        XCTAssertEqual(fetched.id, expected.id)
        XCTAssertEqual(fetched.completionKind, .corrected)
        XCTAssertEqual(fetched.updatedAt, correctedAt)
        XCTAssertEqual(fetched.note, expected.note)
    }

    func testNutritionServingConversionCreatesAnImmutableHistoricalSnapshot() throws {
        let macros = try NutritionMacros(
            calories: 250,
            proteinGrams: 10,
            carbohydrateGrams: 40,
            fatGrams: 6,
            fiberGrams: 5
        )
        let bowl = try FoodServingDefinition(name: "bowl", grams: 160)
        var food = try FoodItem(name: "Oats", macrosPer100Grams: macros, servings: [bowl])
        let entry = try NutritionLogEntry(food: food, mealSlot: .breakfast, quantity: 1.5, serving: bowl)

        food.macrosPer100Grams = try NutritionMacros(
            calories: 999,
            proteinGrams: 0,
            carbohydrateGrams: 0,
            fatGrams: 0
        )

        XCTAssertEqual(entry.servingGramsSnapshot, 160)
        XCTAssertEqual(entry.resolvedMacrosSnapshot.calories, 600, accuracy: 0.001)
        XCTAssertEqual(entry.resolvedMacrosSnapshot.proteinGrams, 24, accuracy: 0.001)
        XCTAssertEqual(entry.foodNameSnapshot, "Oats")
    }

    func testNutritionRepositoryIsLocalFirstStableAndUndoable() async throws {
        let macros = try NutritionMacros(calories: 100, proteinGrams: 2, carbohydrateGrams: 20, fatGrams: 1)
        let serving = try FoodServingDefinition(name: "serving", grams: 100)
        let favorite = try FoodItem(name: "Apple", macrosPer100Grams: macros, servings: [serving], isFavorite: true)
        let other = try FoodItem(name: "Apple sauce", macrosPer100Grams: macros, servings: [serving])
        let repository = InMemoryNutritionRepository(foods: [other, favorite])

        let searchIDs = try await repository.foods(query: "apple").map(\.id)
        XCTAssertEqual(searchIDs, [favorite.id, other.id])
        let entry = try NutritionLogEntry(food: other, mealSlot: .snack, quantity: 1, serving: serving)
        try await repository.save(entry)
        let recentIDs = try await repository.recentFoods(limit: 1).map(\.id)
        XCTAssertEqual(recentIDs, [other.id])
        try await repository.deleteLog(id: entry.id)
        let logs = try await repository.logs(from: nil, to: nil)
        XCTAssertTrue(logs.isEmpty)
    }

    func testNutritionRemoteLookupRequiresBothExplicitIntentAndReleaseFlag() throws {
        XCTAssertFalse(try NutritionLookupPolicy(externalLookupEnabled: true).permitsRemoteLookup(scope: .localOnly))
        XCTAssertTrue(try NutritionLookupPolicy(externalLookupEnabled: true).permitsRemoteLookup(scope: .explicitRemoteRequest))
        XCTAssertThrowsError(
            try NutritionLookupPolicy(externalLookupEnabled: false).permitsRemoteLookup(scope: .explicitRemoteRequest)
        ) { error in
            XCTAssertEqual(error as? NutritionError, .externalLookupNotEnabled)
        }
    }

    func testNutritionBarcodeDeduplicationUsesABoundedInteractionWindow() async {
        let deduplicator = NutritionScanDeduplicator(window: 3)
        let now = Date(timeIntervalSince1970: 1_721_430_000)
        let first = await deduplicator.shouldAccept(barcode: " 0123-4567 ", at: now)
        let duplicate = await deduplicator.shouldAccept(barcode: "01234567", at: now.addingTimeInterval(2))
        let later = await deduplicator.shouldAccept(barcode: "01234567", at: now.addingTimeInterval(6))
        XCTAssertTrue(first)
        XCTAssertFalse(duplicate)
        XCTAssertTrue(later)
    }

    func testNutritionAndLifeMomentModelsPreserveStoreBoundaries() throws {
        let model = try XCTUnwrap(NSManagedObjectModel.mergedModel(from: [Bundle.main, Bundle(for: Self.self)]))
        let cloud = Set(try XCTUnwrap(model.entities(forConfigurationName: "CloudSync")).compactMap(\.name))
        let local = Set(try XCTUnwrap(model.entities(forConfigurationName: "LocalOnly")).compactMap(\.name))
        for name in ["FoodItem", "NutritionLogEntry", "NutritionGoal", "LifeMoment"] {
            XCTAssertTrue(cloud.contains(name)); XCTAssertFalse(local.contains(name))
        }
        for name in ["FoodSearchIndexEntry", "FoodLookupCache"] {
            XCTAssertTrue(local.contains(name)); XCTAssertFalse(cloud.contains(name))
        }
    }

    func testCoreDataNutritionAndLifeMomentsRoundTripImmutableValues() async throws {
        let model = try XCTUnwrap(NSManagedObjectModel.mergedModel(from: [Bundle.main, Bundle(for: Self.self)]))
        let container = NSPersistentContainer(name: "PhaseVIRoundTrip", managedObjectModel: model)
        let description = NSPersistentStoreDescription(); description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            container.loadPersistentStores { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        let nutrition = CoreDataNutritionRepository(container: container)
        let serving = try FoodServingDefinition(name: "cup", grams: 180)
        let food = try FoodItem(name: "Yogurt", macrosPer100Grams: .init(calories: 60, proteinGrams: 4, carbohydrateGrams: 5, fatGrams: 2), servings: [serving])
        let entry = try NutritionLogEntry(food: food, mealSlot: .breakfast, quantity: 1, serving: serving)
        try await nutrition.save(food); try await nutrition.save(entry)
        let restoredFoods = try await nutrition.foods(query: "yogurt")
        let restoredLogs = try await nutrition.logs(from: nil, to: nil)
        XCTAssertEqual(restoredFoods.first?.id, food.id)
        XCTAssertEqual(restoredLogs.first?.resolvedMacrosSnapshot, entry.resolvedMacrosSnapshot)

        let moments = CoreDataLifeMomentRepository(container: container)
        let moment = try LifeMoment(title: "Anniversary", kind: .anniversary, eventDate: Date().addingTimeInterval(86_400), recurrenceRule: .yearly, permitsHomeDisplay: true)
        try await moments.save(moment)
        let restoredMoment = try await moments.moment(id: moment.id)
        XCTAssertEqual(restoredMoment?.recurrenceRule, .yearly)
        try await moments.archive(id: moment.id, at: Date())
        let activeMoments = try await moments.moments(includeArchived: false)
        XCTAssertTrue(activeMoments.isEmpty)
    }

    func testLifeMomentRecurrenceUsesCapturedTimezoneWithoutPersistingOccurrences() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let original = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2025, month: 7, day: 25, hour: 9
        )))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 20, hour: 10
        )))
        let moment = try LifeMoment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000081")!,
            title: "A meaningful day",
            kind: .anniversary,
            eventDate: original,
            recurrenceRule: .yearly,
            capturedTimeZone: timeZone,
            permitsHomeDisplay: true
        )

        let occurrence = try XCTUnwrap(moment.nextOccurrence(onOrAfter: now))
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: occurrence)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 25)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(moment.calendarDaysUntilNextOccurrence(from: now), 5)
    }

    func testLifeMomentCandidateRequiresHomeOptInAndExplainsThreshold() async throws {
        let now = Date(timeIntervalSince1970: 200_000)
        let visible = try LifeMoment(
            title: "Launch day",
            kind: .countdown,
            eventDate: now.addingTimeInterval(3 * 86_400),
            permitsHomeDisplay: true
        )
        let privateMoment = try LifeMoment(
            title: "Private date",
            kind: .countdown,
            eventDate: now.addingTimeInterval(2 * 86_400),
            permitsHomeDisplay: false
        )
        let repository = InMemoryLifeMomentRepository(values: [privateMoment, visible])
        let provider = LifeMomentContextCandidateProvider(repository: repository, thresholdDays: 7)
        let candidates = await provider.candidates(context: .init(
            date: now,
            timeZone: .gmt,
            refreshBoundary: .daypartBoundary
        ))
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.title, "Launch day")
        XCTAssertEqual(candidates.first?.reason.signal, "lifeMomentThreshold")
        XCTAssertTrue(candidates.first?.reason.message.contains("final week") == true)
    }

    func testLifeMomentHomeCardDensityAndArchiveRecovery() async throws {
        let now = Date(timeIntervalSince1970: 300_000)
        let moment = try LifeMoment(
            title: "Trip",
            kind: .countdown,
            eventDate: now.addingTimeInterval(4 * 86_400),
            note: "Pack the small camera.",
            permitsHomeDisplay: true,
            updatedAt: now
        )
        let repository = InMemoryLifeMomentRepository(values: [moment])
        let definition = try XCTUnwrap(DefaultDashboardWidgetRegistry.shared.descriptor(for: .lifeMoment))
        let provider = LifeMomentHomeCardProvider(
            definition: definition,
            momentID: moment.id,
            sensitivity: moment.sensitivity,
            repository: repository
        )
        let glance = await provider.snapshot(configuration: .init(), size: .compact, at: now)
        XCTAssertEqual(glance.availability, .ready)
        XCTAssertEqual(glance.value, "4 days")
        XCTAssertNil(glance.detail)

        let story = await provider.snapshot(configuration: .init(), size: .tall, at: now)
        XCTAssertEqual(story.detail, "Pack the small camera.")

        try await repository.archive(id: moment.id, at: now.addingTimeInterval(1))
        let archived = await provider.snapshot(configuration: .init(), size: .wide, at: now)
        XCTAssertEqual(archived.availability, .unavailable)
    }

    func testContextCandidateRegistryMergesDomainsDeterministically() async {
        let registry = HomeContextCandidateProviderRegistry()
        await registry.register(ContextCandidateProviderFixture(
            providerID: "plan",
            candidateID: "next",
            priority: 300,
            title: "Next meeting"
        ))
        await registry.register(ContextCandidateProviderFixture(
            providerID: "fasting",
            candidateID: "active-fast",
            priority: 700,
            title: "Fast is active"
        ))
        await registry.register(ContextCandidateProviderFixture(
            providerID: "duplicate-lower-priority",
            candidateID: "next",
            priority: 100,
            title: "Duplicate"
        ))
        let values = await registry.candidates(context: .init(refreshBoundary: .appForeground))
        XCTAssertEqual(values.map(\.id), ["active-fast", "next"])
        XCTAssertEqual(values.last?.title, "Next meeting")
        let providerIDs = await registry.providerIDs()
        XCTAssertEqual(providerIDs, ["duplicate-lower-priority", "fasting", "plan"])
    }

    func testJournalKnowledgeGraphRebuildIsDeterministicAndExcludesPrivateContent() throws {
        let included = JournalEntrySnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000041")!,
            date: Date(timeIntervalSince1970: 80_000),
            title: nil,
            text: "Alice met Maya in Paris.",
            mood: .calm,
            energy: 4,
            isStarred: false,
            attachments: [],
            updatedAt: Date(timeIntervalSince1970: 80_100)
        )
        let excluded = JournalEntrySnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000042")!,
            date: Date(timeIntervalSince1970: 81_000),
            title: nil,
            text: "SecretName visited HiddenPlace.",
            mood: LifeBoardJournalMood.none,
            energy: nil,
            isStarred: false,
            attachments: [],
            updatedAt: Date(timeIntervalSince1970: 81_100),
            aiExclusion: .excludedFromAIAndReflection
        )

        let first = JournalKnowledgeGraphReconciler.makeGraph(from: [included, excluded])
        let second = JournalKnowledgeGraphReconciler.makeGraph(from: [excluded, included])
        XCTAssertEqual(Set(first.nodes.keys), Set(second.nodes.keys))
        XCTAssertEqual(first.edges.map { "\($0.from)|\($0.to)" }, second.edges.map { "\($0.from)|\($0.to)" })
        let payload = String(decoding: try JSONEncoder().encode(first), as: UTF8.self)
        XCTAssertFalse(payload.localizedCaseInsensitiveContains("SecretName"))
        XCTAssertFalse(payload.localizedCaseInsensitiveContains("HiddenPlace"))
    }

    func testJournalDerivedPipelineReconcilesCommitExclusionAndDeletion() async throws {
        let original = JournalEntrySnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000051")!,
            date: Date(timeIntervalSince1970: 90_000),
            title: nil,
            text: "Maya planned a walk through Delhi.",
            mood: .happy,
            energy: 4,
            isStarred: false,
            attachments: [],
            updatedAt: Date(timeIntervalSince1970: 90_100)
        )
        let snapshots = JournalSnapshotFixture([original])
        let index = JournalDerivedIndexFixture()
        let graphStore = KnowledgeGraphStoreFixture()
        let invalidations = JournalProjectionInvalidationFixture()
        let pipeline = JournalDerivedPipelineCoordinator(
            derivedIndex: index,
            graphStore: graphStore,
            snapshotProvider: { await snapshots.values() },
            invalidateReflections: { ids in await invalidations.reflections(ids) },
            invalidateHomeAndEvidence: { await invalidations.projections() }
        )

        try await pipeline.processCommitted(original)
        let initiallyIndexed = await index.indexedIDs()
        XCTAssertEqual(initiallyIndexed, [original.id])

        var excluded = original
        excluded.aiExclusion = .excludedFromAIAndReflection
        excluded.updatedAt = excluded.updatedAt.addingTimeInterval(1)
        await snapshots.replace([excluded])
        try await pipeline.processCommitted(excluded)
        let indexedAfterExclusion = await index.indexedIDs()
        XCTAssertTrue(indexedAfterExclusion.isEmpty)
        let optionalGraphAfterExclusion = await graphStore.value()
        let graphAfterExclusion = try XCTUnwrap(optionalGraphAfterExclusion)
        let excludedPayload = String(
            decoding: try JSONEncoder().encode(graphAfterExclusion),
            as: UTF8.self
        )
        XCTAssertFalse(excludedPayload.localizedCaseInsensitiveContains("Maya"))

        await snapshots.replace([])
        try await pipeline.processDeletion(entryID: original.id)
        let indexedAfterDeletion = await index.indexedIDs()
        let optionalGraphAfterDeletion = await graphStore.value()
        let graphAfterDeletion = try XCTUnwrap(optionalGraphAfterDeletion)
        let invalidationCounts = await invalidations.counts()
        XCTAssertTrue(indexedAfterDeletion.isEmpty)
        XCTAssertTrue(graphAfterDeletion.nodes.isEmpty)
        XCTAssertEqual(invalidationCounts, [3, 3])
    }

    @MainActor
    func testHomeProjectionRegistersEveryExistingDomainBehindSnapshotBoundary() async throws {
        let store = HomeLifeOSProjectionStore(
            planningRepository: nil,
            trackRepository: nil,
            phaseIIRepository: nil
        )
        let registry = try store.makeHomeCardProviderRegistry()
        let definitions = await registry.registeredDefinitions()
        let kinds = Set(definitions.map(\.kind))
        XCTAssertTrue([
            DashboardWidgetKind.tasks,
            .lifeSnapshot,
            .care,
            .routines,
            .goals,
            .fasting,
            .journal,
            .progressReflection,
            .quickCapture,
            .evaConversation
        ].allSatisfy(kinds.contains))

        let quickCapture = try await registry.snapshot(
            for: .quickCapture,
            context: .init(semanticSize: .standard)
        )
        XCTAssertEqual(quickCapture.availability, .ready)
        XCTAssertEqual(quickCapture.value, "Capture")

        let unavailableTasks = try await registry.snapshot(
            for: .tasks,
            context: .init(semanticSize: .wide)
        )
        XCTAssertEqual(unavailableTasks.availability, .unavailable)
    }

    private func date(hour: Int, minute: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 13, hour: hour, minute: minute))!
    }

    private actor FastingSessionRepositoryFixture: LifeBoardFastingSessionRepository {
        private var values: [UUID: LifeBoardFastingSessionValue]

        init(seed: [LifeBoardFastingSessionValue] = []) {
            values = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
        }

        func fetchFastingSessions(limit: Int) async throws -> [LifeBoardFastingSessionValue] {
            Array(values.values.sorted { $0.startedAt > $1.startedAt }.prefix(limit))
        }

        func saveFastingSession(_ value: LifeBoardFastingSessionValue) async throws {
            values[value.id] = value
        }

        func all() -> [LifeBoardFastingSessionValue] {
            values.values.sorted { $0.startedAt > $1.startedAt }
        }
    }

    private func journalDateForRepositoryTest() -> Date {
        Date(timeIntervalSince1970: 1_789_200_000)
    }

    private func taskModelBundleURL() throws -> URL {
        for bundle in [Bundle.main, Bundle(for: Self.self)] {
            if let url = bundle.url(forResource: "TaskModelV3", withExtension: "momd") {
                return url
            }
        }
        throw XCTSkip("The compiled TaskModelV3.momd is unavailable in this test host")
    }

    @MainActor
    private func assertLightweightMigration(
        from sourceModelName: String,
        modelBundleURL: URL,
        destinationModel: NSManagedObjectModel
    ) throws {
        let sourceModelURL = modelBundleURL.appendingPathComponent("\(sourceModelName).mom")
        let sourceModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: sourceModelURL))
        let fixtureID = UUID()
        let fixtureName = "Migration fixture \(sourceModelName)"
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LifeOSFoundationMigration-\(UUID().uuidString)", isDirectory: true)
        let sourceStoreURL = directoryURL.appendingPathComponent("source.sqlite")
        let destinationStoreURL = directoryURL.appendingPathComponent("destination.sqlite")
        let sqliteOptions: [AnyHashable: Any] = [
            NSSQLitePragmasOption: ["journal_mode": "DELETE"]
        ]
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let sourceCoordinator = NSPersistentStoreCoordinator(managedObjectModel: sourceModel)
        let sourceStore = try sourceCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: "CloudSync",
            at: sourceStoreURL,
            options: sqliteOptions
        )
        let sourceContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        sourceContext.persistentStoreCoordinator = sourceCoordinator
        try sourceContext.performAndWait {
            let area = NSEntityDescription.insertNewObject(forEntityName: "LifeArea", into: sourceContext)
            area.setValue(fixtureID, forKey: "id")
            area.setValue(fixtureName, forKey: "name")
            try sourceContext.save()
        }
        try sourceCoordinator.remove(sourceStore)

        let mappingModel = try NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        )
        let migrationManager = NSMigrationManager(
            sourceModel: sourceModel,
            destinationModel: destinationModel
        )
        try migrationManager.migrateStore(
            from: sourceStoreURL,
            sourceType: NSSQLiteStoreType,
            options: sqliteOptions,
            with: mappingModel,
            toDestinationURL: destinationStoreURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: sqliteOptions
        )

        let destinationCoordinator = NSPersistentStoreCoordinator(managedObjectModel: destinationModel)
        let destinationStore = try destinationCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: "CloudSync",
            at: destinationStoreURL,
            options: sqliteOptions
        )
        defer { try? destinationCoordinator.remove(destinationStore) }
        let destinationContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        destinationContext.persistentStoreCoordinator = destinationCoordinator
        let fetched: (id: UUID?, name: String?) = try destinationContext.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "LifeArea")
            request.predicate = NSPredicate(format: "id == %@", fixtureID as CVarArg)
            request.fetchLimit = 1
            let result = try destinationContext.fetch(request).first
            return (
                result?.value(forKey: "id") as? UUID,
                result?.value(forKey: "name") as? String
            )
        }
        XCTAssertEqual(fetched.id, fixtureID)
        XCTAssertEqual(fetched.name, fixtureName)
    }

    private func rgbComponents(from hex: String) throws -> (red: Double, green: Double, blue: Double) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let raw = Int(value, radix: 16) else {
            throw NSError(domain: "LifeOSFoundationTests.Color", code: 1)
        }
        return (
            Double((raw >> 16) & 0xFF) / 255,
            Double((raw >> 8) & 0xFF) / 255,
            Double(raw & 0xFF) / 255
        )
    }

    private func rgbComponents(from color: UIColor) throws -> (red: Double, green: Double, blue: Double) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            throw NSError(domain: "LifeOSFoundationTests.Color", code: 2)
        }
        return (Double(red), Double(green), Double(blue))
    }

    private func contrastRatio(
        _ lhs: (red: Double, green: Double, blue: Double),
        _ rhs: (red: Double, green: Double, blue: Double)
    ) -> Double {
        let first = relativeLuminance(lhs)
        let second = relativeLuminance(rhs)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private func relativeLuminance(_ color: (red: Double, green: Double, blue: Double)) -> Double {
        func linearize(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(color.red)
            + 0.7152 * linearize(color.green)
            + 0.0722 * linearize(color.blue)
    }
}

private struct HomeCardProviderFixture: HomeCardProvider {
    let definition: HomeCardDefinition
    let primaryDestination: LifeBoardDestination
    let privacyClassification: DataSensitivity

    init(
        kind: DashboardWidgetKind,
        sensitivity: DataSensitivity = .privateStandard
    ) {
        definition = .init(
            kind: kind,
            title: kind.rawValue.capitalized,
            category: .reflect,
            supportedSizes: [.standard, .wide],
            multiplicity: .singleton,
            sensitivity: sensitivity
        )
        primaryDestination = kind == .journal ? .track : .plan
        privacyClassification = sensitivity
    }

    func snapshot(
        configuration: HomeCardConfiguration,
        size: HomeCardSize,
        at date: Date
    ) async -> HomeCardSnapshot {
        HomeCardSnapshot(
            availability: .ready,
            title: definition.title,
            value: size.title,
            updatedAt: date
        )
    }
}

private struct JournalIntentAdapterFixture: LifeThreadIntentAdapter {
    func resolve(_ input: LifeThreadIntentInput) async -> LifeThreadIntentResolution? {
        guard input.text.hasPrefix("/journal") else { return nil }
        return .captureDraft(
            .init(
                kind: .journal,
                text: input.text.replacingOccurrences(of: "/journal", with: "")
                    .trimmingCharacters(in: .whitespaces),
                destination: .track
            )
        )
    }
}

private struct PlanMutationIntentAdapterFixture: LifeThreadMutationIntentAdapter {
    let recorder: MutationRecorderFixture

    func resolveMutation(_ input: LifeThreadIntentInput) async -> LifeBoardMutationCommand? {
        guard input.text == "move reading" else { return nil }
        let preview = LifeBoardTransactionPreview(
            destination: .plan,
            summary: "Move Reading",
            changes: ["Time: 3:00 PM → 4:00 PM"],
            origin: input.origin
        )
        return LifeBoardMutationCommand(
            preview: preview,
            apply: {
                await recorder.recordApply()
                return "Reading moved to 4:00 PM."
            },
            undo: { await recorder.recordUndo() }
        )
    }
}

private struct ContextCandidateProviderFixture: HomeContextCandidateProvider {
    let providerID: String
    let candidateID: String
    let priority: Int
    let title: String

    func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        [
            .init(
                id: candidateID,
                widgetKind: .focusNow,
                title: title,
                reason: .init(message: title, signal: providerID),
                destination: .plan,
                priority: priority,
                relevantFrom: context.date
            )
        ]
    }
}

private actor MutationRecorderFixture {
    private var applyCount = 0
    private var undoCount = 0

    func recordApply() { applyCount += 1 }
    func recordUndo() { undoCount += 1 }
    func counts() -> [Int] { [applyCount, undoCount] }
}

private actor JournalSnapshotFixture {
    private var snapshots: [JournalEntrySnapshot]
    init(_ snapshots: [JournalEntrySnapshot]) { self.snapshots = snapshots }
    func values() -> [JournalEntrySnapshot] { snapshots }
    func replace(_ values: [JournalEntrySnapshot]) { snapshots = values }
}

private actor JournalDerivedIndexFixture: JournalDerivedIndexRepository {
    private var ids: Set<UUID> = []

    func rebuild(entries: [JournalEntrySnapshot]) async throws {
        ids = Set(entries.filter { $0.aiExclusion.permitsSemanticIndexing }.map(\.id))
    }

    func upsert(entry: JournalEntrySnapshot) async throws {
        if entry.aiExclusion.permitsSemanticIndexing {
            ids.insert(entry.id)
        } else {
            ids.remove(entry.id)
        }
    }

    func remove(entryID: UUID) async throws { ids.remove(entryID) }
    func search(query: String, limit: Int) async throws -> [JournalEvidenceReference] { [] }
    func invalidate() async throws { ids = [] }
    func indexedIDs() -> Set<UUID> { ids }
}

private actor KnowledgeGraphStoreFixture: KnowledgeGraphStore {
    private var graph: PersonalKnowledgeGraph?
    func loadGraph() async throws -> PersonalKnowledgeGraph? { graph }
    func saveGraph(_ graph: PersonalKnowledgeGraph) async throws { self.graph = graph }
    func value() -> PersonalKnowledgeGraph? { graph }
}

private actor JournalProjectionInvalidationFixture {
    private var reflectionCount = 0
    private var projectionCount = 0
    func reflections(_ ids: Set<UUID>) { reflectionCount += ids.isEmpty ? 0 : 1 }
    func projections() { projectionCount += 1 }
    func counts() -> [Int] { [reflectionCount, projectionCount] }
}
