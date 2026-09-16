import XCTest
import SwiftUI
import UIKit
@testable import LifeBoard

/// Representative rendering and isolation regressions. These do not stand in
/// for production-route interaction, accessibility, or Instruments evidence.
@MainActor
final class HomeCardIsolationTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private var palette: DaypartPalette { DaypartTokens.appearancePalette(for: .morning, colorScheme: .light) }

    func testMountedPreviewPreservesInjectedRouterAndLayoutState() async throws {
        let suite = "HomeCardIsolation.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let capture = CaptureRouter()
        let router = AppRouter(defaults: defaults, captureRouter: capture)
        let store = AdaptiveHomeStore(repository: nil)
        let layout = store.layout
        let destination = router.selectedDestination
        let paths = router.paths
        let generation = router.selectionGeneration
        let beforeDefaults = defaults.persistentDomain(forName: suite) as NSDictionary?
        var captureChanges = 0
        capture.onStateChange = { captureChanges += 1 }
        let descriptor = try XCTUnwrap(store.registry.descriptor(for: .tasks))
        let appeared = expectation(description: "Preview mounts and runs its appearance lifecycle")
        let host = UIHostingController(rootView:
            HomeCardSamplePreview(descriptor: descriptor, preset: .standard)
                .environment(router).environment(capture)
                .environment(\.dynamicTypeSize, .large)
                .frame(width: 170.5)
                .onAppear { appeared.fulfill() })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        host.view.layoutIfNeeded()
        await fulfillment(of: [appeared], timeout: 5)
        // Await the actual permitted async dependency rather than sleeping to
        // guess when SwiftUI's image preparation finishes.
        _ = await HomeSceneImageCache.shared.load(kind: .tasks, dark: false)
        XCTAssertEqual(router.selectedDestination, destination)
        XCTAssertEqual(router.paths, paths)
        XCTAssertEqual(router.selectionGeneration, generation)
        XCTAssertNil(capture.activeRequest)
        XCTAssertTrue(capture.pendingRequests.isEmpty)
        XCTAssertEqual(captureChanges, 0)
        XCTAssertEqual(store.layout, layout)
        XCTAssertEqual(defaults.persistentDomain(forName: suite) as NSDictionary?, beforeDefaults)
    }

    func testPreviewDependencyBoundaryHasNoDomainIOOrTimers() throws {
        let folder = root.appendingPathComponent("LifeBoard/DesignSystem/HomeCards")
        let shared = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasSuffix("CardContent.swift") || [
                "HomeCardSamplePreview.swift", "HomeCardPreviewFixtures.swift", "HomeCardScene.swift",
                "HomeCardIllustratedSurface.swift", "HomeCardQueueRow.swift"
            ].contains($0.lastPathComponent) }
        XCTAssertGreaterThan(shared.count, 12)
        let forbidden = ["CompositionRoot.shared", "DependencyContainer.shared", "URLSession", "URLRequest(",
                         "Timer(", "Timer.publish", "Timer.scheduledTimer", "DispatchSource.makeTimerSource",
                         "UserDefaults", "NotificationCenter.default.post", "NSManagedObjectContext"]
        for url in shared + [root.appendingPathComponent("LifeBoard/DesignSystem/LifeBoardHomeCardBodies.swift")] {
            let source = try String(contentsOf: url, encoding: .utf8)
            for token in forbidden {
                XCTAssertFalse(source.contains(token), "\(url.lastPathComponent) introduced \(token) into the preview dependency boundary")
            }
        }
        let preview = try String(contentsOf: folder.appendingPathComponent("HomeCardSamplePreview.swift"), encoding: .utf8)
        XCTAssertTrue(preview.contains(".allowsHitTesting(false)"))
        XCTAssertTrue(preview.contains(".accessibilityElement(children: .ignore)"))
        let cache = try String(contentsOf: folder.appendingPathComponent("HomeSceneImageCache.swift"), encoding: .utf8)
        XCTAssertTrue(cache.contains("UIImage(named:"), "Artwork should resolve a packaged asset")
        XCTAssertFalse(cache.contains("contentsOfFile:"), "Do not load source-resolution files at runtime")
    }

    func testRenderingTaskStatesNeverInvokesMutationOrNavigationCallbacks() throws {
        let cases: [(String, Bool, Bool, [PlanningTaskSummary], String?, PlanningTaskSummary?)] = [
            ("unavailable", false, false, [], nil, nil),
            ("loading", true, true, [], nil, nil),
            ("empty", true, false, [], nil, nil),
            ("refresh recovery", true, false, HomeCardPreviewFixtures.tasks, "Refresh failed", HomeCardPreviewFixtures.tasks[0])
        ]
        for (name, available, loading, tasks, failure, completed) in cases {
            var calls: [String] = []
            let card = HomeTasksCardContent(tasks: tasks, title: "Today’s tasks", emptyMessage: "No tasks due today",
                isLoading: loading, hasPlanningRepository: available, collapsedLimit: 4, isExpanded: false,
                allowsCompletion: true, completedTask: completed, refreshFailure: failure, palette: palette,
                dateControls: EmptyView(), onComplete: { _ in calls.append("complete") },
                onOpen: { _ in calls.append("open") }, onAdd: { calls.append("add") },
                onUndo: { calls.append("undo") }, onRetry: { calls.append("retry") },
                onToggleExpansion: { calls.append("expand") })
            let result = try render(card, width: 170.5)
            XCTAssertGreaterThan(result.image.size.height, 44, name)
            XCTAssertEqual(calls, [], "Rendering \(name) must not execute a user action")
            if !tasks.isEmpty && available && !loading {
                let controls = result.recorder.elements.values.filter { $0.id.hasPrefix("tasks.complete.") || $0.id.hasPrefix("tasks.open.") }
                XCTAssertEqual(controls.count, 8, "Four visible rows, each with separate complete and open targets")
                for control in controls { XCTAssertGreaterThanOrEqual(control.rect[3], 44, control.id) }
            }
        }
    }

    func testProtectedAndDeletedSourcesDoNotRenderSensitivePayloadOrScene() throws {
        for state in [HomeCardSnapshotAvailability.redacted, .unavailable] {
            let snapshot = HomeCardSnapshot(availability: state, title: "Journal", value: "Hidden here",
                detail: "Unlock to continue", payload: .metric(.init(amount: 987654, unit: "private")),
                updatedAt: HomeCardPreviewFixtures.date)
            let result = try render(HomeCardBody(snapshot: snapshot, archetype: .metric, preset: .wide,
                palette: palette, title: "Journal", symbol: "book", presentationStyle: .init(kind: .journal, preset: .wide)))
            XCTAssertEqual(result.recorder.scene, .zero, "\(state) should not mount decorative artwork")
            XCTAssertNil(result.recorder.elements["metric.value"], "Protected payload must not be composed")
            XCTAssertEqual(result.recorder.elements["body.detail"]?.copy, "Unlock to continue")
        }
    }

    func testMissingUserMediaKeepsMediaPrecedenceAndNativeExcerpt() throws {
        let snapshot = HomeCardSnapshot(availability: .ready, title: "Recorded moment",
            payload: .moment(.init(excerpt: "An actual recorded memory", imagePath: "/missing/design-evidence-image.jpg")),
            updatedAt: HomeCardPreviewFixtures.date)
        let result = try render(HomeCardBody(snapshot: snapshot, archetype: .moment, preset: .wide,
            palette: palette, title: "Moment", symbol: "photo", presentationStyle: .init(kind: .lifeMoment, preset: .wide)))
        XCTAssertEqual(result.recorder.scene, .zero, "Missing user media must not be replaced by invented scene evidence")
        XCTAssertTrue(result.recorder.elements.values.contains { $0.copy == "An actual recorded memory" })
    }

    func testLongTaskCopyWrapsInsideNarrowCardAtDefaultTextSize() throws {
        let task = PlanningTaskSummary(id: HomeCardPreviewFixtures.tasks[0].id,
            title: "Review the complete planning notes and prepare the next detailed project proposal before the afternoon review",
            dueDate: HomeCardPreviewFixtures.date,
            metadata: HomeCardPreviewFixtures.tasks[0].metadata)
        let result = try render(HomeTasksCardContent(tasks: [task], title: "Today’s tasks", emptyMessage: "Empty",
            isLoading: false, hasPlanningRepository: true, collapsedLimit: 4, isExpanded: false,
            allowsCompletion: true, completedTask: nil, refreshFailure: nil, palette: palette, dateControls: EmptyView()), width: 170.5)
        let text = try XCTUnwrap(result.recorder.elements["tasks.text.\(task.id.uuidString)"])
        XCTAssertEqual(text.copy, task.title)
        XCTAssertGreaterThan(text.rect[3], 44)
        XCTAssertGreaterThanOrEqual(text.rect[0], 0)
        XCTAssertLessThanOrEqual(text.rect[0] + text.rect[2], 171)
        XCTAssertLessThanOrEqual(text.rect[1] + text.rect[3], result.image.size.height + 0.5)
    }

    func testWarmArtworkLoadReusesPreparedImageAndKeepsAppearanceSeparate() async throws {
        let cache = HomeSceneImageCache()
        let loadedLight = await cache.load(kind: .tasks, dark: false)
        let light = try XCTUnwrap(loadedLight)
        let first = cache.preparationCount
        for _ in 0..<6 {
            let repeated = await cache.load(kind: .tasks, dark: false)
            XCTAssertTrue(repeated === light)
        }
        XCTAssertEqual(cache.preparationCount, first)
        let loadedDark = await cache.load(kind: .tasks, dark: true)
        let dark = try XCTUnwrap(loadedDark)
        XCTAssertFalse(dark === light)
        XCTAssertEqual(cache.preparationCount, first + 1)
        XCTAssertEqual(cache.designEvidenceSnapshot["pendingLoads"], 0)
        XCTAssertEqual(cache.designEvidenceSnapshot["cacheHits"], 6)
    }

    private func render<V: View>(_ content: V, width: CGFloat = 353) throws -> (image: UIImage, recorder: HomeCardGeometryRecorder) {
        let recorder = HomeCardGeometryRecorder()
        let renderer = ImageRenderer(content: content.environment(\.homeCardGeometryRecorder, recorder)
            .environment(\.dynamicTypeSize, .large).environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            .frame(width: width).coordinateSpace(name: "home.card.evidence"))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return (try XCTUnwrap(renderer.uiImage), recorder)
    }
}
