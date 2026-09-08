import XCTest
import SwiftUI
import UIKit
import LifeBoardTokens
@testable import LifeBoard

/// The composer's never-collapse rules, which are the part of the scroll→orb
/// morph that can actually lose someone's work.
///
/// `DESIGN.md:387` lists them: the composer "must never collapse while editing,
/// dictating, reviewing a proposal, waiting for a result, showing a receipt, or
/// holding a draft." Each of those is one test here, because the failure mode is
/// silent — a draft disappears behind an orb and the person has no idea it is
/// still there.
final class ComposerCompressionPolicyTests: XCTestCase {
    private func input(
        offset: CGFloat = 400,
        tracking: Bool = true,
        state: LifeThreadComposerState = .resting,
        hasDraft: Bool = false,
        hasPreview: Bool = false,
        hasReceipt: Bool = false,
        keyboard: Bool = false,
        voiceOver: Bool = false
    ) -> ComposerCompressionInput {
        ComposerCompressionInput(
            contentOffset: offset,
            isTrackingDownward: tracking,
            composerState: state,
            hasDraft: hasDraft,
            hasPreview: hasPreview,
            hasReceipt: hasReceipt,
            isKeyboardFocused: keyboard,
            voiceOverEnabled: voiceOver
        )
    }

    // MARK: The never-collapse list

    func testADraftNeverCompresses() {
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(hasDraft: true), current: .capsule),
            .capsule
        )
        // Also true from an already-compressed state: typing while compressed
        // must restore, not stay hidden.
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(hasDraft: true), current: .orb),
            .capsule
        )
    }

    func testEveryNonRestingStateSuppressesCompression() {
        let suppressing: [LifeThreadComposerState] = [
            .focused, .tools, .recording, .scanning, .working, .review, .dictating
        ]
        for state in suppressing {
            XCTAssertEqual(
                ComposerCompressionPolicy.presentation(input(state: state), current: .capsule),
                .capsule,
                "\(state) must not compress"
            )
        }
    }

    func testOnlyRestingAndSettlingAreCompressible() {
        // `.settling` is the tail of a committed capture — there is nothing left
        // to lose, so it compresses like `.resting`.
        for state in [LifeThreadComposerState.resting, .settling] {
            XCTAssertTrue(
                ComposerCompressionPolicy.isCompressible(input(state: state)),
                "\(state) should be compressible"
            )
        }
        XCTAssertEqual(LifeThreadComposerState.allCases.count, 9, "New states need a compression decision")
    }

    func testPreviewReceiptKeyboardAndVoiceOverEachSuppress() {
        XCTAssertFalse(ComposerCompressionPolicy.isCompressible(input(hasPreview: true)))
        XCTAssertFalse(ComposerCompressionPolicy.isCompressible(input(hasReceipt: true)))
        XCTAssertFalse(ComposerCompressionPolicy.isCompressible(input(keyboard: true)))
        // VoiceOver navigates by element, so a shape change under the cursor
        // moves focus for a reason the user never asked for.
        XCTAssertFalse(ComposerCompressionPolicy.isCompressible(input(voiceOver: true)))
    }

    // MARK: Purposeful scrolling

    func testCompressionRequiresAnActiveDownwardDrag() {
        // Momentum after the finger lifts is movement without intent.
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(tracking: false), current: .capsule),
            .capsule
        )
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(tracking: true), current: .capsule),
            .orb
        )
    }

    func testShallowScrollDoesNotCompress() {
        let justUnder = ComposerCompressionPolicy.compressThreshold - 1
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(offset: justUnder), current: .capsule),
            .capsule
        )
    }

    func testReturningToTopRestores() {
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(
                input(offset: ComposerCompressionPolicy.restoreThreshold, tracking: false),
                current: .orb
            ),
            .capsule
        )
    }

    /// The gap between the two thresholds is the whole reason there are two. With
    /// one value, content resting near it flutters between shapes on every pixel
    /// of scroll.
    func testHysteresisHoldsTheOrbBetweenThresholds() {
        let between = (ComposerCompressionPolicy.compressThreshold
            + ComposerCompressionPolicy.restoreThreshold) / 2
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(offset: between, tracking: false), current: .orb),
            .orb,
            "Already compressed: stays compressed between thresholds"
        )
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(offset: between, tracking: true), current: .capsule),
            .capsule,
            "Not yet compressed: does not compress until the far threshold"
        )
        XCTAssertGreaterThan(
            ComposerCompressionPolicy.compressThreshold,
            ComposerCompressionPolicy.restoreThreshold
        )
    }

    @MainActor
    func testThousandOffsetsPublishOnlyDecisionBoundaries() {
        let observer = ComposerScrollObserver()
        observer.beginTracking()

        for point in 0..<1_000 {
            observer.report(offset: CGFloat(point) / 5)
        }
        observer.endTracking()

        XCTAssertEqual(observer.decisionPublicationCount, 3)
        XCTAssertEqual(observer.sample.positionBand, .compressionRange)
        XCTAssertEqual(observer.sample.interactionGeneration, 1)
        XCTAssertFalse(observer.sample.isTrackingDownward)
    }

    @MainActor
    func testScrollResetPublishesOneGenerationAndClearsIntent() {
        let observer = ComposerScrollObserver()
        observer.beginTracking()
        observer.report(offset: ComposerCompressionPolicy.compressThreshold + 1)
        let publicationCount = observer.decisionPublicationCount

        observer.reset()

        XCTAssertEqual(observer.decisionPublicationCount, publicationCount + 1)
        XCTAssertEqual(observer.sample.positionBand, .top)
        XCTAssertEqual(observer.sample.resetGeneration, 1)
        XCTAssertFalse(observer.sample.isTrackingDownward)
    }

    @MainActor
    func testHomeRefreshCoordinatorCoalescesBurstToLatestGeneration() async {
        let coordinator = AdaptiveHomeRefreshCoordinator()
        var executions: [HomeContextRefreshBoundary] = []
        let operation: @MainActor (AdaptiveHomeRefreshCoordinator.Request, Int) async -> Void = {
            request, generation in
            guard coordinator.isCurrent(generation) else { return }
            executions.append(request.boundary)
        }

        coordinator.request(now: Date(), boundary: .taskMutation, immediate: false, deferred: false, operation: operation)
        coordinator.request(now: Date(), boundary: .trackerCommit, immediate: false, deferred: false, operation: operation)
        coordinator.request(now: Date(), boundary: .daypartBoundary, immediate: false, deferred: false, operation: operation)
        await coordinator.waitUntilSettled()

        XCTAssertEqual(executions, [.daypartBoundary])
        XCTAssertEqual(coordinator.requestCount, 3)
        XCTAssertEqual(coordinator.executedCount, 1)
        XCTAssertEqual(coordinator.completedCount, 1)
    }

    @MainActor
    func testHomeRefreshCoordinatorDefersUntilStable() async {
        let coordinator = AdaptiveHomeRefreshCoordinator()
        var executions = 0
        let operation: @MainActor (AdaptiveHomeRefreshCoordinator.Request, Int) async -> Void = {
            _, generation in
            guard coordinator.isCurrent(generation) else { return }
            executions += 1
        }

        coordinator.request(now: Date(), boundary: .trackerCommit, immediate: false, deferred: true, operation: operation)
        try? await _Concurrency.Task<Never, Never>.sleep(for: .milliseconds(130))
        XCTAssertEqual(executions, 0)

        coordinator.resume(operation: operation)
        try? await _Concurrency.Task<Never, Never>.sleep(for: .milliseconds(130))
        XCTAssertEqual(executions, 1)
    }

    @MainActor
    func testDashboardRenderPlanCacheBuildsOncePerMeaningfulSignature() {
        let cache = HomeDashboardRenderPlanCache()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let signature = HomeDashboardRenderPlanSignature(
            placements: [],
            mode: .smart,
            density: .balanced,
            daypart: .morning,
            calendarDay: day,
            isRegular: false,
            usesAccessibilityLayout: false,
            loopSpineEnabled: true,
            contextCandidates: []
        )
        var builds = 0
        func makePlan() -> HomeDashboardRenderPlan {
            builds += 1
            return HomeDashboardRenderPlan(
                budget: .init(),
                visible: [],
                today: [],
                keepSteady: [],
                closeLoop: [],
                supporting: [],
                resolvedKinds: [:],
                effectivePresets: [:],
                effectiveRoles: [:]
            )
        }

        _ = cache.resolve(signature: signature, build: makePlan)
        _ = cache.resolve(signature: signature, build: makePlan)
        XCTAssertEqual(builds, 1)
        XCTAssertEqual(cache.buildCount, 1)

        let changed = HomeDashboardRenderPlanSignature(
            placements: [],
            mode: .work,
            density: .balanced,
            daypart: .morning,
            calendarDay: day,
            isRegular: false,
            usesAccessibilityLayout: false,
            loopSpineEnabled: true,
            contextCandidates: []
        )
        _ = cache.resolve(signature: changed, build: makePlan)
        XCTAssertEqual(builds, 2)
        XCTAssertEqual(cache.buildCount, 2)
    }

    func testRootActivityRequiresSelectionAndForeground() {
        XCTAssertTrue(RootActivityState.active.performsContinuousWork)
        XCTAssertFalse(
            RootActivityState(isSelected: false, sceneIsActive: true).performsContinuousWork
        )
        XCTAssertFalse(
            RootActivityState(isSelected: true, sceneIsActive: false).performsContinuousWork
        )
    }

    func testInsightsRenderSnapshotHandlesFiveHundredEvidenceRowsOnce() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let domains = ["hydration", "habit", "tracker", "routine", "goal", "plan"]
        let events = (0..<500).map { index in
            NormalizedLifeEvent(
                id: "evidence-\(index)",
                sourceID: UUID(),
                domain: domains[index % domains.count],
                kind: "test",
                occurredAt: now.addingTimeInterval(TimeInterval(-index)),
                localDay: PlanningDay(date: now, timeZone: .current, calendar: calendar),
                numericValue: nil,
                completeness: .complete,
                sensitivity: .privateStandard,
                allowedDestinations: [.insights],
                provenance: "performance-test"
            )
        }

        let snapshot = InsightsRenderSnapshot.build(
            authorizedEvents: events,
            lens: .review,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.events.count, 500)
        XCTAssertEqual(snapshot.sourceCounts.reduce(0) { $0 + $1.count }, 500)
        XCTAssertEqual(snapshot.confidence, 1)
        XCTAssertTrue(snapshot.missingDomains.isEmpty)
    }

    func testRestorationWriterCoalescesAndFlushesNewestSnapshot() async throws {
        let suite = "RestorationWriterTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let writer = RestorationWriter(defaults: .init(value: defaults))

        await writer.enqueue(.init(sequence: 1, state: .init(selectedDestination: .plan)))
        await writer.enqueue(.init(sequence: 2, state: .init(selectedDestination: .track)))
        await writer.enqueue(.init(sequence: 3, state: .init(selectedDestination: .insights)))
        try? await _Concurrency.Task<Never, Never>.sleep(for: .milliseconds(250))

        let coalescedData = try XCTUnwrap(defaults.data(forKey: FoundationPreferenceKey.restorationState))
        XCTAssertEqual(
            try JSONDecoder().decode(RestorationState.self, from: coalescedData).selectedDestination,
            .insights
        )

        await writer.enqueue(.init(sequence: 4, state: .init(selectedDestination: .plan)))
        await writer.flush(.init(sequence: 5, state: .init(selectedDestination: .home)))
        let flushedData = try XCTUnwrap(defaults.data(forKey: FoundationPreferenceKey.restorationState))
        XCTAssertEqual(
            try JSONDecoder().decode(RestorationState.self, from: flushedData).selectedDestination,
            .home
        )
    }
}

@MainActor
private final class PerformanceSuspensionGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var entered = false
    func suspend() async {
        entered = true
        await withCheckedContinuation { continuation = $0 }
    }
    func release() { continuation?.resume(); continuation = nil }
}

extension ComposerCompressionPolicyTests {
    @MainActor
    func testFiniteEffectCleanupExpiresMountedGeneration() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let finished = expectation(description: "Finite effect clears its mounted generation")
        var start: Date? = Date().addingTimeInterval(-1)
        let binding = Binding<Date?>(get: { start }, set: { value in
            start = value
            if value == nil { finished.fulfill() }
        })
        let host = UIHostingController(rootView: Color.clear.frame(width: 30, height: 30)
            .modifier(FiniteEffectLifetime(startDate: binding, duration: 0.42)))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        await fulfillment(of: [finished], timeout: 5)
        XCTAssertNil(start, "Completed effects must clear even when visual ticks are no longer advancing")
    }

    @MainActor
    func testVisualTimelineRegistrationDoesNotDoubleCountAndReleases() {
        let initial = VisualTimelineDiagnostics.activeIDs.count
        let id = UUID()
        VisualTimelineDiagnostics.setActive(true, id: id)
        VisualTimelineDiagnostics.setActive(true, id: id)
        XCTAssertEqual(VisualTimelineDiagnostics.activeIDs.count, initial + 1)
        VisualTimelineDiagnostics.setActive(false, id: id)
        VisualTimelineDiagnostics.setActive(false, id: id)
        XCTAssertEqual(VisualTimelineDiagnostics.activeIDs.count, initial)
    }

    func testMaintenanceRetriesAreBoundedAndIndependentByDomain() {
        var retries = MaintenanceRetryState<String>()
        let now = Date(timeIntervalSinceReferenceDate: 100)
        XCTAssertEqual(retries.failed("focus", message: "offline", at: now), now.addingTimeInterval(5))
        XCTAssertEqual(retries.failed("focus", message: "offline", at: now), now.addingTimeInterval(10))
        XCTAssertEqual(retries.failed("routine", message: "busy", at: now), now.addingTimeInterval(5))
        retries.succeeded("routine")
        XCTAssertEqual(retries.errors["focus"], "offline")
        XCTAssertNil(retries.errors["routine"])
        for _ in 0..<20 { _ = retries.failed("focus", message: "offline", at: now) }
        XCTAssertEqual(retries.failed("focus", message: "offline", at: now), now.addingTimeInterval(300))
        retries.succeeded("focus")
        XCTAssertEqual(retries.failed("focus", message: "again", at: now), now.addingTimeInterval(5))
    }

    func testAmbientVisualPhasePreservesPositionThroughRepeatedVisibilityChanges() {
        let origin = Date(timeIntervalSinceReferenceDate: 100)
        var phase = AmbientVisualPhase()
        XCTAssertEqual(phase.time(at: origin), 100)
        phase.setPaused(true, at: origin.addingTimeInterval(2))
        phase.setPaused(true, at: origin.addingTimeInterval(4))
        XCTAssertEqual(phase.time(at: origin.addingTimeInterval(90)), 102)
        phase.setPaused(false, at: origin.addingTimeInterval(100))
        XCTAssertEqual(phase.time(at: origin.addingTimeInterval(100)), 102)
        XCTAssertEqual(phase.time(at: origin.addingTimeInterval(103)), 105)
        phase.setPaused(true, at: origin.addingTimeInterval(104))
        phase.setPaused(false, at: origin.addingTimeInterval(204))
        phase.setPaused(false, at: origin.addingTimeInterval(205))
        XCTAssertEqual(phase.time(at: origin.addingTimeInterval(205)), 107)
    }

    func testDashboardFramePlannerMatchesReferenceAcrossMixedSpansAndReflow() {
        for columns in [1, 4, 8, 12] {
            for count in [0, 1, 2, 17, 100, 500] {
                for width in [CGFloat(320), CGFloat(760), CGFloat(1_200)] {
                    let spans = (0..<count).map { 1 + (($0 * 7 + count) % columns) }
                    let measure: (Int, CGFloat) -> CGSize = { index, proposed in
                        // Width-dependent text wrapping, varied expansion and media heights.
                        CGSize(width: proposed, height: 28 + CGFloat(index % 9) * 13
                            + ceil(CGFloat(40 + index % 180) / max(1, proposed / 9)) * 18)
                    }
                    let actual = DashboardFramePlanner.frames(width: width, columnCount: columns,
                        spans: spans, measure: measure)
                    let expected = Self.referenceDashboardFrames(width: width, columns: columns,
                        spans: spans, measure: measure)
                    XCTAssertEqual(actual.frames, expected, "columns=\(columns), count=\(count), width=\(width)")
                    XCTAssertEqual(actual.height, expected.map(\.maxY).max() ?? 0)
                }
            }
        }
    }

    private static func referenceDashboardFrames(width: CGFloat, columns: Int, spans: [Int],
        measure: (Int, CGFloat) -> CGSize) -> [CGRect] {
        let gap: CGFloat = 12
        let unit = max(0, (width - CGFloat(columns - 1) * gap) / CGFloat(columns))
        var bottoms = Array(repeating: CGFloat.zero, count: columns)
        var frames: [CGRect] = []
        for (index, requested) in spans.enumerated() {
            let span = min(columns, max(1, requested))
            let candidates = (0...(columns - span)).map { column in
                (column, (column..<(column + span)).map { bottoms[$0] }.max() ?? 0)
            }
            let best = candidates.min { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1 }!
            let itemWidth = unit * CGFloat(span) + gap * CGFloat(span - 1)
            let height = measure(index, itemWidth).height
            frames.append(CGRect(x: CGFloat(best.0) * (unit + gap), y: best.1, width: itemWidth, height: height))
            for column in best.0..<(best.0 + span) { bottoms[column] = best.1 + height + gap }
        }
        let neighbours = frames.indices.map { index in
            frames.indices.contains { other in
                other != index && frames[other].minY < frames[index].maxY - 0.5
                    && frames[other].maxY > frames[index].minY + 0.5
            }
        }
        for index in frames.indices where !neighbours[index] && frames[index].width < width - 0.5 {
            let old = frames[index]
            let height = measure(index, width).height
            frames[index] = CGRect(x: 0, y: old.minY, width: width, height: height)
            let delta = height - old.height
            if abs(delta) > 0.5 {
                for other in frames.indices where other != index && frames[other].minY >= old.maxY - 0.5 {
                    frames[other].origin.y += delta
                }
            }
        }
        return frames
    }

    func testPerformanceAnimationFlagPrecedence() {
        XCTAssertFalse(LifeBoardAnimation.processAnimationsDisabled(arguments: []))
        XCTAssertTrue(LifeBoardAnimation.processAnimationsDisabled(arguments: ["-UI_TESTING"]))
        XCTAssertFalse(LifeBoardAnimation.processAnimationsDisabled(arguments: ["-UI_TESTING", "-LIFEBOARD_UI_TEST_ANIMATIONS_ENABLED"]))
        XCTAssertTrue(LifeBoardAnimation.processAnimationsDisabled(arguments: ["-UI_TESTING", "-LIFEBOARD_UI_TEST_ANIMATIONS_ENABLED", "-DISABLE_ANIMATIONS"]))
    }

    @MainActor
    func testCancelledRefreshWaiterDoesNotCancelNewerRefresh() async {
        let drain = PresentationRefreshDrain()
        let gate = PerformanceSuspensionGate()
        var commits: [Int] = []
        let first = _Concurrency.Task { @MainActor in
            await drain.run { await gate.suspend(); commits.append(1) }
        }
        while !gate.entered { await _Concurrency.Task.yield() }
        let second = _Concurrency.Task { @MainActor in
            await drain.run { commits.append(2) }
        }
        await _Concurrency.Task.yield()
        first.cancel()
        await first.value
        XCTAssertTrue(commits.isEmpty, "Cancelling an awaiter must release it while the producer is still suspended")
        gate.release()
        await second.value
        XCTAssertEqual(commits, [1, 2])
    }

    @MainActor
    func testHomeRefreshRejectsSupersededProviderResultAndMergesReasons() async {
        let coordinator = AdaptiveHomeRefreshCoordinator()
        let gate = PerformanceSuspensionGate()
        var commits = 0
        var reasons: Set<HomeRefreshReason> = []
        let operation: @MainActor (AdaptiveHomeRefreshCoordinator.Request, Int) async -> Void = { request, generation in
            if !gate.entered { await gate.suspend() }
            guard coordinator.isCurrent(generation) else { return }
            commits += 1
            reasons = request.reasons
        }
        coordinator.request(now: Date(), boundary: .taskMutation, immediate: true, deferred: false, operation: operation)
        while !gate.entered { await _Concurrency.Task.yield() }
        coordinator.request(now: Date(), boundary: .trackerCommit, immediate: false, deferred: false, operation: operation)
        coordinator.request(now: Date(), boundary: .daypartBoundary, immediate: false, deferred: false, operation: operation)
        gate.release()
        await coordinator.waitUntilSettled()
        XCTAssertEqual(commits, 1)
        XCTAssertEqual(reasons, [.trackerCommit, .daypartBoundary])
        XCTAssertEqual(coordinator.executedCount, 2)
        XCTAssertEqual(coordinator.completedCount, 1)
    }

    @MainActor
    func testHomeDeactivationRetainsActiveDirtyRequestForReactivation() async {
        let coordinator = AdaptiveHomeRefreshCoordinator()
        let gate = PerformanceSuspensionGate()
        var commits: [Set<HomeRefreshReason>] = []
        let operation: @MainActor (AdaptiveHomeRefreshCoordinator.Request, Int) async -> Void = { request, generation in
            if !gate.entered { await gate.suspend() }
            guard coordinator.isCurrent(generation) else { return }
            commits.append(request.reasons)
        }
        coordinator.request(now: .now, boundary: .taskMutation, immediate: true, deferred: false, operation: operation)
        while !gate.entered { await _Concurrency.Task.yield() }
        coordinator.cancel()
        coordinator.resume(operation: operation)
        await coordinator.waitUntilSettled()
        XCTAssertEqual(commits, [[.taskMutation]])
        gate.release()
        await _Concurrency.Task.yield()
        XCTAssertEqual(commits.count, 1, "The cancelled provider must never publish after reactivation")
        XCTAssertEqual(coordinator.executedCount, 2)
    }

    @MainActor
    func testCommittedRefreshReleasesSatisfiedCallerBeforeNewerWorkFinishes() async {
        let refresh = CommittedProjectionRefresh()
        let firstGate = PerformanceSuspensionGate()
        let secondGate = PerformanceSuspensionGate()
        var firstRevision = SourceRevisionVector()
        firstRevision.advance([.tasks])
        var secondRevision = firstRevision
        secondRevision.advance([.tasks])
        let first = _Concurrency.Task {
            await refresh.run(required: firstRevision, domains: [.tasks]) {
                await firstGate.suspend()
                return .applied(firstRevision)
            }
        }
        while !firstGate.entered { await _Concurrency.Task.yield() }
        let second = _Concurrency.Task {
            await refresh.run(required: secondRevision, domains: [.tasks]) {
                await secondGate.suspend()
                return .applied(secondRevision)
            }
        }
        await _Concurrency.Task.yield()
        firstGate.release()
        let firstResult = await first.value
        XCTAssertEqual(firstResult, .applied(firstRevision))
        while !secondGate.entered { await _Concurrency.Task.yield() }
        secondGate.release()
        let secondResult = await second.value
        XCTAssertEqual(secondResult, .applied(secondRevision))
    }

    @MainActor
    func testCommittedRefreshCancellationReleasesCallerWithoutCancellingPublication() async {
        let refresh = CommittedProjectionRefresh()
        let gate = PerformanceSuspensionGate()
        var revision = SourceRevisionVector()
        revision.advance([.tasks])
        var published = false
        let caller = _Concurrency.Task {
            await refresh.run(required: revision, domains: [.tasks]) {
                await gate.suspend()
                published = true
                return .applied(revision)
            }
        }
        while !gate.entered { await _Concurrency.Task.yield() }
        caller.cancel()
        let outcome = await caller.value
        XCTAssertEqual(outcome, .cancelled)
        XCTAssertFalse(published)
        gate.release()
        while !published { await _Concurrency.Task.yield() }
    }

    @MainActor
    func testCommittedRefreshDoesNotAcknowledgeUnpublishedDomain() async {
        let refresh = CommittedProjectionRefresh()
        let firstGate = PerformanceSuspensionGate()
        let secondGate = PerformanceSuspensionGate()
        var revisions = SourceRevisionVector()
        revisions.advance([.tasks, .tracking])
        var trackingFinished = false
        let first = _Concurrency.Task {
            await refresh.run(required: revisions, domains: [.tasks]) {
                await firstGate.suspend()
                return .applied(revisions)
            }
        }
        while !firstGate.entered { await _Concurrency.Task.yield() }
        let second = _Concurrency.Task {
            let result = await refresh.run(required: revisions, domains: [.tracking]) {
                await secondGate.suspend()
                return .applied(revisions)
            }
            trackingFinished = true
            return result
        }
        await _Concurrency.Task.yield()
        firstGate.release()
        _ = await first.value
        while !secondGate.entered { await _Concurrency.Task.yield() }
        await _Concurrency.Task.yield()
        XCTAssertFalse(trackingFinished, "Task publication cannot acknowledge tracking just because its revision was observed")
        secondGate.release()
        let result = await second.value
        XCTAssertEqual(result, .applied(revisions))
    }

    @MainActor
    func testCommittedRefreshDeactivationCannotFinishNewGenerationWaiters() async {
        let refresh = CommittedProjectionRefresh()
        let oldGate = PerformanceSuspensionGate()
        let newGate = PerformanceSuspensionGate()
        var required = SourceRevisionVector()
        required.advance([.tracking])
        let first = _Concurrency.Task {
            await refresh.run(required: required, domains: [.tracking]) {
                await oldGate.suspend()
                return .applied(required)
            }
        }
        while !oldGate.entered { await _Concurrency.Task.yield() }
        refresh.cancel()
        let cancelled = await first.value
        XCTAssertEqual(cancelled, .cancelled)
        var finished = false
        let second = _Concurrency.Task {
            let result = await refresh.run(required: required, domains: [.tracking]) {
                await newGate.suspend()
                return .applied(required)
            }
            finished = true
            return result
        }
        while !newGate.entered { await _Concurrency.Task.yield() }
        oldGate.release()
        await _Concurrency.Task.yield()
        XCTAssertFalse(finished)
        newGate.release()
        let applied = await second.value
        XCTAssertEqual(applied, .applied(required))
    }

    @MainActor
    func testCommittedRefreshNeverReportsOldProjectionAsApplied() async {
        let refresh = CommittedProjectionRefresh()
        var required = SourceRevisionVector()
        required.advance([.tasks])
        let outcome = await refresh.run(required: required, domains: [.tasks]) {
            .applied(SourceRevisionVector())
        }
        guard case .failed = outcome else { return XCTFail("An older projection is an explicit failure") }
    }

    @MainActor
    func testImmediateHomeRefreshBypassesExistingDebounce() async {
        let gate = PerformanceSuspensionGate()
        let coordinator = AdaptiveHomeRefreshCoordinator(debounce: { await gate.suspend() })
        var committed = false
        let operation: @MainActor (AdaptiveHomeRefreshCoordinator.Request, Int) async -> Void = { _, generation in
            if coordinator.isCurrent(generation) { committed = true }
        }
        coordinator.request(now: .now, boundary: .trackerCommit, immediate: false, deferred: false, operation: operation)
        while !gate.entered { await _Concurrency.Task.yield() }
        coordinator.request(now: .now, boundary: .taskMutation, immediate: true, deferred: false, operation: operation)
        await coordinator.waitUntilSettled()
        gate.release()
        XCTAssertTrue(committed, "Immediate work must start without waiting for the automatic debounce timer")
        await coordinator.waitUntilSettled()
        XCTAssertEqual(coordinator.executedCount, 1)
    }

    @MainActor
    func testHomeProviderRegistryDoesNotRetainProjectionStore() async throws {
        var store: HomeLifeOSProjectionStore? = HomeLifeOSProjectionStore(planningRepository: nil, trackRepository: nil, phaseIIRepository: nil)
        weak var weakStore = store
        let registry = try XCTUnwrap(store).makeHomeCardProviderRegistry()
        store = nil
        XCTAssertNil(weakStore)
        let definitions = await registry.registeredDefinitions()
        XCTAssertFalse(definitions.isEmpty)
    }

    @MainActor
    func testNoOpHomeLoadDoesNotPublishAnotherCommit() async {
        let store = HomeLifeOSProjectionStore(planningRepository: nil, trackRepository: nil, phaseIIRepository: nil)
        await store.load()
        let count = store.loadCommitCount
        await store.load()
        XCTAssertEqual(store.loadCommitCount, count)
    }

    func testCardPresentationIgnoresFetchTimeButIncludesRouteAndAvailability() {
        let first = HomeCardResolution(snapshot: .init(availability: .ready, title: "Water", value: "250 ml", updatedAt: .distantPast), primaryRoute: nil)
        var second = first
        second.snapshot.updatedAt = .now
        XCTAssertTrue(first.hasSamePresentation(as: second))
        second.primaryActionTitle = "Record water"
        XCTAssertFalse(first.hasSamePresentation(as: second))
        second = first
        second.snapshot.availability = .degraded
        XCTAssertFalse(first.hasSamePresentation(as: second))
    }

    func testInvisiblePeriodicClockHasNoRecurringEntries() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(Array(VisiblePeriodicSchedule(interval: 1, active: false).entries(from: now, mode: .normal)), [now])
        let active = Array(VisiblePeriodicSchedule(interval: 1, active: true).entries(from: now, mode: .normal).prefix(3))
        XCTAssertEqual(active, [now, now.addingTimeInterval(1), now.addingTimeInterval(2)])
    }

    @MainActor
    func testRootCompletionRejectsOldGeneration() {
        let count = RootNavigationPerformanceTrace.completedCount
        RootNavigationPerformanceTrace.begin(destination: .home, coldMount: false, generation: 1)
        RootNavigationPerformanceTrace.begin(destination: .home, coldMount: false, generation: 2)
        RootNavigationPerformanceTrace.markInteractive(destination: .home, generation: 1)
        XCTAssertEqual(RootNavigationPerformanceTrace.completedCount, count)
        RootNavigationPerformanceTrace.markInteractive(destination: .home, generation: 2)
        XCTAssertEqual(RootNavigationPerformanceTrace.completedCount, count + 1)
    }

    func testRestorationRejectsLateEnqueueAfterNewerFlush() async throws {
        let name = "RestorationOrdering.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let writer = RestorationWriter(defaults: .init(value: defaults))
        await writer.flush(.init(sequence: 10, state: .init(selectedDestination: .insights)))
        await writer.enqueue(.init(sequence: 9, state: .init(selectedDestination: .plan)))
        await writer.flush(.init(sequence: 8, state: .init(selectedDestination: .track)))
        let data = try XCTUnwrap(defaults.data(forKey: FoundationPreferenceKey.restorationState))
        XCTAssertEqual(try JSONDecoder().decode(RestorationState.self, from: data).selectedDestination, .insights)
    }
}
