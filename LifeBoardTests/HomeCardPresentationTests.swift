import XCTest
import SwiftUI
import UIKit
@testable import LifeBoard

@MainActor
final class HomeCardPresentationTests: XCTestCase {
    func testSelectedSizeLivesInDraftAndCancelRestoresLayout() throws {
        let store = AdaptiveHomeStore(repository: nil)
        let original = store.layout
        let descriptor = try XCTUnwrap(store.registry.descriptor(for: .goals))
        store.beginCustomization()
        store.addWidget(descriptor, size: .expanded)
        XCTAssertEqual(store.activeLayout.placements.last?.semanticSize, .expanded)
        XCTAssertEqual(store.layout, original)
        store.cancelCustomization()
        XCTAssertEqual(store.activeLayout, original)
    }

    func testUnsupportedSizeCannotEnterDraft() throws {
        let store = AdaptiveHomeStore(repository: nil)
        let descriptor = try XCTUnwrap(store.registry.descriptor(for: .quickCapture))
        store.beginCustomization()
        let original = store.activeLayout
        store.addWidget(descriptor, size: .expanded)
        XCTAssertEqual(store.activeLayout, original)
        store.cancelCustomization()
    }

    func testRegistryCoverageAndDeterministicFixtures() {
        let descriptors = DefaultDashboardWidgetRegistry.shared.availableDescriptors()
        XCTAssertEqual(descriptors.count, 22)
        XCTAssertEqual(descriptors.reduce(0) { $0 + $1.supportedSizes.count }, 92)
        for descriptor in descriptors {
            let first = HomeCardPreviewFixtures.snapshot(for: descriptor.kind)
            XCTAssertEqual(first, HomeCardPreviewFixtures.snapshot(for: descriptor.kind))
            XCTAssertFalse(first.title.isEmpty)
            XCTAssertEqual(first.actions.count, 1)
            XCTAssertNil(first.actions.first?.destination)
        }
    }

    func testPreviewDimensionsAndRenderEvidence() async throws {
        let descriptors = DefaultDashboardWidgetRegistry.shared.availableDescriptors()
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/design/home-cards")
        let capturesEnabled = ProcessInfo.processInfo.environment["LIFEBOARD_CAPTURE_HOME_CARDS"] == "1"
        let images = root.appendingPathComponent("implementation")
        if capturesEnabled { try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true) }
        var measurements: [String: [String: Double]] = [:]
        var compositions: [String: [String: [Double]]] = [:]
        for (device, viewport, columns) in [("iphone", CGFloat(393), 4), ("ipad", CGFloat(834), 8)] {
            for descriptor in descriptors {
                for preset in WidgetSizePreset.allCases where descriptor.supportedSizes.contains(preset) {
                    let contentWidth = viewport - 40
                    let width = HomeCardPresentationStyle.cardWidth(contentWidth: contentWidth, preset: preset, regular: columns > 4)
                    for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                        _ = await HomeSceneImageCache.shared.load(kind: descriptor.kind, dark: name == "dark")
                        let recorder = HomeCardGeometryRecorder()
                        let content = HomeCardSamplePreview(descriptor: descriptor, preset: preset)
                            .environment(\.homeCardGeometryRecorder, recorder)
                            .environment(\.colorScheme, scheme)
                            .environment(\.dynamicTypeSize, .large)
                            .environment(\.locale, Locale(identifier: "en_US"))
                            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                            .frame(width: width)
                        let renderer = ImageRenderer(content: content)
                        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
                        renderer.scale = 2
                        let image = try XCTUnwrap(renderer.uiImage)
                        XCTAssertGreaterThanOrEqual(image.size.height, 104)
                        XCTAssertEqual(image.size.width, width, accuracy: 0.5)
                        let key = "\(descriptor.kind.rawValue)-\(preset.rawValue)-\(device)"
                        if name == "light" {
                            measurements[key] = ["width": width, "height": image.size.height]
                            let body = recorder.content == .zero ? CGRect(origin: .zero, size: image.size) : recorder.content
                            compositions[key] = ["content": [body.minX, body.minY, body.width, body.height],
                                "scene": [recorder.scene.minX, recorder.scene.minY, recorder.scene.width, recorder.scene.height]]
                        }
                        if capturesEnabled { try XCTUnwrap(image.pngData()).write(to: images.appendingPathComponent("\(key)-\(name).png")) }
                    }
                }
            }
        }
        XCTAssertEqual(measurements.count, 184)
        if capturesEnabled {
            try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys])
                .write(to: root.appendingPathComponent("layout-measurements.json"))
            try JSONSerialization.data(withJSONObject: compositions, options: [.prettyPrinted, .sortedKeys])
                .write(to: root.appendingPathComponent("composition-measurements.json"))
        }
    }

    func testSceneVisibilityProtectsNonReadyContentAndUserMedia() {
        for state in HomeCardSnapshotAvailability.allCases {
            XCTAssertFalse(HomeCardPresentationStyle.showsScene(availability: state, hasUserMedia: true))
            XCTAssertEqual(HomeCardPresentationStyle.showsScene(availability: state, hasUserMedia: false), state == .ready || state == .empty)
        }
        XCTAssertFalse(HomeCardPresentationStyle.showsScene(availability: nil, hasUserMedia: false))
    }

    func testPairedAndSolitaryCardsUseProductionFramePlanner() {
        for (width, columns) in [(CGFloat(353), 4), (CGFloat(794), 8)] {
            let span = DashboardResponsiveSpanResolver.columns(for: .standard, columnCount: columns)
            let paired = DashboardFramePlanner.frames(width: width, columnCount: columns, spans: [span, span]) { _, w in
                CGSize(width: w, height: 178)
            }
            XCTAssertEqual(paired.frames[0].width, (width - 12) / 2, accuracy: 0.01)
            let solitary = DashboardFramePlanner.frames(width: width, columnCount: columns, spans: [span]) { _, w in
                CGSize(width: w, height: 178)
            }
            XCTAssertEqual(solitary.frames[0].width, width)
            XCTAssertEqual(paired.frames[1].minX - paired.frames[0].maxX, 12, accuracy: 0.01)
        }
    }

    func testAccessibilityPreviewRemainsMeasurableForEveryKind() throws {
        for descriptor in DefaultDashboardWidgetRegistry.shared.availableDescriptors() {
          for preset in descriptor.supportedSizes {
            let content = HomeCardSamplePreview(descriptor: descriptor, preset: preset)
                .environment(\.dynamicTypeSize, .accessibility5)
                .frame(width: 353)
            let renderer = ImageRenderer(content: content)
            renderer.proposedSize = ProposedViewSize(width: 353, height: nil)
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertGreaterThan(image.size.height, 44)
          }
        }
    }

    func testRTLAmbientSceneKeepsTheSameNativeContentBounds() throws {
        let descriptor = try XCTUnwrap(DefaultDashboardWidgetRegistry.shared.descriptor(for: .journal))
        var frames: [HomeCardGeometryRecorder] = []
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let recorder = HomeCardGeometryRecorder()
            let content = HomeCardSamplePreview(descriptor: descriptor, preset: .wide)
                .environment(\.homeCardGeometryRecorder, recorder)
                .environment(\.layoutDirection, direction)
                .frame(width: 353)
            let renderer = ImageRenderer(content: content)
            XCTAssertNotNil(renderer.uiImage)
            frames.append(recorder)
        }
        XCTAssertGreaterThan(frames[0].scene.width, 0)
        XCTAssertEqual(frames[0].content.size, frames[1].content.size)
        XCTAssertEqual(frames[1].scene.minX, 353 - frames[0].scene.maxX, accuracy: 0.5)
        XCTAssertEqual(frames[1].content.minX, 353 - frames[0].content.maxX, accuracy: 0.5)
        XCTAssertEqual(frames[1].scene, frames[1].content)
    }
}

@MainActor
private final class HomeCardLiveFixture {
    let store = AdaptiveHomeStore(repository: nil)
    let lifeOS: HomeLifeOSProjectionStore
    let projection: HomeProjectionCoordinator
    let capture = CaptureRouter()
    let router: AppRouter
    let date = HomeCardPreviewFixtures.date
    let rhythm = DayLoopSummary(closedStamps: ["20260914", "20260915"], runLength: 1, closedInWindow: 2)

    init() {
        let suite = "LifeBoard.HomeCardDesignFixture.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        router = AppRouter(defaults: defaults, captureRouter: capture)
        projection = HomeProjectionCoordinator(designSnapshot: AdaptiveHomeProjectionSnapshot(
            selectedDate: date, focusTitles: ["Sketch the first draft"], openTaskCount: 7,
            completionRate: 0.4, timelineItems: HomeCardPreviewFixtures.timeline, calendarNeedsSetup: false))
        lifeOS = HomeLifeOSProjectionStore(planningRepository: nil, trackRepository: nil,
                                          phaseIIRepository: nil, taskAgendaDate: date)
        let capacity = CapacityBudget(workingDuration: 14400, fixedCalendarDuration: 0,
            internalFixedDuration: 0, bufferDuration: 0, plannedEstimatedDuration: 9000, missingEstimateCount: 0)
        let plan = PlanDaySnapshot(day: PlanningDay(date: date, timeZone: TimeZone(secondsFromGMT: 0)!),
            capacity: capacity, commitments: [], blocks: [], plannedTasks: HomeCardPreviewFixtures.tasks,
            unscheduledTasks: [], generatedAt: date)
        let track = TrackTodaySnapshot(
            unresolvedMedicationEvents: HomeCardPreviewFixtures.careRows.map {
                MedicationEventValue(id: $0.id, medicationID: $0.id, scheduledAt: date)
            }, habitGrades: [], dueRoutines: HomeCardPreviewFixtures.routineRows.map {
                RoutineDefinition(id: $0.id, title: $0.title, steps: [], createdAt: date, updatedAt: date)
            }, goals: [], hydrationAmountMilliliters: 500, hydrationTargetMilliliters: nil, generatedAt: date)
        var snapshots: [String: HomeCardSnapshot] = [:]
        for descriptor in store.registry.availableDescriptors() {
            for size in descriptor.supportedSizes {
                snapshots[HomeLifeOSProjectionStore.cardSnapshotKey(descriptor.kind, size)] = HomeCardPreviewFixtures.snapshot(for: descriptor.kind)
            }
        }
        lifeOS.installDesignFixture(date: date, tasks: HomeCardPreviewFixtures.tasks, plan: plan, track: track,
            hero: AdaptiveHeroSnapshot(id: "sample.focus", priority: .generalFocus,
                title: "Sketch the first draft", detail: "A quiet 25-minute focus block",
                primaryActionTitle: "Start", generatedAt: date), snapshots: snapshots)
    }

    func card(_ descriptor: DashboardWidgetDescriptor, size: WidgetSizePreset, scheme: ColorScheme) -> HomeDashboardWidget {
        HomeDashboardWidget(
            placement: .init(id: HomeCardPreviewFixtures.tasks[0].id, widgetKind: descriptor.kind.rawValue,
                             semanticSize: size, ordinal: 0),
            kind: descriptor.kind, preset: size, daypart: .morning,
            palette: DaypartTokens.appearancePalette(for: .morning, colorScheme: scheme),
            store: store, lifeOSStore: lifeOS, projectionAdapter: projection, router: router,
            captureRouter: capture, modePolicy: DeterministicDashboardModePolicy(), dashboardDensity: .balanced,
            hasPlanningRepository: true, hasTrackFoundationRepository: true, dayLoopSummary: rhythm,
            motionAnimation: nil, reduceMotion: true, selectedMood: .none, moodEnergy: nil,
            showsMoodDial: .constant(false), expandedTaskWidgetIDs: .constant([]), onOpenWidget: { _ in })
    }
}

extension HomeCardPresentationTests {
    func testProductionAdapterAndPreviewGeometryParity() async throws {
        let fixture = HomeCardLiveFixture()
        let exports = ProcessInfo.processInfo.environment["LIFEBOARD_CAPTURE_HOME_CARDS"] == "1"
        let captureKinds = Set((ProcessInfo.processInfo.environment["LIFEBOARD_CAPTURE_KINDS"] ?? "").split(separator: ",").map(String.init))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/design/home-cards")
        var measurements: [String: [String: Double]] = [:]
        if exports {
            for folder in ["live", "preview"] {
                try FileManager.default.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
            }
        }
        for (device, viewport, regular) in [("iphone", CGFloat(393), false), ("ipad", CGFloat(834), true)] {
            for descriptor in fixture.store.registry.availableDescriptors() where captureKinds.isEmpty || captureKinds.contains(descriptor.kind.rawValue) {
                for size in descriptor.supportedSizes where Self.representativeCases(device: device).contains("\(descriptor.kind.rawValue)-\(size.rawValue)") {
                    let width = HomeCardPresentationStyle.cardWidth(contentWidth: viewport - 40, preset: size, regular: regular)
                    for (appearance, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                        let prepared = await HomeSceneImageCache.shared.load(kind: descriptor.kind, dark: appearance == "dark")
                        let scene = try XCTUnwrap(prepared)
                        let recorder = HomeCardGeometryRecorder()
                        recorder.preparedScene = scene
                        let live = ImageRenderer(content: fixture.card(descriptor, size: size, scheme: scheme)
                            .environment(\.homeCardGeometryRecorder, recorder)
                            .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, .large)
                            .environment(\.locale, Locale(identifier: "en_US"))
                            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!).frame(width: width))
                        let preview = ImageRenderer(content: HomeCardSamplePreview(descriptor: descriptor, preset: size)
                            .environment(\.homeCardGeometryRecorder, recorder)
                            .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, .large)
                            .environment(\.locale, Locale(identifier: "en_US"))
                            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!).frame(width: width))
                        live.scale = 2; preview.scale = 2
                        let liveImage = try XCTUnwrap(live.uiImage)
                        let previewImage = try XCTUnwrap(preview.uiImage)
                        let key = "\(descriptor.kind.rawValue)-\(size.rawValue)-\(device)-\(appearance)"
                        XCTAssertEqual(liveImage.size.height, previewImage.size.height, accuracy: 0.5, key)
                        measurements[key] = ["width": width, "liveHeight": liveImage.size.height, "previewHeight": previewImage.size.height]
                        if exports {
                            try XCTUnwrap(liveImage.pngData()).write(to: root.appendingPathComponent("live/\(key).png"))
                            try XCTUnwrap(previewImage.pngData()).write(to: root.appendingPathComponent("preview/\(key).png"))
                        }
                    }
                }
            }
        }
        let expected = ["iphone", "ipad"].reduce(0) { count, device in
            count + Self.representativeCases(device: device).filter { pair in
                captureKinds.isEmpty || captureKinds.contains(String(pair.split(separator: "-")[0]))
            }.count * 2
        }
        XCTAssertEqual(measurements.count, expected)
        if exports {
            let previousURL = root.appendingPathComponent("live-preview-measurements.json")
            if !captureKinds.isEmpty, let data = try? Data(contentsOf: previousURL),
               let previous = try JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] {
                measurements = previous.merging(measurements) { _, refreshed in refreshed }
            }
            try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys])
                .write(to: root.appendingPathComponent("live-preview-measurements.json"))
        }
        XCTAssertNil(fixture.capture.activeRequest)
        XCTAssertEqual(fixture.router.selectedDestination, .home)
    }
}

extension HomeCardPresentationTests {
    func testAmbientArtworkNeverIncreasesCardHeight() throws {
        let palette = DaypartTokens.appearancePalette(for: .morning, colorScheme: .light)
        for size in WidgetSizePreset.allCases {
            let style = HomeCardPresentationStyle(kind: .journal, preset: size)
            var heights: [CGFloat] = []
            for enabled in [false, true] {
                let renderer = ImageRenderer(content: Text("Native content").padding(16)
                    .modifier(HomeCardIllustratedSurface(style: style, palette: palette, showsScene: enabled))
                    .frame(width: 170.5))
                heights.append(try XCTUnwrap(renderer.uiImage).size.height)
            }
            XCTAssertEqual(heights[0], heights[1], size.rawValue)
        }
    }

    func testSceneImagePreparationIsCoalescedAndReused() async throws {
        let cache = HomeSceneImageCache()
        async let first = cache.load(kind: .journal, dark: false)
        async let second = cache.load(kind: .journal, dark: false)
        let values = await (first, second)
        XCTAssertNotNil(values.0)
        XCTAssertTrue(values.0 === values.1)
        XCTAssertEqual(cache.preparationCount, 1)
        _ = await cache.load(kind: .journal, dark: false)
        XCTAssertEqual(cache.preparationCount, 1)
        let dark = await cache.load(kind: .journal, dark: true)
        XCTAssertNotNil(dark)
        XCTAssertFalse(dark === values.0)
        XCTAssertEqual(cache.preparationCount, 2)
    }
}

extension HomeCardPresentationTests {
    func testAmbientExemplarReview() async throws {
        for kind in [DashboardWidgetKind.bodyMetric, .journal, .tasks] {
            let descriptor = try XCTUnwrap(DefaultDashboardWidgetRegistry.shared.descriptor(for: kind))
            let sizes: [WidgetSizePreset] = kind == .bodyMetric ? [.compact, .wide] : [.standard, .wide]
            for size in sizes {
                for (appearance, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                    _ = await HomeSceneImageCache.shared.load(kind: kind, dark: scheme == .dark)
                    let width: CGFloat = size == .wide ? 353 : 170.5
                    let renderer = ImageRenderer(content: HomeCardSamplePreview(descriptor: descriptor, preset: size)
                        .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, .large).frame(width: width))
                    renderer.scale = 2
                    let image = try XCTUnwrap(renderer.uiImage)
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "ambient-\(kind.rawValue)-\(size.rawValue)-\(appearance)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }
}

extension HomeCardPresentationTests {
    func testFeatureHeaderArtworkAndNormalSizeReview() async throws {
        let titles: [FeatureHeaderScene: String] = [
            .home: "Home", .track: "Track", .plan: "Plan", .insights: "Insights", .eva: "Eva",
            .journal: "Journal", .care: "Care", .routines: "Routines", .goals: "Goals",
            .fasting: "Fasting", .body: "Body metrics", .workout: "Workouts", .sleep: "Sleep",
            .movement: "Movement", .nutrition: "Nutrition", .moment: "Life Moments", .capture: "Capture"
        ]
        var measurements: [String: [String: Double]] = [:]
        for scene in FeatureHeaderScene.allCases {
            for (appearance, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                let image = await HomeSceneImageCache.shared.load(kind: scene.fallbackKind, dark: scheme == .dark, assetName: scene.assetName)
                XCTAssertNotNil(image, scene.assetName)
                let header = AppRootHeader(model: .init(title: try XCTUnwrap(titles[scene]), context: "Tuesday, 15 September"), onCapture: {})
                let plain = ImageRenderer(content: header.frame(width: 353).environment(\.dynamicTypeSize, .large))
                let decorated = ImageRenderer(content: header.featureHeaderArtwork(scene).frame(width: 353)
                    .background(scheme == .dark ? Color(red: 0.08, green: 0.10, blue: 0.17) : Color(red: 0.984, green: 0.953, blue: 0.886))
                    .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, .large))
                decorated.scale = 2
                let capture = try XCTUnwrap(decorated.uiImage)
                XCTAssertEqual(capture.size.height, try XCTUnwrap(plain.uiImage).size.height, scene.rawValue)
                measurements["\(scene.rawValue)-\(appearance)"] = ["width": Double(capture.size.width), "height": Double(capture.size.height)]
                let attachment = XCTAttachment(image: capture)
                attachment.name = "feature-header-\(scene.rawValue)-\(appearance)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        let geometry = XCTAttachment(data: try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        geometry.name = "feature-header-component-measurements"
        geometry.lifetime = .keepAlways
        add(geometry)
    }

    func testFeatureAndCardArtworkHaveIndependentCacheIdentities() async throws {
        let cache = HomeSceneImageCache()
        let card = await cache.load(kind: .tasks, dark: false)
        let header = await cache.load(kind: .tasks, dark: false, assetName: FeatureHeaderScene.plan.assetName)
        XCTAssertNotNil(card)
        XCTAssertNotNil(header)
        XCTAssertFalse(card === header)
        let repeated = await cache.load(kind: .tasks, dark: false, assetName: FeatureHeaderScene.plan.assetName)
        XCTAssertTrue(header === repeated)
        XCTAssertEqual(cache.preparationCount, 2)
    }
}


extension HomeCardPresentationTests {
    private static func representativeCases(device: String) -> Set<String> {
        if device == "ipad" {
            return ["tasks-wide", "journal-tall", "care-standard", "bodyMetric-compact", "lifeSnapshot-wide", "recentMeal-wide"]
        }
        return ["bodyMetric-compact", "logMeal-compact", "setupChecklist-standard", "care-standard", "routines-standard",
                "goals-standard", "workout-standard", "sleep-standard", "movement-standard", "lifeMoment-standard",
                "focusNow-wide", "lifeSnapshot-wide", "tasks-wide", "scheduleCapacity-wide", "quickCapture-wide",
                "compactTimeline-wide", "journal-wide", "progressReflection-wide", "fasting-wide", "evaConversation-wide",
                "nutritionSummary-wide", "recentMeal-wide", "tasks-standard", "tasks-expanded", "journal-tall",
                "quickCapture-compact", "care-compact", "bodyMetric-wide"]
    }

    /// An explicit specification export, excluded from ordinary regression runs.
    func testExportInstrumentedElementSpecifications() async throws {
        guard ProcessInfo.processInfo.environment["LIFEBOARD_CAPTURE_HOME_CARDS"] == "1" else {
            throw XCTSkip("Requires the explicit design evidence capture command")
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/design/home-cards")
        let directory = root.appendingPathComponent("native-specifications")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fixtures: [(DashboardWidgetKind, WidgetSizePreset)] = DefaultDashboardWidgetRegistry.shared.availableDescriptors().flatMap { descriptor in
            descriptor.supportedSizes.map { (descriptor.kind, $0) }
        }
        for (kind, size) in fixtures {
            let descriptor = try XCTUnwrap(DefaultDashboardWidgetRegistry.shared.descriptor(for: kind))
            let width = HomeCardPresentationStyle.cardWidth(contentWidth: 353, preset: size, regular: false)
            for (appearance, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                let preparedScene = await HomeSceneImageCache.shared.load(kind: kind, dark: appearance == "dark")
                XCTAssertNotNil(preparedScene, "Missing prepared scene: \(kind.rawValue) \(appearance)")
                let recorder = HomeCardGeometryRecorder()
                recorder.preparedScene = preparedScene
                let renderer = ImageRenderer(content: HomeCardSamplePreview(descriptor: descriptor, preset: size)
                    .environment(\.homeCardGeometryRecorder, recorder)
                    .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, .large)
                    .environment(\.locale, Locale(identifier: "en_US"))
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                    .frame(width: width).coordinateSpace(name: "home.card.evidence"))
                renderer.scale = 4
                let image = try XCTUnwrap(renderer.uiImage)
                let id = "\(kind.rawValue)-\(size.rawValue)-\(appearance)"
                XCTAssertFalse(recorder.elements.isEmpty, id)
                let elements = recorder.elements.values.sorted { $0.rect[1] == $1.rect[1] ? $0.rect[0] < $1.rect[0] : $0.rect[1] < $1.rect[1] }
                for element in elements {
                    XCTAssertGreaterThan(element.rect[2], 0, element.id)
                    XCTAssertGreaterThan(element.rect[3], 0, element.id)
                }
                let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(elements))
                let spec: [String: Any] = ["id": id, "renderer": "shared-native-content-preview", "fixture_version": 4,
                    "logical_card_points": [width, image.size.height], "viewport_points": [393, 852],
                    "safe_areas": "isolated card; production-route safe areas require separate evidence",
                    "elements": encoded, "appearance": appearance, "dynamic_type": "large",
                    "locale": "en_US", "time_zone": "UTC", "date": "2026-09-15", "daypart": "morning"]
                try JSONSerialization.data(withJSONObject: spec, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent(id + ".json"), options: .atomic)
                try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent(id + ".png"), options: .atomic)
            }
        }
    }
}
