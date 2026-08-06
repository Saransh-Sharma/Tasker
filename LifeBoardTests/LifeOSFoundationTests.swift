import CoreData
import JournalFoundation
import KnowledgeGraphKit
import ReflectionKit
import UIKit
import XCTest
@testable import LifeBoard

private struct StubNutritionRemoteLookup: NutritionRemoteFoodLookingUp {
    var value: FoodItem?

    func food(barcode: String) async throws -> FoodItem? {
        value?.barcode == barcode.filter(\.isNumber) ? value : nil
    }
}

final class HomeFastingAnchorPolicyTests: XCTestCase {
    func testRecentMealWithinOneDayAnchorsAutomaticStart() async throws {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let meal = now.addingTimeInterval(-6 * 60 * 60)

        XCTAssertEqual(
            HomeFastingAnchorPolicy.recentMealAnchor(latestMealAt: meal, now: now),
            meal
        )

        let repository = InMemoryFastingSessionRepository()
        let timer = FastingTimerStore(repository: repository, now: { now })
        let session = try await timer.start(targetDuration: nil, at: meal)
        XCTAssertEqual(session.startedAt, meal)
        XCTAssertEqual(session.elapsed(at: now), 6 * 60 * 60, accuracy: 0.001)
    }

    func testMealOlderThanOneDayFallsBackToManualStart() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let tooOld = now.addingTimeInterval(-HomeFastingAnchorPolicy.recentMealWindow - 1)

        XCTAssertNil(HomeFastingAnchorPolicy.recentMealAnchor(latestMealAt: tooOld, now: now))
        XCTAssertNil(HomeFastingAnchorPolicy.recentMealAnchor(latestMealAt: nil, now: now))
    }

    func testFutureMealCannotAnchorAFast() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        XCTAssertNil(
            HomeFastingAnchorPolicy.recentMealAnchor(
                latestMealAt: now.addingTimeInterval(60),
                now: now
            )
        )
    }
}

final class HomeTaskAgendaProjectionTests: XCTestCase {
    func testBuildReturnsDeduplicatedOverdueThenSelectedDayDeadlines() throws {
        let calendar = calendar(timeZoneIdentifier: "Asia/Kolkata")
        let selectedDate = try date(2026, 8, 3, 12, calendar: calendar)
        let duplicateID = UUID()
        let tasks = [
            task("Later", dueDate: try date(2026, 8, 4, 9, calendar: calendar)),
            task("Due second", dueDate: try date(2026, 8, 3, 17, calendar: calendar)),
            task("Oldest overdue", dueDate: try date(2026, 7, 30, 8, calendar: calendar)),
            task("Due first", dueDate: try date(2026, 8, 3, 8, calendar: calendar)),
            task("Recent overdue", dueDate: try date(2026, 8, 2, 20, calendar: calendar)),
            task("Duplicate", id: duplicateID, dueDate: try date(2026, 8, 1, 10, calendar: calendar)),
            task("Duplicate ignored", id: duplicateID, dueDate: try date(2026, 8, 3, 10, calendar: calendar)),
            task("Undated", dueDate: nil),
            task("Archived", dueDate: try date(2026, 8, 3, 11, calendar: calendar), disposition: .archived),
            task("Reference", dueDate: try date(2026, 8, 3, 12, calendar: calendar), disposition: .reference),
            task("Deleted", dueDate: try date(2026, 8, 3, 13, calendar: calendar), disposition: .deleted)
        ]

        let projection = HomeTaskAgendaProjection.build(
            tasks: tasks,
            selectedDate: selectedDate,
            calendar: calendar
        )

        XCTAssertEqual(
            projection.overdueTasks.map(\.title),
            ["Oldest overdue", "Duplicate", "Recent overdue"]
        )
        XCTAssertEqual(projection.dueTasks.map(\.title), ["Due first", "Due second"])
        XCTAssertEqual(
            projection.tasks.map(\.title),
            ["Oldest overdue", "Duplicate", "Recent overdue", "Due first", "Due second"]
        )
        XCTAssertEqual(Set(projection.tasks.map(\.id)).count, projection.tasks.count)
        XCTAssertEqual(projection.selectedDate, calendar.startOfDay(for: selectedDate))
    }

    func testBuildUsesCalendarDayBoundariesAcrossDaylightSavingTime() throws {
        let calendar = calendar(timeZoneIdentifier: "America/Los_Angeles")
        let selectedDate = try date(2026, 3, 8, 12, calendar: calendar)
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: dayStart))
        XCTAssertEqual(dayEnd.timeIntervalSince(dayStart), 23 * 60 * 60)

        let projection = HomeTaskAgendaProjection.build(
            tasks: [
                task("Overdue boundary", dueDate: dayStart.addingTimeInterval(-1)),
                task("At day start", dueDate: dayStart),
                task("At day end minus one", dueDate: dayEnd.addingTimeInterval(-1)),
                task("At next day", dueDate: dayEnd)
            ],
            selectedDate: selectedDate,
            calendar: calendar
        )

        XCTAssertEqual(projection.overdueTasks.map(\.title), ["Overdue boundary"])
        XCTAssertEqual(projection.dueTasks.map(\.title), ["At day start", "At day end minus one"])
        XCTAssertFalse(projection.tasks.contains(where: { $0.title == "At next day" }))
    }

    func testChangingSelectedDateMovesEarlierDeadlineIntoOverdueBucket() throws {
        let calendar = calendar(timeZoneIdentifier: "UTC")
        let firstDay = try date(2026, 8, 3, 12, calendar: calendar)
        let secondDay = try date(2026, 8, 4, 12, calendar: calendar)
        let tasks = [
            task("First day", dueDate: try date(2026, 8, 3, 9, calendar: calendar)),
            task("Second day", dueDate: try date(2026, 8, 4, 9, calendar: calendar)),
            task("Later", dueDate: try date(2026, 8, 5, 9, calendar: calendar))
        ]

        let firstProjection = HomeTaskAgendaProjection.build(
            tasks: tasks,
            selectedDate: firstDay,
            calendar: calendar
        )
        let secondProjection = HomeTaskAgendaProjection.build(
            tasks: tasks,
            selectedDate: secondDay,
            calendar: calendar
        )

        XCTAssertEqual(firstProjection.overdueTasks.map(\.title), [])
        XCTAssertEqual(firstProjection.dueTasks.map(\.title), ["First day"])
        XCTAssertEqual(secondProjection.overdueTasks.map(\.title), ["First day"])
        XCTAssertEqual(secondProjection.dueTasks.map(\.title), ["Second day"])
    }

    private func task(
        _ title: String,
        id: UUID = UUID(),
        dueDate: Date?,
        disposition: UnscheduledDisposition = .inbox
    ) -> PlanningTaskSummary {
        PlanningTaskSummary(
            id: id,
            title: title,
            dueDate: dueDate,
            metadata: PlanningTaskMetadata(
                taskID: id,
                unscheduledDisposition: disposition
            )
        )
    }

    private func calendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        calendar: Calendar
    ) throws -> Date {
        try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    timeZone: calendar.timeZone,
                    year: year,
                    month: month,
                    day: day,
                    hour: hour
                )
            )
        )
    }
}

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

    func testPremiumRootLensesAndInteractionPhasesRemainStableContracts() {
        XCTAssertEqual(TrackLens.allCases.map(\.rawValue), ["today", "areas", "history"])
        XCTAssertEqual(InsightsLens.allCases.map(\.rawValue), ["overview", "trends", "review", "experience"])
        XCTAssertEqual(
            LifeBoardInteractionPhase.allCases.map(\.rawValue),
            ["idle", "pressed", "running", "success", "recoverableFailure", "cancelled"]
        )
        // The allowlist is append-only and every entry must be unique; asserting
        // on `.last` just pinned whichever effect was added most recently.
        XCTAssertTrue(LifeBoardSignatureEffect.allCases.contains(.contextLens))
        XCTAssertTrue(LifeBoardSignatureEffect.allCases.contains(.chartRevealSweep))
        XCTAssertTrue(LifeBoardSignatureEffect.allCases.contains(.liquidGlassRefract))
        XCTAssertTrue(LifeBoardSignatureEffect.allCases.contains(.cardMorphWarp))
        XCTAssertTrue(LifeBoardSignatureEffect.allCases.contains(.paperGrain))
        XCTAssertTrue(LifeBoardSignatureEffect.allCases.contains(.dissolveAway))
        XCTAssertTrue(LifeBoardSignatureEffect.allCases.contains(.triageSettle))
        XCTAssertEqual(Set(LifeBoardSignatureEffect.allCases).count, LifeBoardSignatureEffect.allCases.count)
    }

    @MainActor
    func testSignatureShaderRegistryExactlyMatchesMetalDeclarations() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let metalURL = projectRoot
            .appendingPathComponent("LifeBoard/View/Effects/LifeBoardSignatureEffects.metal")
        let source = try String(contentsOf: metalURL, encoding: .utf8)
        let expression = try NSRegularExpression(
            pattern: #"\[\[\s*stitchable\s*\]\]\s+\w+\s+(LifeBoard\w+)\s*\("#
        )
        let sourceRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let declaredNames: [String] = expression.matches(in: source, range: sourceRange).compactMap { match in
            guard let range = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[range])
        }
        let declared = Set(declaredNames)
        let registered = Set(LifeBoardSignatureShaders.functionNames)

        // 20 since LifeBoardValueDrumWarp (2026-08-05). This number, the
        // registry, the [[stitchable]] declarations and DESIGN.md's approved
        // list are one atomic contract — warmUp() is all-or-nothing, so a
        // mismatch disables *every* signature effect at runtime with nothing
        // logged at the UI layer.
        //
        // This constant was already stale before the drum landed: it still said
        // 18 while the registry and the .metal had carried 19 since
        // LifeBoardFirstLight, so this assertion was failing on a clean tree.
        XCTAssertEqual(registered.count, 20)
        XCTAssertEqual(declared, registered)
    }

    // MARK: Completion control

    func testCompletionMarkIsAClosedRingAtRestAndAFullTickWhenComplete() {
        XCTAssertEqual(LifeBoardCompletionMark.ringExtent(at: 0), 1)
        XCTAssertEqual(LifeBoardCompletionMark.tickExtent(at: 0), 0)

        XCTAssertEqual(LifeBoardCompletionMark.ringExtent(at: 1), 0)
        XCTAssertEqual(LifeBoardCompletionMark.tickExtent(at: 1), 1)

        // The ring is fully unwound by the split and the tick has not started,
        // so the two phases never draw over each other.
        XCTAssertEqual(LifeBoardCompletionMark.ringExtent(at: LifeBoardCompletionMark.phaseSplit), 0)
        XCTAssertEqual(LifeBoardCompletionMark.tickExtent(at: LifeBoardCompletionMark.phaseSplit), 0)

        // Out-of-range progress clamps rather than producing an inverted arc.
        XCTAssertEqual(LifeBoardCompletionMark.ringExtent(at: -4), 1)
        XCTAssertEqual(LifeBoardCompletionMark.tickExtent(at: 9), 1)
    }

    func testCompletionMarkRingAndTickAreMonotonicAcrossTheMorph() {
        var previousRing = LifeBoardCompletionMark.ringExtent(at: 0)
        var previousTick = LifeBoardCompletionMark.tickExtent(at: 0)
        for step in 1...100 {
            let progress = Double(step) / 100
            let ring = LifeBoardCompletionMark.ringExtent(at: progress)
            let tick = LifeBoardCompletionMark.tickExtent(at: progress)
            XCTAssertLessThanOrEqual(ring, previousRing, "Ring must only unwind, never regrow, at \(progress)")
            XCTAssertGreaterThanOrEqual(tick, previousTick, "Tick must only draw in, never retract, at \(progress)")
            previousRing = ring
            previousTick = tick
        }
    }

    func testCompletionMarkProducesAnEmptyPathOnlyForADegenerateRect() {
        let box = CGRect(x: 0, y: 0, width: 44, height: 44)
        XCTAssertFalse(LifeBoardCompletionMark(progress: 0).path(in: box).isEmpty)
        XCTAssertFalse(LifeBoardCompletionMark(progress: 0.5).path(in: box).isEmpty)
        XCTAssertFalse(LifeBoardCompletionMark(progress: 1).path(in: box).isEmpty)
        XCTAssertTrue(LifeBoardCompletionMark(progress: 1).path(in: .zero).isEmpty)
    }

    func testCompletionMarkAnimatableDataRoundTrips() {
        var mark = LifeBoardCompletionMark(progress: 0.2)
        mark.animatableData = 0.75
        XCTAssertEqual(mark.progress, 0.75)
        XCTAssertEqual(mark.animatableData, 0.75)
    }

    func testTickGrowsAlongItsStrokeRatherThanScalingTheWholeGlyph() {
        let box = CGRect(x: 0, y: 0, width: 44, height: 44)
        // A partial tick must end short of the finished tick's far point; a
        // scaled-down whole glyph would keep the same end point and only shrink.
        let partial = LifeBoardCompletionMark.tickPath(in: box, extent: 0.5).currentPoint
        let complete = LifeBoardCompletionMark.tickPath(in: box, extent: 1).currentPoint
        XCTAssertNotNil(partial)
        XCTAssertNotNil(complete)
        XCTAssertLessThan(partial?.x ?? .infinity, complete?.x ?? 0)
    }

    // MARK: Completion mutation

    func testTaskCompletionMutationInvertsToTheOppositeCompletion() {
        let taskID = UUID()
        let complete = PlanMutation.setTaskCompletion(taskID: taskID, before: false, after: true)

        guard case .setTaskCompletion(let inverseID, let before, let after) = complete.inverse else {
            return XCTFail("Completion must invert to another completion, not a metadata write")
        }
        XCTAssertEqual(inverseID, taskID, "Undo must target the same task")
        XCTAssertTrue(before)
        XCTAssertFalse(after, "Undoing a completion has to reopen the task")

        // Undo of undo is the original, so a completion survives a round trip.
        XCTAssertEqual(complete.inverse.inverse, complete)
    }

    func testBatchedCompletionsInvertInReverseOrder() {
        let first = UUID()
        let second = UUID()
        let batch = PlanMutation.batch([
            .setTaskCompletion(taskID: first, before: false, after: true),
            .setTaskCompletion(taskID: second, before: false, after: true)
        ])

        guard case .batch(let inverted) = batch.inverse, inverted.count == 2 else {
            return XCTFail("A batch must invert to a batch of the same size")
        }
        guard case .setTaskCompletion(let leadingID, _, _) = inverted[0] else {
            return XCTFail("Expected a completion mutation")
        }
        XCTAssertEqual(leadingID, second, "Undo has to unwind the last write first")
    }

    /// The completion has to survive the whole receipt round trip, not just
    /// invert as a value: apply must clear the task from the open-task
    /// projection, and undo must bring it back with its completion date gone.
    func testCompletionAppliesAndUndoesThroughTheReceiptLedger() async throws {
        let model = try XCTUnwrap(
            NSManagedObjectModel(
                contentsOf: try completionModelBundleURL()
                    .appendingPathComponent("TaskModelV3_TaskStartDay.mom")
            )
        )
        let container = NSPersistentContainer(name: "CompletionRoundTrip", managedObjectModel: model)
        let cloud = NSPersistentStoreDescription()
        cloud.type = NSInMemoryStoreType
        cloud.configuration = "CloudSync"
        cloud.url = URL(fileURLWithPath: "/dev/null/cloud-\(UUID().uuidString)")
        let local = NSPersistentStoreDescription()
        local.type = NSInMemoryStoreType
        local.configuration = "LocalOnly"
        local.url = URL(fileURLWithPath: "/dev/null/local-\(UUID().uuidString)")
        container.persistentStoreDescriptions = [cloud, local]
        try await loadCompletionStores(container)

        let taskID = UUID()
        let context = container.newBackgroundContext()
        try await context.perform {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            task.setValue(taskID, forKey: "id")
            task.setValue("Finish the ledger", forKey: "title")
            task.setValue(false, forKey: "isComplete")
            try context.save()
        }

        let planning = CoreDataPlanningRepository(container: container)
        let openBefore = try await planning.fetchOpenPlanningTasks().map(\.id)
        XCTAssertEqual(openBefore, [taskID])

        let receipt = try await planning.prepare(
            .setTaskCompletion(taskID: taskID, before: false, after: true),
            source: "plan.task.completion",
            summary: "Completed Finish the ledger"
        )
        try await planning.apply(receiptID: receipt.id)
        let openAfterApply = try await planning.fetchOpenPlanningTasks()
        XCTAssertTrue(
            openAfterApply.isEmpty,
            "A completed task must leave the open-task projection"
        )

        try await planning.undo(receiptID: receipt.id)
        let openAfterUndo = try await planning.fetchOpenPlanningTasks().map(\.id)
        XCTAssertEqual(
            openAfterUndo, [taskID],
            "Undo has to reopen the task"
        )

        let reopened = try await context.perform { () -> NSManagedObject? in
            let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
            request.predicate = NSPredicate(format: "id == %@", taskID as CVarArg)
            return try context.fetch(request).first
        }
        XCTAssertEqual(try XCTUnwrap(reopened).value(forKey: "isComplete") as? Bool, false)
        XCTAssertNil(
            try XCTUnwrap(reopened).value(forKey: "dateCompleted"),
            "A reopened task keeping its completion date would still count as done everywhere else"
        )
    }

    // MARK: Timeline lanes

    private func laneItem(_ id: String, _ startHour: Double, _ endHour: Double) -> PlanTimelineLaneResolver.Item {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        return .init(
            id: id,
            start: base.addingTimeInterval(startHour * 3_600),
            end: base.addingTimeInterval(endHour * 3_600)
        )
    }

    func testNonOverlappingItemsAllKeepTheFullWidthLane() {
        let placements = PlanTimelineLaneResolver.placements(for: [
            laneItem("a", 9, 10),
            laneItem("b", 10, 11),
            laneItem("c", 11, 12)
        ])
        for id in ["a", "b", "c"] {
            XCTAssertEqual(placements[id]?.lane, 0)
            XCTAssertEqual(placements[id]?.laneCount, 1, "A clear hour must not be narrowed")
        }
        // Each is its own cluster, so one busy hour cannot narrow the whole day.
        XCTAssertEqual(Set([placements["a"], placements["b"], placements["c"]].map { $0?.clusterID }).count, 3)
    }

    func testOverlappingItemsGetDistinctLanesAndShareTheirClusterWidth() {
        let placements = PlanTimelineLaneResolver.placements(for: [
            laneItem("a", 9, 11),
            laneItem("b", 9.5, 10.5),
            laneItem("c", 10, 12)
        ])
        let lanes = ["a", "b", "c"].compactMap { placements[$0]?.lane }
        XCTAssertEqual(Set(lanes).count, 3, "Three mutually overlapping items cannot share a lane")
        for id in ["a", "b", "c"] {
            XCTAssertEqual(placements[id]?.laneCount, 3)
            XCTAssertEqual(placements[id]?.clusterID, placements["a"]?.clusterID)
        }
    }

    func testALaneIsReusedOnceItsPreviousItemHasEnded() {
        // b and c both overlap a, but not each other, so two lanes suffice.
        let placements = PlanTimelineLaneResolver.placements(for: [
            laneItem("a", 9, 12),
            laneItem("b", 9, 10),
            laneItem("c", 10, 11)
        ])
        XCTAssertEqual(placements["a"]?.laneCount, 2, "Sequential items must reuse a lane, not add one")
        XCTAssertEqual(placements["b"]?.lane, placements["c"]?.lane)
        XCTAssertNotEqual(placements["a"]?.lane, placements["b"]?.lane)
    }

    func testBackToBackItemsDoNotCountAsOverlapping() {
        let placements = PlanTimelineLaneResolver.placements(for: [
            laneItem("a", 9, 10),
            laneItem("b", 10, 11)
        ])
        XCTAssertEqual(placements["a"]?.laneCount, 1)
        XCTAssertEqual(placements["b"]?.laneCount, 1)
        XCTAssertNotEqual(
            placements["a"]?.clusterID, placements["b"]?.clusterID,
            "A meeting ending exactly when the next begins is not a conflict"
        )
    }

    func testDegenerateIntervalsStillGetALaneInsteadOfBreakingTheDay() {
        let placements = PlanTimelineLaneResolver.placements(for: [
            laneItem("zero", 9, 9),
            laneItem("reversed", 10, 9.5),
            laneItem("normal", 9, 11)
        ])
        XCTAssertEqual(placements.count, 3, "Every item must be placed, however malformed")
        for placement in placements.values {
            XCTAssertGreaterThanOrEqual(placement.lane, 0)
            XCTAssertGreaterThan(placement.laneCount, 0)
            XCTAssertLessThan(placement.lane, placement.laneCount, "A lane index must fit its lane count")
        }
    }

    func testOneAndTwoLanesFillTheCanvasWithoutScrolling() {
        let width: CGFloat = 340
        let spacing: CGFloat = 6

        let single = PlanTimelineLaneResolver.laneMetrics(laneCount: 1, availableWidth: width, spacing: spacing)
        XCTAssertEqual(single.laneWidth, width)
        XCTAssertFalse(single.scrolls)

        let pair = PlanTimelineLaneResolver.laneMetrics(laneCount: 2, availableWidth: width, spacing: spacing)
        XCTAssertEqual(pair.laneWidth, (width - spacing) / 2)
        XCTAssertFalse(pair.scrolls, "Two lanes fit, so the strip must stay still")
    }

    /// Dividing by the true lane count was tried and reverted: at three lanes
    /// every title truncated to an ellipsis. Lanes hold the two-up width and the
    /// cluster scrolls instead.
    func testBeyondTwoLanesKeepsTheTwoUpWidthAndScrolls() {
        let width: CGFloat = 258
        let spacing: CGFloat = 6
        let twoUp = (width - spacing) / 2

        for laneCount in 3...10 {
            let metrics = PlanTimelineLaneResolver.laneMetrics(
                laneCount: laneCount, availableWidth: width, spacing: spacing
            )
            XCTAssertEqual(
                metrics.laneWidth, twoUp, accuracy: 0.01,
                "\(laneCount) lanes must not shrink below the readable two-up width"
            )
            XCTAssertTrue(metrics.scrolls, "\(laneCount) lanes cannot fit and must scroll")
        }
    }

    func testExactlyTwoLanesAreVisibleWhateverTheDensity() {
        let width: CGFloat = 258
        let spacing: CGFloat = 6
        for laneCount in 2...12 {
            let metrics = PlanTimelineLaneResolver.laneMetrics(
                laneCount: laneCount, availableWidth: width, spacing: spacing
            )
            let visible = metrics.laneWidth * 2 + spacing
            XCTAssertEqual(
                visible, width, accuracy: 0.01,
                "\(laneCount) lanes should still show two across the full canvas"
            )
        }
    }

    func testTheStripCannotBePannedIntoEmptySpace() {
        let contentWidth: CGFloat = 258
        let strip = PlanTimelineLaneResolver.stripWidth(laneCount: 3, laneWidth: 126, spacing: 6)
        XCTAssertEqual(strip, 126 * 3 + 12)

        func clamp(_ offset: CGFloat) -> CGFloat {
            PlanTimelineLaneResolver.clampedStripOffset(
                offset, contentWidth: contentWidth, stripWidth: strip
            )
        }

        XCTAssertEqual(clamp(0), 0)
        XCTAssertEqual(clamp(200), 0, "Dragging right past the first lane must not expose a gap")
        XCTAssertEqual(
            clamp(-10_000), contentWidth - strip,
            "Dragging left must stop at the last lane's trailing edge"
        )
        XCTAssertEqual(clamp(-60), -60, "A pan inside the range is left alone")
    }

    func testAStripThatAlreadyFitsNeverMoves() {
        let strip = PlanTimelineLaneResolver.stripWidth(laneCount: 2, laneWidth: 126, spacing: 6)
        for offset in [CGFloat(-500), -1, 0, 1, 500] {
            XCTAssertEqual(
                PlanTimelineLaneResolver.clampedStripOffset(
                    offset, contentWidth: 258, stripWidth: strip
                ),
                0,
                "Two lanes fit the canvas, so there is nothing to pan to"
            )
        }
    }

    // MARK: Root transition

    func testTheCurrentRootSitsOnScreen() {
        for destination in LifeBoardDestination.allCases {
            XCTAssertEqual(
                LifeBoardRootTransition.offset(for: destination, selected: destination), 0,
                "\(destination) is the current root and must be centred"
            )
        }
    }

    func testARootWaitsOnTheSideItOccupiesInTheDock() {
        let order = LifeBoardDestination.allCases
        let middle = order[2]
        for (index, destination) in order.enumerated() where destination != middle {
            let offset = LifeBoardRootTransition.offset(
                for: destination, selected: middle, distance: 24
            )
            if index < 2 {
                XCTAssertEqual(offset, -24, "\(destination) sits left of \(middle) in the dock")
            } else {
                XCTAssertEqual(offset, 24, "\(destination) sits right of \(middle) in the dock")
            }
        }
    }

    /// Distance is capped rather than scaled by how far apart the roots are: a
    /// far root is invisible either way, and a longer throw only slows arrival.
    func testDistantRootsAreNoFurtherOffThanNeighbours() {
        let order = LifeBoardDestination.allCases
        let neighbour = LifeBoardRootTransition.offset(
            for: order[1], selected: order[0], distance: 24
        )
        let distant = LifeBoardRootTransition.offset(
            for: order[order.count - 1], selected: order[0], distance: 24
        )
        XCTAssertEqual(neighbour, distant)
    }

    func testReduceMotionCollapsesTheSlideToAPlainChange() {
        let order = LifeBoardDestination.allCases
        for destination in order {
            XCTAssertEqual(
                LifeBoardRootTransition.offset(for: destination, selected: order[0], distance: 0),
                0,
                "With no distance every root rests centred and only the crossfade remains"
            )
        }
    }

    // MARK: Root retention

    /// The Home "Open Plan" regression. `router.select(.plan)` is observed by
    /// the render pass before `onChange` can record the visit, so the pass that
    /// first sees Plan selected must already render it. Rendering on the
    /// visited set alone left that pass with Home faded out and Plan not yet
    /// built, and the white window backing showed through the gap.
    func testTheSelectedRootIsRenderedBeforeItHasEverBeenVisited() {
        for destination in LifeBoardDestination.allCases {
            XCTAssertTrue(
                LifeBoardRootRetention.isRendered(destination, selected: destination, visited: []),
                "\(destination) is selected, so it must be on screen even on the pass that selects it"
            )
        }
    }

    /// The property the blank frame violated, stated directly: at every
    /// combination of selection and visited set, something is on screen.
    func testSomeRootIsAlwaysOnScreen() {
        let order = LifeBoardDestination.allCases
        var visited: Set<LifeBoardDestination> = []
        for selected in order + order.reversed() {
            let rendered = order.filter {
                LifeBoardRootRetention.isRendered($0, selected: selected, visited: visited)
            }
            XCTAssertTrue(
                rendered.contains(selected),
                "Selecting \(selected) with visited=\(visited.count) left no visible root"
            )
            visited = LifeBoardRootRetention.retained(
                visited: visited, previous: nil, selected: selected
            )
        }
    }

    func testAVisitedRootStaysInTheStackAfterTheSelectionMovesOn() {
        let visited = LifeBoardRootRetention.retained(
            visited: [], previous: nil, selected: .home
        )
        XCTAssertTrue(
            LifeBoardRootRetention.isRendered(.home, selected: .plan, visited: visited),
            "Home keeps its scroll position and navigation depth while Plan is on screen"
        )
        XCTAssertFalse(
            LifeBoardRootRetention.isRendered(.track, selected: .plan, visited: visited),
            "An unvisited root is not built just because another root is selected"
        )
    }

    /// Eva is evicted on the way out, but eviction must never be able to blank
    /// the screen: it only ever removes a root that is no longer selected.
    func testEvaIsEvictedOnTheWayOutAndStillRendersWhileSelected() {
        var visited = LifeBoardRootRetention.retained(
            visited: [.home], previous: .home, selected: .eva
        )
        XCTAssertTrue(
            LifeBoardRootRetention.isRendered(.eva, selected: .eva, visited: visited),
            "Eva is on screen while it is the selection"
        )
        visited = LifeBoardRootRetention.retained(
            visited: visited, previous: .eva, selected: .plan
        )
        XCTAssertFalse(visited.contains(.eva), "Eva's runtime is released once it is off screen")
        XCTAssertTrue(
            LifeBoardRootRetention.isRendered(.plan, selected: .plan, visited: visited),
            "The arriving root is still rendered in the same pass that evicts Eva"
        )
    }

    /// Home ↔ Plan hammered back and forth: no pass may render an empty stack,
    /// and the two roots must not be rebuilt on each change.
    func testRapidRootChangesNeverProduceAnEmptyStack() {
        var visited: Set<LifeBoardDestination> = []
        var previous: LifeBoardDestination?
        for step in 0..<12 {
            let selected: LifeBoardDestination = step.isMultiple(of: 2) ? .home : .plan
            XCTAssertTrue(
                LifeBoardRootRetention.isRendered(selected, selected: selected, visited: visited),
                "Step \(step) selected \(selected) with nothing rendered"
            )
            visited = LifeBoardRootRetention.retained(
                visited: visited, previous: previous, selected: selected
            )
            previous = selected
        }
        XCTAssertEqual(
            visited, [.home, .plan],
            "Both roots are retained, so neither is rebuilt on each change"
        )
    }

    // MARK: Celestial daypart indicator

    private func moment(_ hour: Int, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 27
        components.hour = hour
        components.minute = minute
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private var gregorian: Calendar { Calendar(identifier: .gregorian) }

    func testDayProgressTracksTheClockIncludingMinutes() {
        XCTAssertEqual(LifeBoardDaypartProgress.dayProgress(at: moment(0), calendar: gregorian), 0, accuracy: 0.0001)
        XCTAssertEqual(LifeBoardDaypartProgress.dayProgress(at: moment(12), calendar: gregorian), 0.5, accuracy: 0.0001)
        XCTAssertEqual(LifeBoardDaypartProgress.dayProgress(at: moment(18), calendar: gregorian), 0.75, accuracy: 0.0001)
        XCTAssertGreaterThan(
            LifeBoardDaypartProgress.dayProgress(at: moment(9, 30), calendar: gregorian),
            LifeBoardDaypartProgress.dayProgress(at: moment(9, 0), calendar: gregorian),
            "Half an hour must move the indicator, or it looks frozen"
        )
    }

    func testPhaseProgressIsMeasuredWithinTheMomentsOwnPhase() {
        // Midday runs 12:00–17:00, so 14:30 is half way through it.
        XCTAssertEqual(
            LifeBoardDaypartProgress.phaseProgress(at: moment(14, 30), calendar: gregorian),
            0.5, accuracy: 0.0001
        )
        // Golden hour runs 17:00–19:00.
        XCTAssertEqual(
            LifeBoardDaypartProgress.phaseProgress(at: moment(18), calendar: gregorian),
            0.5, accuracy: 0.0001
        )
    }

    /// Night runs 21:00 to 05:00. The hours after midnight are late in that
    /// phase, not the start of a new one — the wrap is where this goes wrong.
    func testNightProgressCarriesAcrossMidnight() {
        let evening = LifeBoardDaypartProgress.phaseProgress(at: moment(22), calendar: gregorian)
        let smallHours = LifeBoardDaypartProgress.phaseProgress(at: moment(3), calendar: gregorian)

        XCTAssertEqual(evening, 0.125, accuracy: 0.0001, "22:00 is one hour into an eight-hour night")
        XCTAssertEqual(smallHours, 0.75, accuracy: 0.0001, "03:00 is six hours in")
        XCTAssertGreaterThan(smallHours, evening, "After midnight must read as later, not earlier")
    }

    func testTheArcGivesDaylightAndNightTheirOwnFullSweep() {
        XCTAssertEqual(LifeBoardDaypartProgress.arcProgress(at: moment(5), calendar: gregorian), 0, accuracy: 0.0001)
        XCTAssertEqual(LifeBoardDaypartProgress.arcProgress(at: moment(13), calendar: gregorian), 0.5, accuracy: 0.0001)
        XCTAssertEqual(LifeBoardDaypartProgress.arcProgress(at: moment(20, 59), calendar: gregorian), 1, accuracy: 0.01)

        // Night restarts the sweep so the moon rises rather than resuming at dusk's height.
        XCTAssertEqual(LifeBoardDaypartProgress.arcProgress(at: moment(21), calendar: gregorian), 0, accuracy: 0.0001)
        XCTAssertEqual(LifeBoardDaypartProgress.arcProgress(at: moment(1), calendar: gregorian), 0.5, accuracy: 0.0001)
    }

    func testDaylightIsEveryPhaseButNight() {
        XCTAssertTrue(LifeBoardDaypartProgress.isDaylight(at: moment(6), calendar: gregorian))
        XCTAssertTrue(LifeBoardDaypartProgress.isDaylight(at: moment(16), calendar: gregorian))
        XCTAssertTrue(LifeBoardDaypartProgress.isDaylight(at: moment(20), calendar: gregorian))
        XCTAssertFalse(LifeBoardDaypartProgress.isDaylight(at: moment(23), calendar: gregorian))
        XCTAssertFalse(LifeBoardDaypartProgress.isDaylight(at: moment(2), calendar: gregorian))
    }

    func testPhaseBoundsCoverTheWholeDayWithoutOverlap() {
        let total = LifeBoardCelestialPhase.allCases
            .map { LifeBoardDaypartProgress.bounds(of: $0).length }
            .reduce(0, +)
        XCTAssertEqual(total, 24, "The phases must tile the day exactly once")
    }

    func testTheCelestialBodyRisesAndSetsAcrossTheArc() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let rise = LifeBoardCelestialArc.point(forProgress: 0, in: rect)
        let peak = LifeBoardCelestialArc.point(forProgress: 0.5, in: rect)
        let set = LifeBoardCelestialArc.point(forProgress: 1, in: rect)

        XCTAssertEqual(rise.x, 0, accuracy: 0.001)
        XCTAssertEqual(rise.y, rect.maxY, accuracy: 0.001, "It starts on the horizon")
        XCTAssertEqual(peak.x, rect.midX, accuracy: 0.001)
        XCTAssertEqual(peak.y, rect.minY, accuracy: 0.001, "Highest at the midpoint")
        XCTAssertEqual(set.x, rect.maxX, accuracy: 0.001)
        XCTAssertEqual(set.y, rect.maxY, accuracy: 0.001, "And returns to the horizon")
    }

    // MARK: Arc dial

    func testTheDialRunsFromItsStartAngleToItsEnd() {
        XCTAssertEqual(
            LifeBoardArcDialGeometry.angle(forProgress: 0),
            LifeBoardArcDialGeometry.startAngle
        )
        XCTAssertEqual(
            LifeBoardArcDialGeometry.angle(forProgress: 1),
            LifeBoardArcDialGeometry.endAngle
        )
        XCTAssertEqual(
            LifeBoardArcDialGeometry.angle(forProgress: 0.5),
            LifeBoardArcDialGeometry.startAngle + LifeBoardArcDialGeometry.sweep / 2
        )
    }

    func testProgressOutsideTheTrackIsClampedNotWrapped() {
        XCTAssertEqual(LifeBoardArcDialGeometry.angle(forProgress: -3), LifeBoardArcDialGeometry.startAngle)
        XCTAssertEqual(LifeBoardArcDialGeometry.angle(forProgress: 4), LifeBoardArcDialGeometry.endAngle)
    }

    /// The gap at the bottom of the dial is where a wrap-around bug lives: a
    /// thumb crossing it must park at the near end, never jump the full range.
    func testAnAngleInTheGapSnapsToTheNearerEnd() {
        let gap = 360 - LifeBoardArcDialGeometry.sweep
        let justPastEnd = LifeBoardArcDialGeometry.endAngle + gap * 0.2
        let justBeforeStart = LifeBoardArcDialGeometry.startAngle - gap * 0.2

        XCTAssertEqual(LifeBoardArcDialGeometry.progress(forAngle: justPastEnd), 1)
        XCTAssertEqual(LifeBoardArcDialGeometry.progress(forAngle: justBeforeStart), 0)
    }

    func testAngleAndProgressRoundTrip() {
        for percent in stride(from: 0.0, through: 1.0, by: 0.05) {
            let angle = LifeBoardArcDialGeometry.angle(forProgress: percent)
            XCTAssertEqual(
                LifeBoardArcDialGeometry.progress(forAngle: angle), percent, accuracy: 0.0001,
                "Progress \(percent) did not survive the trip through its angle"
            )
        }
    }

    func testATouchIsReadAsAnAngleWhereverItLands() {
        let center = CGPoint(x: 100, y: 100)
        // Straight up is the midpoint of a 270° sweep starting down-left.
        let up = LifeBoardArcDialGeometry.progress(at: CGPoint(x: 100, y: 20), center: center)
        XCTAssertEqual(up, 0.5, accuracy: 0.0001)

        // Distance must not matter: the same bearing far off the ring reads the same.
        let farUp = LifeBoardArcDialGeometry.progress(at: CGPoint(x: 100, y: -900), center: center)
        XCTAssertEqual(farUp, up, accuracy: 0.0001)

        // The track starts south-west and runs clockwise through west and north,
        // so west is one sixth along and east is five sixths.
        XCTAssertEqual(
            LifeBoardArcDialGeometry.progress(at: CGPoint(x: 20, y: 100), center: center),
            1.0 / 6.0, accuracy: 0.0001, "Due west"
        )
        XCTAssertEqual(
            LifeBoardArcDialGeometry.progress(at: CGPoint(x: 180, y: 100), center: center),
            5.0 / 6.0, accuracy: 0.0001, "Due east"
        )
    }

    func testValuesQuantiseToTheirStepAndStayInRange() {
        let range = 0.0...60.0
        XCTAssertEqual(
            LifeBoardArcDialGeometry.value(forProgress: 0.5, range: range, step: 15), 30
        )
        XCTAssertEqual(
            LifeBoardArcDialGeometry.value(forProgress: 0.13, range: range, step: 15), 15,
            "A value between detents lands on the nearest one"
        )
        XCTAssertEqual(LifeBoardArcDialGeometry.value(forProgress: -5, range: range, step: 15), 0)
        XCTAssertEqual(LifeBoardArcDialGeometry.value(forProgress: 5, range: range, step: 15), 60)
    }

    func testADegenerateRangeCannotProduceNonsense() {
        let flat = 20.0...20.0
        XCTAssertEqual(LifeBoardArcDialGeometry.value(forProgress: 0.7, range: flat, step: 5), 20)
        XCTAssertEqual(LifeBoardArcDialGeometry.progress(forValue: 20, range: flat), 0)
    }

    func testAStepOfZeroLeavesTheValueContinuous() {
        let range = 0.0...10.0
        XCTAssertEqual(
            LifeBoardArcDialGeometry.value(forProgress: 0.333, range: range, step: 0),
            3.33, accuracy: 0.0001
        )
    }

    // MARK: Plan repair deck

    private static let fourRepairs: [PlanRepairAction] =
        [.moveLaterToday, .moveToAnotherDay, .split, .defer]

    private func flick(_ dx: CGFloat, _ dy: CGFloat) -> PlanRepairAction? {
        PlanRepairDeckDragResolver.action(
            translation: CGSize(width: dx, height: dy),
            predictedEndTranslation: CGSize(width: dx, height: dy),
            candidates: Self.fourRepairs
        )
    }

    func testEachDirectionCommitsItsOwnRepair() {
        XCTAssertEqual(flick(140, 0), .moveLaterToday, "Right is the first repair")
        XCTAssertEqual(flick(-140, 0), .moveToAnotherDay, "Left is the second")
        XCTAssertEqual(flick(0, -140), .split, "Up is the third")
        XCTAssertEqual(flick(0, 140), .defer, "Down is the fourth")
    }

    func testDirectionsWithoutARepairCommitNothing() {
        // A proposal offering two ways out must not invent a third and fourth.
        let two: [PlanRepairAction] = [.resume, .leaveUnchanged]
        XCTAssertEqual(PlanRepairDeckDragResolver.action(for: .right, candidates: two), .resume)
        XCTAssertEqual(PlanRepairDeckDragResolver.action(for: .left, candidates: two), .leaveUnchanged)
        XCTAssertNil(PlanRepairDeckDragResolver.action(for: .up, candidates: two))
        XCTAssertNil(PlanRepairDeckDragResolver.action(for: .down, candidates: two))
    }

    func testAShortFlickIsNotEnoughToChangeThePlan() {
        XCTAssertNil(flick(40, 0), "Below threshold must not mutate the plan")
        XCTAssertNil(flick(0, 40))
        XCTAssertNil(flick(10, 4), "Barely a touch is not intent")
    }

    func testDiagonalsResolveToNothingRatherThanGuessing() {
        // Committing the wrong repair edits the user's day, so an ambiguous
        // throw must do nothing at all.
        XCTAssertNil(flick(140, 140))
        XCTAssertNil(flick(-140, 130))
        XCTAssertNil(flick(120, -120))
    }

    func testDominantAxisWinsWhenAFlickIsOnlySlightlyOffAxis() {
        XCTAssertEqual(flick(160, 30), .moveLaterToday)
        XCTAssertEqual(flick(-160, -30), .moveToAnotherDay)
        XCTAssertEqual(flick(25, -160), .split)
        XCTAssertEqual(flick(-25, 160), .defer)
    }

    func testACardLeavesTheWayItWasThrown() {
        XCTAssertEqual(
            PlanRepairDeckDragResolver.exitOffset(for: .right, distance: 400),
            CGSize(width: 400, height: 0)
        )
        XCTAssertEqual(
            PlanRepairDeckDragResolver.exitOffset(for: .up, distance: 400),
            CGSize(width: 0, height: -400)
        )
        XCTAssertEqual(
            PlanRepairDeckDragResolver.exitOffset(for: .down, distance: 400),
            CGSize(width: 0, height: 400)
        )
    }

    func testAnEmptyProposalCannotBeFlickedIntoAMutation() {
        XCTAssertNil(
            PlanRepairDeckDragResolver.action(
                translation: CGSize(width: 200, height: 0),
                predictedEndTranslation: CGSize(width: 200, height: 0),
                candidates: []
            )
        )
    }

    // MARK: Kinetic greeting

    func testKineticGreetingIsPerfectlyStillAtRest() {
        // This is the screenshot-stability guarantee: with no touch, or with
        // intensity at zero, every glyph must draw exactly where SwiftUI laid
        // it out, or the appearance fixture matrix stops being deterministic.
        for midX in stride(from: 0.0, through: 320.0, by: 16.0) {
            XCTAssertEqual(
                LifeBoardKineticTextRenderer.rise(glyphMidX: CGFloat(midX), touchX: nil, intensity: 1),
                0,
                "An untouched greeting must not move"
            )
            XCTAssertEqual(
                LifeBoardKineticTextRenderer.rise(glyphMidX: CGFloat(midX), touchX: 120, intensity: 0),
                0,
                "A settled greeting must not move"
            )
        }
    }

    func testKineticGreetingRiseStaysWithinItsBoundAndPeaksUnderTheFinger() {
        let touchX: CGFloat = 140
        let peak = LifeBoardKineticTextRenderer.rise(glyphMidX: touchX, touchX: touchX, intensity: 1)
        XCTAssertEqual(peak, -LifeBoardKineticTextRenderer.maximumRise, accuracy: 0.0001)

        var previousMagnitude = abs(peak)
        for offset in stride(from: 0.0, through: 240.0, by: 8.0) {
            let rise = LifeBoardKineticTextRenderer.rise(
                glyphMidX: touchX + CGFloat(offset), touchX: touchX, intensity: 1
            )
            XCTAssertLessThanOrEqual(
                abs(rise), LifeBoardKineticTextRenderer.maximumRise + 0.0001,
                "Displacement must stay bounded so the line stays readable"
            )
            XCTAssertLessThanOrEqual(
                abs(rise), previousMagnitude + 0.0001,
                "Influence must fall off with distance from the finger"
            )
            previousMagnitude = abs(rise)

            // Symmetric either side of the finger.
            let mirrored = LifeBoardKineticTextRenderer.rise(
                glyphMidX: touchX - CGFloat(offset), touchX: touchX, intensity: 1
            )
            XCTAssertEqual(rise, mirrored, accuracy: 0.0001)
        }
    }

    func testKineticGreetingIntensityIsTheAnimatableChannel() {
        var renderer = LifeBoardKineticTextRenderer(touchX: 40, intensity: 0.25)
        renderer.animatableData = 0.8
        XCTAssertEqual(renderer.intensity, 0.8)
        XCTAssertEqual(renderer.animatableData, 0.8)

        // Out-of-range intensity clamps rather than flinging glyphs off-line.
        let overdriven = LifeBoardKineticTextRenderer.rise(glyphMidX: 40, touchX: 40, intensity: 9)
        XCTAssertEqual(overdriven, -LifeBoardKineticTextRenderer.maximumRise, accuracy: 0.0001)
    }

    // MARK: Schedule snapping

    func testScheduleDragSnapsToFiveMinutesForCorrectionsAndFifteenForRealMoves() {
        let hourHeight: CGFloat = 66
        let wide = -600...600

        // 8 minutes of travel is a correction: it lands on the 5-minute grid.
        let smallTravel = CGFloat(8.0 / 60 * Double(hourHeight))
        XCTAssertEqual(
            PlanBlockSnapResolver.snappedMinutes(translation: smallTravel, hourHeight: hourHeight, bounds: wide),
            10
        )

        // 47 minutes is a real move: it lands on the 15-minute grid.
        let largeTravel = CGFloat(47.0 / 60 * Double(hourHeight))
        XCTAssertEqual(
            PlanBlockSnapResolver.snappedMinutes(translation: largeTravel, hourHeight: hourHeight, bounds: wide),
            45
        )
    }

    func testScheduleDragSnapIsSymmetricAndRestsAtZero() {
        let hourHeight: CGFloat = 66
        let wide = -600...600
        XCTAssertEqual(
            PlanBlockSnapResolver.snappedMinutes(translation: 0, hourHeight: hourHeight, bounds: wide),
            0,
            "An untouched block must not drift"
        )
        for minutes in stride(from: 5.0, through: 120.0, by: 5.0) {
            let travel = CGFloat(minutes / 60 * Double(hourHeight))
            let up = PlanBlockSnapResolver.snappedMinutes(translation: -travel, hourHeight: hourHeight, bounds: wide)
            let down = PlanBlockSnapResolver.snappedMinutes(translation: travel, hourHeight: hourHeight, bounds: wide)
            XCTAssertEqual(up, -down, "Dragging up and down by \(minutes)m must be symmetric")
        }
    }

    func testScheduleDragSnapAlwaysLandsOnTheGridAndInsideTheDay() {
        let hourHeight: CGFloat = 66
        let bounds = -90...120
        for step in stride(from: -900.0, through: 900.0, by: 7.0) {
            let snapped = PlanBlockSnapResolver.snappedMinutes(
                translation: CGFloat(step), hourHeight: hourHeight, bounds: bounds
            )
            XCTAssertTrue(bounds.contains(snapped), "\(snapped) escaped the drawn day")
            let onFine = snapped % PlanBlockSnapResolver.fineStepMinutes == 0
            let onCoarse = snapped % PlanBlockSnapResolver.coarseStepMinutes == 0
            XCTAssertTrue(
                onFine || onCoarse || snapped == bounds.lowerBound || snapped == bounds.upperBound,
                "\(snapped) is off-grid"
            )
        }
    }

    func testScheduleDragSnapIsMonotonicSoTheBlockNeverMovesAgainstTheFinger() {
        let hourHeight: CGFloat = 66
        let bounds = -600...600
        var previous = PlanBlockSnapResolver.snappedMinutes(
            translation: -400, hourHeight: hourHeight, bounds: bounds
        )
        for step in stride(from: -400.0, through: 400.0, by: 3.0) {
            let snapped = PlanBlockSnapResolver.snappedMinutes(
                translation: CGFloat(step), hourHeight: hourHeight, bounds: bounds
            )
            XCTAssertGreaterThanOrEqual(snapped, previous, "Block jumped backwards at \(step)")
            previous = snapped
        }
    }

    func testScheduleDragSnapSurvivesADegenerateCanvas() {
        XCTAssertEqual(
            PlanBlockSnapResolver.snappedMinutes(translation: 120, hourHeight: 0, bounds: -60...60),
            0,
            "A zero-height canvas must not divide by zero or fling the block"
        )
        XCTAssertEqual(
            PlanBlockSnapResolver.snappedMinutes(translation: 500, hourHeight: 66, bounds: 0...0),
            0,
            "A block with no room to move must stay put"
        )
    }

    func testResizeUsesFiveMinuteGridOnlyNearARealBoundary() {
        let edge = Date(timeIntervalSince1970: 10_000)
        let hourHeight: CGFloat = 60
        let translation: CGFloat = 20 // Twenty raw minutes.

        let nearBoundary = PlanBlockSnapResolver.boundaryAwareSnappedMinutes(
            translation: translation,
            hourHeight: hourHeight,
            movingEdgeAt: edge,
            boundaries: [edge.addingTimeInterval(22 * 60)],
            bounds: -120...120
        )
        let withoutBoundary = PlanBlockSnapResolver.boundaryAwareSnappedMinutes(
            translation: translation,
            hourHeight: hourHeight,
            movingEdgeAt: edge,
            boundaries: [],
            bounds: -120...120
        )

        XCTAssertEqual(nearBoundary, 20)
        XCTAssertEqual(withoutBoundary, 15)
    }

    func testResizeBoundarySnapClampsToFifteenMinuteMinimumBounds() {
        let edge = Date(timeIntervalSince1970: 10_000)
        let snapped = PlanBlockSnapResolver.boundaryAwareSnappedMinutes(
            translation: -500,
            hourHeight: 60,
            movingEdgeAt: edge,
            boundaries: [edge.addingTimeInterval(-480 * 60)],
            bounds: -45...300
        )
        XCTAssertEqual(snapped, -45)
    }

    private nonisolated func completionModelBundleURL() throws -> URL {
        for bundle in [Bundle.main, Bundle(for: Self.self)] {
            if let url = bundle.url(forResource: "TaskModelV3", withExtension: "momd") { return url }
        }
        throw NSError(domain: "LifeOSFoundationContractTests", code: 1)
    }

    private nonisolated func loadCompletionStores(_ container: NSPersistentContainer) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let lock = NSLock()
            var remaining = container.persistentStoreDescriptions.count
            var firstError: (any Error)?
            container.loadPersistentStores { _, error in
                lock.lock()
                if firstError == nil { firstError = error }
                remaining -= 1
                let isFinished = remaining == 0
                let resolvedError = firstError
                lock.unlock()
                guard isFinished else { return }
                if let resolvedError { continuation.resume(throwing: resolvedError) }
                else { continuation.resume() }
            }
        }
    }

    /// The shipping model keeps every health-sensitive entity in both the
    /// `CloudSync` and `LocalOnly` configurations so
    /// `HealthPrivacyMigrationCoordinator` can copy each row into its private
    /// local store, and `HealthPrivacyMigrationAccess.requireValidated` refuses
    /// writes until that copy is checkpointed. A repository round trip therefore
    /// has to run against a two-configuration container with a validated
    /// checkpoint — a single unconfigured store makes the production gate throw
    /// `writeClosed`, which says nothing about the repository under test.
    private nonisolated func makeHealthPrivacyValidatedContainer(
        name: String
    ) async throws -> NSPersistentContainer {
        let model = try XCTUnwrap(
            NSManagedObjectModel(
                contentsOf: try completionModelBundleURL()
                    .appendingPathComponent("TaskModelV3_BehaviorFlagship.mom")
            )
        )
        let container = NSPersistentContainer(name: name, managedObjectModel: model)
        let cloud = NSPersistentStoreDescription()
        cloud.type = NSInMemoryStoreType
        cloud.configuration = "CloudSync"
        cloud.url = URL(fileURLWithPath: "/dev/null/cloud-\(UUID().uuidString)")
        let local = NSPersistentStoreDescription()
        local.type = NSInMemoryStoreType
        local.configuration = "LocalOnly"
        local.url = URL(fileURLWithPath: "/dev/null/local-\(UUID().uuidString)")
        container.persistentStoreDescriptions = [cloud, local]
        try await loadCompletionStores(container)

        let localStore = try XCTUnwrap(
            container.persistentStoreCoordinator.persistentStores.first {
                $0.configurationName == "LocalOnly"
            },
            "The LocalOnly configuration has to load for the health privacy gate to open"
        )
        let context = container.newBackgroundContext()
        try await context.perform {
            let checkpoint = NSEntityDescription.insertNewObject(
                forEntityName: "HealthMigrationCheckpoint",
                into: context
            )
            context.assign(checkpoint, to: localStore)
            checkpoint.setValue("overall", forKey: "id")
            checkpoint.setValue("validated", forKey: "phaseRaw")
            checkpoint.setValue(Date(), forKey: "completedAt")
            checkpoint.setValue(Date(), forKey: "updatedAt")
            try context.save()
        }
        return container
    }

    func testCapturePresentationContextRoundTripsWithoutChangingTheMutationRequest() throws {
        let request = CaptureRequest(
            kind: .journal,
            source: .shell,
            presentationContext: .init(
                sourceRoot: .home,
                sourcePoint: .init(x: 0.9, y: 0.1),
                preferredCaptureKind: .journal
            )
        )
        let decoded = try JSONDecoder().decode(
            CaptureRequest.self,
            from: JSONEncoder().encode(request)
        )

        XCTAssertEqual(decoded.kind, .journal)
        XCTAssertEqual(decoded.presentationContext?.sourceRoot, .home)
        XCTAssertEqual(decoded.presentationContext?.sourcePoint, .init(x: 0.9, y: 0.1))
        XCTAssertEqual(decoded.presentationContext?.preferredCaptureKind, .journal)
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

        // Dark appearance must still express the *current* daypart. This
        // previously asserted that morning-in-dark resolved to the night
        // palette, which is precisely why a dark-mode user saw the same screen
        // at 7am and 11pm.
        let dark = LifeBoardDaypartTokens.functionalPalette(for: .morning, colorScheme: .dark)
        XCTAssertEqual(dark.canvas, LifeBoardDaypartTokens.morningDark.canvas)
        XCTAssertNotEqual(dark.canvas, LifeBoardDaypartTokens.night.canvas)
        XCTAssertTrue(dark.isNocturnal, "A dark-appearance palette must report itself as nocturnal")
        XCTAssertEqual(dark.daypart, .morning)
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
        XCTAssertEqual(LifeBoardDaypartTokens.morning.canvas, "#FFF9E4")
        XCTAssertEqual(LifeBoardDaypartTokens.morning.celestialPrimary, "#F7D98E")
        XCTAssertEqual(LifeBoardDaypartTokens.afternoon.canvas, "#FFF2C9")
        XCTAssertEqual(LifeBoardDaypartTokens.afternoon.celestialPrimary, "#F3C45F")
        XCTAssertEqual(LifeBoardDaypartTokens.evening.foreground, "#2B2118")
        XCTAssertEqual(LifeBoardDaypartTokens.night.canvas, "#151B2D")
        XCTAssertEqual(LifeBoardDaypartTokens.night.foreground, "#F7F1E7")
    }

    /// The adaptive-daypart promise is that the screen is recognisably
    /// different at different times. Morning and afternoon previously shared an
    /// identical canvas, canvasSecondary, layerOne, coolMist and highlight and
    /// differed only in `celestialCore`, which the swatch test above happily
    /// locked in place. This asserts the property that actually matters, so a
    /// regression back to a single shared canvas fails loudly.
    func testLightDaypartsAreVisuallyDistinct() {
        let canvases = ResolvedDaypart.allCases.map { LifeBoardDaypartTokens.palette(for: $0).canvas }
        XCTAssertEqual(Set(canvases).count, ResolvedDaypart.allCases.count,
                       "Every daypart needs its own canvas")

        let celestials = ResolvedDaypart.allCases.map { LifeBoardDaypartTokens.palette(for: $0).celestialPrimary }
        XCTAssertEqual(Set(celestials).count, ResolvedDaypart.allCases.count,
                       "Every daypart needs its own celestial colour")
    }

    /// The dark compositions must be distinct from each other too, and every
    /// one of them must actually be dark.
    func testDarkDaypartsAreDistinctAndDark() throws {
        let canvases = ResolvedDaypart.allCases.map { LifeBoardDaypartTokens.darkPalette(for: $0).canvas }
        XCTAssertEqual(Set(canvases).count, ResolvedDaypart.allCases.count,
                       "Every daypart needs its own dark canvas")

        for daypart in ResolvedDaypart.allCases {
            let palette = LifeBoardDaypartTokens.darkPalette(for: daypart)
            let canvas = try rgbComponents(from: palette.canvas)
            XCTAssertLessThan(relativeLuminance(canvas), 0.04,
                              "\(daypart.rawValue) dark canvas must be genuinely dark")
            XCTAssertGreaterThanOrEqual(
                contrastRatio(try rgbComponents(from: palette.foreground), canvas),
                4.5,
                "Primary text must stay readable on the \(daypart.rawValue) dark canvas"
            )
            XCTAssertGreaterThanOrEqual(
                contrastRatio(try rgbComponents(from: palette.foregroundSecondary), canvas),
                4.5,
                "Secondary text must stay readable on the \(daypart.rawValue) dark canvas"
            )
        }
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

    func testSharedMotionPolicySeparatesFocusedAndCalmIdleMotionFromDirectInteraction() {
        let calm = LifeBoardMotionPolicy.resolve(
            reduceMotion: false,
            reduceTransparency: false,
            lowPowerMode: false,
            thermalState: .nominal,
            sceneIsActive: true,
            comfortProfile: .calm
        )
        XCTAssertFalse(calm.allowsIdleMotion)
        XCTAssertTrue(calm.allowsSpatialMotion)
        XCTAssertFalse(calm.allowsCustomShaders)

        let focused = LifeBoardMotionPolicy.resolve(
            reduceMotion: false,
            reduceTransparency: false,
            lowPowerMode: false,
            thermalState: .nominal,
            sceneIsActive: true,
            comfortProfile: .balanced,
            isFocusedPresentation: true
        )
        XCTAssertFalse(focused.allowsIdleMotion)
        XCTAssertTrue(focused.allowsSpatialMotion)
        XCTAssertFalse(focused.allowsCustomShaders)
        XCTAssertTrue(focused.isFocusedPresentation)
    }

    @MainActor
    func testTransitionCoordinatorClaimsSemanticEffectsOnlyOnceUntilReset() {
        let coordinator = LifeBoardTransitionCoordinator()
        XCTAssertTrue(coordinator.claimOneShot("task.completed.1"))
        XCTAssertFalse(coordinator.claimOneShot("task.completed.1"))
        coordinator.resetOneShot("task.completed.1")
        XCTAssertTrue(coordinator.claimOneShot("task.completed.1"))
    }

    func testSpatialRoutesUseStableContentIdentitiesAndRestrainedModes() {
        let taskID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
        let noteID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
        XCTAssertEqual(AppRoute.taskDetail(taskID).spatialTransitionID, "route.task.\(taskID.uuidString)")
        XCTAssertEqual(AppRoute.note(noteID).spatialTransitionID, "route.note.\(noteID.uuidString)")
        XCTAssertNil(
            AppRoute.notesLibrary(.library(.init(
                collection: .pinned,
                searchText: "launch",
                sort: .titleAscending
            ))).spatialTransitionID
        )
        XCTAssertEqual(AppRoute.taskDetail(taskID).screenMode, .editor)
        XCTAssertEqual(AppRoute.note(noteID).screenMode, .editor)
        XCTAssertNil(AppRoute.settings.spatialTransitionID)
        XCTAssertEqual(AppRoute.settings.screenMode, .utility)
        XCTAssertEqual(AppRoute.focusSession(nil).screenMode, .focused)
        XCTAssertEqual(LifeBoardGlassMorphRole.capture.rawValue, "capture")
        XCTAssertEqual(LifeBoardGlassMorphRole.evaComposer.rawValue, "evaComposer")
    }

    func testPlanRepairDeckUsesVelocityButRequiresHorizontalIntent() {
        let candidates: [PlanRepairAction] = [.moveLaterToday, .moveToAnotherDay]
        XCTAssertEqual(
            PlanRepairDeckDragResolver.action(
                translation: CGSize(width: 38, height: 4),
                predictedEndTranslation: CGSize(width: 140, height: 7),
                candidates: candidates
            ),
            .moveLaterToday
        )
        XCTAssertEqual(
            PlanRepairDeckDragResolver.action(
                translation: CGSize(width: -42, height: 4),
                predictedEndTranslation: CGSize(width: -148, height: 8),
                candidates: candidates
            ),
            .moveToAnotherDay
        )
        XCTAssertNil(
            PlanRepairDeckDragResolver.action(
                translation: CGSize(width: 12, height: 2),
                predictedEndTranslation: CGSize(width: 180, height: 4),
                candidates: candidates
            )
        )
        XCTAssertNil(
            PlanRepairDeckDragResolver.action(
                translation: CGSize(width: 50, height: 100),
                predictedEndTranslation: CGSize(width: 120, height: 180),
                candidates: candidates
            )
        )
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

    func testFocusDialProgressUsesElapsedFractionAndClampsDomainEdges() throws {
        XCTAssertNil(
            LifeBoardFocusDialMetrics.elapsedFraction(
                totalDuration: nil,
                remainingDuration: 60
            )
        )
        XCTAssertNil(
            LifeBoardFocusDialMetrics.elapsedFraction(
                totalDuration: 0,
                remainingDuration: 0
            )
        )
        XCTAssertEqual(
            try XCTUnwrap(
                LifeBoardFocusDialMetrics.elapsedFraction(
                    totalDuration: 1_200,
                    remainingDuration: 900
                )
            ),
            0.25,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            LifeBoardFocusDialMetrics.elapsedFraction(
                totalDuration: 1_200,
                remainingDuration: 1_500
            ),
            0
        )
        XCTAssertEqual(
            LifeBoardFocusDialMetrics.elapsedFraction(
                totalDuration: 1_200,
                remainingDuration: -10
            ),
            1
        )
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
    func testNotesLibraryDeepLinkRestoresTypedQueryState() throws {
        let suite = "LifeOSFoundationNotesDeepLinkTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let router = LifeBoardAppRouter(defaults: defaults)
        let folderID = UUID()
        let tagID = UUID()

        XCTAssertTrue(router.handle(url: URL(
            string: "lifeboard://notes?collection=pinned&folder=\(folderID.uuidString)&tag=\(tagID.uuidString)&search=launch&sort=titleAscending"
        )!))
        XCTAssertEqual(router.selectedDestination, .track)
        XCTAssertEqual(
            router.path(for: .track),
            [.notesLibrary(.library(.init(
                collection: .pinned,
                folderID: folderID,
                tagIDs: [tagID],
                searchText: "launch",
                sort: .titleAscending
            )))]
        )
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
            .weeklyReflection(Date(timeIntervalSince1970: 1_789_344_000)),
            .notesLibrary(.library(.init(collection: .recent, searchText: "idea"))), .note(id),
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

        // The nightly summary used to land on Insights while Home's evening row
        // opened the ritual — two destinations for one moment. Both now open the
        // day the notification was written about.
        router.popToRoot(in: .home)
        router.handle(notificationRoute: .dailySummary(kind: .nightly, dateStamp: "20260716"))
        XCTAssertEqual(router.selectedDestination, .home)
        guard case .dayClose(let closedDay)? = router.path(for: .home).last else {
            return XCTFail("The nightly summary must open the day-close ritual")
        }
        // Resolved from the stamp, not from "now": a notification tapped after
        // midnight still closes the day it was written about.
        let closedParts = Calendar.current.dateComponents([.year, .month, .day], from: closedDay)
        XCTAssertEqual(closedParts.year, 2026)
        XCTAssertEqual(closedParts.month, 7)
        XCTAssertEqual(closedParts.day, 16)

        router.popToRoot(in: .home)

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
            "KnowledgeBlock", "KnowledgeTag", "KnowledgeNoteTagLink", "KnowledgeLink", "KnowledgeAttachment",
            "KnowledgeSmartCollection", "KnowledgeNoteRevision", "KnowledgeNoteSecurePayload",
            "GoalStatusEvent", "Recipe", "RecipeIngredient", "MealTemplate", "GroceryList",
            "ServingMemory", "NutritionPreference", "FastingTemplate"
        ] {
            XCTAssertTrue(cloud.contains(name), "\(name) must be in CloudSync")
        }
        for name in ["JournalDerivedIndex", "JournalDraft", "KnowledgeNoteDraft", "KnowledgeGraphPosition"] {
            XCTAssertTrue(local.contains(name), "\(name) must be LocalOnly")
            XCTAssertFalse(cloud.contains(name), "\(name) must never enter CloudSync")
        }
    }

    func testBehaviorFlagshipModelContainsOnlyTheAdditiveBehaviorFields() throws {
        let model = try XCTUnwrap(NSManagedObjectModel.mergedModel(from: [Bundle.main, Bundle(for: Self.self)]))
        let expected: [String: Set<String>] = [
            "MedicationDefinition": [
                "formRaw", "startDate", "endDate", "refillQuantity", "refillRemaining",
                "refillThreshold", "lastRefilledAt"
            ],
            "TrackerDefinition": [
                "valueTypeRaw", "rangeMin", "rangeMax", "aggregationRaw",
                "privacyClassRaw", "isHomeEligible", "choiceOptionsData"
            ],
            "TrackerEntry": ["valueData"],
            "GoalDefinition": [
                "intentRaw", "statusRaw", "baselineValue", "confidenceRaw",
                "whyItMatters", "checkInCadenceRaw", "pausedAt"
            ],
            "HabitDefinition": [
                "quotaTargetCount", "quotaPeriodRaw", "timedTargetSeconds", "minimumTargetData"
            ]
        ]
        for (entityName, fields) in expected {
            let entity = try XCTUnwrap(model.entitiesByName[entityName])
            XCTAssertTrue(
                fields.isSubset(of: Set(entity.attributesByName.keys)),
                "\(entityName) is missing \(fields.subtracting(entity.attributesByName.keys))"
            )
        }
        let statusEvent = try XCTUnwrap(model.entitiesByName["GoalStatusEvent"])
        XCTAssertEqual(
            Set(statusEvent.attributesByName.keys),
            ["id", "goalID", "statusRaw", "reason", "recordedAt"]
        )
        for entityName in [
            "Recipe", "RecipeIngredient", "MealTemplate", "GroceryList",
            "ServingMemory", "NutritionPreference", "FastingTemplate"
        ] {
            XCTAssertNotNil(
                model.entitiesByName[entityName],
                "\(entityName) must be locked into the single unshipped Phase 2 model."
            )
        }
        let nutritionLog = try XCTUnwrap(model.entitiesByName["NutritionLogEntry"])
        XCTAssertTrue(
            Set(["recipeID", "mealTemplateID", "provenanceRaw", "sourceReference"])
                .isSubset(of: Set(nutritionLog.attributesByName.keys))
        )
        XCTAssertNotNil(model.entitiesByName["FastingSession"]?.attributesByName["templateID"])
    }

    /// Every compiled predecessor has to migrate, and "every" is discovered from
    /// the built `.momd` rather than transcribed.
    ///
    /// This list used to be hardcoded, which makes the one mistake that matters
    /// invisible: add an additive model version, forget the list, and the new
    /// version ships with no migration fixture while the suite stays green. The
    /// bundle is the only honest source of what actually shipped.
    @MainActor
    func testEveryPreviousModelMigratesToCurrentModelWithoutChangingStableIDs() throws {
        let modelBundleURL = try taskModelBundleURL()
        let currentVersionName = try currentModelVersionName()
        let previousModelNames = try FileManager.default
            .contentsOfDirectory(at: modelBundleURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "mom" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { $0 != currentVersionName }
            .sorted()

        XCTAssertFalse(
            previousModelNames.isEmpty,
            "No compiled predecessor models were found in \(modelBundleURL.lastPathComponent)"
        )
        // The count is asserted so a *removed* version is caught too — deleting a
        // compiled model strands anyone still on it.
        XCTAssertEqual(
            previousModelNames.count, 22,
            """
            The number of compiled predecessors changed to \(previousModelNames.count). \
            Adding a version is expected — update this count in the same change. \
            Removing one strands every store still on it and is almost never right. \
            Found: \(previousModelNames.joined(separator: ", "))
            """
        )

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
                DashboardWidgetKind.care.rawValue,
                DashboardWidgetKind.tasks.rawValue,
                DashboardWidgetKind.routines.rawValue,
                DashboardWidgetKind.journal.rawValue,
                DashboardWidgetKind.progressReflection.rawValue
            ]
        )
    }

    /// The failure this guards against: eleven registered kinds used to fall
    /// through to `EmptyView()` at wide and above, and accessibility text sizes
    /// force the wide preset — so those cards were blank for anyone using large
    /// type. Every registered kind must declare an archetype, and every
    /// archetype must be one the renderer knows how to draw.
    func testEveryRegisteredWidgetDeclaresARenderableArchetypeAndSection() throws {
        let descriptors = DefaultDashboardWidgetRegistry.shared.availableDescriptors()
        XCTAssertFalse(descriptors.isEmpty)

        for descriptor in descriptors {
            XCTAssertTrue(
                HomeCardArchetype.allCases.contains(descriptor.archetype),
                "\(descriptor.kind.rawValue) has no renderable archetype"
            )
            XCTAssertTrue(
                HomeSectionRole.allCases.contains(descriptor.sectionRole),
                "\(descriptor.kind.rawValue) has no section role"
            )
            XCTAssertFalse(
                descriptor.supportedSizes.isEmpty,
                "\(descriptor.kind.rawValue) supports no sizes"
            )
        }

        // Today's committed work must not sit below wellbeing and reflection.
        XCTAssertEqual(
            DefaultDashboardWidgetRegistry.shared.descriptor(for: .tasks)?.sectionRole,
            .today
        )
    }

    /// The payload is additive: snapshots persisted before it — including
    /// app-group widget envelopes still on disk — must keep decoding.
    func testHomeCardSnapshotDecodesWithoutAPayloadAndRedactsOnDemand() throws {
        let legacy = """
        {"availability":"ready","title":"Movement","value":"8,120","detail":"steps","updatedAt":768000000}
        """
        let decoder = JSONDecoder()
        let snapshot = try decoder.decode(HomeCardSnapshot.self, from: Data(legacy.utf8))
        XCTAssertEqual(snapshot.title, "Movement")
        XCTAssertEqual(snapshot.payload, .none)
        XCTAssertTrue(snapshot.actions.isEmpty)

        let rich = HomeCardSnapshot(
            availability: .ready,
            title: "Movement",
            payload: .metric(.init(amount: 8_120, unit: "steps"))
        )
        let roundTripped = try decoder.decode(
            HomeCardSnapshot.self,
            from: JSONEncoder().encode(rich)
        )
        XCTAssertEqual(roundTripped.payload, rich.payload)
        // Sensitive cards may show a numeral in-app and must never leak one.
        XCTAssertEqual(rich.redactingPayload().payload, .none)
    }

    /// Modes were persisted and restored, yet only `.lowEnergy` changed
    /// anything and nothing could change the mode at all.
    func testDashboardModePolicyGivesEveryModeDistinctBehaviour() throws {
        let policy = DeterministicDashboardModePolicy()

        XCTAssertEqual(policy.contexts(for: .smart), [.neutral, .work, .personal])
        // Neutral survives in both: unlabelled work is not "not work".
        XCTAssertEqual(policy.contexts(for: .work), [.neutral, .work])
        XCTAssertEqual(policy.contexts(for: .personal), [.neutral, .personal])

        let journal = try XCTUnwrap(
            DefaultDashboardWidgetRegistry.shared.descriptor(for: .journal)
        )
        let tasks = try XCTUnwrap(
            DefaultDashboardWidgetRegistry.shared.descriptor(for: .tasks)
        )
        XCTAssertFalse(policy.permits(journal, in: .work), "Work mode must not surface journal")
        XCTAssertTrue(policy.permits(journal, in: .personal))
        XCTAssertTrue(policy.permits(tasks, in: .work))
        XCTAssertFalse(policy.permits(tasks, in: .lowEnergy), "Low Energy must not ask for output")

        XCTAssertTrue(policy.sectionBudget(for: .smart).showsUserSpace)
        let lowEnergy = policy.sectionBudget(for: .lowEnergy)
        XCTAssertFalse(lowEnergy.showsToday)
        XCTAssertFalse(lowEnergy.showsNeedsAttention)
        XCTAssertEqual(lowEnergy.queueLimit, 1)

        let workBudget = policy.sectionBudget(for: .work)
        XCTAssertEqual(workBudget.applying(.minimal).queueLimit, 2)
        XCTAssertFalse(workBudget.applying(.minimal).showsDayAhead)
        XCTAssertEqual(workBudget.applying(.balanced).queueLimit, 4)
        XCTAssertEqual(workBudget.applying(.rich).queueLimit, 6)
        XCTAssertTrue(workBudget.applying(.minimal).showsToday)
    }

    /// Ranking by row count always named the chattiest tracker; consistency is
    /// the honest signal, and below the floor nothing is claimed at all.
    func testInsightsInterpretationRanksConsistencyAndRefusesBelowTheFloor() throws {
        let engine = InsightsInterpretationEngine()
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

        func event(_ domain: String, dayOffset: Int, id: String) -> NormalizedLifeEvent {
            let occurred = calendar.date(byAdding: .day, value: dayOffset, to: day) ?? day
            return NormalizedLifeEvent(
                id: id,
                sourceID: UUID(),
                domain: domain,
                kind: "sample",
                occurredAt: occurred,
                localDay: PlanningDay(date: occurred, timeZone: .current, calendar: calendar),
                numericValue: nil,
                completeness: .complete,
                sensitivity: .privateStandard,
                allowedDestinations: [.insights],
                provenance: "test"
            )
        }

        XCTAssertEqual(engine.interpret(events: [], calendar: calendar).density, .empty)

        // Hydration is louder (6 records) but lives on 2 days; journal is
        // quieter (3 records) and present on 3. Consistency should win.
        var events: [NormalizedLifeEvent] = []
        for index in 0..<6 {
            events.append(event("hydration", dayOffset: index % 2, id: "h\(index)"))
        }
        for index in 0..<3 {
            events.append(event("journal", dayOffset: index, id: "j\(index)"))
        }

        let result = engine.interpret(events: events, calendar: calendar)
        XCTAssertEqual(result.density, .full)
        XCTAssertTrue(result.claim.lowercased().contains("journal"), result.claim)
        XCTAssertFalse(result.evidenceReferences.isEmpty)
        XCTAssertEqual(result.dailyCounts.count, 3)
    }

    /// `planningReview` rendered exactly the same weekly-review route as
    /// `weeklyReview` and was never pushed. Every remaining route must be
    /// reachable or gone — a declared-but-unreachable route is a promise the
    /// app does not keep.
    func testAppRouteHasNoDuplicateWeeklyReviewCase() throws {
        let mirror = "\(AppRoute.weeklyReview)"
        XCTAssertEqual(mirror, "weeklyReview")
        // `.insightEvidence` keeps its identifier through equality, which is
        // what lets the destination scroll to the record a link named.
        let id = UUID()
        XCTAssertEqual(AppRoute.insightEvidence(id), AppRoute.insightEvidence(id))
        XCTAssertNotEqual(AppRoute.insightEvidence(id), AppRoute.insightEvidence(nil))
    }

    /// Fasting existed only inside the legacy Track root, which the new root
    /// presented as a sheet. Its lifecycle must be usable on its own.
    func testFastingLifecycleIsUsableWithoutTheLegacyTrackTree() async throws {
        let repository = InMemoryFastingSessionRepository()
        let store = FastingTimerStore(repository: repository)

        let started = try await store.start(targetDuration: 8 * 3_600)
        XCTAssertNil(started.endedAt)
        let active = try await store.activeSession()
        XCTAssertEqual(active?.id, started.id)

        // One active fast at a time, whichever surface asks.
        do {
            _ = try await store.start(targetDuration: nil)
            XCTFail("A second concurrent fast must be refused")
        } catch {
            XCTAssertEqual(error as? FastingTimerStoreError, .alreadyActive)
        }

        let finished = try await store.finish()
        XCTAssertNotNil(finished.endedAt)
        let afterFinish = try await store.activeSession()
        XCTAssertNil(afterFinish)

        let corrected = try await store.correct(
            sessionID: finished.id,
            startedAt: finished.startedAt,
            endedAt: finished.startedAt.addingTimeInterval(3_600),
            targetDuration: finished.targetDuration,
            note: nil
        )
        XCTAssertEqual(corrected.completionKind, .corrected)
    }

    func testDashboardV5MigrationRemovesOnlyAppOwnedAnchoredDuplicates() throws {
        let pinnedFocusID = UUID()
        var pinnedFocus = DashboardWidgetPlacementValue(
            id: pinnedFocusID,
            widgetKind: DashboardWidgetKind.focusNow.rawValue,
            semanticSize: .wide,
            ordinal: 0
        )
        pinnedFocus.updateHomeConfiguration { $0.placement.ownership = .pinned }
        var smartTimeline = DashboardWidgetPlacementValue(
            widgetKind: DashboardWidgetKind.compactTimeline.rawValue,
            semanticSize: .wide,
            ordinal: 1
        )
        smartTimeline.updateHomeConfiguration { $0.placement.ownership = .smart }
        let unknownID = UUID()
        let unknown = DashboardWidgetPlacementValue(
            id: unknownID,
            widgetKind: "futureWidget",
            semanticSize: .standard,
            ordinal: 2,
            isVisible: false
        )
        let legacy = DashboardLayoutValue(
            mode: .smart,
            schemaVersion: 4,
            isDefault: false,
            placements: [pinnedFocus, smartTimeline, unknown]
        )
        let container = NSPersistentContainer(
            name: "DashboardV5MigrationContract",
            managedObjectModel: NSManagedObjectModel()
        )

        let migrated = try CoreDataDashboardLayoutRepository(container: container).migrate(legacy)

        XCTAssertEqual(migrated.schemaVersion, 5)
        XCTAssertTrue(migrated.placements.contains { $0.id == pinnedFocusID })
        XCTAssertFalse(migrated.placements.contains { $0.widgetKind == DashboardWidgetKind.compactTimeline.rawValue })
        XCTAssertEqual(migrated.placements.first(where: { $0.id == unknownID })?.isVisible, false)
        XCTAssertFalse(migrated.isDefault)
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
        // Runs against the shipping model, not `TaskModelV3_KnowledgeNotes`.
        // Medication entities are health-sensitive, so their writes pass through
        // the health privacy gate, and `HealthMigrationCheckpoint` only exists
        // from `TaskModelV3_HealthPrivacy` onward. Migration from the older
        // versions stays covered by `assertLightweightMigration`.
        let container = try await makeHealthPrivacyValidatedContainer(name: "PhaseIIRoundTrip")
        let repository = CoreDataLifeBoardPhaseIIRepository(container: container)

        let tracker = LifeBoardTrackerDefinitionValue(
            title: "Water",
            kind: .quantity,
            unitLabel: "ml",
            valueType: .quantity,
            rangeMin: 0,
            rangeMax: 5_000,
            aggregation: .sum,
            privacyClass: .personal,
            isHomeEligible: true
        )
        try await repository.saveTracker(tracker)
        let trackerEntry = LifeBoardTrackerEntryValue(
            trackerID: tracker.id,
            numericValue: 450,
            value: .quantity(450, unit: "ml")
        )
        try await repository.saveTrackerEntry(trackerEntry)
        let fetchedTrackers = try await repository.fetchTrackers()
        let fetchedEntries = try await repository.fetchTrackerEntries(trackerID: tracker.id)
        XCTAssertEqual(fetchedTrackers.map(\.id), [tracker.id])
        XCTAssertEqual(fetchedEntries.first?.numericValue, 450)
        XCTAssertEqual(fetchedTrackers.first?.aggregation, .sum)
        XCTAssertEqual(fetchedTrackers.first?.privacyClass, .personal)
        XCTAssertEqual(fetchedTrackers.first?.isHomeEligible, true)
        XCTAssertEqual(fetchedEntries.first?.value, .quantity(450, unit: "ml"))
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

        let medicationStart = journalDateForRepositoryTest().addingTimeInterval(-86_400)
        let medication = LifeBoardMedicationDefinitionValue(
            name: "Vitamin D",
            formRaw: "tablet",
            startDate: medicationStart,
            refillQuantity: 30,
            refillRemaining: 12,
            refillThreshold: 5,
            lastRefilledAt: medicationStart
        )
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
        let fetchedMedications = try await repository.fetchMedications()
        let fetchedMedication = try XCTUnwrap(fetchedMedications.first)
        XCTAssertEqual(fetchedMedication.formRaw, "tablet")
        XCTAssertEqual(fetchedMedication.refillRemaining, 12)
        XCTAssertEqual(fetchedMedication.lastRefilledAt, medicationStart)
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

    func testContextPolicyIsPrivateStableAndBoundedByTheCandidateCap() {
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
        // One hero plus up to three in "Needs attention". The old cap of two
        // meant nine domain providers competed for a section that could only
        // ever render a single row, and only when exactly two survived.
        XCTAssertEqual(privateSelection.candidates.map(\.id), ["active", "next"])

        let permittedSelection = policy.select(
            candidates: [medication, lower, next, active],
            dispositions: ["medication": .suggestLess],
            permitsSensitiveHomeContent: true,
            now: now
        )
        // `medication` is sensitive and penalised by `suggestLess`, so it still
        // sorts last even once sensitive content is permitted.
        XCTAssertEqual(permittedSelection.candidates.map(\.id), ["active", "next", "medication"])
        XCTAssertEqual(
            Set(permittedSelection.candidates.map(\.resolvedSemanticRole)).count,
            permittedSelection.candidates.count
        )
        XCTAssertLessThanOrEqual(
            permittedSelection.candidates.count,
            HomeContextSelection.maximumCandidates
        )
    }

    func testContextPolicyGuaranteesOnePrimaryNowAndAtMostOneDayAheadStory() {
        let now = Date(timeIntervalSince1970: 21_000)
        let primary = HomeContextCandidate(
            id: "primary",
            widgetKind: .focusNow,
            title: "Write the outline",
            reason: .init(message: "Actionable now", signal: "task"),
            destination: .plan,
            priority: 100,
            relevantFrom: now,
            semanticRole: .primaryNow
        )
        let higherPriorityCare = HomeContextCandidate(
            id: "care",
            widgetKind: .care,
            title: "Care",
            reason: .init(message: "A care decision", signal: "care"),
            destination: .track,
            priority: 900,
            relevantFrom: now,
            semanticRole: .care
        )
        let firstStory = HomeContextCandidate(
            id: "story-a",
            widgetKind: .compactTimeline,
            title: "Next meeting",
            reason: .init(message: "Starts soon", signal: "calendar"),
            destination: .plan,
            priority: 800,
            relevantFrom: now,
            semanticRole: .dayAheadStory
        )
        let secondStory = HomeContextCandidate(
            id: "story-b",
            widgetKind: .scheduleCapacity,
            title: "Later meeting",
            reason: .init(message: "Later today", signal: "calendar"),
            destination: .plan,
            priority: 700,
            relevantFrom: now,
            semanticRole: .dayAheadStory
        )

        let selection = DeterministicHomeContextPolicy().select(
            candidates: [higherPriorityCare, secondStory, primary, firstStory],
            dispositions: [:],
            permitsSensitiveHomeContent: true,
            now: now
        )
        XCTAssertEqual(selection.candidates.first?.id, primary.id)
        XCTAssertEqual(
            selection.candidates.filter { $0.resolvedSemanticRole == .primaryNow }.count,
            1
        )
        XCTAssertEqual(
            selection.candidates.filter { $0.resolvedSemanticRole == .dayAheadStory }.map(\.id),
            [firstStory.id]
        )
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
        draft.setSection(.keepSteady, id: placement.id)

        XCTAssertEqual(draft.current.placements.first?.ownership, .pinned)
        XCTAssertEqual(draft.current.placements.first?.sectionOverride, .keepSteady)
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

    func testUniversalInputCommandsRouteToTheExpectedNativeActivities() async {
        let adapter = CommandIntentAdapter()
        let expectations: [(String, String)] = [
            ("start journaling", "journal"),
            ("add a note", "note"),
            ("check my meetings", "schedule"),
            ("start planning", "planning"),
            ("day rescue", "dayRescue"),
            ("overdue rescue", "overdueRescue")
        ]

        for (text, expected) in expectations {
            let resolution = await adapter.resolve(.init(text: text, destination: .home))
            switch (resolution, expected) {
            case (.captureDraft(let draft)?, "journal"):
                XCTAssertEqual(draft.kind, .journal)
            case (.captureDraft(let draft)?, "note"):
                XCTAssertEqual(draft.kind, .note)
            case (.surfaceAction(.showTodaySchedule)?, "schedule"),
                 (.surfaceAction(.dayRescue)?, "dayRescue"),
                 (.surfaceAction(.overdueRescue)?, "overdueRescue"):
                break
            case (.navigation(let request)?, "planning"):
                XCTAssertEqual(request.destination, .plan)
                XCTAssertEqual(request.route, .planDay)
            default:
                XCTFail("Unexpected resolution for \(text): \(String(describing: resolution))")
            }
        }
    }

    func testBareCaptureCommandsDoNotPrefillEditorsWithCommandLanguage() async {
        let adapter = CommandIntentAdapter()

        let journal = await adapter.resolve(.init(text: "start journaling", destination: .home))
        guard case .captureDraft(let journalDraft)? = journal else {
            return XCTFail("Expected a journal capture")
        }
        XCTAssertEqual(journalDraft.seed?.rawText, "")

        let note = await adapter.resolve(.init(text: "add a note", destination: .home))
        guard case .captureDraft(let noteDraft)? = note else {
            return XCTFail("Expected a note capture")
        }
        XCTAssertEqual(noteDraft.seed?.rawText, "")
    }

    func testTaskAdapterDoesNotTurnAQuestionWithADateIntoATask() async {
        let resolution = await TaskCaptureIntentAdapter().resolve(
            .init(text: "what meetings do I have tomorrow", destination: .home)
        )
        XCTAssertNil(resolution)
    }

    func testUniversalInputCoordinatorRunsSemanticAdapterOnlyInFullResolution() async {
        let coordinator = UniversalInputCoordinator(semanticAdapter: SemanticIntentAdapterFixture())
        let input = LifeThreadIntentInput(text: "help me recover the afternoon", destination: .home)

        let preview = await coordinator.resolvePreview(input)
        guard case .answer = preview else {
            return XCTFail("Live preview must stay deterministic and avoid semantic inference")
        }

        let submitted = await coordinator.resolve(input)
        XCTAssertEqual(submitted, .surfaceAction(.dayRescue))
    }

    @MainActor
    func testDictationCommitsTheLatestCumulativeTranscriptWithoutLoss() {
        let controller = UniversalDictationController()
        controller.consumeCumulativeTranscript("Plan")
        controller.consumeCumulativeTranscript("Plan the launch tomorrow")

        XCTAssertEqual(controller.volatileSegment, "Plan the launch tomorrow")
        controller.commitLatestTranscript()
        XCTAssertEqual(controller.draftText, "Plan the launch tomorrow")
        XCTAssertEqual(controller.volatileSegment, "")
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

    func testRemoteEvaRequiresAccountOptInAndIndependentCategoryGrants() async {
        let sections = RemoteEvaContextCategory.allCases.map {
            RemoteEvaContextSection(category: $0, payload: Data($0.rawValue.utf8))
        }
        var policy = RemoteEvaContextPolicy(
            accountID: "account-a",
            grantedCategories: [.journal, .planningContext]
        )
        XCTAssertTrue(
            policy.authorize(sections, forAccountID: "account-a").isEmpty,
            "Category grants cannot bypass account opt-in."
        )

        policy.setRemoteEvaEnabled(true)
        let authorized = policy.authorize(sections, forAccountID: "account-a")
        XCTAssertEqual(authorized.map(\.category), [.journal, .planningContext])
        XCTAssertFalse(policy.permits(.health, forAccountID: "account-a"))
        XCTAssertFalse(policy.permits(.lifeMoments, forAccountID: "account-a"))
        XCTAssertTrue(
            policy.authorize(sections, forAccountID: "account-b").isEmpty,
            "A policy must never authorize a different signed-in account."
        )

        let futurePolicy = RemoteEvaContextPolicy(
            schemaVersion: RemoteEvaContextPolicy.currentSchemaVersion + 1,
            accountID: "account-a",
            isRemoteEvaEnabled: true,
            grantedCategories: Set(RemoteEvaContextCategory.allCases)
        )
        XCTAssertTrue(
            futurePolicy.authorize(sections, forAccountID: "account-a").isEmpty,
            "Unknown policy schemas must fail closed."
        )
    }

    func testRemoteEvaRevocationImmediatelyExcludesSubsequentRequestContext() async {
        let authorizer = RemoteEvaContextAuthorizer(policy: RemoteEvaContextPolicy(
            accountID: "account-a",
            isRemoteEvaEnabled: true,
            grantedCategories: [.journal, .health, .lifeMoments, .planningContext]
        ))
        let sections = RemoteEvaContextCategory.allCases.map {
            RemoteEvaContextSection(category: $0, payload: Data($0.rawValue.utf8))
        }

        let initiallyAuthorized = await authorizer.authorize(sections, forAccountID: "account-a")
        XCTAssertEqual(initiallyAuthorized.count, 4)
        await authorizer.setGrant(false, for: .journal)
        let afterJournalRevocation = await authorizer.authorize(sections, forAccountID: "account-a")
        XCTAssertEqual(
            afterJournalRevocation.map(\.category),
            [.health, .lifeMoments, .planningContext]
        )
        await authorizer.setRemoteEvaEnabled(false)
        let afterAccountRevocation = await authorizer.authorize(sections, forAccountID: "account-a")
        XCTAssertTrue(afterAccountRevocation.isEmpty)
    }

    func testRemoteEvaGrantsNeverAuthorizeSystemSurfaceDisclosure() {
        let remotePolicy = RemoteEvaContextPolicy(
            accountID: "account-a",
            isRemoteEvaEnabled: true,
            grantedCategories: Set(RemoteEvaContextCategory.allCases)
        )
        XCTAssertTrue(remotePolicy.permits(.journal, forAccountID: "account-a"))

        let snapshot = LifeBoardSystemSurfaceSnapshot(
            id: UUID(),
            title: "Private journal title",
            primaryValue: "Private journal text",
            systemImage: "book.closed",
            sensitivity: .privateSensitive,
            isExplicitlyAuthorized: false,
            updatedAt: Date()
        )
        XCTAssertEqual(snapshot.redactedForExternalDisplay.title, "LifeBoard")
        XCTAssertEqual(snapshot.redactedForExternalDisplay.primaryValue, "Open LifeBoard to view")
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

    func testWellnessPreferencesPersistOrderingUnitsAndConflictChoices() throws {
        let suiteName = "LifeBoardTests.WellnessPreferences.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsWellnessPreferenceStore(defaults: defaults)
        let preferredSampleID = UUID()
        let preferences = WellnessDisplayPreferences(
            enabledMetrics: [.waistCircumference, .bodyMass, .waistCircumference],
            preferredUnits: [
                .waistCircumference: .inches,
                .bodyMass: .pounds,
                .restingHeartRate: .kilograms
            ],
            preferredSampleIDsByConflict: ["conflict": preferredSampleID]
        )

        store.save(preferences)
        let restored = store.load()
        XCTAssertEqual(restored.enabledMetrics, [.waistCircumference, .bodyMass])
        XCTAssertEqual(restored.preferredUnit(for: .waistCircumference), .inches)
        XCTAssertEqual(restored.preferredUnit(for: .bodyMass), .pounds)
        XCTAssertEqual(restored.preferredUnit(for: .restingHeartRate), .beatsPerMinute)
        XCTAssertEqual(restored.preferredSampleIDsByConflict["conflict"], preferredSampleID)
    }

    func testWellnessSourceConflictKeepsBothSamplesAndChangesProjectionOnly() throws {
        let observedAt = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let manual = try BodyMetricSample(
            kind: .bodyMass,
            value: 70,
            unit: .kilograms,
            observedAt: observedAt,
            source: .manual
        )
        let health = try BodyMetricSample(
            kind: .bodyMass,
            value: 70.5,
            unit: .kilograms,
            observedAt: observedAt.addingTimeInterval(5 * 60),
            source: .healthKit,
            sourceIdentifier: "health-sample"
        )
        let distant = try BodyMetricSample(
            kind: .bodyMass,
            value: 71,
            unit: .kilograms,
            observedAt: observedAt.addingTimeInterval(60 * 60),
            source: .watch
        )

        let conflicts = WellnessSourceConflictDetector().conflicts(in: [manual, health, distant])
        let conflict = try XCTUnwrap(conflicts.first)
        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(Set(conflict.samples.map(\.id)), [manual.id, health.id])

        var preferences = WellnessDisplayPreferences()
        preferences.preferredSampleIDsByConflict[conflict.id] = manual.id
        XCTAssertEqual(conflict.preferredSample(using: preferences)?.id, manual.id)
        XCTAssertEqual(conflict.samples.count, 2, "Choosing a projection must not rewrite source history")
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
        let container = try await makeHealthPrivacyValidatedContainer(name: "WellnessCoreRoundTrip")
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
        let container = try await makeHealthPrivacyValidatedContainer(name: "FastingCompletionRoundTrip")
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

    func testFastingTemplateStartsCanonicalSessionAndCorrectionUndoRestoresHistory() async throws {
        let container = try await makeHealthPrivacyValidatedContainer(name: "FastingTemplateRoundTrip")
        let phaseII = CoreDataLifeBoardPhaseIIRepository(container: container)
        let repository = LifeBoardFastingRepositoryAdapter(repository: phaseII)
        let now = Date(timeIntervalSince1970: 1_721_430_000)
        let store = FastingTimerStore(repository: repository, now: { now })
        let template = try LifeBoardFastingTemplateValue(
            label: "My quiet timer",
            targetDuration: 7_200,
            reminderOffsets: [3_600],
            displayPreferences: .init(showsElapsedTime: true, showsTargetProgress: false),
            createdAt: now,
            updatedAt: now
        )

        try await store.saveTemplate(template)
        let session = try await store.start(template: template, note: "User-selected", at: now)
        XCTAssertEqual(session.templateID, template.id)
        XCTAssertEqual(session.targetDuration, 7_200)
        let templates = try await store.templates()
        XCTAssertEqual(templates.first, template)

        _ = try await store.finish(at: now.addingTimeInterval(3_600))
        let receipt = try await store.correctWithReceipt(
            sessionID: session.id,
            startedAt: now.addingTimeInterval(-300),
            endedAt: now.addingTimeInterval(4_000),
            targetDuration: 7_200,
            note: "Corrected"
        )
        XCTAssertEqual(receipt.after.completionKind, .corrected)
        try await store.undo(receipt)
        let sessions = try await store.sessions()
        let restored = try XCTUnwrap(sessions.first(where: { $0.id == session.id }))
        XCTAssertEqual(restored.startedAt, now)
        XCTAssertEqual(restored.endedAt, now.addingTimeInterval(3_600))
        XCTAssertEqual(restored.completionKind, .early)
        XCTAssertEqual(restored.templateID, template.id)
    }

    func testNativeTrackStoreRoutesTrackerAndMedicationWritesThroughValidationServices() async throws {
        let container = try await makeHealthPrivacyValidatedContainer(name: "NativeTrackValidationBoundary")
        let repository = CoreDataLifeBoardPhaseIIRepository(container: container)
        let store = await LifeBoardTrackStore(repository: repository)

        let invalidTracker = LifeBoardTrackerDefinitionValue(
            title: "Pain",
            kind: .rating,
            rangeMin: 10,
            rangeMax: 1,
            privacyClass: .sensitive,
            isHomeEligible: true
        )
        await store.saveTracker(invalidTracker)
        let trackerError = await store.errorMessage
        XCTAssertNotNil(trackerError)
        let trackers = try await repository.fetchTrackers()
        XCTAssertTrue(trackers.isEmpty)

        let invalidMedication = LifeBoardMedicationDefinitionValue(
            name: "Personal record",
            startDate: Date(),
            endDate: Date().addingTimeInterval(-60)
        )
        let schedule = LifeBoardMedicationScheduleValue(
            medicationID: invalidMedication.id,
            windowStartMinutes: 480,
            windowEndMinutes: 540
        )
        await store.saveMedication(invalidMedication, schedule: schedule)
        let medicationError = await store.errorMessage
        XCTAssertNotNil(medicationError)
        let medications = try await repository.fetchMedications()
        let schedules = try await repository.fetchMedicationSchedules(medicationID: nil)
        XCTAssertTrue(medications.isEmpty)
        XCTAssertTrue(schedules.isEmpty)
    }

    func testMedicationScheduleIsPreflightedBeforeDefinitionPersistence() async throws {
        let container = try await makeHealthPrivacyValidatedContainer(name: "MedicationSchedulePreflight")
        let repository = CoreDataLifeBoardPhaseIIRepository(container: container)
        let store = await LifeBoardTrackStore(repository: repository)
        let medication = LifeBoardMedicationDefinitionValue(name: "Personal record")
        let invalidSchedule = LifeBoardMedicationScheduleValue(
            medicationID: medication.id,
            windowStartMinutes: 600,
            windowEndMinutes: 500,
            weekdays: []
        )

        await store.saveMedication(medication, schedule: invalidSchedule)

        let error = await store.errorMessage
        let medications = try await repository.fetchMedications()
        let schedules = try await repository.fetchMedicationSchedules(medicationID: nil)
        XCTAssertEqual(error, MedicationScheduleServiceError.invalidSchedule.localizedDescription)
        XCTAssertTrue(medications.isEmpty)
        XCTAssertTrue(schedules.isEmpty)
    }

    func testTrackerServiceRejectsAmbiguousChoicesAndNonFiniteValues() async throws {
        let container = try await makeHealthPrivacyValidatedContainer(name: "TrackerFiniteValidation")
        let repository = CoreDataLifeBoardPhaseIIRepository(container: container)
        let service = TrackerDefinitionService(repository: repository)
        let ambiguousChoice = LifeBoardTrackerDefinitionValue(
            title: "Signal",
            kind: .choice,
            valueType: .choice,
            privacyClass: .personal,
            choiceOptions: ["Only one"]
        )

        do {
            try await service.saveDefinition(ambiguousChoice)
            XCTFail("A choice tracker with fewer than two options must be rejected.")
        } catch {
            XCTAssertEqual(error as? TrackerDefinitionServiceError, .invalidChoiceOptions)
        }

        let quantity = LifeBoardTrackerDefinitionValue(
            title: "Quantity",
            kind: .quantity,
            valueType: .quantity,
            privacyClass: .personal
        )
        try await service.saveDefinition(quantity)
        do {
            try await service.saveEntry(.init(
                trackerID: quantity.id,
                value: .quantity(.nan, unit: nil)
            ))
            XCTFail("Non-finite tracker values must be rejected.")
        } catch {
            XCTAssertEqual(error as? TrackerDefinitionServiceError, .valueOutOfRange)
        }
    }

    func testTrackerServicePersistsEveryTaggedValueShape() async throws {
        let container = try await makeHealthPrivacyValidatedContainer(name: "TrackerTaggedValues")
        let repository = CoreDataLifeBoardPhaseIIRepository(container: container)
        let service = TrackerDefinitionService(repository: repository)
        let definitions: [(LifeBoardTrackerDefinitionValue, TrackerValue)] = [
            (.init(title: "Boolean", kind: .boolean, valueType: .boolean, privacyClass: .personal), .boolean(false)),
            (.init(title: "Count", kind: .count, valueType: .count, privacyClass: .personal), .count(0)),
            (.init(title: "Quantity", kind: .quantity, valueType: .quantity, privacyClass: .personal), .quantity(2.5, unit: "cups")),
            (.init(title: "Rating", kind: .rating, valueType: .rating, rangeMin: 0, rangeMax: 5, privacyClass: .personal), .rating(0)),
            (.init(title: "Duration", kind: .duration, valueType: .duration, privacyClass: .personal), .duration(1_200)),
            (.init(title: "Text", kind: .text, valueType: .text, privacyClass: .personal), .text("steady")),
            (.init(title: "Choice", kind: .choice, valueType: .choice, privacyClass: .personal, choiceOptions: ["Low", "High"]), .choice("Low")),
            (.init(title: "Timestamp", kind: .timestamp, valueType: .timestamp, privacyClass: .personal), .timestamp(Date(timeIntervalSince1970: 1_721_430_000)))
        ]

        for (definition, value) in definitions {
            try await service.saveDefinition(definition)
            try await service.saveEntry(.init(trackerID: definition.id, value: value))
        }

        let entries = try await repository.fetchTrackerEntries(trackerID: nil)
        XCTAssertEqual(entries.count, definitions.count)
        XCTAssertEqual(Set(entries.compactMap(\.value)), Set(definitions.map(\.1)))
    }

    func testTrackerTemplatesCreateFreshNeutralPrivacyAwareDefinitions() {
        let first = LifeBoardTrackerTemplate.pain.instantiate(
            at: Date(timeIntervalSince1970: 1_721_430_000)
        )
        let second = LifeBoardTrackerTemplate.pain.instantiate(
            at: Date(timeIntervalSince1970: 1_721_430_000)
        )

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.effectiveValueType, .rating)
        XCTAssertEqual(first.effectivePrivacyClass, .sensitive)
        XCTAssertFalse(first.permitsHomeProjection)
        XCTAssertTrue(LifeBoardTrackerTemplate.pain.detail.localizedCaseInsensitiveContains("non-clinical"))
        XCTAssertEqual(LifeBoardTrackerTemplate.allCases.count, 6)
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

    func testBarcodeReviewIsLocalFirstAndRequiresExplicitRemoteResolution() async throws {
        let barcode = "12345678"
        let macros = try NutritionMacros(
            calories: 100,
            proteinGrams: 2,
            carbohydrateGrams: 20,
            fatGrams: 1
        )
        let local = try FoodItem(
            name: "Saved oats",
            barcode: barcode,
            macrosPer100Grams: macros,
            source: .userCreated
        )
        let remote = try FoodItem(
            name: "Online oats",
            barcode: barcode,
            macrosPer100Grams: try NutritionMacros(
                calories: 120,
                proteinGrams: 3,
                carbohydrateGrams: 22,
                fatGrams: 2
            ),
            source: .openFoodFacts,
            externalReference: "open-food-facts:\(barcode)"
        )
        let repository = InMemoryNutritionRepository(foods: [local])
        let localOnly = NutritionBarcodeReviewService(
            repository: repository,
            remoteLookup: StubNutritionRemoteLookup(value: remote)
        )

        let localReview = try await localOnly.review(barcode: barcode, scope: .localOnly)
        XCTAssertEqual(localReview.kind, .local(local))
        XCTAssertFalse(localReview.remoteLookupWasExplicit)
        do {
            _ = try await localOnly.review(barcode: barcode, scope: .explicitRemoteRequest)
            XCTFail("Remote lookup must remain disabled by default.")
        } catch {
            XCTAssertEqual(error as? NutritionError, .externalLookupNotEnabled)
        }

        let enabled = NutritionBarcodeReviewService(
            repository: repository,
            remoteLookup: StubNutritionRemoteLookup(value: remote),
            policy: .init(externalLookupEnabled: true)
        )
        let comparison = try await enabled.review(
            barcode: barcode,
            scope: .explicitRemoteRequest
        )
        XCTAssertEqual(comparison.kind, .duplicate(local: local, remote: remote))
        XCTAssertEqual(
            enabled.selection(from: comparison, resolution: .useLocal)?.provenance,
            .barcodeLocal
        )
        let remoteSelection = try XCTUnwrap(
            enabled.selection(from: comparison, resolution: .useRemote)
        )
        XCTAssertEqual(remoteSelection.food, remote)
        XCTAssertEqual(remoteSelection.provenance, .barcodeRemote)
        XCTAssertEqual(remoteSelection.sourceReference, remote.externalReference)
        XCTAssertNil(enabled.selection(from: comparison, resolution: .cancel))
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

    func testNutritionWorkflowPreservesSnapshotsAndReversesCorrection() async throws {
        let macros = try NutritionMacros(calories: 120, proteinGrams: 8, carbohydrateGrams: 18, fatGrams: 2)
        let serving = try FoodServingDefinition(name: "bowl", grams: 150)
        let food = try FoodItem(name: "Yogurt bowl", macrosPer100Grams: macros, servings: [serving])
        let original = try NutritionLogEntry(
            food: food,
            mealSlot: .breakfast,
            quantity: 1,
            serving: serving,
            provenance: .barcodeLocal,
            sourceReference: "01234567"
        )
        let repository = InMemoryNutritionRepository(foods: [food], logs: [original])
        let service = NutritionWorkflowService(repository: repository)

        let receipt = try await service.correctLog(
            id: original.id,
            quantity: 2,
            mealSlot: .snack,
            loggedAt: original.loggedAt.addingTimeInterval(60),
            note: "Shared bowl"
        )
        let correctedLogs = try await repository.logs(from: nil, to: nil)
        let corrected = try XCTUnwrap(correctedLogs.first)
        XCTAssertEqual(corrected.resolvedMacrosSnapshot.calories, original.resolvedMacrosSnapshot.calories * 2)
        XCTAssertEqual(corrected.provenance, .barcodeLocal)
        XCTAssertEqual(corrected.sourceReference, "01234567")

        try await service.undo(receipt)
        let restoredLogs = try await repository.logs(from: nil, to: nil)
        let restored = try XCTUnwrap(restoredLogs.first)
        XCTAssertEqual(restored, original)
    }

    func testNutritionRecipeTemplateGroceryAndPreferencesRoundTrip() async throws {
        let container = try await makeHealthPrivacyValidatedContainer(name: "NutritionLibraryRoundTrip")
        let repository = CoreDataNutritionRepository(container: container)
        let macros = try NutritionMacros(calories: 100, proteinGrams: 4, carbohydrateGrams: 15, fatGrams: 3)
        let serving = try FoodServingDefinition(name: "slice", grams: 50)
        let food = try FoodItem(name: "Bread", macrosPer100Grams: macros, servings: [serving])
        try await repository.save(food)

        let recipeID = UUID()
        let ingredient = try RecipeIngredient(
            recipeID: recipeID,
            foodID: food.id,
            nameSnapshot: food.name,
            quantity: 2,
            unitLabel: "slices",
            gramsSnapshot: 100,
            ordinal: 0
        )
        let recipe = try NutritionRecipe(
            id: recipeID,
            title: "Toast",
            servingCount: 1,
            resolvedNutrition: try food.resolvedMacros(grams: 100),
            isFavorite: true
        )
        try await repository.save(recipe, ingredients: [ingredient])

        let template = try NutritionMealTemplate(
            title: "Quick breakfast",
            mealSlot: .breakfast,
            items: [try MealTemplateItem(source: .recipe, sourceID: recipe.id, quantity: 1)]
        )
        try await repository.save(template)
        let service = NutritionWorkflowService(repository: repository)
        let receipts = try await service.instantiate(template: template)
        let grocery = try await service.groceryList(title: "Breakfast shop", recipeIDs: [recipe.id])
        let preferences = try NutritionPreferences(
            caloriesHidden: true,
            macroTargets: macros,
            micronutrientTargets: ["iron": 18]
        )
        try await repository.save(preferences)

        let restoredRecipes = try await repository.recipes()
        let restoredIngredients = try await repository.ingredients(recipeID: recipe.id)
        let restoredLogs = try await repository.logs(from: nil, to: nil)
        let restoredPreferences = try await repository.preferences()
        XCTAssertEqual(restoredRecipes.map(\.id), [recipe.id])
        XCTAssertEqual(restoredIngredients, [ingredient])
        XCTAssertEqual(receipts.count, 1)
        XCTAssertEqual(restoredLogs.first?.recipeID, recipe.id)
        XCTAssertEqual(restoredLogs.first?.mealTemplateID, template.id)
        XCTAssertEqual(grocery.items.first?.sourceRecipeID, recipe.id)
        XCTAssertEqual(restoredPreferences, preferences)
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

    /// Asserted against the shipping model rather than `mergedModel`, which
    /// unions all twenty-one compiled versions and reports a configuration
    /// membership no store ever loads.
    ///
    /// `TaskModelV3_HealthPrivacy` deliberately added the nutrition entities to
    /// `LocalOnly` alongside `CloudSync`: `HealthPrivacyMigrationCoordinator`
    /// copies each row into the private local store and only
    /// `purgeLegacyCloudRowsIfEligible` removes the cloud copy, after the
    /// upgrade window. Both memberships are load-bearing until that purge runs,
    /// so this asserts the dual-homing rather than the pre-HealthPrivacy
    /// exclusivity the entities shipped with.
    func testNutritionAndLifeMomentModelsPreserveStoreBoundaries() throws {
        let model = try XCTUnwrap(
            NSManagedObjectModel(
                contentsOf: try completionModelBundleURL()
                    .appendingPathComponent("TaskModelV3_TaskStartDay.mom")
            )
        )
        let cloud = Set(try XCTUnwrap(model.entities(forConfigurationName: "CloudSync")).compactMap(\.name))
        let local = Set(try XCTUnwrap(model.entities(forConfigurationName: "LocalOnly")).compactMap(\.name))

        for name in ["FoodItem", "NutritionLogEntry", "NutritionGoal"] {
            XCTAssertTrue(cloud.contains(name), "\(name) still syncs until the legacy cloud purge runs")
            XCTAssertTrue(local.contains(name), "\(name) needs a LocalOnly home for the private health copy")
            XCTAssertTrue(
                HealthPrivacyMigrationCoordinator.affectedEntities.contains(name),
                "\(name) is dual-homed only because the health privacy migration copies it"
            )
        }

        // Life Moments carry no health payload, so they stay cloud-only.
        XCTAssertTrue(cloud.contains("LifeMoment"))
        XCTAssertFalse(local.contains("LifeMoment"))
        XCTAssertFalse(HealthPrivacyMigrationCoordinator.affectedEntities.contains("LifeMoment"))

        // Derived caches are rebuildable and must never reach the cloud.
        for name in ["FoodSearchIndexEntry", "FoodLookupCache"] {
            XCTAssertTrue(local.contains(name), "\(name) is a rebuildable local index")
            XCTAssertFalse(cloud.contains(name), "\(name) must never sync")
        }

        // The gate the dual-homing exists for has to be present in this model.
        XCTAssertTrue(local.contains("HealthMigrationCheckpoint"))
        XCTAssertFalse(cloud.contains("HealthMigrationCheckpoint"))
    }

    func testCoreDataNutritionAndLifeMomentsRoundTripImmutableValues() async throws {
        let container = try await makeHealthPrivacyValidatedContainer(name: "PhaseVIRoundTrip")
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

    /// The current model version as the *built product* records it, read from
    /// `VersionInfo.plist` inside the compiled `.momd`. Reading the source
    /// `.xccurrentversion` instead would let a stale build pass.
    private func currentModelVersionName() throws -> String {
        let versionInfo = try taskModelBundleURL().appendingPathComponent("VersionInfo.plist")
        let data = try Data(contentsOf: versionInfo)
        let plist = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        return try XCTUnwrap(
            plist["NSManagedObjectModel_CurrentVersionName"] as? String,
            "VersionInfo.plist does not name a current version"
        )
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
        var domainFixtures: [DomainMigrationFixture] = []
        try sourceContext.performAndWait {
            let area = NSEntityDescription.insertNewObject(forEntityName: "LifeArea", into: sourceContext)
            area.setValue(fixtureID, forKey: "id")
            area.setValue(fixtureName, forKey: "name")
            domainFixtures = seedDomainMigrationFixtures(
                sourceModel: sourceModel,
                context: sourceContext,
                modelName: sourceModelName
            )
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
        try assertDomainMigrationFixtures(
            domainFixtures,
            in: destinationContext,
            sourceModelName: sourceModelName
        )
    }

    private struct DomainMigrationFixture {
        var entityName: String
        var id: UUID
        var attributes: [String: NSObject]
        var relationshipIDs: [String: UUID] = [:]
    }

    private func seedDomainMigrationFixtures(
        sourceModel: NSManagedObjectModel,
        context: NSManagedObjectContext,
        modelName: String
    ) -> [DomainMigrationFixture] {
        let cloudEntities = Set(
            sourceModel.entities(forConfigurationName: "CloudSync")?.compactMap(\.name) ?? []
        )
        var fixtures: [DomainMigrationFixture] = []

        func insert(
            _ entityName: String,
            values: [String: NSObject]
        ) -> (NSManagedObject, DomainMigrationFixture)? {
            guard cloudEntities.contains(entityName),
                  let entity = sourceModel.entitiesByName[entityName] else {
                return nil
            }
            let object = NSManagedObject(entity: entity, insertInto: context)
            let id = UUID()
            object.setValue(id, forKey: "id")
            var retained: [String: NSObject] = ["id": id as NSUUID]
            for (key, value) in values where entity.attributesByName[key] != nil {
                object.setValue(value, forKey: key)
                retained[key] = value
            }
            return (
                object,
                DomainMigrationFixture(
                    entityName: entityName,
                    id: id,
                    attributes: retained
                )
            )
        }

        let semanticPayload = Data("meaning:\(modelName)".utf8) as NSData
        if let (_, fixture) = insert("HabitDefinition", values: [
            "title": "Migrated habit" as NSString,
            "habitType": "daily" as NSString,
            "kindRaw": "positive" as NSString,
            "trackingModeRaw": "completion" as NSString,
            "targetConfigData": semanticPayload,
            "streakCurrent": NSNumber(value: 4),
            "streakBest": NSNumber(value: 9)
        ]) {
            fixtures.append(fixture)
        }

        var trackerObject: NSManagedObject?
        var trackerID: UUID?
        if let (object, fixture) = insert("TrackerDefinition", values: [
            "title": "Migrated tracker" as NSString,
            "kindRaw": "quantity" as NSString,
            "unitLabel": "cups" as NSString,
            "targetValue": NSNumber(value: 3.5),
            "isArchived": NSNumber(value: false)
        ]) {
            trackerObject = object
            trackerID = fixture.id
            fixtures.append(fixture)
        }
        if let trackerID,
           var (entry, fixture) = insert("TrackerEntry", values: [
               "trackerID": trackerID as NSUUID,
               "timestamp": NSDate(timeIntervalSince1970: 1_721_430_000),
               "numericValue": NSNumber(value: 0),
               "booleanValue": NSNumber(value: false),
               "note": "Explicit zero remains data" as NSString
           ]) {
            if let trackerObject,
               entry.entity.relationshipsByName["tracker"] != nil {
                entry.setValue(trackerObject, forKey: "tracker")
                fixture.relationshipIDs["tracker"] = trackerID
            }
            fixtures.append(fixture)
        }

        var medicationObject: NSManagedObject?
        var medicationID: UUID?
        if let (object, fixture) = insert("MedicationDefinition", values: [
            "name": "Migrated medication record" as NSString,
            "dosageText": "User label" as NSString,
            "instructions": "User note" as NSString,
            "isArchived": NSNumber(value: false)
        ]) {
            medicationObject = object
            medicationID = fixture.id
            fixtures.append(fixture)
        }
        if let medicationID,
           var (schedule, fixture) = insert("MedicationSchedule", values: [
               "medicationID": medicationID as NSUUID,
               "windowStartMinutes": NSNumber(value: 480),
               "windowEndMinutes": NSNumber(value: 540),
               "reminderEnabled": NSNumber(value: true)
           ]) {
            if let medicationObject,
               schedule.entity.relationshipsByName["medication"] != nil {
                schedule.setValue(medicationObject, forKey: "medication")
                fixture.relationshipIDs["medication"] = medicationID
            }
            fixtures.append(fixture)
        }
        if let medicationID,
           var (event, fixture) = insert("MedicationEvent", values: [
               "medicationID": medicationID as NSUUID,
               "scheduledAt": NSDate(timeIntervalSince1970: 1_721_430_000),
               "statusRaw": "unresolved" as NSString,
               "note": "Silence was not inferred" as NSString
           ]) {
            if let medicationObject,
               event.entity.relationshipsByName["medication"] != nil {
                event.setValue(medicationObject, forKey: "medication")
                fixture.relationshipIDs["medication"] = medicationID
            }
            fixtures.append(fixture)
        }

        if let (_, fixture) = insert("GoalDefinition", values: [
            "title": "Migrated goal" as NSString,
            "typeRaw": "quantity" as NSString,
            "targetValue": NSNumber(value: 12.5),
            "unitLabel": "hours" as NSString,
            "isArchived": NSNumber(value: false)
        ]) {
            fixtures.append(fixture)
        }
        return fixtures
    }

    private func assertDomainMigrationFixtures(
        _ fixtures: [DomainMigrationFixture],
        in context: NSManagedObjectContext,
        sourceModelName: String
    ) throws {
        try context.performAndWait {
            for fixture in fixtures {
                let request = NSFetchRequest<NSManagedObject>(entityName: fixture.entityName)
                request.predicate = NSPredicate(format: "id == %@", fixture.id as CVarArg)
                request.fetchLimit = 1
                let object = try XCTUnwrap(
                    context.fetch(request).first,
                    "\(fixture.entityName) was lost migrating \(sourceModelName)"
                )
                for (key, expected) in fixture.attributes {
                    let actual = object.value(forKey: key) as? NSObject
                    XCTAssertTrue(
                        actual?.isEqual(expected) == true,
                        "\(fixture.entityName).\(key) changed migrating \(sourceModelName): \(String(describing: actual)) != \(expected)"
                    )
                }
                for (relationship, expectedID) in fixture.relationshipIDs {
                    let related = object.value(forKey: relationship) as? NSManagedObject
                    XCTAssertEqual(
                        related?.value(forKey: "id") as? UUID,
                        expectedID,
                        "\(fixture.entityName).\(relationship) was not preserved migrating \(sourceModelName)"
                    )
                }
            }
        }
    }

    func testKnowledgeNoteQueryAppliesSmartCollectionsSearchAndSort() {
        let spaceID = UUID()
        let pinnedID = UUID()
        let checklistID = UUID()
        let pinned = LifeBoardKnowledgeNoteValue(
            id: pinnedID,
            spaceID: spaceID,
            title: "Launch Brief",
            isPinned: true,
            updatedAt: Date(timeIntervalSince1970: 20),
            blocks: [.init(noteID: pinnedID, text: "Premium notes")]
        )
        let checklist = LifeBoardKnowledgeNoteValue(
            id: checklistID,
            spaceID: spaceID,
            title: "Today",
            updatedAt: Date(timeIntervalSince1970: 10),
            blocks: [.init(noteID: checklistID, kind: .checklist, text: "Review motion")]
        )
        var archived = checklist
        archived.id = UUID()
        archived.blocks = [.init(noteID: archived.id, text: "Old")]
        archived.state = .archived

        XCTAssertEqual(
            KnowledgeNoteQuery(collection: .pinned, spaceID: spaceID)
                .apply(to: [checklist, archived, pinned]).map(\.id),
            [pinnedID]
        )
        XCTAssertEqual(
            KnowledgeNoteQuery(collection: .checklists, searchText: "motion")
                .apply(to: [pinned, checklist, archived]).map(\.id),
            [checklistID]
        )
        XCTAssertEqual(
            KnowledgeNoteQuery(collection: .archived)
                .apply(to: [pinned, checklist, archived]).map(\.id),
            [archived.id]
        )
    }

    func testKnowledgeTemplatesCreateStableOrderedBlocks() throws {
        let noteID = UUID()
        let meeting = try XCTUnwrap(KnowledgeNoteTemplate.library.first { $0.id == "meeting" })
        let blocks = meeting.blocks.enumerated().map { index, template in
            LifeBoardKnowledgeBlockValue(
                noteID: noteID,
                kind: template.kind,
                text: template.text,
                ordinal: index
            )
        }
        XCTAssertEqual(blocks.map(\.ordinal), Array(blocks.indices))
        XCTAssertTrue(blocks.contains { $0.kind == .checklist })
        XCTAssertTrue(blocks.contains { $0.kind == .heading2 })
    }

    func testNotesProModelAddsRecoveryAndRichContentFields() throws {
        let model = try XCTUnwrap(NSManagedObjectModel.mergedModel(from: [Bundle.main, Bundle(for: Self.self)]))
        let note = try XCTUnwrap(model.entitiesByName["KnowledgeNote"])
        let block = try XCTUnwrap(model.entitiesByName["KnowledgeBlock"])
        let attachment = try XCTUnwrap(model.entitiesByName["KnowledgeAttachment"])
        XCTAssertNotNil(note.attributesByName["stateRaw"])
        XCTAssertNotNil(note.attributesByName["deletedAt"])
        XCTAssertNotNil(note.attributesByName["lockPolicyRaw"])
        XCTAssertNotNil(block.attributesByName["richTextData"])
        XCTAssertNotNil(block.attributesByName["indentLevel"])
        XCTAssertNotNil(attachment.attributesByName["ocrText"])
        XCTAssertNotNil(model.entitiesByName["KnowledgeNoteDraft"])
        XCTAssertNotNil(model.entitiesByName["KnowledgeNoteRevision"])
    }

    func testNotesCompletionModelKeepsSecureAndDerivedDataSeparated() throws {
        let model = try XCTUnwrap(NSManagedObjectModel.mergedModel(from: [Bundle.main, Bundle(for: Self.self)]))
        let cloud = Set(try XCTUnwrap(model.entities(forConfigurationName: "CloudSync")).compactMap(\.name))
        let local = Set(try XCTUnwrap(model.entities(forConfigurationName: "LocalOnly")).compactMap(\.name))
        let draft = try XCTUnwrap(model.entitiesByName["KnowledgeNoteDraft"])
        let revision = try XCTUnwrap(model.entitiesByName["KnowledgeNoteRevision"])
        let link = try XCTUnwrap(model.entitiesByName["KnowledgeLink"])
        let attachment = try XCTUnwrap(model.entitiesByName["KnowledgeAttachment"])

        XCTAssertTrue(cloud.contains("KnowledgeSecureAttachmentPayload"))
        XCTAssertFalse(local.contains("KnowledgeSecureAttachmentPayload"))
        XCTAssertTrue(local.contains("KnowledgeAttachmentJob"))
        XCTAssertFalse(cloud.contains("KnowledgeAttachmentJob"))
        XCTAssertNotNil(draft.attributesByName["createdAt"])
        XCTAssertNotNil(draft.attributesByName["baseContentVersion"])
        XCTAssertNotNil(draft.attributesByName["sceneID"])
        XCTAssertNotNil(revision.attributesByName["sessionID"])
        XCTAssertNotNil(revision.attributesByName["changeKindRaw"])
        XCTAssertNotNil(link.attributesByName["sourceBlockID"])
        XCTAssertNotNil(link.attributesByName["kindRaw"])
        XCTAssertNotNil(attachment.attributesByName["processingStateRaw"])
        XCTAssertNotNil(attachment.attributesByName["protectedRelativePath"])
    }

    func testKnowledgeRichTextV2RoundTripsAndFlagsForwardVersions() throws {
        let linkedNoteID = UUID()
        let payload = KnowledgeRichTextPayload(
            runs: [
                .init(
                    location: 2,
                    length: 7,
                    marks: [.bold, .highlight],
                    link: URL(string: "https://example.com"),
                    foreground: .cocoa,
                    background: .apricot,
                    noteID: linkedNoteID
                )
            ],
            paragraph: .callout
        )

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(KnowledgeRichTextPayload.self, from: encoded)
        XCTAssertEqual(decoded, payload)
        XCTAssertNil(decoded.unsupportedVersion)
        XCTAssertEqual(KnowledgeRichTextPayload(version: 99).unsupportedVersion, 99)
    }

    func testKnowledgeBlockSplitMergeAndMutationInversePreserveIdentity() {
        let id = UUID()
        let original = LifeBoardKnowledgeBlockValue(id: id, noteID: UUID(), text: "Hello world", ordinal: 3)
        let split = KnowledgeNoteDocument.split(block: original, atUTF16Offset: 5)

        XCTAssertEqual(split.leading.id, id)
        XCTAssertNotEqual(split.trailing.id, id)
        XCTAssertEqual(split.leading.text, "Hello")
        XCTAssertEqual(split.trailing.text, " world")

        let merged = KnowledgeNoteDocument.merge(leading: split.leading, trailing: split.trailing)
        XCTAssertEqual(merged.id, id)
        XCTAssertEqual(merged.text, original.text)

        let mutation = NoteMutation.replaceText(
            blockID: id,
            range: NSRange(location: 6, length: 5),
            original: "world",
            replacement: "LifeBoard"
        )
        XCTAssertEqual(
            mutation.inverse(),
            .replaceText(
                blockID: id,
                range: NSRange(location: 6, length: 9),
                original: "LifeBoard",
                replacement: "world"
            )
        )
    }

    func testKnowledgeSearchRankingAndLockedRedaction() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LifeBoardSearchTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let index = try LocalKnowledgeSearchIndex(databaseURL: directory.appendingPathComponent("notes.sqlite"))
        let exactID = UUID()
        let prefixID = UUID()
        let bodyID = UUID()
        let lockedID = UUID()

        try await index.rebuild([
            .init(noteID: exactID, title: "Launch", body: "brief", tags: "", attachments: "", updatedAt: .now, isLocked: false),
            .init(noteID: prefixID, title: "Launch plan", body: "", tags: "", attachments: "", updatedAt: .now, isLocked: false),
            .init(noteID: bodyID, title: "Project", body: "Launch checklist", tags: "", attachments: "", updatedAt: .now, isLocked: false),
            .init(noteID: lockedID, title: "Launch secrets", body: "private", tags: "", attachments: "", updatedAt: .now, isLocked: true)
        ])

        let results = try await index.search("Launch", limit: 10)
        XCTAssertEqual(results.first?.noteID, exactID)
        XCTAssertEqual(results.dropFirst().first?.noteID, prefixID)
        XCTAssertFalse(results.contains { $0.noteID == lockedID })

        try await index.remove(noteID: exactID)
        let resultsAfterRemoval = try await index.search("Launch", limit: 10)
        XCTAssertFalse(resultsAfterRemoval.contains { $0.noteID == exactID })
    }

    func testMarkdownCodecPreservesStructureAndUnsupportedSyntax() {
        let noteID = UUID()
        let markdown = """
        ## Findings
        - [x] Verified migration
        1. Ship safely
        ```
        let value = 42
        ```
        ~~future syntax~~
        """

        let blocks = KnowledgeMarkdownCodec.parse(markdown, noteID: noteID)
        XCTAssertEqual(blocks.map(\.kind), [.heading2, .checklist, .numberedList, .code, .paragraph])
        XCTAssertTrue(blocks[1].isChecked)
        XCTAssertEqual(blocks[3].text, "let value = 42")
        XCTAssertEqual(blocks[4].text, "~~future syntax~~")
        XCTAssertEqual(blocks.map(\.ordinal), Array(blocks.indices))

        let note = LifeBoardKnowledgeNoteValue(id: noteID, spaceID: UUID(), title: "Research", blocks: blocks)
        let exported = KnowledgeMarkdownCodec.render(note)
        XCTAssertTrue(exported.contains("# Research"))
        XCTAssertTrue(exported.contains("- [x] Verified migration"))
        XCTAssertTrue(exported.contains("```"))
    }

    func testKnowledgeSmartQueryComposesDatesChecklistsLinksAndPagination() {
        let spaceID = UUID()
        let tagID = UUID()
        let linkedID = UUID()
        let matching = LifeBoardKnowledgeNoteValue(
            id: linkedID,
            spaceID: spaceID,
            title: "Launch",
            isPinned: true,
            isFavorite: true,
            updatedAt: Date(timeIntervalSince1970: 200),
            blocks: [.init(noteID: linkedID, kind: .checklist, text: "Review", isChecked: false)],
            tagIDs: [tagID]
        )
        let olderID = UUID()
        let older = LifeBoardKnowledgeNoteValue(
            id: olderID,
            spaceID: spaceID,
            title: "Older",
            updatedAt: Date(timeIntervalSince1970: 100),
            blocks: [.init(noteID: olderID, text: "Review")]
        )
        let query = KnowledgeNoteQuery(
            spaceID: spaceID,
            tagIDs: [tagID],
            searchText: "Review",
            modifiedAfter: Date(timeIntervalSince1970: 150),
            checklist: .incomplete,
            links: .incoming,
            pinned: true,
            favorite: true,
            limit: 1
        )

        XCTAssertEqual(
            query.apply(
                to: [older, matching],
                linkedNoteIDs: [linkedID],
                incomingNoteIDs: [linkedID]
            ).map(\.id),
            [linkedID]
        )
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

private struct SemanticIntentAdapterFixture: LifeThreadIntentAdapter {
    func resolve(_ input: LifeThreadIntentInput) async -> LifeThreadIntentResolution? {
        .surfaceAction(.dayRescue)
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

/// Exercises the fasting lifecycle without a Core Data store, so the contract
/// is verified independently of the persistence failures inherited by this
/// worktree.
private actor InMemoryFastingSessionRepository: LifeBoardFastingSessionRepository {
    private var storage: [LifeBoardFastingSessionValue] = []

    func fetchFastingSessions(limit: Int) async throws -> [LifeBoardFastingSessionValue] {
        Array(storage.sorted { $0.startedAt > $1.startedAt }.prefix(max(1, limit)))
    }

    func saveFastingSession(_ value: LifeBoardFastingSessionValue) async throws {
        if let index = storage.firstIndex(where: { $0.id == value.id }) {
            storage[index] = value
        } else {
            storage.append(value)
        }
    }
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

// MARK: - Recovery Center

final class LifeBoardRecoveryStatusTests: XCTestCase {

    private func makeService(
        storeMode: LifeBoardRecoveryStatusService.StoreMode = .fullSync,
        journalIndex: LifeBoardRecoveryStatusService.DerivedIndexState = .ready,
        notesIndex: LifeBoardRecoveryStatusService.DerivedIndexState = .ready,
        pendingJobs: Int = 0
    ) -> LifeBoardRecoveryStatusService {
        LifeBoardRecoveryStatusService(
            storeMode: { storeMode },
            journalIndex: { journalIndex },
            notesIndex: { notesIndex },
            pendingJobCount: { pendingJobs },
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
    }

    func testHealthyWorkspaceReportsEverythingUpToDate() {
        let status = makeService().status()
        XCTAssertEqual(status.worstHealth, .healthy)
        XCTAssertEqual(status.headline, "Everything is up to date.")
        XCTAssertTrue(status.areas.allSatisfy { $0.recovery == nil })
    }

    /// A read-only store is the most frightening state this screen can show, so
    /// it has to lead with the fact that nothing was lost.
    func testReadOnlyStoreLeadsWithSafetyAndNeverNamesTheInternalReason() {
        let status = makeService(storeMode: .readOnly(reason: "persistent_store_schema_invalid")).status()

        XCTAssertEqual(status.worstHealth, .unavailable)
        XCTAssertTrue(status.headline.hasPrefix("Your data is safe"))

        let store = try? XCTUnwrap(status.areas.first { $0.id == "store" })
        XCTAssertEqual(store?.health, .unavailable)
        XCTAssertFalse(
            store?.detail.contains("persistent_store_schema_invalid") ?? true,
            "An internal reason token must never reach primary copy"
        )
    }

    /// Rebuilding is offered only when the user can actually fix something.
    /// A rebuild already in progress is progress, not a call to action.
    func testOnlyStaleIndexesOfferARebuildAction() {
        let rebuilding = makeService(journalIndex: .rebuilding).status()
        let journalRebuilding = rebuilding.areas.first { $0.id == "journal-index" }
        XCTAssertEqual(journalRebuilding?.health, .working)
        XCTAssertNil(journalRebuilding?.recovery, "A rebuild in flight needs no button")

        let stale = makeService(journalIndex: .needsRebuild).status()
        let journalStale = stale.areas.first { $0.id == "journal-index" }
        XCTAssertEqual(journalStale?.health, .attention)
        XCTAssertEqual(journalStale?.recovery, .rebuildJournalIndex)
    }

    /// `working` must not be escalated to a failure, or every ordinary rebuild
    /// reads as damage.
    func testWorkInProgressIsNotReportedAsAFailure() {
        let status = makeService(notesIndex: .rebuilding, pendingJobs: 3).status()
        XCTAssertEqual(status.worstHealth, .working)
        XCTAssertEqual(status.headline, "Your data is safe. Some things are still catching up.")
        XCTAssertEqual(status.areas.first { $0.id == "jobs" }?.detail, "3 attachments are still being processed.")
    }

    func testPendingJobsAreOmittedEntirelyWhenThereIsNoWork() {
        XCTAssertNil(makeService(pendingJobs: 0).status().areas.first { $0.id == "jobs" })
        XCTAssertEqual(
            makeService(pendingJobs: 1).status().areas.first { $0.id == "jobs" }?.detail,
            "One attachment is still being processed."
        )
    }

    /// Every rebuild offered here is derived-only, and the copy has to say so —
    /// this is what makes the button safe to press while worried.
    func testEveryRecoveryActionPromisesCanonicalContentIsUntouched() {
        for recovery in [
            LifeBoardRecoveryStatus.Recovery.rebuildJournalIndex,
            .rebuildNotesIndex,
            .rebuildHomeProjections
        ] {
            XCTAssertTrue(recovery.reassurance.contains("stay exactly as they are"))
            XCTAssertFalse(recovery.actionTitle.isEmpty)
        }
    }

    /// Row identity is stable so a refresh does not re-animate the list.
    func testAreaIdentityIsStableAcrossRefreshes() {
        let service = makeService(journalIndex: .needsRebuild)
        XCTAssertEqual(service.status().areas.map(\.id), service.status().areas.map(\.id))
    }
}

// MARK: - Inbox and triage (Stage 1.1)

final class InboxTriageContractTests: XCTestCase {

    private func item(_ title: String, id: UUID = UUID()) -> InboxItem {
        InboxItem(id: id, origin: .task(id), title: title, capturedAt: Date(timeIntervalSince1970: 0))
    }

    /// The Inbox must never invite triage on something already gone.
    func testScopesNeverMatchArchivedOrDeletedWork() {
        for scope in LifeBoardInboxQuery.Scope.allCases {
            let matching = LifeBoardInboxQuery(scope: scope).matchingDispositions
            XCTAssertFalse(matching.contains(.archived), "\(scope) must not surface archived work")
            XCTAssertFalse(matching.contains(.deleted), "\(scope) must not surface tombstones")
        }
        XCTAssertEqual(LifeBoardInboxQuery(scope: .untriaged).matchingDispositions, [.inbox])
        XCTAssertEqual(LifeBoardInboxQuery(scope: .reference).matchingDispositions, [.reference])
    }

    /// Someday and Reference mean different things; conflating them makes the
    /// Reference destination silently mean "ask me about this later".
    func testReferenceIsDistinctFromSomeday() {
        XCTAssertNotEqual(UnscheduledDisposition.reference, .someday)
        XCTAssertNotEqual(BacklogGroup.reference, .someday)
        XCTAssertTrue(BacklogGroup.allCases.contains(.reference))
    }

    /// An unrecognized disposition has to degrade to Inbox, not disappear —
    /// that is what makes adding this case safe for devices on an older build.
    func testUnknownDispositionDegradesToInboxRatherThanVanishing() {
        XCTAssertNil(UnscheduledDisposition(rawValue: "somethingFromTheFuture"))
        let decoded = UnscheduledDisposition(rawValue: "somethingFromTheFuture") ?? .inbox
        XCTAssertEqual(decoded, .inbox)
        XCTAssertEqual(UnscheduledDisposition(rawValue: "reference"), .reference)
    }

    func testPaginationRejectsDegenerateValues() {
        let query = LifeBoardInboxQuery(scope: .untriaged, limit: 0, offset: -5)
        XCTAssertEqual(query.limit, 1, "A zero limit would fetch nothing forever")
        XCTAssertEqual(query.offset, 0)
    }

    /// Undo has to restore the exact prior day, not a guessed default.
    func testScheduleInvertsToTheExactPreviousDay() {
        let taskID = UUID()
        let monday = PlanningDay(year: 2026, month: 7, day: 27, timeZoneIdentifier: "Asia/Kolkata")
        let friday = PlanningDay(year: 2026, month: 7, day: 31, timeZoneIdentifier: "Asia/Kolkata")

        let mutation = InboxTriageMutation.schedule(taskID: taskID, before: monday, after: friday)
        guard case let .schedule(_, before, after) = mutation.inverse else {
            return XCTFail("Scheduling must invert to a schedule")
        }
        XCTAssertEqual(before, friday)
        XCTAssertEqual(after, monday, "Undo must return the task to the day it came from")
    }

    /// Undoing a schedule that had no prior day must not pin the task to today.
    func testSchedulingPreviouslyUnscheduledWorkUndoesToUnscheduled() {
        let taskID = UUID()
        let mutation = InboxTriageMutation.schedule(
            taskID: taskID,
            before: nil,
            after: PlanningDay(year: 2026, month: 7, day: 31, timeZoneIdentifier: "Asia/Kolkata")
        )
        guard case let .setDisposition(_, _, after) = mutation.inverse else {
            return XCTFail("Undo of a first-time schedule must return it to the Inbox")
        }
        XCTAssertEqual(after, UnscheduledDisposition.inbox)
    }

    func testDispositionChangeInvertsExactly() {
        let taskID = UUID()
        let mutation = InboxTriageMutation.setDisposition(taskID: taskID, before: .inbox, after: .reference)
        XCTAssertEqual(
            mutation.inverse,
            .setDisposition(taskID: taskID, before: .reference, after: .inbox)
        )
        XCTAssertEqual(mutation.inverse.inverse, mutation, "Undo of an undo is the original")
    }

    /// A batch has to unwind last-write-first, or a later mutation can clobber
    /// the state an earlier one is trying to restore.
    func testBatchUnwindsInReverseOrder() {
        let first = UUID()
        let second = UUID()
        let batch = InboxTriageMutation.batch([
            .setDisposition(taskID: first, before: .inbox, after: .someday),
            .setDisposition(taskID: second, before: .inbox, after: .reference)
        ])
        guard case let .batch(inverted) = batch.inverse, inverted.count == 2 else {
            return XCTFail("A batch must invert to a batch of the same size")
        }
        guard case let .setDisposition(leadingID, _, _) = inverted[0] else {
            return XCTFail("Expected a disposition mutation")
        }
        XCTAssertEqual(leadingID, second, "The last write unwinds first")
    }

    func testSummaryCopyNamesTheDestinationInPlainLanguage() {
        let id = UUID()
        XCTAssertEqual(
            InboxTriageMutation.setDisposition(taskID: id, before: .inbox, after: .reference).summary,
            "Kept as reference"
        )
        XCTAssertEqual(
            InboxTriageMutation.setDisposition(taskID: id, before: .inbox, after: .someday).summary,
            "Moved to Someday"
        )
    }

    /// A pending capture has not been committed, so it cannot be scheduled yet.
    func testPendingCapturesAreFlaggedAsNeedingCommitFirst() {
        let captureID = UUID()
        let pending = InboxItem(
            id: captureID,
            origin: .pendingCapture(captureID),
            title: "Call the plumber",
            capturedAt: Date(),
            captureSource: "widget"
        )
        XCTAssertTrue(pending.requiresCommitBeforeScheduling)
        XCTAssertFalse(item("Already a task").requiresCommitBeforeScheduling)
    }

    // MARK: Duplicate detection

    func testIdenticalAndNearIdenticalTitlesAreOfferedForReview() {
        XCTAssertEqual(InboxDuplicatePolicy.similarity("Call the plumber", "call the plumber!"), 1.0)
        let candidates = InboxDuplicatePolicy.candidates(
            for: "Call the plumber",
            among: [item("Call the plumber"), item("Buy milk")]
        )
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.existing.title, "Call the plumber")
    }

    /// Detection only decides whether to *ask*. Unrelated captures must not
    /// interrupt a sub-100ms capture with a duplicate prompt.
    func testUnrelatedCapturesAreNotFlagged() {
        XCTAssertTrue(InboxDuplicatePolicy.similarity("Buy milk", "Renew passport") < InboxDuplicatePolicy.askThreshold)
        XCTAssertTrue(
            InboxDuplicatePolicy.candidates(for: "Buy milk", among: [item("Renew passport")]).isEmpty
        )
    }

    func testEmptyTitlesNeverMatch() {
        XCTAssertEqual(InboxDuplicatePolicy.similarity("", "Buy milk"), 0)
        XCTAssertEqual(InboxDuplicatePolicy.similarity("   ", ""), 0)
    }

    func testCandidatesAreRankedByStrongestMatchFirst() {
        let candidates = InboxDuplicatePolicy.candidates(
            for: "Call the plumber today",
            among: [item("Call the plumber today about the leak"), item("Call the plumber today")]
        )
        XCTAssertEqual(candidates.first?.existing.title, "Call the plumber today")
        XCTAssertTrue(
            candidates.map(\.similarity) == candidates.map(\.similarity).sorted(by: >),
            "Strongest match must be offered first"
        )
    }
}

final class InboxReaderTests: XCTestCase {

    private func task(
        _ title: String,
        disposition: UnscheduledDisposition = .inbox,
        day: PlanningDay? = nil,
        updatedAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> PlanningTaskSummary {
        let id = UUID()
        return PlanningTaskSummary(
            id: id,
            title: title,
            metadata: PlanningTaskMetadata(
                taskID: id,
                planningDay: day,
                unscheduledDisposition: disposition,
                updatedAt: updatedAt
            )
        )
    }

    private func reader(
        tasks: [PlanningTaskSummary] = [],
        captures: [PendingCapture] = []
    ) -> InboxReader {
        InboxReader(openTasks: { tasks }, pendingCaptures: { captures })
    }

    /// A task with a planning day has been triaged, whatever its disposition
    /// still says — otherwise scheduled work reappears in the Inbox forever.
    func testScheduledWorkLeavesTheInboxEvenWhileStillMarkedInbox() async throws {
        let scheduled = task(
            "Already planned",
            day: PlanningDay(year: 2026, month: 7, day: 28, timeZoneIdentifier: "Asia/Kolkata")
        )
        let items = try await reader(tasks: [task("Untriaged"), scheduled])
            .items(for: LifeBoardInboxQuery(scope: .untriaged))
        XCTAssertEqual(items.map(\.title), ["Untriaged"])
    }

    /// Out-of-process captures are the likeliest to be forgotten, so they lead.
    func testPendingCapturesAppearBeforeCanonicalTasks() async throws {
        let items = try await reader(
            tasks: [task("A canonical task")],
            captures: [PendingCapture(rawText: "From the widget", source: "widget")]
        ).items(for: LifeBoardInboxQuery(scope: .untriaged))

        XCTAssertEqual(items.first?.title, "From the widget")
        XCTAssertEqual(items.first?.captureSource, "widget")
        XCTAssertTrue(items.first?.requiresCommitBeforeScheduling ?? false)
        XCTAssertEqual(items.count, 2)
    }

    /// Captures are untriaged by definition and must not leak into a scope the
    /// user opened to review deliberate decisions.
    func testSomedayAndReferenceScopesExcludePendingCaptures() async throws {
        let subject = reader(
            tasks: [task("Deferred", disposition: .someday), task("Kept", disposition: .reference)],
            captures: [PendingCapture(rawText: "Unreviewed", source: "control")]
        )
        let someday = try await subject.items(for: LifeBoardInboxQuery(scope: .someday))
        XCTAssertEqual(someday.map(\.title), ["Deferred"])

        let reference = try await subject.items(for: LifeBoardInboxQuery(scope: .reference))
        XCTAssertEqual(reference.map(\.title), ["Kept"])
    }

    func testArchivedAndDeletedNeverSurface() async throws {
        let items = try await reader(tasks: [
            task("Gone", disposition: .deleted),
            task("Filed", disposition: .archived),
            task("Real")
        ]).items(for: LifeBoardInboxQuery(scope: .untriaged))
        XCTAssertEqual(items.map(\.title), ["Real"])
    }

    func testPaginationSlicesDeterministically() async throws {
        let tasks = (1...5).map {
            task("Task \($0)", updatedAt: Date(timeIntervalSince1970: TimeInterval(1_000 - $0)))
        }
        let subject = reader(tasks: tasks)
        let firstPage = try await subject.items(for: .init(scope: .untriaged, limit: 2, offset: 0))
        let secondPage = try await subject.items(for: .init(scope: .untriaged, limit: 2, offset: 2))

        XCTAssertEqual(firstPage.map(\.title), ["Task 1", "Task 2"])
        XCTAssertEqual(secondPage.map(\.title), ["Task 3", "Task 4"])
    }

    /// The badge must not pay for a full page fetch, and must cap rather than
    /// scan thousands of rows to render a number nobody reads precisely.
    func testUntriagedCountCapsWithoutFetchingTasks() async throws {
        let probe = InboxTaskFetchProbe()
        let subject = InboxReader(
            openTasks: { await probe.record(); return [] },
            pendingCaptures: {
                (1...150).map { PendingCapture(rawText: "Capture \($0)", source: "widget") }
            }
        )
        let count = try await subject.untriagedCount(cap: 99)
        XCTAssertEqual(count, 99)
        let fetched = await probe.didFetch
        XCTAssertFalse(fetched, "The cap was already reached by captures alone")
    }

    func testUntriagedCountCombinesBothOrigins() async throws {
        let count = try await reader(
            tasks: [task("One"), task("Two"), task("Scheduled", day: PlanningDay(year: 2026, month: 7, day: 28, timeZoneIdentifier: "UTC"))],
            captures: [PendingCapture(rawText: "Three", source: "control")]
        ).untriagedCount()
        XCTAssertEqual(count, 3, "Two untriaged tasks plus one capture; the scheduled task is excluded")
    }
}

private actor InboxTaskFetchProbe {
    private(set) var didFetch = false
    func record() { didFetch = true }
}

final class InboxTriageLedgerRoutingTests: XCTestCase {

    private let taskID = UUID()

    private func metadata(
        day: PlanningDay? = nil,
        disposition: UnscheduledDisposition = .inbox
    ) -> PlanningTaskMetadata {
        PlanningTaskMetadata(
            taskID: taskID,
            planningDay: day,
            unscheduledDisposition: disposition,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func day(_ value: Int) -> PlanningDay {
        PlanningDay(year: 2026, month: 7, day: value, timeZoneIdentifier: "Asia/Kolkata")
    }

    /// Triage has to reuse the canonical ledger so it inherits receipts, Undo
    /// and the Insights projection rather than growing a parallel history.
    func testSchedulingTranslatesToACanonicalMetadataMutation() throws {
        let current = metadata()
        let result = InboxTriageMutation
            .schedule(taskID: taskID, before: nil, after: day(31))
            .planMutation(resolve: { _ in current })

        guard case let .success(.saveTaskMetadata(before, after)) = result else {
            return XCTFail("Expected a canonical metadata mutation, got \(result)")
        }
        XCTAssertEqual(before.planningDay, nil, "The before state must be the real one, not a default")
        XCTAssertEqual(after.planningDay, day(31))
    }

    /// Taking something off the calendar has to clear its day, or it keeps
    /// showing up on the Day spine after the user deliberately deferred it.
    func testDeferringClearsAnyStalePlanningDay() throws {
        let scheduled = metadata(day: day(28))
        for disposition in [UnscheduledDisposition.someday, .reference, .deleted] {
            let result = InboxTriageMutation
                .setDisposition(taskID: taskID, before: .inbox, after: disposition)
                .planMutation(resolve: { _ in scheduled })

            guard case let .success(.saveTaskMetadata(_, after)) = result else {
                return XCTFail("Expected a metadata mutation for \(disposition)")
            }
            XCTAssertNil(after.planningDay, "\(disposition) must leave the Day spine")
            XCTAssertEqual(after.unscheduledDisposition, disposition)
        }
    }

    /// Returning something to the Inbox must not silently wipe a day the user
    /// may still want.
    func testReturningToInboxPreservesTheExistingDay() throws {
        let scheduled = metadata(day: day(28), disposition: .someday)
        let result = InboxTriageMutation
            .setDisposition(taskID: taskID, before: .someday, after: .inbox)
            .planMutation(resolve: { _ in scheduled })

        guard case let .success(.saveTaskMetadata(_, after)) = result else {
            return XCTFail("Expected a metadata mutation")
        }
        XCTAssertEqual(after.planningDay, day(28))
    }

    /// A missing task means there is no real `before`, so Undo would be a guess.
    /// Failing loudly beats applying something that cannot be reversed.
    func testUnknownTaskFailsRatherThanSynthesizingABeforeState() {
        let result = InboxTriageMutation
            .setDisposition(taskID: taskID, before: .inbox, after: .someday)
            .planMutation(resolve: { _ in nil })
        XCTAssertEqual(result, .failure(.unknownTask(taskID)))
    }

    /// Project membership and capture commits are not planning metadata, and
    /// saying so explicitly stops a caller silently dropping the decision.
    func testDecisionsOutsidePlanningMetadataReportTheirRealRequirement() {
        XCTAssertEqual(
            InboxTriageMutation.moveToProject(taskID: taskID, before: nil, after: UUID())
                .planMutation(resolve: { _ in self.metadata() }),
            .failure(.requiresTaskRepository)
        )
        XCTAssertEqual(
            InboxTriageMutation.commitCapture(captureID: UUID(), createdTaskID: taskID)
                .planMutation(resolve: { _ in self.metadata() }),
            .failure(.requiresCaptureCommit)
        )
    }

    /// A partially applied batch would leave a half-triaged selection behind a
    /// receipt that cannot undo what it never recorded.
    func testBatchIsAllOrNothing() {
        let known = UUID()
        let unknown = UUID()
        let result = InboxTriageMutation.batch([
            .setDisposition(taskID: known, before: .inbox, after: .someday),
            .setDisposition(taskID: unknown, before: .inbox, after: .reference)
        ]).planMutation(resolve: { id in
            id == known ? PlanningTaskMetadata(taskID: known) : nil
        })
        XCTAssertEqual(result, .failure(.unknownTask(unknown)))
    }

    func testBatchTranslatesToACanonicalBatchPreservingOrder() throws {
        let first = UUID()
        let second = UUID()
        let result = InboxTriageMutation.batch([
            .setDisposition(taskID: first, before: .inbox, after: .someday),
            .setDisposition(taskID: second, before: .inbox, after: .reference)
        ]).planMutation(resolve: { PlanningTaskMetadata(taskID: $0) })

        guard case let .success(.batch(mutations)) = result, mutations.count == 2 else {
            return XCTFail("Expected a canonical batch of two")
        }
        guard case let .saveTaskMetadata(_, leading) = mutations[0] else {
            return XCTFail("Expected metadata mutations")
        }
        XCTAssertEqual(leading.taskID, first, "Application order must be preserved")
    }
}

@MainActor
final class InboxReviewProposalTests: XCTestCase {

    private func store(captures: [PendingCapture]) -> InboxStore {
        InboxStore(
            reader: InboxReader(openTasks: { [] }, pendingCaptures: { captures }),
            planningRepository: NoopInboxPlanningRepository(),
            mutationRepository: NoopInboxMutationRepository()
        )
    }

    private func capture(_ text: String, at date: Date) -> InboxItem {
        let id = UUID()
        return InboxItem(
            id: id,
            origin: .pendingCapture(id),
            title: text,
            capturedAt: date,
            captureSource: "widget"
        )
    }

    /// A proposal is shown, never applied. The Inbox must be able to display
    /// what filing a capture *would* do without doing it.
    func testProposalIsOfferedForUnreviewedCapturesOnly() {
        let subject = store(captures: [])
        let pending = capture("standup 3pm", at: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertNotNil(subject.proposal(for: pending))

        let taskID = UUID()
        let committed = InboxItem(
            id: taskID,
            origin: .task(taskID),
            title: "standup 3pm",
            capturedAt: Date()
        )
        XCTAssertNil(
            subject.proposal(for: committed),
            "A committed task already has its metadata; re-proposing would invite a double edit"
        )
    }

    /// The capture's own timestamp is the reference, not "now" — a capture made
    /// yesterday saying "3pm" meant yesterday's 3pm.
    func testProposalResolvesAgainstTheCaptureTimeNotTheCurrentClock() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 16
        components.hour = 8
        let captured = try XCTUnwrap(Calendar.current.date(from: components))

        let proposal = try XCTUnwrap(store(captures: []).proposal(for: capture("standup 3pm", at: captured)))
        let due = try XCTUnwrap(proposal.dueDate)
        let day = Calendar.current.dateComponents([.year, .month, .day], from: due)

        XCTAssertEqual(day.year, 2026)
        XCTAssertEqual(day.month, 6)
        XCTAssertEqual(day.day, 16, "Must resolve on the capture's day, not today")
    }

    /// Captures with nothing to propose must not render an empty chip row.
    func testCapturesWithoutADateProposeNothing() {
        XCTAssertNil(
            store(captures: []).proposal(for: capture("buy milk", at: Date())),
            "No date phrase means no proposal, not a blank one"
        )
    }

    /// The proposal strips the date phrase from the title, so the review has to
    /// show the title as it would actually be filed.
    func testProposalReportsTheTitleAsItWouldBeFiled() throws {
        let proposal = try XCTUnwrap(
            store(captures: []).proposal(for: capture("call mom tomorrow 3pm", at: Date()))
        )
        XCTAssertEqual(proposal.cleanTitle, "call mom")
        XCTAssertNotEqual(proposal.cleanTitle, "call mom tomorrow 3pm")
    }
}

private struct NoopInboxPlanningRepository: PlanningRepository {
    func fetchTaskMetadata(taskIDs: Set<UUID>?) async throws -> [PlanningTaskMetadata] { [] }
    func saveTaskMetadata(_ value: PlanningTaskMetadata) async throws {}
    func saveTaskMetadata(_ values: [PlanningTaskMetadata]) async throws {}
}

private struct NoopInboxMutationRepository: PlanningMutationRepository {
    func prepare(_ mutation: PlanMutation, source: String, summary: String) async throws -> PlanMutationReceipt {
        throw NSError(domain: "NoopInboxMutationRepository", code: 1)
    }
    func apply(receiptID: UUID) async throws {}
    func undo(receiptID: UUID) async throws {}
    func hasAppliedReceipt(source: String) async throws -> Bool { false }
    func fetchMutationReceipts(since: Date?) async throws -> [PlanningReceiptRecord] { [] }
}

final class CalendarSelectionSemanticsTests: XCTestCase {

    private func event(_ id: String, calendarID: String) -> LifeBoardCalendarEventSnapshot {
        LifeBoardCalendarEventSnapshot(
            id: id,
            calendarID: calendarID,
            calendarTitle: calendarID,
            title: "Event \(id)",
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_000),
            isAllDay: false
        )
    }

    private func filter(_ events: [LifeBoardCalendarEventSnapshot], selected: Set<String>) -> [String] {
        FilterCalendarEventsUseCase().execute(
            events: events,
            selectedCalendarIDs: selected,
            includeDeclined: true,
            includeCanceled: true,
            includeAllDayInAgenda: true
        ).map(\.id)
    }

    /// Consent, not just consistency: someone who never picked calendars must
    /// not silently have all of them read.
    func testEmptySelectionAdmitsNothing() {
        let events = [event("a", calendarID: "work"), event("b", calendarID: "personal")]
        XCTAssertTrue(
            filter(events, selected: []).isEmpty,
            "An empty selection means no calendars chosen, not every calendar"
        )
    }

    func testOnlySelectedCalendarsAreAdmitted() {
        let events = [
            event("a", calendarID: "work"),
            event("b", calendarID: "personal"),
            event("c", calendarID: "work")
        ]
        XCTAssertEqual(filter(events, selected: ["work"]), ["a", "c"])
        XCTAssertEqual(filter(events, selected: ["work", "personal"]).count, 3)
    }

    /// A selection naming a calendar the user no longer has must not resurrect
    /// unselected ones.
    func testStaleSelectionDoesNotFallBackToEverything() {
        let events = [event("a", calendarID: "work"), event("b", calendarID: "personal")]
        XCTAssertTrue(filter(events, selected: ["deleted-calendar"]).isEmpty)
    }
}

final class RecoveryIndexClassificationTests: XCTestCase {

    private typealias Service = LifeBoardRecoveryStatusService

    /// An index that cannot report its own contents is omitted, never shown as
    /// healthy — the Recovery Center must not invent reassurance.
    func testUnreportableIndexIsOmittedRatherThanAssumedHealthy() {
        XCTAssertNil(Service.classifyIndex(indexedItemCount: nil, sourceItemCount: 0))
        XCTAssertNil(Service.classifyIndex(indexedItemCount: nil, sourceItemCount: 42))
    }

    func testPopulatedIndexIsReady() {
        XCTAssertEqual(Service.classifyIndex(indexedItemCount: 12, sourceItemCount: 12), .ready)
        XCTAssertEqual(Service.classifyIndex(indexedItemCount: 1, sourceItemCount: 900), .ready)
    }

    /// An empty index over an empty journal is correct, not broken — offering a
    /// rebuild there would invite the user to fix nothing.
    func testEmptyIndexOverNoContentIsNotAProblem() {
        XCTAssertEqual(Service.classifyIndex(indexedItemCount: 0, sourceItemCount: 0), .notApplicable)
    }

    /// An empty index while source content exists is the one case worth acting on.
    func testEmptyIndexWithContentNeedsRebuild() {
        XCTAssertEqual(Service.classifyIndex(indexedItemCount: 0, sourceItemCount: 5), .needsRebuild)
    }

    /// The classification drives whether a rebuild button appears at all.
    func testOnlyNeedsRebuildSurfacesAnAction() {
        func status(_ state: Service.DerivedIndexState?) -> LifeBoardRecoveryStatus {
            Service(
                storeMode: { .fullSync },
                journalIndex: { state },
                notesIndex: { nil },
                pendingJobCount: { 0 },
                now: { Date(timeIntervalSince1970: 0) }
            ).status()
        }

        XCTAssertNil(status(.ready).areas.first { $0.id == "journal-index" }?.recovery)
        XCTAssertNil(status(.notApplicable).areas.first { $0.id == "journal-index" }?.recovery)
        XCTAssertNil(status(.rebuilding).areas.first { $0.id == "journal-index" }?.recovery)
        XCTAssertEqual(
            status(.needsRebuild).areas.first { $0.id == "journal-index" }?.recovery,
            .rebuildJournalIndex
        )
        XCTAssertNil(status(nil).areas.first { $0.id == "journal-index" })
    }
}

final class TaskExecutionQueryTests: XCTestCase {

    private let today = PlanningDay(year: 2026, month: 7, day: 28, timeZoneIdentifier: "UTC")

    private func day(_ value: Int) -> PlanningDay {
        PlanningDay(year: 2026, month: 7, day: value, timeZoneIdentifier: "UTC")
    }

    private func task(
        _ title: String,
        day plannedDay: PlanningDay? = nil,
        disposition: UnscheduledDisposition = .inbox,
        availability: TaskAvailability = .actionable,
        due: Date? = nil,
        projectID: UUID? = nil,
        pinOrder: Int? = nil,
        updatedAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> PlanningTaskSummary {
        let id = UUID()
        return PlanningTaskSummary(
            id: id,
            title: title,
            projectID: projectID,
            dueDate: due,
            metadata: PlanningTaskMetadata(
                taskID: id,
                planningDay: plannedDay,
                availability: availability,
                unscheduledDisposition: disposition,
                pinOrder: pinOrder,
                updatedAt: updatedAt
            )
        )
    }

    /// A deleted task must never reappear through any saved filter — that would
    /// be data loss wearing a feature's clothes.
    func testTombstonesAreExcludedFromEveryScope() {
        let deleted = task("Gone", day: today, disposition: .deleted)
        for scope in TaskExecutionQuery.Scope.allCases {
            XCTAssertFalse(
                TaskExecutionQuery(scope: scope).matches(deleted, today: today),
                "\(scope) must not surface a tombstone"
            )
        }
    }

    /// Overdue work is today's problem, not quietly filed under a day that passed.
    func testTodayIncludesOverdueWork() {
        let query = TaskExecutionQuery(scope: .today)
        XCTAssertTrue(query.matches(task("Overdue", day: day(20)), today: today))
        XCTAssertTrue(query.matches(task("Due today", day: today), today: today))
        XCTAssertFalse(query.matches(task("Later", day: day(30)), today: today))
        XCTAssertFalse(query.matches(task("Unscheduled"), today: today))
    }

    func testUpcomingIsStrictlyAfterToday() {
        let query = TaskExecutionQuery(scope: .upcoming)
        XCTAssertTrue(query.matches(task("Later", day: day(30)), today: today))
        XCTAssertFalse(query.matches(task("Due today", day: today), today: today))
        XCTAssertFalse(query.matches(task("Overdue", day: day(20)), today: today))
    }

    /// Waiting and paused work must not appear in Today: it is not actionable,
    /// and listing it makes the day look fuller than it is.
    func testTodayExcludesNonActionableWork() {
        let query = TaskExecutionQuery(scope: .today)
        XCTAssertFalse(query.matches(task("Blocked", day: today, availability: .waiting), today: today))
        XCTAssertFalse(query.matches(task("Paused", day: today, availability: .paused), today: today))
    }

    func testInboxIsUntriagedAndUnscheduled() {
        let query = TaskExecutionQuery(scope: .inbox)
        XCTAssertTrue(query.matches(task("Raw"), today: today))
        XCTAssertFalse(query.matches(task("Scheduled", day: today), today: today))
        XCTAssertFalse(query.matches(task("Deferred", disposition: .someday), today: today))
    }

    func testCompletedScopeOnlyMatchesCompletedWork() {
        let query = TaskExecutionQuery(scope: .completed)
        XCTAssertTrue(query.matches(task("Done", day: today), today: today, isComplete: true))
        XCTAssertFalse(query.matches(task("Open", day: today), today: today, isComplete: false))
    }

    func testFiltersCombineAsConjunction() {
        let project = UUID()
        let area = UUID()
        let tag = UUID()
        let query = TaskExecutionQuery(
            scope: .all,
            projectID: project,
            lifeAreaID: area,
            tagIDs: [tag]
        )
        let subject = task("Match", projectID: project)

        XCTAssertTrue(query.matches(subject, today: today, tagIDsForTask: [tag], lifeAreaForTask: area))
        XCTAssertFalse(query.matches(subject, today: today, tagIDsForTask: [], lifeAreaForTask: area))
        XCTAssertFalse(query.matches(subject, today: today, tagIDsForTask: [tag], lifeAreaForTask: UUID()))
        XCTAssertFalse(
            query.matches(task("Other project"), today: today, tagIDsForTask: [tag], lifeAreaForTask: area)
        )
    }

    /// Pagination must not repeat or drop a row, so ties break deterministically.
    func testSortingIsStableAcrossEqualKeys() {
        let same = Date(timeIntervalSince1970: 5_000)
        let tasks = (1...5).map { task("Task \($0)", due: same) }
        let query = TaskExecutionQuery(scope: .all, sort: .deadline)

        XCTAssertEqual(query.sorted(tasks).map(\.id), query.sorted(tasks.shuffled()).map(\.id))
    }

    func testTasksWithoutDeadlinesSortLast() {
        let dated = task("Dated", due: Date(timeIntervalSince1970: 1_000))
        let undated = task("Undated")
        XCTAssertEqual(
            TaskExecutionQuery(scope: .all, sort: .deadline).sorted([undated, dated]).map(\.title),
            ["Dated", "Undated"]
        )
    }

    func testPaginationSlicesWithoutOverlap() {
        let tasks = (1...6).map { task("T\($0)", due: Date(timeIntervalSince1970: TimeInterval($0))) }
        let first = TaskExecutionQuery(scope: .all, limit: 2, offset: 0).paginated(tasks).map(\.title)
        let second = TaskExecutionQuery(scope: .all, limit: 2, offset: 2).paginated(tasks).map(\.title)

        XCTAssertEqual(first, ["T1", "T2"])
        XCTAssertEqual(second, ["T3", "T4"])
        XCTAssertTrue(Set(first).isDisjoint(with: Set(second)))
    }

    func testDegeneratePaginationIsClamped() {
        let query = TaskExecutionQuery(scope: .all, limit: 0, offset: -3)
        XCTAssertEqual(query.limit, 1)
        XCTAssertEqual(query.offset, 0)
    }
}

final class ProjectExecutionSnapshotTests: XCTestCase {

    private let projectID = UUID()

    private func task(
        _ title: String,
        ready: Bool = true,
        availability: TaskAvailability = .actionable,
        due: Date? = nil,
        pinOrder: Int? = nil
    ) -> PlanningTaskSummary {
        let id = UUID()
        return PlanningTaskSummary(
            id: id,
            title: title,
            projectID: projectID,
            dueDate: due,
            metadata: PlanningTaskMetadata(taskID: id, availability: availability, pinOrder: pinOrder),
            dependenciesReady: ready
        )
    }

    private func snapshot(
        mode: ProjectExecutionMode,
        tasks: [PlanningTaskSummary],
        completed: Int = 0,
        milestones: [ProjectMilestone] = []
    ) -> ProjectExecutionSnapshot {
        ProjectExecutionSnapshot(
            projectID: projectID,
            name: "Ship it",
            isArchived: false,
            executionMode: mode,
            sections: [],
            milestones: milestones,
            tasks: tasks,
            completedTaskCount: completed,
            generatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    /// Sequential means one next step. Showing five when only the first is
    /// actionable is how a plan starts lying.
    func testSequentialProjectsFollowUserOrderNotUrgency() {
        let subject = snapshot(
            mode: .sequential,
            tasks: [
                task("Third", due: Date(timeIntervalSince1970: 10), pinOrder: 3),
                task("First", due: Date(timeIntervalSince1970: 9_000), pinOrder: 1),
                task("Second", due: Date(timeIntervalSince1970: 50), pinOrder: 2)
            ]
        )
        XCTAssertEqual(subject.nextAction?.title, "First")
    }

    func testParallelProjectsSurfaceTheMostUrgentReadyTask() {
        let subject = snapshot(
            mode: .parallel,
            tasks: [
                task("Later", due: Date(timeIntervalSince1970: 9_000)),
                task("Soonest", due: Date(timeIntervalSince1970: 10))
            ]
        )
        XCTAssertEqual(subject.nextAction?.title, "Soonest")
    }

    func testDependencyBlockedAndWaitingWorkIsNeverTheNextAction() {
        let subject = snapshot(
            mode: .parallel,
            tasks: [task("Blocked", ready: false), task("Waiting", availability: .waiting)]
        )
        XCTAssertNil(subject.nextAction)
        XCTAssertTrue(subject.isBlocked, "Work exists but none of it can start")
    }

    /// Blocked and finished are different states and must not be conflated.
    func testFinishedProjectIsNotReportedAsBlocked() {
        let subject = snapshot(mode: .parallel, tasks: [], completed: 4)
        XCTAssertNil(subject.nextAction)
        XCTAssertFalse(subject.isBlocked)
        XCTAssertEqual(subject.completionFraction, 1.0)
    }

    /// A brand-new project showing "0%" reads as failure; nothing reads as
    /// what it is — not started.
    func testEmptyProjectReportsNoProgressRatherThanZero() {
        XCTAssertNil(snapshot(mode: .parallel, tasks: []).completionFraction)
    }

    func testCompletionFractionCountsCompletedAgainstTotal() {
        let subject = snapshot(mode: .parallel, tasks: [task("A"), task("B")], completed: 2)
        XCTAssertEqual(subject.totalTaskCount, 4)
        XCTAssertEqual(subject.completionFraction ?? -1, 0.5, accuracy: 0.0001)
    }

    func testNextMilestonePrefersTheEarliestIncompleteTarget() {
        let subject = snapshot(
            mode: .parallel,
            tasks: [task("A")],
            milestones: [
                ProjectMilestone(projectID: projectID, title: "Done already", completedAt: Date(), sortOrder: 0),
                ProjectMilestone(
                    projectID: projectID,
                    title: "Later",
                    targetDay: PlanningDay(year: 2026, month: 9, day: 1, timeZoneIdentifier: "UTC"),
                    sortOrder: 2
                ),
                ProjectMilestone(
                    projectID: projectID,
                    title: "Sooner",
                    targetDay: PlanningDay(year: 2026, month: 8, day: 1, timeZoneIdentifier: "UTC"),
                    sortOrder: 1
                )
            ]
        )
        XCTAssertEqual(subject.nextMilestone?.title, "Sooner")
    }

    /// An undated milestone must not outrank a dated one.
    func testUndatedMilestonesRankAfterDatedOnes() {
        let subject = snapshot(
            mode: .parallel,
            tasks: [],
            milestones: [
                ProjectMilestone(projectID: projectID, title: "Someday", sortOrder: 0),
                ProjectMilestone(
                    projectID: projectID,
                    title: "Dated",
                    targetDay: PlanningDay(year: 2026, month: 12, day: 1, timeZoneIdentifier: "UTC"),
                    sortOrder: 9
                )
            ]
        )
        XCTAssertEqual(subject.nextMilestone?.title, "Dated")
    }
}

final class TaskExecutionProjectionTests: XCTestCase {

    private let today = PlanningDay(year: 2026, month: 7, day: 28, timeZoneIdentifier: "UTC")
    private let projectID = UUID()

    private func day(_ value: Int) -> PlanningDay {
        PlanningDay(year: 2026, month: 7, day: value, timeZoneIdentifier: "UTC")
    }

    private func task(
        _ title: String,
        day plannedDay: PlanningDay? = nil,
        disposition: UnscheduledDisposition = .inbox,
        availability: TaskAvailability = .actionable,
        projectID: UUID? = nil
    ) -> PlanningTaskSummary {
        let id = UUID()
        return PlanningTaskSummary(
            id: id,
            title: title,
            projectID: projectID,
            metadata: PlanningTaskMetadata(
                taskID: id,
                planningDay: plannedDay,
                availability: availability,
                unscheduledDisposition: disposition
            )
        )
    }

    private func projection(
        tasks: [PlanningTaskSummary],
        projects: [PlanningProjectSummary] = []
    ) -> TaskExecutionProjection {
        let reference = today
        return TaskExecutionProjection(
            openTasks: { tasks },
            projects: { projects },
            today: { reference }
        )
    }

    func testEachScopeAnswersTheSameDataDifferently() async throws {
        let subject = projection(tasks: [
            task("Untriaged"),
            task("Overdue", day: day(20)),
            task("Later", day: day(30)),
            task("Blocked", day: today, availability: .waiting),
            task("Deferred", disposition: .someday)
        ])

        let today = try await subject.tasks(for: .init(scope: .today)).map(\.title)
        let upcoming = try await subject.tasks(for: .init(scope: .upcoming)).map(\.title)
        let waiting = try await subject.tasks(for: .init(scope: .waiting)).map(\.title)
        let someday = try await subject.tasks(for: .init(scope: .someday)).map(\.title)
        let inbox = try await subject.tasks(for: .init(scope: .inbox)).map(\.title)

        XCTAssertEqual(today, ["Overdue"])
        XCTAssertEqual(upcoming, ["Later"])
        XCTAssertEqual(waiting, ["Blocked"])
        XCTAssertEqual(someday, ["Deferred"])
        XCTAssertEqual(inbox, ["Untriaged"])
    }

    /// Header counts must not cost one round trip per scope.
    func testCountsResolveEveryScopeFromASingleFetch() async throws {
        let probe = ProjectionFetchProbe()
        let tasks = [task("Overdue", day: day(20)), task("Later", day: day(30))]
        let reference = today
        let subject = TaskExecutionProjection(
            openTasks: { await probe.record(); return tasks },
            today: { reference }
        )

        let counts = try await subject.counts(for: [.today, .upcoming, .waiting])

        XCTAssertEqual(counts[.today], 1)
        XCTAssertEqual(counts[.upcoming], 1)
        XCTAssertEqual(counts[.waiting], 0)
        let fetches = await probe.count
        XCTAssertEqual(fetches, 1, "Five counts must not cost five fetches")
    }

    func testCompletedAndCanonicalFiltersUseTaskDefinitions() async throws {
        let completed = task("Shipped")
        let open = task("Draft")
        let wantedTag = UUID()
        let reference = today
        let subject = TaskExecutionProjection(
            openTasks: { [completed, open] },
            taskDefinitions: {
                [
                    TaskDefinition(
                        id: completed.id,
                        lifeAreaID: UUID(),
                        title: completed.title,
                        context: .computer,
                        isComplete: true,
                        tagIDs: [wantedTag]
                    ),
                    TaskDefinition(
                        id: open.id,
                        title: open.title,
                        context: .anywhere,
                        isComplete: false
                    )
                ]
            },
            today: { reference }
        )

        let completedRows = try await subject.tasks(for: .init(
            scope: .completed,
            tagIDs: [wantedTag],
            context: .computer
        ))
        let allOpenRows = try await subject.tasks(for: .init(scope: .all))

        XCTAssertEqual(completedRows.map(\.id), [completed.id])
        XCTAssertEqual(Set(allOpenRows.map(\.id)), Set([completed.id, open.id]))
    }

    func testUnknownProjectReturnsNilRatherThanAnEmptySnapshot() async throws {
        let subject = projection(tasks: [], projects: [])
        let snapshot = try await subject.projectSnapshot(projectID: UUID(), completedTaskCount: 0)
        XCTAssertNil(snapshot, "A missing project is absent, not empty")
    }

    func testProjectSnapshotExcludesTombstonesAndUsesSuppliedCompletionCount() async throws {
        let subject = projection(
            tasks: [
                task("Open", projectID: projectID),
                task("Gone", disposition: .deleted, projectID: projectID),
                task("Other project", projectID: UUID())
            ],
            projects: [PlanningProjectSummary(id: projectID, name: "Ship it", isArchived: false)]
        )

        let snapshot = try await subject.projectSnapshot(projectID: projectID, completedTaskCount: 3)

        XCTAssertEqual(snapshot?.tasks.map(\.title), ["Open"])
        // Derived from open work alone this would read 0% forever, because
        // completed tasks are not in the open-task projection by definition.
        XCTAssertEqual(snapshot?.completedTaskCount, 3)
        XCTAssertEqual(snapshot?.totalTaskCount, 4)
    }

    func testSectionsAndMilestonesArriveInSortOrder() async throws {
        let subject = projection(
            tasks: [task("Open", projectID: projectID)],
            projects: [PlanningProjectSummary(id: projectID, name: "Ship it", isArchived: false)]
        )
        let snapshot = try await subject.projectSnapshot(
            projectID: projectID,
            completedTaskCount: 0,
            sections: [
                LifeBoardProjectSection(projectID: projectID, name: "Second", sortOrder: 2),
                LifeBoardProjectSection(projectID: projectID, name: "First", sortOrder: 1)
            ],
            milestones: [
                ProjectMilestone(projectID: projectID, title: "Beta", sortOrder: 2),
                ProjectMilestone(projectID: projectID, title: "Alpha", sortOrder: 1)
            ]
        )

        XCTAssertEqual(snapshot?.sections.map(\.name), ["First", "Second"])
        XCTAssertEqual(snapshot?.milestones.map(\.title), ["Alpha", "Beta"])
    }
}

private actor ProjectionFetchProbe {
    private(set) var count = 0
    func record() { count += 1 }
}

@MainActor
final class InboxAlreadyFiledTests: XCTestCase {

    private func store(items: [InboxItem]) -> InboxStore {
        let store = InboxStore(
            reader: InboxReader(openTasks: { [] }, pendingCaptures: { [] }),
            planningRepository: NoopPlanningRepository(),
            mutationRepository: NoopPlanningMutationRepository()
        )
        store.setItemsForTesting(items)
        return store
    }

    private func capture(_ text: String) -> InboxItem {
        let id = UUID()
        return InboxItem(
            id: id,
            origin: .pendingCapture(id),
            title: text,
            capturedAt: Date(timeIntervalSince1970: 0),
            captureSource: "siri"
        )
    }

    private func task(_ title: String) -> InboxItem {
        let id = UUID()
        return InboxItem(id: id, origin: .task(id), title: title, capturedAt: Date(timeIntervalSince1970: 0))
    }

    /// The editor strips the date phrase, so the capture's raw text and the
    /// resulting task title differ — matching must use the parsed title.
    func testCaptureIsRecognisedAfterItsDatePhraseWasStripped() {
        let subject = store(items: [capture("call mom tomorrow"), task("call mom")])
        XCTAssertTrue(subject.alreadyFiled(subject.items[0]))
    }

    func testUnfiledCaptureIsNotFlagged() {
        let subject = store(items: [capture("renew passport"), task("buy milk")])
        XCTAssertFalse(subject.alreadyFiled(subject.items[0]))
    }

    /// A canonical task is not itself a capture and can never be "already filed".
    func testCanonicalTasksAreNeverFlagged() {
        let subject = store(items: [task("call mom"), capture("call mom")])
        XCTAssertFalse(subject.alreadyFiled(subject.items[0]))
    }

    func testCaptureWithNoCanonicalTasksIsNotFlagged() {
        let subject = store(items: [capture("call mom")])
        XCTAssertFalse(subject.alreadyFiled(subject.items[0]))
    }
}

private struct NoopPlanningRepository: PlanningRepository {
    func fetchTaskMetadata(taskIDs: Set<UUID>?) async throws -> [PlanningTaskMetadata] { [] }
    func saveTaskMetadata(_ value: PlanningTaskMetadata) async throws {}
    func saveTaskMetadata(_ values: [PlanningTaskMetadata]) async throws {}
}

private struct NoopPlanningMutationRepository: PlanningMutationRepository {
    func prepare(_ mutation: PlanMutation, source: String, summary: String) async throws -> PlanMutationReceipt {
        PlanMutationReceipt(
            id: UUID(),
            source: source,
            summary: summary,
            forwardData: Data(),
            undoData: Data(),
            createdAt: Date()
        )
    }
    func apply(receiptID: UUID) async throws {}
    func undo(receiptID: UUID) async throws {}
    func hasAppliedReceipt(source: String) async throws -> Bool { false }
    func fetchMutationReceipts(since: Date?) async throws -> [PlanningReceiptRecord] { [] }
}

final class TaskStartDayTests: XCTestCase {

    private let today = PlanningDay(year: 2026, month: 7, day: 28, timeZoneIdentifier: "UTC")

    private func day(_ value: Int) -> PlanningDay {
        PlanningDay(year: 2026, month: 7, day: value, timeZoneIdentifier: "UTC")
    }

    private func task(planned: PlanningDay?, start: PlanningDay?) -> PlanningTaskSummary {
        let id = UUID()
        return PlanningTaskSummary(
            id: id,
            title: "Subject",
            metadata: PlanningTaskMetadata(taskID: id, planningDay: planned, startDay: start)
        )
    }

    /// Planned, start and due are three different questions. Collapsing them is
    /// what makes a day look fuller than it can be.
    func testTaskThatCannotStartYetIsNotTodaysWork() {
        let query = TaskExecutionQuery(scope: .today)
        XCTAssertFalse(
            query.matches(task(planned: today, start: day(30)), today: today),
            "Scheduled for today but not startable until the 30th"
        )
    }

    func testStartDayInThePastDoesNotBlock() {
        let query = TaskExecutionQuery(scope: .today)
        XCTAssertTrue(query.matches(task(planned: today, start: day(20)), today: today))
        XCTAssertTrue(query.matches(task(planned: today, start: today), today: today))
    }

    func testAbsentStartDayImposesNoConstraint() {
        let query = TaskExecutionQuery(scope: .today)
        XCTAssertTrue(query.matches(task(planned: today, start: nil), today: today))
    }

    /// Additive on the wire: metadata written before this field existed decodes
    /// with no start constraint, which is the previous behaviour exactly.
    func testLegacyMetadataDecodesWithoutAStartDay() throws {
        let taskID = UUID()
        let legacy = """
        {
          "taskID": "\(taskID.uuidString)",
          "commitmentLevel": "standard",
          "availability": "actionable",
          "planningContext": "neutral",
          "unscheduledDisposition": "inbox",
          "updatedAt": 0
        }
        """
        let decoded = try JSONDecoder().decode(
            PlanningTaskMetadata.self,
            from: Data(legacy.utf8)
        )
        XCTAssertNil(decoded.startDay)
        XCTAssertEqual(decoded.taskID, taskID)
    }
}

final class StartDayPersistenceTests: XCTestCase {

    /// A start date the user sets must survive relaunch, or the field is
    /// decoration and the Today gate silently forgets its own constraint.
    func testStartDayRoundTripsThroughCoreData() async throws {
        let container = try await makeStartDayContainer()
        let taskID = UUID()
        let context = container.newBackgroundContext()
        try await context.perform {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            task.setValue(taskID, forKey: "id")
            task.setValue("Blocked until August", forKey: "title")
            try context.save()
        }

        let repository = CoreDataPlanningRepository(container: container)
        let start = PlanningDay(year: 2026, month: 8, day: 15, timeZoneIdentifier: "Asia/Kolkata")
        try await repository.saveTaskMetadata(
            PlanningTaskMetadata(
                taskID: taskID,
                planningDay: PlanningDay(year: 2026, month: 7, day: 28, timeZoneIdentifier: "Asia/Kolkata"),
                startDay: start
            )
        )

        let restored = try await repository.fetchTaskMetadata(taskIDs: [taskID]).first
        XCTAssertEqual(restored?.startDay, start)
        XCTAssertEqual(restored?.startDay?.timeZoneIdentifier, "Asia/Kolkata")
    }

    /// Absent is a real state, not zero. A task with no start constraint must
    /// come back with none rather than a fabricated date.
    func testAbsentStartDayStaysAbsent() async throws {
        let container = try await makeStartDayContainer()
        let taskID = UUID()
        let context = container.newBackgroundContext()
        try await context.perform {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            task.setValue(taskID, forKey: "id")
            task.setValue("Anytime", forKey: "title")
            try context.save()
        }

        let repository = CoreDataPlanningRepository(container: container)
        try await repository.saveTaskMetadata(PlanningTaskMetadata(taskID: taskID))

        let restored = try await repository.fetchTaskMetadata(taskIDs: [taskID]).first
        XCTAssertNil(restored?.startDay)
    }

    /// Clearing a start date must actually clear it, not leave the old one.
    func testStartDayCanBeCleared() async throws {
        let container = try await makeStartDayContainer()
        let taskID = UUID()
        let context = container.newBackgroundContext()
        try await context.perform {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            task.setValue(taskID, forKey: "id")
            task.setValue("Unblocked", forKey: "title")
            try context.save()
        }

        let repository = CoreDataPlanningRepository(container: container)
        try await repository.saveTaskMetadata(
            PlanningTaskMetadata(
                taskID: taskID,
                startDay: PlanningDay(year: 2026, month: 8, day: 15, timeZoneIdentifier: "UTC")
            )
        )
        try await repository.saveTaskMetadata(PlanningTaskMetadata(taskID: taskID, startDay: nil))

        let restored = try await repository.fetchTaskMetadata(taskIDs: [taskID]).first
        XCTAssertNil(restored?.startDay)
    }

    /// The new model must carry the milestone entity the project snapshot needs.
    func testCurrentModelDeclaresProjectMilestone() throws {
        let model = try XCTUnwrap(
            NSManagedObjectModel(
                contentsOf: try startDayModelBundleURL()
                    .appendingPathComponent("TaskModelV3_TaskStartDay.mom")
            )
        )
        let milestone = try XCTUnwrap(model.entitiesByName["ProjectMilestone"])
        for attribute in ["id", "projectID", "title", "completedAt", "sortOrder"] {
            XCTAssertNotNil(milestone.attributesByName[attribute], "ProjectMilestone needs \(attribute)")
        }
        // Ordinary planning data, so it syncs privately rather than staying local.
        let cloud = Set(try XCTUnwrap(model.entities(forConfigurationName: "CloudSync")).compactMap(\.name))
        let local = Set(try XCTUnwrap(model.entities(forConfigurationName: "LocalOnly")).compactMap(\.name))
        XCTAssertTrue(cloud.contains("ProjectMilestone"))
        XCTAssertFalse(local.contains("ProjectMilestone"))
    }

    private func startDayModelBundleURL() throws -> URL {
        for bundle in [Bundle.main, Bundle(for: Self.self)] {
            if let url = bundle.url(forResource: "TaskModelV3", withExtension: "momd") { return url }
        }
        throw XCTSkip("Compiled TaskModelV3.momd unavailable")
    }

    private func makeStartDayContainer() async throws -> NSPersistentContainer {
        let model = try XCTUnwrap(
            NSManagedObjectModel(
                contentsOf: try startDayModelBundleURL()
                    .appendingPathComponent("TaskModelV3_TaskStartDay.mom")
            )
        )
        let container = NSPersistentContainer(name: "StartDayRoundTrip", managedObjectModel: model)
        let cloud = NSPersistentStoreDescription()
        cloud.type = NSInMemoryStoreType
        cloud.configuration = "CloudSync"
        cloud.url = URL(fileURLWithPath: "/dev/null/cloud-\(UUID().uuidString)")
        let local = NSPersistentStoreDescription()
        local.type = NSInMemoryStoreType
        local.configuration = "LocalOnly"
        local.url = URL(fileURLWithPath: "/dev/null/local-\(UUID().uuidString)")
        container.persistentStoreDescriptions = [cloud, local]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let lock = NSLock()
            var remaining = container.persistentStoreDescriptions.count
            var firstError: (any Error)?
            container.loadPersistentStores { _, error in
                lock.lock()
                if firstError == nil { firstError = error }
                remaining -= 1
                let finished = remaining == 0
                let resolved = firstError
                lock.unlock()
                guard finished else { return }
                if let resolved { continuation.resume(throwing: resolved) }
                else { continuation.resume() }
            }
        }
        return container
    }
}
