import CoreData
import UIKit
import XCTest
@testable import LifeBoard

final class LifeOSFoundationContractTests: XCTestCase {
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
        XCTAssertEqual(LifeBoardDaypartTokens.morning.canvas, "#FDF3D6")
        XCTAssertEqual(LifeBoardDaypartTokens.morning.celestialPrimary, "#F8DD79")
        XCTAssertEqual(LifeBoardDaypartTokens.afternoon.canvas, "#FAF2DC")
        XCTAssertEqual(LifeBoardDaypartTokens.afternoon.celestialPrimary, "#F6D16C")
        XCTAssertEqual(LifeBoardDaypartTokens.evening.foreground, "#2F2523")
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
    func testEveryPreviousModelMigratesToKnowledgeNotesWithoutChangingStableIDs() throws {
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
            "TaskModelV3_Journal"
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
                    XCTFail("\(modelName) could not migrate to TaskModelV3_KnowledgeNotes: \(error)")
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
                DashboardWidgetKind.scheduleCapacity.rawValue,
                DashboardWidgetKind.quickCapture.rawValue,
                DashboardWidgetKind.compactTimeline.rawValue,
                DashboardWidgetKind.progressReflection.rawValue
            ]
        )
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

    func testUnresolvedMedicationDoesNotContributeToAdherence() {
        XCTAssertFalse(LifeBoardMedicationEventStatus.unresolved.contributesToAdherence)
        XCTAssertFalse(LifeBoardMedicationEventStatus.scheduled.contributesToAdherence)
        XCTAssertTrue(LifeBoardMedicationEventStatus.taken.contributesToAdherence)
        XCTAssertTrue(LifeBoardMedicationEventStatus.skipped.contributesToAdherence)
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

    private func date(hour: Int, minute: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 13, hour: hour, minute: minute))!
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
