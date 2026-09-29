//
//  LifeBoardUITests.swift
//  LifeBoardUITests
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import XCTest

@MainActor
class LifeBoardUITests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }


    /// Explicit capture command writes durable files; ordinary XCTest runs only attach evidence.
    func testProductionArtworkRouteEvidence() throws {
        let env = ProcessInfo.processInfo.environment
        let routes = (env["LIFEBOARD_EVIDENCE_ROUTES"] ?? "home").split(separator: ",").map(String.init)
        let arrangements = (env["LIFEBOARD_EVIDENCE_ARRANGEMENTS"] ?? "mixed").split(separator: ",").map(String.init)
        let appearances = (env["LIFEBOARD_EVIDENCE_APPEARANCES"] ?? "light,dark").split(separator: ",").map(String.init)
        for appearance in appearances {
            for route in routes {
                for arrangement in (route == "home" ? arrangements : ["mixed"]) {
                    let app = productionEvidenceApp(route: route, arrangement: arrangement, appearance: appearance)
                    app.launch()
                    defer { app.terminate() }
                    let geometry = app.descendants(matching: .any)["home.productionEvidence.geometry"]
                    XCTAssertTrue(geometry.waitForExistence(timeout: 30), "The real FoundationShell must mount.")
                    let frame = app.windows.firstMatch.frame
                    let isTablet = frame.width > 700
                    // Device class, not a pinned frame: the evidence script
                    // runs this on the artwork iPhone 16 (393×852), but the
                    // suite's test device is an iPhone 17 Pro (402×874).
                    XCTAssertTrue(isTablet ? frame.width >= 744 : (frame.width >= 375 && frame.width <= 440), "Unexpected window \(frame)")
                    XCTAssertTrue(isTablet ? frame.height >= 1024 : (frame.height >= 812 && frame.height <= 960), "Unexpected window \(frame)")
                    let expected: [String: String] = [
                        "home": "home.header", "plan": "plan.header", "track": "track.header",
                        "eva": "foundation.eva", "insights": "foundation.insights", "journal": "journal.workspace",
                        "care": "track.medication.new", "routines": "track.routines.destination", "goals": "track.goals.destination",
                        "fasting": "fasting.workspace", "body": "wellness.workspace", "workout": "wellness.workspace",
                        "sleep": "wellness.workspace", "movement": "wellness.workspace", "nutrition": "nutrition.timeline",
                        "moment": "lifeMoments.workspace", "capture": "addTask.view"
                    ]
                    if let identifier = expected[route] {
                        XCTAssertTrue(app.descendants(matching: .any)[identifier].waitForExistence(timeout: 20), "Actual route \(route) must mount \(identifier).")
                    } else {
                        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15))
                    }
                    // The customization framing check is a default-size
                    // composition rule; at accessibility sizes the control sits
                    // several screens down and the capture is what matters.
                    if route == "home" && arrangement != "lowEnergy" && Self.productionEvidenceNameSuffix.isEmpty {
                        // The primary capture is the initial production composition. Scroll
                        // reachability is checked independently so a header control cannot
                        // change the framing of the saved evidence image.
                        let customize = app.buttons["home.customize"]
                        XCTAssertTrue(customize.waitForExistence(timeout: 12), "Home must expose customization.")
                        let scrollSurface = app.scrollViews.firstMatch
                        if scrollSurface.exists {
                            scrollUntilHittableWithSmallSteps(customize, in: app, maximumSteps: 8)
                        }
                        XCTAssertTrue(customize.isHittable, "Home customization must remain reachable.")
                    }
                    let name = "\(isTablet ? "tablet" : "phone")-\(route)-\(arrangement)-\(appearance)\(Self.productionEvidenceNameSuffix)"
                    let screenshot = XCUIScreen.main.screenshot()
                    let attachment = XCTAttachment(screenshot: screenshot)
                    attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
                    if env["LIFEBOARD_CAPTURE_PRODUCTION_ROUTES"] == "1", let output = env["LIFEBOARD_EVIDENCE_OUTPUT"] {
                        let directory = URL(fileURLWithPath: output)
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        try screenshot.pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
                        var metadata = (geometry.value as? String).flatMap { $0.data(using: .utf8) }
                            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
                        metadata["viewport"] = [frame.width, frame.height]
                        metadata["appearance"] = appearance
                        metadata["rendererRevision"] = env["LIFEBOARD_EVIDENCE_RENDERER_REVISION"] ?? "unrecorded"
                        metadata["evidenceLevel"] = "actual-production-route-seeded-repositories"
                        try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                            .write(to: directory.appendingPathComponent(name + ".json"), options: .atomic)
                        try app.debugDescription.write(to: directory.appendingPathComponent(name + ".accessibility.txt"), atomically: true, encoding: .utf8)
                    }
                    app.terminate()
                }
            }
        }
    }

    /// `LIFEBOARD_EVIDENCE_CONTENT_SIZE` lets the sweep run at an accessibility
    /// size; captures at any size other than L carry a suffix so they never
    /// overwrite the default evidence.
    private static var productionEvidenceContentSize: String {
        ProcessInfo.processInfo.environment["LIFEBOARD_EVIDENCE_CONTENT_SIZE"] ?? "UICTContentSizeCategoryL"
    }

    /// `LIFEBOARD_EVIDENCE_CELESTIAL_PHASE` picks the sky. The foundation roots
    /// are paper at night (`DESIGN.md`, Colors), so "dark" evidence for them is
    /// a `night` capture rather than a system-appearance one. Any value other
    /// than a `CelestialPhase` raw value falls back to `morning`.
    private static var productionEvidenceCelestialPhase: String {
        let phases = ["dawn", "morning", "midday", "goldenHour", "twilight", "night"]
        let requested = ProcessInfo.processInfo.environment["LIFEBOARD_EVIDENCE_CELESTIAL_PHASE"] ?? "morning"
        return phases.contains(requested) ? requested : "morning"
    }

    private static var productionEvidenceNameSuffix: String {
        var suffix = ""
        let phase = productionEvidenceCelestialPhase
        if phase != "morning" { suffix += "-" + phase.lowercased() }
        let size = productionEvidenceContentSize
        if size != "UICTContentSizeCategoryL" {
            suffix += "-" + size.replacingOccurrences(of: "UICTContentSizeCategory", with: "").lowercased()
        }
        return suffix
    }

    private func productionEvidenceApp(route: String, arrangement: String, appearance: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UI_TESTING", "-RESET_APP_STATE", "-SKIP_ONBOARDING", "-DISABLE_CLOUD_SYNC",
            "-LIFEBOARD_PRODUCTION_EVIDENCE", "-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE",
            "-LIFEBOARD_TEST_EVA_ACTIVATION_COMPLETED", "-LIFEBOARD_CELESTIAL_PHASE=\(Self.productionEvidenceCelestialPhase)",
            "-LIFEBOARD_DISABLE_HOME_LOOP_SPINE_V1", "-LIFEBOARD_DISABLE_DAY_OPEN_COMMIT_V1", "-LIFEBOARD_DISABLE_DAY_CLOSE_V1",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-AppleInterfaceStyle", appearance == "dark" ? "Dark" : "Light",
            "-UIPreferredContentSizeCategoryName", Self.productionEvidenceContentSize,
            // The shell pins its colour scheme to this fixture; the UIKit
            // interface-style argument alone left every "dark" capture light.
            "-LIFEBOARD_VISUAL_APPEARANCE=\(appearance == "dark" ? "dark" : "light")"]
        app.launchArguments += ["LIFE_OS_FOUNDATION", "DASHBOARD_CUSTOMIZATION_V2", "TRACKERS_V1", "HEALTH_INTEGRATIONS_V1",
            "JOURNAL_V1", "KNOWLEDGE_NOTES_V1", "PLANNING_CORE_V1", "FOCUS_EXECUTION_V2", "TRACK_FOUNDATIONS_V2",
            "GOALS_ROUTINES_V1", "CARE_MODULES_V2", "LIFE_OS_UNIFIED_PRESENTATION_V2", "PREMIUM_IA_V5",
            "WELLNESS_CORE_V1", "FASTING_V2", "NUTRITION_V1", "LIFE_MOMENTS_V1"].map { "-LIFEBOARD_ENABLE_" + $0 }
        app.launchEnvironment = ["PERFORMANCE_TEST": "1", "TZ": "UTC",
            "LIFEBOARD_EVIDENCE_ROUTE": route, "LIFEBOARD_EVIDENCE_ARRANGEMENT": arrangement]
        return app
    }

    func testLaunchPerformance() {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    func testFoundationRootsAndCaptureRemainReachableAtLargestAccessibilitySize() {
        let app = launchFoundationApp(accessibilityCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        defer { app.terminate() }

        let chrome = app.descendants(matching: .any)["LifeBoardCompactChrome"]
        XCTAssertTrue(chrome.waitForExistence(timeout: 15), "The measured foundation chrome should mount.")

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        assertFoundationDestination("track", rootIdentifier: "track.header", in: app)
        assertFoundationDestination("insights", rootIdentifier: "foundation.insights", in: app)
        assertFoundationDestination("eva", rootIdentifier: "foundation.eva", in: app)
        // `home.header` is Home's root everywhere else; the signal row is a
        // lazy section that need not be realised at accessibility XXXL.
        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        XCTAssertFalse(app.textFields["home.lifeThread.composer"].exists)

        // At accessibility sizes Home hides the floating composer, so the
        // header owns capture there; Plan always keeps the floating composer
        // (its tools toggle is the capture entry). Both must stay reachable.
        let capture = app.buttons["foundation.capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        XCTAssertTrue(capture.isHittable, "Header capture must remain reachable.")
        capture.tap()
        if app.buttons["Capture Task"].waitForExistence(timeout: 5) == false {
            // The header is still settling its accessibility layout right
            // after the root cycle; one more tap on the settled control.
            capture.tap()
        }
        XCTAssertTrue(app.buttons["Capture Task"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Capture Journal"].exists)
        XCTAssertTrue(app.buttons["Capture Note"].exists)
        XCTAssertTrue(app.buttons["Capture Tracker"].exists)
        XCTAssertTrue(app.buttons["Capture Mood"].exists)
        XCTAssertTrue(capture.isHittable, "The header control must remain anchored while its tray is open.")
        capture.tap()
        XCTAssertFalse(app.buttons["Capture Task"].waitForExistence(timeout: 2))

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        let tools = app.buttons["lifeThread.composer.toolsToggle"]
        XCTAssertTrue(tools.waitForExistence(timeout: 5), "Plan's floating composer is its capture entry.")
        XCTAssertTrue(tools.isHittable)
        tools.tap()
        XCTAssertTrue(app.buttons["lifeThread.composer.tool.task"].waitForExistence(timeout: 5))
    }

    func testFoundationEvaComposerClearsDockAndKeyboard() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            evaActivationCompleted: true
        )
        defer { app.terminate() }

        assertFoundationDestination("eva", rootIdentifier: "foundation.eva", in: app)
        let (composer, chrome) = assertFoundationEvaRestingLayout(in: app)
        composer.tap()

        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Eva composer should receive the tap instead of the dock.")
        XCTAssertTrue(waitForElementToDisappear(chrome, timeout: 5), "The phone dock should withdraw while Eva is editing.")
        XCTAssertTrue(composer.isHittable)
        XCTAssertLessThanOrEqual(
            evaComposerInteractiveFrame(in: app, composer: composer).maxY,
            keyboard.frame.minY + 1,
            "The entire composer must remain above the keyboard."
        )

        composer.typeText("Plan my focus block")
        let send = app.buttons["chat.send_button"]
        XCTAssertTrue(send.waitForExistence(timeout: 3))
        send.tap()
        XCTAssertTrue(waitForElementToDisappear(keyboard, timeout: 5))
        XCTAssertTrue(chrome.waitForExistence(timeout: 5), "The dock should return when composer focus ends.")
        assertRequiredEvaDockSpacing(composer: composer, chrome: chrome, in: app)
    }

    /// Eva's keyboard bar, and the structured composer's slash-command draft:
    /// the draft for /project was invisible in Eva's default composer, with
    /// Send disabled and no way to cancel it.
    /// Eva's conversation stays live while typing. A layer used to cover it
    /// whenever the prompt had focus and ate every tap and scroll, so a tap
    /// on anything there only put the keyboard away.
    func testFoundationEvaTapWhileTypingStillActs() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            evaActivationCompleted: true
        )
        defer { app.terminate() }

        assertFoundationDestination("eva", rootIdentifier: "foundation.eva", in: app)
        let (composer, _) = assertFoundationEvaRestingLayout(in: app)
        let keyboard = app.keyboards.firstMatch
        let guide = app.buttons["eva.structured.help"]
        XCTAssertTrue(guide.waitForExistence(timeout: 5), "Eva's empty state needs its guide.")

        composer.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        XCTAssertTrue(guide.isHittable, "The guide must stay reachable while typing.")
        guide.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["eva.guide.sheet"].waitForExistence(timeout: 5),
            "The tap that puts the keyboard away must still open the guide."
        )
        XCTAssertTrue(waitForElementToDisappear(keyboard, timeout: 5))
    }

    func testFoundationEvaKeyboardBarAndCommandDraft() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            evaActivationCompleted: true
        )
        defer { app.terminate() }

        assertFoundationDestination("eva", rootIdentifier: "foundation.eva", in: app)
        let (composer, chrome) = assertFoundationEvaRestingLayout(in: app)
        let keyboard = app.keyboards.firstMatch

        composer.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        let done = app.buttons["chat.composer.dismiss_keyboard"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Eva's keyboard needs its Done.")
        done.tap()
        XCTAssertTrue(waitForElementToDisappear(keyboard, timeout: 5))
        XCTAssertTrue(chrome.waitForExistence(timeout: 5), "The dock should return when Done ends editing.")

        composer.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        composer.typeText("/")
        let projectRow = app.descendants(matching: .any)["chat.command_picker.row.project"]
        XCTAssertTrue(projectRow.waitForExistence(timeout: 5))
        projectRow.tap()
        let cancel = app.buttons["chat.command_chip.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "The /project draft must be visible and cancellable.")
        XCTAssertTrue(app.textFields["chat.command_argument_field"].exists)
        cancel.tap()
        XCTAssertTrue(waitForElementToDisappear(cancel, timeout: 5))
    }

    func testFoundationEvaComposerClearsDockAtLargestAccessibilitySize() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            evaActivationCompleted: true
        )
        defer { app.terminate() }

        assertFoundationDestination("eva", rootIdentifier: "foundation.eva", in: app)
        attachScreenshot(named: "Eva composer above dock — accessibility XXXL")
        _ = assertFoundationEvaRestingLayout(in: app)
    }

    func testFoundationEvaComposerClearsDockInCompactHeight() throws {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            evaActivationCompleted: true
        )
        defer { app.terminate() }

        let window = app.windows.firstMatch
        guard window.frame.height < 800 else {
            throw XCTSkip("Run this regression on a compact-height phone simulator such as iPhone SE.")
        }
        assertFoundationDestination("eva", rootIdentifier: "foundation.eva", in: app)
        _ = assertFoundationEvaRestingLayout(in: app)
    }

    func testFoundationEvaPopulatedConversationRemainsReachableAboveDock() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            evaActivationCompleted: true
        )
        defer { app.terminate() }

        assertFoundationDestination("eva", rootIdentifier: "foundation.eva", in: app)
        let (composer, _) = assertFoundationEvaRestingLayout(in: app)
        composer.tap()
        composer.typeText("Keep this transcript reachable")
        let send = app.buttons["chat.send_button"]
        XCTAssertTrue(send.waitForExistence(timeout: 3))
        send.tap()

        let message = app.staticTexts["Keep this transcript reachable"]
        XCTAssertTrue(message.waitForExistence(timeout: 10), "The populated transcript should expose its newest message.")
        XCTAssertLessThanOrEqual(
            message.frame.maxY,
            evaComposerInteractiveFrame(in: app, composer: composer).minY + 1,
            "The newest transcript message should remain reachable above the inset composer."
        )
        let stop = app.buttons["chat.stop_button"]
        if stop.waitForExistence(timeout: 3) {
            XCTAssertTrue(stop.isHittable, "Streaming controls should remain reachable in the inset composer.")
            stop.tap()
        }
    }

    func testInsightsEmptyStatesOfferCanonicalNextActions() {
        let app = launchFoundationApp(accessibilityCategory: "UICTContentSizeCategoryL")
        defer { app.terminate() }

        assertFoundationDestination("insights", rootIdentifier: "foundation.insights", in: app)
        let openTrack = app.buttons["insights.empty.openTrack"]
        XCTAssertTrue(openTrack.waitForExistence(timeout: 10))
        XCTAssertTrue(openTrack.isHittable)
        openTrack.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["track.header"].waitForExistence(timeout: 10),
            "The successful-empty state should lead directly to the place that records evidence."
        )

        assertFoundationDestination("insights", rootIdentifier: "foundation.insights", in: app)
        let experience = app.buttons["insights.lens.experience"]
        XCTAssertTrue(experience.waitForExistence(timeout: 8))
        experience.tap()
        let openReview = app.buttons["insights.experience.empty.openReview"]
        XCTAssertTrue(openReview.waitForExistence(timeout: 10))
        XCTAssertTrue(openReview.isHittable)
        openReview.tap()
        let review = app.buttons["insights.lens.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 10))
        XCTAssertTrue(review.isSelected, "The optional Experience lens should select canonical Review without a dead end.")
    }

    func testCustomTrackerCreationCaptureAndHistoryFlow() {
        let app = launchFoundationApp(accessibilityCategory: "UICTContentSizeCategoryL")
        defer { app.terminate() }

        assertFoundationDestination("track", rootIdentifier: "track.header", in: app)
        let trackerShortcut = app.buttons["track.quick.trackers"]
        XCTAssertTrue(trackerShortcut.waitForExistence(timeout: 5))
        XCTAssertTrue(trackerShortcut.isHittable)
        trackerShortcut.tap()

        let newTracker = app.buttons["track.tracker.new"]
        XCTAssertTrue(newTracker.waitForExistence(timeout: 8))
        newTracker.tap()

        let name = app.textFields["track.tracker.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Focus depth")

        let amountKind = app.buttons["track.tracker.kind.quantity"]
        XCTAssertTrue(amountKind.waitForExistence(timeout: 5))
        amountKind.tap()

        let create = app.buttons["track.tracker.commit"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        XCTAssertTrue(create.isEnabled)
        attachScreenshot(named: "track-custom-tracker-composer")
        create.tap()

        let record = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "track.tracker.log.")
        ).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        record.tap()

        let numeric = app.textFields["track.tracker.value.numeric"]
        XCTAssertTrue(numeric.waitForExistence(timeout: 5))
        numeric.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        numeric.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
        numeric.typeText("42")

        let saveValue = app.buttons["track.tracker.value.commit"]
        XCTAssertTrue(saveValue.waitForExistence(timeout: 5))
        XCTAssertTrue(saveValue.isEnabled)
        attachScreenshot(named: "track-custom-tracker-capture")
        saveValue.tap()

        let actions = app.buttons["Actions for Focus depth"]
        XCTAssertTrue(actions.waitForExistence(timeout: 10))
        actions.tap()
        let history = app.buttons["History"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["track.tracker.history.summary"].waitForExistence(timeout: 8),
            "The persisted value should appear in the tracker’s history summary."
        )
        XCTAssertTrue(app.staticTexts["42"].exists, "History should preserve the exact recorded value.")
        attachScreenshot(named: "track-custom-tracker-history")
    }

    func testPhase5IPhoneRootVisualCheckpoint() throws {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true,
            evaActivationCompleted: true
        )
        defer { app.terminate() }

        guard app.windows.firstMatch.frame.width < 700 else {
            throw XCTSkip("Phase 5 approves the iPhone composition before wider adaptations.")
        }

        assertFoundationDestination("home", rootIdentifier: "home.signalRow", in: app)
        try saveVisualEvidenceScreenshot(named: "phase5-home-populated", platform: "iphone-phase5")

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        try saveVisualEvidenceScreenshot(named: "phase5-plan-day", platform: "iphone-phase5")

        assertFoundationDestination("track", rootIdentifier: "track.header", in: app)
        try saveVisualEvidenceScreenshot(named: "phase5-track-today", platform: "iphone-phase5")

        assertFoundationDestination("insights", rootIdentifier: "foundation.insights", in: app)
        try saveVisualEvidenceScreenshot(named: "phase5-insights-overview", platform: "iphone-phase5")
        let experience = app.buttons["insights.lens.experience"]
        XCTAssertTrue(experience.waitForExistence(timeout: 8))
        experience.tap()
        XCTAssertTrue(app.descendants(matching: .any)["foundation.insights"].waitForExistence(timeout: 8))
        try saveVisualEvidenceScreenshot(named: "phase5-insights-experience", platform: "iphone-phase5")

        assertFoundationDestination("eva", rootIdentifier: "foundation.eva", in: app)
        try saveVisualEvidenceScreenshot(named: "phase5-eva", platform: "iphone-phase5")
    }

    func testInAppCaptureDraftRecoversAfterProcessInterruption() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL"
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.tasks.add", in: app)
        let title = app.textFields["addTask.titleField"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("Recovered interruption draft")
        XCTAssertEqual(title.value as? String, "Recovered interruption draft")

        app.terminate()
        app.launchArguments.removeAll {
            $0 == "-RESET_APP_STATE" || $0 == "-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE"
        }
        app.launch()

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.tasks.add", in: app)
        let recovered = app.textFields["addTask.titleField"].firstMatch
        XCTAssertTrue(recovered.waitForExistence(timeout: 10))
        XCTAssertEqual(
            recovered.value as? String,
            "Recovered interruption draft",
            "A process interruption must recover the latest provisional capture instead of losing it."
        )
    }

    func testInboxCaptureSurvivesInterruptionThenFilesAndUndoes() {
        let captureID = "A1B2C3D4-0001-4000-8000-00000000FEED"
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true,
            seedInboxCaptures: true
        )
        defer { app.terminate() }

        openSeededInbox(in: app)
        let capture = app.descendants(matching: .any)["plan.inbox.row.\(captureID)"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        let file = app.buttons["File it"].firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 8))
        file.tap()
        XCTAssertTrue(app.navigationBars["Review capture"].waitForExistence(timeout: 8))

        // Terminate before File It. The pending capture is the only durable copy
        // and must remain reviewable after a fresh app process.
        app.terminate()
        app.launchArguments.removeAll {
            $0 == "-RESET_APP_STATE"
                || $0 == "-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE"
                || $0 == "-LIFEBOARD_TEST_SEED_INBOX_CAPTURES"
        }
        app.launch()

        openSeededInbox(in: app)
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        let restoredFile = app.buttons["File it"].firstMatch
        XCTAssertTrue(restoredFile.waitForExistence(timeout: 8))
        restoredFile.tap()
        let commit = app.buttons["plan.inbox.review.file"].firstMatch
        XCTAssertTrue(commit.waitForExistence(timeout: 8))
        commit.tap()
        XCTAssertTrue(waitForElementToDisappear(app.navigationBars["Review capture"], timeout: 12))
        XCTAssertTrue(waitForElementToDisappear(capture, timeout: 12))

        let undo = app.buttons["Undo"].firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 8))
        undo.tap()
        XCTAssertTrue(
            capture.waitForExistence(timeout: 12),
            "Undo must restore the same capture identity after the canonical task is removed."
        )
    }

    func testFoundationCompactChromeRemainsReadableAcrossScrollAndCapture() throws {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let chrome = app.descendants(matching: .any)["LifeBoardCompactChrome"]
        XCTAssertTrue(chrome.waitForExistence(timeout: 10))
        let restingFrame = chrome.frame

        let homeScroll = app.scrollViews.firstMatch
        XCTAssertTrue(homeScroll.waitForExistence(timeout: 5))
        homeScroll.swipeUp()
        XCTAssertTrue(chrome.waitForExistence(timeout: 5))
        // DESIGN.md: a purposeful scroll compresses the composer to its orb,
        // and a tap restores it. The chrome is measured in its restored state.
        // Scrolling back restores the composer without focusing it; the orb
        // tap is the fallback and brings the keyboard with it.
        app.swipeDown()
        let orb = app.buttons["lifeThread.composer.orb"]
        if app.buttons["lifeThread.composer.toolsToggle"].waitForExistence(timeout: 3) == false, orb.waitForExistence(timeout: 3) {
            orb.tap()
            // Restoring the orb also focuses the composer; the chrome is
            // measured at rest, so a tap on the page puts the keyboard away.
            // This used to swipe, then tap, and assert neither. (Drag is
            // covered by `testHomeComposerKeyboardHasAWayDown`; here the page
            // is scrolled, and a drag that starts on the Now card is claimed by
            // the card's own touch gesture.)
            let keyboard = app.keyboards.firstMatch
            XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "The orb restores the composer with the keyboard.")
            app.descendants(matching: .any)["home.header"]
                .coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
                .tap()
            XCTAssertTrue(waitForElementToDisappear(keyboard, timeout: 5), "A tap on the page must dismiss the keyboard.")
        }
        XCTAssertTrue(app.buttons["lifeThread.composer.toolsToggle"].waitForExistence(timeout: 5))
        XCTAssertTrue(chrome.waitForExistence(timeout: 5))
        XCTAssertEqual(chrome.frame.height, restingFrame.height, accuracy: 2)
        XCTAssertEqual(chrome.frame.maxY, restingFrame.maxY, accuracy: 2)

        let capture = app.buttons["lifeThread.composer.toolsToggle"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        capture.tap()
        let taskCapture = app.buttons["lifeThread.composer.tool.task"]
        XCTAssertTrue(taskCapture.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(taskCapture.frame.minY, chrome.frame.minY)
        XCTAssertLessThanOrEqual(taskCapture.frame.maxY, chrome.frame.maxY)
        XCTAssertTrue(taskCapture.isHittable)
        try saveVisualEvidenceScreenshot(named: "home-compact-chrome-capture", platform: "iphone")
    }

    /// The Home composer's keyboard used to have no way down: Return added a
    /// newline, there was no accessory, and a tab switch carried it along.
    func testHomeComposerKeyboardHasAWayDown() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let composer = app.textFields["home.lifeThread.composer"].exists
            ? app.textFields["home.lifeThread.composer"]
            : app.textViews["home.lifeThread.composer"]
        let keyboard = app.keyboards.firstMatch

        // 1. Switching roots puts the keyboard away.
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        assertFoundationDestination("plan", rootIdentifier: "foundation.plan.scroll", in: app)
        XCTAssertTrue(waitForElementToDisappear(keyboard, timeout: 5), "A tab switch must dismiss the composer keyboard.")
        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        XCTAssertFalse(keyboard.waitForExistence(timeout: 1), "Returning to Home must not bring the keyboard back.")

        // 2. The accessory's Done button dismisses it.
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        let done = app.buttons["lifeThread.composer.dismissKeyboard"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "The composer keyboard needs a Done accessory.")
        done.tap()
        XCTAssertTrue(waitForElementToDisappear(keyboard, timeout: 5))

        // 3. Return on an empty draft dismisses without leaving a newline.
        composer.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        composer.typeText("\n")
        XCTAssertTrue(waitForElementToDisappear(keyboard, timeout: 5), "Return on an empty composer must dismiss the keyboard.")
        XCTAssertFalse((composer.value as? String ?? "").contains("\n"))

        // 4. Return with text sends it, once. The newline strip used to release
        // the submit lock mid-save.
        composer.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        composer.typeText("Buy oat milk tomorrow\n")
        let undo = app.buttons.matching(identifier: "lifeboard.receipt.undo")
        XCTAssertTrue(undo.firstMatch.waitForExistence(timeout: 10), "Return with text must send the draft.")
        XCTAssertEqual(undo.count, 1, "Return must save the draft exactly once.")
        XCTAssertTrue(waitForElementToDisappear(keyboard, timeout: 5), "Sending ends editing.")

        // 5. A tap on the page, and a drag on it, each put the keyboard away.
        composer.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        app.descendants(matching: .any)["home.header"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            .tap()
        XCTAssertTrue(waitForElementToDisappear(keyboard, timeout: 5), "A tap on the page must dismiss the keyboard.")
        composer.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        // The simulator treats XCUITest as a hardware keyboard and keeps the
        // software keyboard minimized until something is typed, and a scroll
        // only dismisses a keyboard that is on screen.
        composer.typeText("milk")
        XCTAssertLessThan(keyboard.frame.minY, app.frame.maxY, "The software keyboard must be on screen.")
        dragRootContent(below: app.descendants(matching: .any)["home.header"], in: app)
        XCTAssertTrue(waitForElementToDisappear(keyboard, timeout: 5), "A drag on a root must dismiss the keyboard.")

        // 6. The keyboard bar's token keys write the syntax, spaced from the
        // draft, and open its suggestions. (No Esc leg: a focused text field
        // consumes Escape before any handler of ours sees it.)
        composer.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        let tagKey = app.buttons["lifeThread.composer.token.tag"]
        XCTAssertTrue(tagKey.waitForExistence(timeout: 5), "The capture keyboard bar needs its token keys.")
        tagKey.tap()
        XCTAssertEqual(composer.value as? String, "milk #", "The drag must keep the draft.")
        // A typed name always has a suggestion — at worst "Create #errands" —
        // so this doesn't depend on which tags the seed made.
        composer.typeText("errands")
        XCTAssertEqual(composer.value as? String, "milk #errands", "Typing after a token key must land after it.")
        XCTAssertTrue(
            app.descendants(matching: .any)["lifeThread.tokenSuggestions"].waitForExistence(timeout: 5),
            "A token key must start a token the suggestions can finish."
        )
    }

    /// Drags the page itself, downward, from just under the root's pinned
    /// header and in the side gutter. With the keyboard up only the top ~40% of
    /// an iPhone shows root content — `swipeDown()` from the centre dragged the
    /// composer and dock riding above the keyboard — and a query for the root's
    /// scroll identifier can resolve to a child the identifier was stamped onto.
    /// The gutter matters because Home's Now card claims a press-then-drag
    /// (`DragGesture(minimumDistance: 0)`), and where that card sits depends on
    /// the day. Downward at the top also keeps the composer from compressing
    /// into its orb once the keyboard is gone.
    private func dragRootContent(below header: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        // `.firstMatch`: Plan's orientation bar reuses "plan.header".
        let start = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 8, dy: header.firstMatch.frame.maxY + 16))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 160)))
    }

    /// A Send that beat the live preview left the composer on "Understanding
    /// what you need" for good: the in-place save refused to run because the
    /// submit had already marked the composer working.
    func testHomeComposerSendBeforePreviewSavesInPlace() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true,
            additionalArguments: ["-LIFEBOARD_DISABLE_COMPOSER_LIVE_PREVIEW"]
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let composer = app.textFields["home.lifeThread.composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap()
        composer.typeText("Buy oat milk tomorrow")
        let send = app.buttons["lifeThread.composer.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        send.tap()
        XCTAssertTrue(
            app.buttons["lifeboard.receipt.undo"].waitForExistence(timeout: 10),
            "The task must save in place and leave its receipt."
        )
        XCTAssertFalse(app.staticTexts["Thinking…"].exists)
        XCTAssertFalse(app.staticTexts["Adding…"].exists)
    }

    /// While the composer has the keyboard, a tap on a task's completion circle
    /// only puts the keyboard away — a tap meant to dismiss must not complete
    /// the task. The second tap, keyboard down, completes it, which is also
    /// what proves the first tap reached the circle.
    func testCompletionTapWhileTypingOnlyDismisses() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true,
            additionalArguments: ["-LIFEBOARD_ENABLE_DAILY_LOOP_V1"]
        )
        defer { app.terminate() }

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        openBacklog(in: app)
        let open = app.buttons.matching(NSPredicate(format: "value == %@", "Not complete"))
        XCTAssertTrue(open.firstMatch.waitForExistence(timeout: 12), "The canonical seed should expose an open backlog task.")
        let circle = app.buttons.matching(
            NSPredicate(format: "label == %@ AND value == %@", open.firstMatch.label, "Not complete")
        ).firstMatch
        raiseIntoUncoveredBand(circle, in: app)

        let keyboard = app.keyboards.firstMatch
        let composer = focusShellComposer(in: app)
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        XCTAssertLessThan(circle.frame.maxY, composer.frame.minY, "The circle must sit above the raised composer.")

        circle.tap()
        XCTAssertTrue(waitForElementToDisappear(keyboard, timeout: 5), "A tap while typing must put the keyboard away.")
        XCTAssertFalse(waitForElementToDisappear(circle, timeout: 3), "A tap meant to dismiss must not complete the task.")

        circle.tap()
        XCTAssertTrue(waitForElementToDisappear(circle, timeout: 10), "With the keyboard down, the same tap completes the task.")
    }

    /// Every dashboard root puts the keyboard away on a drag, not only Home.
    /// Plan is dragged on its backlog, a plain list; the day canvas scrolls
    /// inside its own timeline.
    func testDragOnEachRootPutsTheKeyboardAway() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        let composer = app.textFields["home.lifeThread.composer"]
        let keyboard = app.keyboards.firstMatch
        for (root, rootIdentifier) in [("plan", "plan.header"), ("track", "track.header"), ("insights", "foundation.insights")] {
            assertFoundationDestination(root, rootIdentifier: rootIdentifier, in: app)
            if root == "plan" { openBacklog(in: app) }
            XCTAssertTrue(composer.waitForExistence(timeout: 5), "\(root) needs the composer.")
            composer.tap()
            composer.typeText("a")
            XCTAssertLessThan(keyboard.frame.minY, app.frame.maxY, "The software keyboard must be on screen on \(root).")
            dragRootContent(below: app.descendants(matching: .any)["\(root).header"], in: app)
            XCTAssertTrue(waitForElementToDisappear(keyboard, timeout: 5), "A drag on \(root) must put the keyboard away.")
        }
    }

    /// A tap on content while typing puts the keyboard away *and* does what
    /// was tapped: here it opens the task, with no keyboard left over it.
    func testTapOnATaskWhileTypingOpensIt() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        let task = openBacklogTaskRow(in: app)
        let keyboard = app.keyboards.firstMatch
        focusShellComposer(in: app)
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        task.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["task.editor.title"].waitForExistence(timeout: 8),
            "The tap that puts the keyboard away must still open the task."
        )
        XCTAssertTrue(waitForElementToDisappear(keyboard, timeout: 5), "Opening a task must leave no keyboard over it.")
    }

    /// A task title never holds a newline: Return, even mid-title, moves on
    /// to the notes.
    func testTaskTitleReturnMovesToNotes() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        openBacklogTaskRow(in: app).tap()
        let title = app.textFields["task.editor.title"]
        let notes = app.textFields["task.editor.notes"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertTrue(notes.exists)
        title.tap()
        title.typeText("\n")
        app.typeText("zq")
        XCTAssertTrue((notes.value as? String ?? "").contains("zq"), "Return on the title must move on to the notes.")
        XCTAssertFalse((title.value as? String ?? "").contains("\n"), "A title must not keep the newline.")
        XCTAssertFalse((title.value as? String ?? "").contains("zq"))
    }

    /// Plan's backlog, scrolled so its first task row sits above a raised
    /// keyboard. Returns the row's body, which opens the task.
    private func openBacklogTaskRow(in app: XCUIApplication) -> XCUIElement {
        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        openBacklog(in: app)
        let task = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plan.task.")).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 12), "The canonical seed should expose a backlog task.")
        raiseIntoUncoveredBand(task, in: app)
        return task
    }

    /// Focuses the shell composer, through its orb when scrolling has
    /// compressed it, and returns the field.
    @discardableResult
    private func focusShellComposer(in app: XCUIApplication) -> XCUIElement {
        let composer = app.textFields["home.lifeThread.composer"]
        if composer.exists, composer.isHittable {
            composer.tap()
        } else {
            app.descendants(matching: .any)["lifeThread.composer.orb"].tap()
        }
        return composer
    }

    /// Scrolls the page until `element` sits in the band a raised keyboard
    /// leaves uncovered. A slow drag held at its end moves the page by the drag
    /// and no more; it starts in the side gutter so no card claims it.
    private func raiseIntoUncoveredBand(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let height = app.frame.height
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 8, dy: height * 0.75))
        for _ in 0..<4 {
            let distance = element.frame.midY - height * 0.3
            guard distance > 20 else { return }
            start.press(
                forDuration: 0.1,
                thenDragTo: start.withOffset(CGVector(dx: 0, dy: -min(distance, height * 0.45))),
                withVelocity: .slow,
                thenHoldForDuration: 0.3
            )
        }
    }

    func testAdaptiveHomeCustomizationCancelAndComposerHandoff() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true,
            seedHomeUserSpace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let customize = app.buttons["home.customize"]
        XCTAssertTrue(customize.waitForExistence(timeout: 8))
        customize.tap()

        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
        let seededCardMenu = app.buttons[
            "home.widget.edit.D6ED45B2-1267-4C2C-9A91-A3F5503D51AF"
        ]
        scrollUntilHittable(seededCardMenu, in: app, maximumSwipes: 8)
        XCTAssertTrue(seededCardMenu.isHittable)
        seededCardMenu.tap()
        XCTAssertTrue(app.buttons["Glance"].waitForExistence(timeout: 5))
        app.buttons["Glance"].tap()
        app.buttons["home.customization.cancel"].tap()
        XCTAssertTrue(customize.waitForExistence(timeout: 5), "Cancel should restore the pre-edit Home transaction.")

        let capture = app.buttons["lifeThread.composer.toolsToggle"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        capture.tap()
        app.buttons["lifeThread.composer.tool.task"].tap()
        XCTAssertTrue(app.buttons["addTask.cancelButton"].waitForExistence(timeout: 8))
    }

    func testVisualEvidenceWideIPadAtomicHomeEdit() throws {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        guard app.windows.firstMatch.frame.width >= 1_024 else {
            throw XCTSkip("Wide Home edit evidence requires the expanded iPad destination.")
        }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let customize = app.buttons["home.customize"]
        XCTAssertTrue(customize.waitForExistence(timeout: 10))
        customize.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Done"].exists)
        try saveVisualEvidenceScreenshot(named: "home-atomic-edit-wide")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(customize.waitForExistence(timeout: 8), "Cancel must restore the atomic Home draft.")
    }

    func testAddToHomeUsesSizePreviewAndProducesUndoReceipt() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        let more = app.buttons["foundation.more.plan"]
        XCTAssertTrue(more.waitForExistence(timeout: 8))
        more.tap()
        let addMenu = app.buttons["home.addToHome.plan"]
        XCTAssertTrue(addMenu.waitForExistence(timeout: 8))
        addMenu.tap()

        let tasks = app.buttons["Today’s tasks"]
        XCTAssertTrue(tasks.waitForExistence(timeout: 5))
        tasks.tap()

        XCTAssertTrue(app.staticTexts["Add Today’s tasks to Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your Home"].exists)
        let wide = app.buttons["Wide"]
        XCTAssertTrue(wide.exists)
        wide.tap()

        let add = app.buttons["home.placement.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let receipt = app.descendants(matching: .any)["home.addCard.receipt"]
        XCTAssertTrue(receipt.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Undo"].exists)
        XCTAssertTrue(app.buttons["View"].exists)
    }

    func testFoundationHabitResilienceThirtyDayEditorAtLargestAccessibilitySize() throws {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            seedHabits: true
        )
        defer { app.terminate() }

        assertFoundationDestination("track", rootIdentifier: "track.header", in: app)
        let areas = app.buttons["track.lens.areas"]
        XCTAssertTrue(areas.waitForExistence(timeout: 8))
        // At accessibility XXXL the lens rail sits under the floating
        // composer until the page scrolls a little. Everything visible above
        // it is a horizontal rail, so a flick is what moves the page.
        if areas.isHittable == false {
            app.swipeUp()
        }
        scrollUntilHittableWithSmallSteps(areas, in: app, maximumSteps: 8)
        XCTAssertTrue(areas.isHittable, "The Areas lens must be reachable at accessibility XXXL.")
        areas.tap()
        let resilience = app.buttons["track.habits.resilience"]
        scrollUntilHittable(resilience, in: app, maximumSwipes: 12)
        XCTAssertTrue(resilience.isHittable, "Resilience settings must remain operable at accessibility XXXL.")
        resilience.tap()

        XCTAssertTrue(app.navigationBars["Habit settings"].waitForExistence(timeout: 12))
        let policy = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "track.habit.resilience.")
        ).firstMatch
        XCTAssertTrue(policy.waitForExistence(timeout: 12), "The canonical seeded habit should expose a resilience policy.")
        scrollUntilHittable(policy, in: app)
        policy.tap()

        let recoveryToggle = app.switches["Allow recovery"]
        XCTAssertTrue(
            recoveryToggle.waitForExistence(timeout: 8),
            "The recovery policy must remain operable at accessibility XXXL."
        )
        XCTAssertTrue(app.buttons["track.resilience.commit"].exists)

        let historyHeader = app.staticTexts["30-day history"]
        scrollUntilHittable(historyHeader, in: app, maximumSwipes: 10)
        XCTAssertTrue(historyHeader.exists, "The full history section must remain reachable at accessibility XXXL.")

        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.intersects(historyHeader.frame))
        XCTAssertLessThanOrEqual(historyHeader.frame.maxX, window.maxX + 1)
        XCTAssertGreaterThanOrEqual(historyHeader.frame.minX, window.minX - 1)
    }

    func testFoundationBacklogDeletionConfirmsUndoesAndPersistsAcrossRelaunch() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        openBacklog(in: app)

        let taskButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "plan.task.")
        )
        let task = taskButtons.firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 12), "The canonical seed should expose a backlog task.")
        let taskIdentifier = task.identifier
        let initialTaskCount = taskButtons.count

        requestBacklogDeletion(for: task, in: app)
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        app.buttons["Delete"].tap()

        let undoBanner = app.descendants(matching: .any)["plan.backlog.deletionUndo"]
        XCTAssertTrue(undoBanner.waitForExistence(timeout: 8))
        // Identity, not cardinality: the backlog caps the rows it shows per
        // group, so removing one row can pull the next one into view.
        XCTAssertTrue(
            waitForElementToDisappear(app.buttons[taskIdentifier], timeout: 8),
            "A confirmed tombstone should leave the active backlog."
        )
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()
        let restoredTask = app.buttons[taskIdentifier]
        XCTAssertTrue(restoredTask.waitForExistence(timeout: 10), "Undo should restore the same stable task identity.")
        _ = initialTaskCount

        requestBacklogDeletion(for: restoredTask, in: app)
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        app.buttons["Delete"].tap()
        XCTAssertTrue(waitForElementToDisappear(app.buttons[taskIdentifier], timeout: 8))

        app.terminate()
        app.launchArguments.removeAll {
            $0 == "-RESET_APP_STATE" || $0 == "-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE"
        }
        app.launch()
        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        openBacklog(in: app)
        XCTAssertFalse(
            app.buttons[taskIdentifier].waitForExistence(timeout: 5),
            "The synced tombstone must remain hidden after a fresh app process."
        )
    }

    func testFoundationHomeExposesCompletePhaseIIHierarchy() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let hero = app.descendants(matching: .any)["home.hero"]
        let loopSpine = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home.loopSpine.")
        ).firstMatch
        XCTAssertTrue(
            hero.exists || loopSpine.exists,
            "Home must lead with either its contextual decision or the canonical Daily Loop spine."
        )
        XCTAssertTrue(app.descendants(matching: .any)["home.signalRow"].exists)

        let orderedSections = [
            "home.widget.tasks",
            "home.widget.care",
            "home.widget.routines",
            "home.widget.journal",
            "home.widget.progressReflection"
        ]
        for identifier in orderedSections {
            let section = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            scrollUntilVisible(section, in: app, maximumSwipes: 12)
            XCTAssertTrue(section.exists, "The locked Home hierarchy is missing \(identifier).")
            XCTAssertTrue(
                app.windows.firstMatch.frame.intersects(section.frame),
                "The Home section \(identifier) must be reachable by scrolling."
            )
        }

    }

    func testHomeFastingOneTapLifecycleAndHydrationComposer() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.signalRow", in: app)

        let fasting = app.buttons["home.signal.fasting"]
        XCTAssertTrue(fasting.waitForExistence(timeout: 10))
        // Keep steady sits under Up next and Today, so it may start below the fold.
        scrollUntilHittableWithSmallSteps(fasting, in: app, maximumSteps: 24)
        XCTAssertTrue(fasting.isHittable)
        fasting.tap()

        let activeFast = app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label == %@", "home.signal.fasting", "End fasting timer")
        ).firstMatch
        XCTAssertTrue(activeFast.waitForExistence(timeout: 8), "One tap should persist and activate the fasting clock.")
        attachScreenshot(named: "Home Fasting Active")
        activeFast.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["home.fasting.receipt"].waitForExistence(timeout: 8),
            "Ending should save immediately and expose a reversible receipt."
        )

        let hydration = app.buttons["home.signal.hydration"]
        XCTAssertTrue(hydration.waitForExistence(timeout: 8))
        hydration.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["track.hydration.composer"].waitForExistence(timeout: 8)
        )
        app.buttons["Bottle, 500 mL"].tap()
        XCTAssertTrue(app.buttons["Add 500 mL"].waitForExistence(timeout: 4))
        attachScreenshot(named: "Hydration Composer 500 mL")
        app.buttons["Add 500 mL"].tap()
        XCTAssertTrue(
            waitForElementToDisappear(
                app.descendants(matching: .any)["track.hydration.composer"],
                timeout: 5
            ),
            "The hydration composer should dismiss only after the log is committed."
        )
    }

    func testFoundationHomeTaskUsesTypedDetailRoute() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let task = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home.task.")
        ).firstMatch
        for _ in 0..<8 { app.swipeDown() }
        scrollUntilHittableWithSmallSteps(task, in: app, maximumSteps: 24)
        XCTAssertTrue(task.waitForExistence(timeout: 8))
        XCTAssertTrue(task.isHittable)
        task.tap()

        let homeRoot = app.buttons["foundation.destination.home"]
        let routeMutation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Detail depth 1"),
            object: homeRoot
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [routeMutation], timeout: 8),
            .completed,
            "The Home action must append one typed task route."
        )
        XCTAssertTrue(app.navigationBars["Task"].waitForExistence(timeout: 8))
    }

    func testFoundationHomeTaskCardExpandsHiddenDueTasksInline() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let taskRows = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home.task.")
        )
        let addTask = app.buttons["home.tasks.add"]
        let showMore = app.buttons[AccessibilityIdentifiers.Home.taskCardShowMore]
        scrollUntilHittableWithSmallSteps(showMore, in: app, maximumSteps: 24)

        XCTAssertTrue(showMore.waitForExistence(timeout: 8))
        XCTAssertTrue(showMore.isHittable)
        XCTAssertTrue(addTask.exists)
        XCTAssertLessThan(
            addTask.frame.midX,
            showMore.frame.midX,
            "Add a task and Show more should anchor opposite sides of the same footer row."
        )
        XCTAssertEqual(addTask.frame.midY, showMore.frame.midY, accuracy: 2)
        XCTAssertEqual(showMore.label, "Show more")
        XCTAssertTrue(
            waitForQuery(taskRows, toHaveCount: 4, timeout: 8),
            "The collapsed Home task card should render only its four-row preview."
        )

        showMore.tap()

        let showLess = app.buttons[AccessibilityIdentifiers.Home.taskCardShowLess]
        XCTAssertTrue(showLess.waitForExistence(timeout: 8))
        XCTAssertEqual(showLess.label, "Show less")
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Home.taskCardDatePicker]
                .waitForExistence(timeout: 8),
            "The expanded card should expose its compact inline date picker."
        )
        XCTAssertTrue(
            waitForQuery(taskRows, toHaveCount: 6, timeout: 8),
            "Show more should expand the same card to every open task due today."
        )

        scrollUntilHittableWithSmallSteps(showLess, in: app, maximumSteps: 24)
        XCTAssertTrue(showLess.isHittable)
        showLess.tap()

        XCTAssertTrue(showMore.waitForExistence(timeout: 8))
        XCTAssertTrue(
            waitForQuery(taskRows, toHaveCount: 4, timeout: 8),
            "Show less should restore the four-row Home preview."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Home.taskCardDatePicker].exists,
            "The compact date picker belongs only to the expanded card."
        )
    }

    func testFoundationHomeLongTaskCardRemainsReachableAcrossItsFullScrollRange() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true,
            seedLongHomeTaskAgenda: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let taskRows = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home.task.")
        )
        let showMore = app.buttons[AccessibilityIdentifiers.Home.taskCardShowMore]
        scrollUntilHittableWithSmallSteps(showMore, in: app, maximumSteps: 32)
        XCTAssertTrue(showMore.waitForExistence(timeout: 8))
        XCTAssertTrue(showMore.isHittable)
        showMore.tap()

        XCTAssertTrue(
            waitForQuery(taskRows, toHaveCount: 24, timeout: 12),
            "The dedicated long agenda should expose all 24 task rows in the expanded card."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Home.taskCardDatePicker]
                .waitForExistence(timeout: 8)
        )
        attachScreenshot(named: "home-expanded-tasks-top")

        app.swipeUp()
        let middleTask = taskRows.element(boundBy: 12)
        scrollUntilHittableWithSmallSteps(middleTask, in: app, maximumSteps: 40)
        XCTAssertTrue(middleTask.exists)
        XCTAssertTrue(middleTask.isHittable, "A middle task must remain reachable in the outer Home scroll view.")
        attachScreenshot(named: "home-expanded-tasks-middle")

        let finalTask = taskRows.element(boundBy: 23)
        scrollUntilHittableWithSmallSteps(finalTask, in: app, maximumSteps: 40)
        XCTAssertTrue(finalTask.exists)
        XCTAssertTrue(finalTask.isHittable, "The final task must remain reachable without a nested task-card scroller.")
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Home.taskCardShowLess].exists)
        attachScreenshot(named: "home-expanded-tasks-bottom")
    }

    func testFoundationTaskEditPersistsAcrossRelaunchThenCompletesAndReopens() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let task = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home.task.")
        ).firstMatch
        scrollUntilHittableWithSmallSteps(task, in: app, maximumSteps: 24)
        XCTAssertTrue(task.waitForExistence(timeout: 8))
        let taskIdentifier = task.identifier
        task.tap()

        XCTAssertTrue(app.navigationBars["Task"].waitForExistence(timeout: 8))
        let editedTitle = "Persisted native task edit"
        let title = app.textFields["task.editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        title.tap()
        app.typeKey("a", modifierFlags: .command)
        title.typeText(editedTitle)

        // The editor autosaves; leaving the title field flushes the edit, so
        // there is no Save button to press.
        app.navigationBars["Task"].tap()
        XCTAssertTrue(app.staticTexts["Task updated"].waitForExistence(timeout: 10))

        app.terminate()
        app.launchArguments.removeAll {
            $0 == "-RESET_APP_STATE" || $0 == "-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE"
        }
        app.launch()

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let restoredTask = app.buttons[taskIdentifier]
        scrollUntilHittableWithSmallSteps(restoredTask, in: app, maximumSteps: 24)
        XCTAssertTrue(restoredTask.waitForExistence(timeout: 8))
        restoredTask.tap()
        XCTAssertTrue(app.navigationBars["Task"].waitForExistence(timeout: 8))
        let restoredTitle = app.textFields["task.editor.title"]
        XCTAssertTrue(restoredTitle.waitForExistence(timeout: 8))
        XCTAssertTrue(
            (restoredTitle.value as? String)?.hasPrefix(editedTitle) == true,
            "The canonical task title edit must survive a fresh app process."
        )

        let restoredCompletion = app.switches["task.editor.completion"]
        scrollUntilHittable(restoredCompletion, in: app, maximumSwipes: 16)
        XCTAssertTrue(restoredCompletion.waitForExistence(timeout: 8))
        if (restoredCompletion.value as? String) != "0" { restoredCompletion.tap() }
        restoredCompletion.tap()
        XCTAssertEqual(
            restoredCompletion.value as? String,
            "1",
            "The canonical editor must complete the restored task."
        )
        restoredCompletion.tap()
        XCTAssertEqual(restoredCompletion.value as? String, "0", "The same editor must reopen it.")
    }

    func testFoundationHomePrimaryActionsUseTypedNativeDestinations() {
        let app = productionEvidenceApp(route: "home", arrangement: "actions", appearance: "light")
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.descendants(matching: .any)["home.header"].waitForExistence(timeout: 30))

        tapHomeAction("home.care.open", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.track"]),
            "Care must open as a typed Track leaf."
        )
        // careLibrary resolves to BehaviorAreaRouteView(initialArea: .medication),
        // not TrackRootView's Overview module picker.
        XCTAssertTrue(app.buttons["track.medication.new"].waitForExistence(timeout: 8))

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.capacity.openDay", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.plan"]),
            "Capacity must open the typed Day route."
        )
        XCTAssertTrue(app.descendants(matching: .any)["plan.header"].waitForExistence(timeout: 8))

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.progress.openInsights", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["foundation.insights"].waitForExistence(timeout: 8))

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.journal.search", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.home"]),
            "Journal search must remain a typed Home leaf."
        )
        XCTAssertTrue(app.buttons["Library"].waitForExistence(timeout: 8))

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.journal.weeklyReflection", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.home"]),
            "Weekly reflection must remain a typed protected Home leaf."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["journal.weeklyReflection.header"].waitForExistence(timeout: 8),
            "Weekly reflection must mount its native Monday–Sunday report surface."
        )
    }

    /// A day can be named in place (receipt, Undo), and "New entry" starts a
    /// second sitting that reads as its own entry with a time header.
    func testFoundationJournalDayTitleAndNewEntryReadAsEntries() {
        let app = launchFoundationApp(accessibilityCategory: "UICTContentSizeCategoryL", seedEstablishedWorkspace: true)
        defer { app.terminate() }
        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.journal.search", in: app)
        let today = app.buttons["Today"]
        XCTAssertTrue(today.waitForExistence(timeout: 8))
        today.tap()

        func write(_ text: String, via button: XCUIElement) {
            XCTAssertTrue(button.waitForExistence(timeout: 8))
            button.tap()
            let composer = app.descendants(matching: .any)["journal.text.composer"]
            XCTAssertTrue(composer.waitForExistence(timeout: 8))
            let field = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(text)
            let commit = app.buttons["journal.text.commit"]
            XCTAssertTrue(commit.waitForExistence(timeout: 5))
            commit.tap()
            XCTAssertTrue(waitForElementToDisappear(composer, timeout: 8))
        }

        write("First thought of the day", via: app.buttons["Start writing"].exists ? app.buttons["Start writing"] : app.buttons["Add more"])
        let title = app.textFields["journal.day.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8), "The day card offers a title once the day has content")
        title.tap()
        title.typeText("A calm day\n")
        let undo = app.buttons["lifeboard.receipt.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 8), "Naming the day leaves a receipt with Undo")
        // The keyboard can outlive the field's focus on the simulator and
        // cover the receipt; a tap that lands on the dock instead is not Undo.
        if app.keyboards.count > 0 {
            let done = app.keyboards.buttons.matching(NSPredicate(format: "label IN %@", ["Done", "return", "Return", "done"])).firstMatch
            if done.exists { done.tap() } else { app.swipeDown() }
        }
        scrollUntilHittableWithSmallSteps(undo, in: app, maximumSteps: 6)
        XCTAssertTrue(undo.isHittable, "Undo must be reachable, not hidden under the keyboard")
        keepScreenshot(app, named: "journal-title-receipt")
        undo.tap()
        XCTAssertTrue(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@ OR value == %@", "", "Title"), object: title)], timeout: 8) == .completed,
            "Undo clears the title again"
        )

        write("Second sitting", via: app.buttons["journal.day.newEntry"])
        let headers = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "journal.day.entry."))
        XCTAssertTrue(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "count >= 2"), object: headers)], timeout: 8) == .completed,
            "Two sittings read as two entries"
        )
        keepScreenshot(app, named: "journal-two-entries")
    }

    /// Three weeks of seeded history: Trends draws per-domain charts, Review
    /// reads the month and asks "Did it help?", and a verdict leaves a
    /// receipt whose Undo puts the question back. Identity, not counts.
    func testFoundationInsightsTrendsAndReviewRenderSeededHistory() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            additionalArguments: ["-LIFEBOARD_TEST_SEED_INSIGHTS_HISTORY"]
        )
        defer { app.terminate() }

        assertFoundationDestination("insights", rootIdentifier: "foundation.insights", in: app)
        let trends = app.buttons["insights.lens.trends"]
        XCTAssertTrue(trends.waitForExistence(timeout: 10))
        trends.tap()
        let series = app.descendants(matching: .any)["insights.series"]
        XCTAssertTrue(series.waitForExistence(timeout: 15), "Trends mounts its series section")
        let chart = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "insights.series.")).firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 15), "Seeded history draws at least one per-domain chart")
        keepScreenshot(app, named: "insights-trends-seeded")

        let review = app.buttons["insights.lens.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        review.tap()
        // The inline weekly review sits above the month, so the month may
        // be below the fold of a lazy stack until the page scrolls.
        let monthly = app.descendants(matching: .any)["insights.review.monthly"]
        for _ in 0..<10 where monthly.exists == false {
            app.swipeUp()
        }
        XCTAssertTrue(monthly.waitForExistence(timeout: 15), "Review reads the month")
        let helped = app.buttons["insights.review.experiment.helped"]
        scrollUntilHittableWithSmallSteps(helped, in: app, maximumSteps: 12)
        XCTAssertTrue(helped.exists, "The seeded experiment is due, so Review asks whether it helped")
        helped.tap()
        let receipt = app.descendants(matching: .any)["insights.review.verdict.receipt"]
        XCTAssertTrue(receipt.waitForExistence(timeout: 8), "A verdict leaves a receipt")
        keepScreenshot(app, named: "insights-review-verdict-receipt")
        let undo = app.buttons["lifeboard.receipt.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        XCTAssertTrue(app.buttons["insights.review.experiment.helped"].waitForExistence(timeout: 8), "Undo puts the question back")
    }

    /// Browsing: the Calendar and Gallery lenses mount, and the prompt library opens.
    func testFoundationJournalBrowseLensesAndPromptsMount() {
        let app = launchFoundationApp(accessibilityCategory: "UICTContentSizeCategoryL", seedEstablishedWorkspace: true)
        defer { app.terminate() }
        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.journal.search", in: app)
        let calendar = app.buttons["Calendar"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 8))
        calendar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["journal.calendar.grid"].waitForExistence(timeout: 8), "The Calendar lens shows a month grid")
        keepScreenshot(app, named: "journal-calendar")
        let gallery = app.buttons["Gallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 4))
        gallery.tap()
        XCTAssertTrue(app.descendants(matching: .any)["journal.gallery"].waitForExistence(timeout: 8), "The Gallery lens mounts")
        let today = app.buttons["Today"]
        XCTAssertTrue(today.waitForExistence(timeout: 4))
        today.tap()
        let prompts = app.buttons["journal.prompts.open"]
        XCTAssertTrue(prompts.waitForExistence(timeout: 8))
        prompts.tap()
        XCTAssertTrue(app.buttons["journal.prompts.gratitude.small"].waitForExistence(timeout: 8), "The prompt library lists its prompts")
        keepScreenshot(app, named: "journal-prompts")
    }

    /// Eva comes to the root: "Ask Eva about today" lifts a sheet over Plan,
    /// and closing it returns to Plan with its header still there.
    func testFoundationPlanAsksEvaInASheetOverTheRoot() {
        let app = launchFoundationApp(accessibilityCategory: "UICTContentSizeCategoryL", seedEstablishedWorkspace: true)
        defer { app.terminate() }
        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        let ask = app.buttons["plan.header.askEva"]
        XCTAssertTrue(ask.waitForExistence(timeout: 8))
        ask.tap()
        let sheet = app.descendants(matching: .any)["eva.sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 12), "Eva opens as a sheet over the Plan root")
        keepScreenshot(app, named: "plan-ask-eva-sheet")
        let close = app.buttons["eva.sheet.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 6))
        close.tap()
        XCTAssertTrue(waitForElementToDisappear(sheet, timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["plan.header"].waitForExistence(timeout: 6), "Plan is still there, state intact")
    }

    func testFoundationEvaAppliedChangesSheetOpensFromTheChatsList() {
        let app = launchFoundationApp(accessibilityCategory: "UICTContentSizeCategoryL", evaActivationCompleted: true)
        defer { app.terminate() }
        assertFoundationDestination("eva", rootIdentifier: "foundation.eva", in: app)
        let more = app.buttons["foundation.more.eva"]
        XCTAssertTrue(more.waitForExistence(timeout: 8))
        more.tap()
        let chats = app.buttons["foundation.eva.chats"]
        XCTAssertTrue(chats.waitForExistence(timeout: 6), "The Eva root's More menu offers the chats list")
        chats.tap()
        let open = app.buttons["eva.history.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 8), "The chats list offers Applied changes")
        open.tap()
        let sheet = app.descendants(matching: .any)["eva.history.sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 8), "Applied changes reads back as its own sheet")
        XCTAssertTrue(app.staticTexts["Nothing applied yet"].waitForExistence(timeout: 4), "A fresh workspace has nothing applied")
        keepScreenshot(app, named: "eva-applied-changes-sheet")
        let close = app.buttons["Close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 4))
        close.tap()
        XCTAssertTrue(waitForElementToDisappear(sheet, timeout: 6))
    }

    func testFoundationHomeCaptureActionsMountNativeSheets() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.tasks.add", in: app)
        let taskCapture = app.descendants(matching: .any)["addTask.view"]
        XCTAssertTrue(taskCapture.waitForExistence(timeout: 10))
        let closeCapture = app.buttons["addTask.cancelButton"]
        XCTAssertTrue(closeCapture.waitForExistence(timeout: 5))
        closeCapture.tap()
        XCTAssertTrue(waitForElementToDisappear(taskCapture, timeout: 8))

        tapHomeAction("home.journal.capture", in: app)
        let journalCaptureClose = app.buttons["foundation.capture.dismiss"]
        XCTAssertTrue(
            journalCaptureClose.waitForExistence(timeout: 10)
                && waitForAccessibilityValue("Journal", on: journalCaptureClose),
            "Journal capture must mount the native private Journal surface."
        )
    }

    func testFoundationHomeWeeklyReflectionUsesTypedProtectedRoute() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.journal.weeklyReflection", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.home"]),
            "Weekly reflection must append one typed protected Home leaf."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["journal.weeklyReflection.header"].waitForExistence(timeout: 8)
                || app.descendants(matching: .any)["journal.privacy.lock"].exists,
            "Weekly reflection must mount its native report or privacy gate."
        )
    }

    /// The day's first completion lights the shell once. The second one is
    /// just saved: no caption, no sweep.
    func testFoundationHomeFirstCommitmentLightsOnce() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedHabits: true,
            additionalArguments: ["-LIFEBOARD_TEST_RESET_FIRST_LIGHT"]
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let section = app.descendants(matching: .any)["home.habitsToday"]
        scrollUntilVisible(section, in: app, maximumSwipes: 10)
        XCTAssertTrue(section.waitForExistence(timeout: 10))

        func ring(_ title: String, _ value: String) -> XCUIElement {
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@ AND value == %@", title, value))
                .firstMatch
        }
        let first = ring("Drink water after breakfast", "Not done")
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        scrollUntilHittable(first, in: app, maximumSwipes: 6)
        first.press(forDuration: 1.4)
        // The caption folds away after ~3 s, so look for it before anything else.
        let fired = app.descendants(matching: .any)["lifeboard.firstLight.fired"]
        XCTAssertTrue(fired.waitForExistence(timeout: 6), "The first completion of the day lights the shell")
        keepScreenshot(app, named: "home-first-light")
        XCTAssertTrue(ring("Drink water after breakfast", "Done").waitForExistence(timeout: 8))
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: fired)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 6), .completed, "The caption folds away on its own")

        let second = app.descendants(matching: .any)
            .matching(NSPredicate(format: "value == %@ AND identifier BEGINSWITH %@", "Not done", "habitBoard.day.ring."))
            .firstMatch
        if second.waitForExistence(timeout: 4) {
            scrollUntilHittable(second, in: app, maximumSwipes: 6)
            second.press(forDuration: 1.4)
            XCTAssertFalse(fired.waitForExistence(timeout: 3), "The second completion is saved quietly")
        }
    }

    /// A template is a real target, not a name: picking "Water" and adding it
    /// puts an amount ring on Home that reads "0 of 8 glasses".
    func testFoundationHabitTemplateCreatesAnAmountHabitOnHome() {
        let app = launchFoundationApp(accessibilityCategory: "UICTContentSizeCategoryL", seedHabits: true)
        defer { app.terminate() }
        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)

        let tools = app.buttons["lifeThread.composer.toolsToggle"]
        XCTAssertTrue(tools.waitForExistence(timeout: 8))
        tools.tap()
        let habitTool = app.buttons["lifeThread.composer.tool.habit"]
        XCTAssertTrue(habitTool.waitForExistence(timeout: 4))
        habitTool.tap()
        XCTAssertTrue(app.otherElements["addHabit.view"].waitForExistence(timeout: 6))

        let water = app.buttons["addHabit.template.water"]
        XCTAssertTrue(water.waitForExistence(timeout: 4), "The template row leads the composer")
        water.tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "8 glasses a day")).firstMatch.waitForExistence(timeout: 4),
            "The living preview reads the target back"
        )
        keepScreenshot(app, named: "add-habit-water-template")
        let create = app.buttons["addHabit.createButton"].exists
            ? app.buttons["addHabit.createButton"]
            : app.descendants(matching: .any)["addHabit.createButton"]
        XCTAssertTrue(create.waitForExistence(timeout: 4))
        create.tap()

        let section = app.descendants(matching: .any)["home.habitsToday"]
        XCTAssertTrue(section.waitForExistence(timeout: 10))
        scrollUntilVisible(section, in: app, maximumSwipes: 10)
        let ring = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ AND value == %@", "Water", "0 of 8 glasses"))
            .firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 10), "The new habit is an amount ring with its target")
        keepScreenshot(app, named: "home-water-ring")
    }

    /// "Enter amount" sets today's amount in place: the ring reads the new
    /// number, the receipt offers Undo, and Undo puts the old number back.
    func testFoundationHomeEnterAmountSetsTheRingWithUndo() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedHabits: true,
            additionalArguments: ["-LIFEBOARD_TEST_SEED_HABIT_AMOUNTS"]
        )
        defer { app.terminate() }
        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)

        let section = app.descendants(matching: .any)["home.habitsToday"]
        scrollUntilVisible(section, in: app, maximumSwipes: 10)
        XCTAssertTrue(section.waitForExistence(timeout: 10))
        let ring = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ AND value == %@", "Water", "0 of 8 glasses"))
            .firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 10), "The seeded amount habit shows its ring")
        scrollUntilHittable(ring, in: app, maximumSwipes: 6)

        let label = app.staticTexts["Water"].firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 4))
        label.press(forDuration: 1.0)
        let enter = app.buttons["Enter amount…"]
        XCTAssertTrue(enter.waitForExistence(timeout: 4), "The label menu offers Enter amount")
        enter.tap()

        let field = app.textFields["habit.amount.entry.value"]
        XCTAssertTrue(field.waitForExistence(timeout: 6))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        field.typeText("5")
        let commit = app.buttons["habit.amount.entry.commit"]
        XCTAssertTrue(commit.waitForExistence(timeout: 4))
        commit.tap()

        let updated = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ AND value == %@", "Water", "5 of 8 glasses"))
            .firstMatch
        XCTAssertTrue(updated.waitForExistence(timeout: 10), "The ring reads the typed amount")
        keepScreenshot(app, named: "home-enter-amount-set")
        let undo = app.buttons["lifeboard.receipt.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 6), "Setting an amount leaves a receipt with Undo")
        undo.tap()
        XCTAssertTrue(ring.waitForExistence(timeout: 10), "Undo puts the previous amount back")
    }

    private func launchHomeHabitsRow() -> XCUIApplication {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedHabits: true,
            additionalArguments: ["-LIFEBOARD_TEST_SEED_HABIT_AMOUNTS", "-LIFEBOARD_TEST_SEED_HABIT_QUIT"]
        )
        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let section = app.descendants(matching: .any)["home.habitsToday"]
        scrollUntilVisible(section, in: app, maximumSwipes: 10)
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Home lists today's habits")
        return app
    }

    /// The row also scrolls from a card's words, where the card's own tap and
    /// menu live.
    func testFoundationHomeHabitsRowScrollsFromCardText() {
        let app = launchHomeHabitsRow()
        defer { app.terminate() }
        let first = app.staticTexts["Drink water after breakfast"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        scrollUntilHittable(first, in: app, maximumSwipes: 6)
        let allHabits = app.buttons["home.habitsToday.allHabits"]
        XCTAssertTrue(allHabits.waitForExistence(timeout: 8))
        let screen = app.windows.firstMatch.frame
        let titles = app.staticTexts.matching(NSPredicate(format: "label IN %@", [
            "Drink water after breakfast", "Choose tomorrow's top priority before bed", "No phone in bed",
            "Water", "No doomscrolling after dinner", "Stretch after every long meeting"
        ]))
        for _ in 0..<8 where (allHabits.exists && screen.contains(allHabits.frame)) == false {
            guard let visible = (0..<titles.count).map({ titles.element(boundBy: $0) })
                .first(where: { screen.contains($0.frame) }) else { break }
            visible.swipeLeft()
        }
        XCTAssertTrue(allHabits.exists && screen.contains(allHabits.frame), "Swiping on card text scrolls the row")
    }

    /// Six habits overflow the row; a swipe that starts on a ring still
    /// scrolls it, all the way to the "All habits" card.
    func testFoundationHomeHabitsRowScrollsAcrossManyHabits() {
        let app = launchHomeHabitsRow()
        defer { app.terminate() }

        let first = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ AND identifier BEGINSWITH %@", "Drink water after breakfast", "home.habitsToday.ring."))
            .firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        scrollUntilHittable(first, in: app, maximumSwipes: 6)
        keepScreenshot(app, named: "home-habits-row-start")

        let allHabits = app.buttons["home.habitsToday.allHabits"]
        XCTAssertTrue(allHabits.waitForExistence(timeout: 8))
        let screen = app.windows.firstMatch.frame
        // An off-screen button has no hit point, so read its frame instead.
        func onScreen() -> Bool { allHabits.exists && screen.contains(allHabits.frame) }
        XCTAssertFalse(onScreen(), "Six habits overflow the row")
        let rings = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.habitsToday.ring."))
        for _ in 0..<8 where onScreen() == false {
            // Every swipe begins on a ring, where the hold gesture lives: the
            // row must scroll anyway.
            guard let visible = (0..<rings.count).map({ rings.element(boundBy: $0) })
                .first(where: { screen.contains($0.frame) }) else { break }
            visible.swipeLeft()
        }
        XCTAssertTrue(onScreen(), "The row scrolls to its end")
        keepScreenshot(app, named: "home-habits-row-end")
    }

    /// A lapse-only habit reads as clean, logs a slip only after confirming,
    /// and Undo takes the slip back.
    func testFoundationHomeQuitHabitLogsASlipWithUndo() {
        let app = launchHomeHabitsRow()
        defer { app.terminate() }

        let title = "No doomscrolling after dinner"
        let clean = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ AND value BEGINSWITH %@", title, "Clean"))
            .firstMatch
        let row = app.descendants(matching: .any)["home.habitsToday.row"]
        let screen = app.windows.firstMatch.frame
        for _ in 0..<8 where (clean.exists && screen.contains(clean.frame)) == false {
            row.swipeLeft()
        }
        XCTAssertTrue(clean.waitForExistence(timeout: 8), "A quit habit reads its clean count, not Hold or Done")
        XCTAssertTrue(clean.isHittable)
        keepScreenshot(app, named: "home-quit-habit-clean")

        app.staticTexts[title].firstMatch.press(forDuration: 1.0)
        let logSlip = app.buttons["Log a slip…"]
        XCTAssertTrue(logSlip.waitForExistence(timeout: 4), "The card menu offers a slip")
        logSlip.tap()
        // The dialog can surface its action twice in the tree; any one will do.
        let confirm = app.buttons.matching(NSPredicate(format: "label == %@", "Log slip")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 4), "A slip is confirmed before it is recorded")
        confirm.tap()

        let slipped = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ AND value == %@", title, "Slip logged today"))
            .firstMatch
        XCTAssertTrue(slipped.waitForExistence(timeout: 8), "The card says the slip plainly")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Slip logged · \(title)")).firstMatch.waitForExistence(timeout: 6),
            "The slip leaves a receipt"
        )
        keepScreenshot(app, named: "home-quit-habit-slip")
        let undo = app.buttons["lifeboard.receipt.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 4))
        undo.tap()
        XCTAssertTrue(clean.waitForExistence(timeout: 8), "Undo puts the clean count back")
    }

    func testFoundationHomeHabitsTodayCompletesACheckInOnHoldNotTap() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedHabits: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        let section = app.descendants(matching: .any)["home.habitsToday"]
        scrollUntilVisible(section, in: app, maximumSwipes: 10)
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Home lists today's habits where they can be logged")

        let ring = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ AND value == %@", "Drink water after breakfast", "Not done"))
            .firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 8))
        scrollUntilHittable(ring, in: app, maximumSwipes: 6)

        keepScreenshot(app, named: "home-habits-today-before")
        ring.press(forDuration: 1.4)
        let done = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ AND value == %@", "Drink water after breakfast", "Done"))
            .firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 8), "Holding completes a check-in habit in place")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Drink water after breakfast done")).firstMatch
                .waitForExistence(timeout: 6),
            "Completion leaves a receipt with Undo"
        )
        keepScreenshot(app, named: "home-habits-today-after")
    }

    private func keepScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFoundationHomeRoutineFallbackUsesTypedHabitBoardRoute() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedHabits: true,
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        tapHomeAction("home.routines.openHabitBoard", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.track"]),
            "A habit-backed routine suggestion must open the typed native Habit Board leaf."
        )
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.HabitBoard.view].firstMatch.waitForExistence(timeout: 10))
    }

    func testFoundationHomeHierarchyAndDaypartRemainUsableInDarkAppearance() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true,
            appearance: "Dark"
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
        assertHomeNowDecision(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["home.signalRow"].waitForExistence(timeout: 8))

        selectAtmosphere(.night, in: app)
        dismissDisplayPanel(in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["lifeboard.atmosphere.night"].waitForExistence(timeout: 8),
            "Choosing Night must retint the canvas, not just move the control."
        )

        tapHomeAction("home.journal.weeklyReflection", in: app)
        XCTAssertTrue(
            waitForAccessibilityValue("Detail depth 1", on: app.buttons["foundation.destination.home"])
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["journal.weeklyReflection.header"].waitForExistence(timeout: 8)
        )
    }

    func testFoundationHomeHierarchyAcrossEveryContentSizeCategory() {
        let categories = [
            "UICTContentSizeCategoryXS",
            "UICTContentSizeCategoryS",
            "UICTContentSizeCategoryM",
            "UICTContentSizeCategoryL",
            "UICTContentSizeCategoryXL",
            "UICTContentSizeCategoryXXL",
            "UICTContentSizeCategoryXXXL",
            "UICTContentSizeCategoryAccessibilityM",
            "UICTContentSizeCategoryAccessibilityL",
            "UICTContentSizeCategoryAccessibilityXL",
            "UICTContentSizeCategoryAccessibilityXXL",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]

        for category in categories {
            XCTContext.runActivity(named: category) { _ in
                let app = launchFoundationApp(
                    accessibilityCategory: category,
                    seedEstablishedWorkspace: true
                )
                defer { app.terminate() }

                assertFoundationDestination("home", rootIdentifier: "home.header", in: app)
                assertHomeNowDecision(in: app)

                let deepestSection = app.descendants(matching: .any)["home.widget.progressReflection"]
                scrollUntilVisible(deepestSection, in: app, maximumSwipes: 16)
                XCTAssertTrue(deepestSection.exists, "The full Home hierarchy must remain reachable at \(category).")
                XCTAssertTrue(app.windows.firstMatch.frame.intersects(deepestSection.frame))

                // Home hides the floating composer at accessibility sizes and
                // the header owns capture instead; below that, the scroll
                // above compressed the composer to its orb, which a tap restores.
                if category.contains("Accessibility") {
                    let capture = app.buttons["foundation.capture"]
                    XCTAssertTrue(capture.waitForExistence(timeout: 5) && capture.isHittable, "Header capture must be reachable at \(category).")
                } else {
                    let orb = app.buttons["lifeThread.composer.orb"]
                    if orb.waitForExistence(timeout: 2) { orb.tap() }
                    let composer = app.textFields["home.lifeThread.composer"]
                    XCTAssertTrue(composer.waitForExistence(timeout: 5) && composer.isHittable, "The composer must be reachable at \(category).")
                }
            }
        }
    }

    /// Home Repair acts where you are: choosing a repair stages a preview in
    /// place, Apply ends in a receipt, and Undo brings the deck back. Seeded
    /// with two drifted blocks so the loop spine opens on the Repair stage.
    func testFoundationHomeRepairAppliesInPlaceWithReceiptAndUndo() {
        let app = launchFoundationApp(accessibilityCategory: "UICTContentSizeCategoryL", seedDriftedPlan: true)
        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)

        let repairBody = app.descendants(matching: .any)["home.loopSpine.repair.body"]
        XCTAssertTrue(repairBody.waitForExistence(timeout: 20), "Two drifted blocks must put the loop spine on Repair.")
        let deck = app.descendants(matching: .any)["plan.repair"]
        XCTAssertTrue(deck.waitForExistence(timeout: 8), "The repair deck must render inside Home.")
        attachScreenshot(named: "Home repair deck")

        // Which moves are offered depends on the time of day; take the first
        // one that stages a scenario rather than pinning a single label.
        let candidates = ["Later today", "Tomorrow", "Unschedule", "Split"]
        guard let choice = candidates.map({ app.buttons[$0] }).first(where: { $0.exists }) else {
            XCTFail("The repair deck offered none of \(candidates).")
            return
        }
        scrollUntilHittableWithSmallSteps(choice, in: app, maximumSteps: 24)
        XCTAssertTrue(choice.isHittable, "The repair choice must be reachable.")
        choice.tap()

        let preview = app.descendants(matching: .any)["plan.minimumViableDay.preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 15), "Choosing a repair must stage a preview in place.")
        attachScreenshot(named: "Home repair preview")

        let apply = app.buttons["Apply repair"]
        scrollUntilHittableWithSmallSteps(apply, in: app, maximumSteps: 24)
        XCTAssertTrue(apply.waitForExistence(timeout: 8), "The staged repair must offer Apply.")
        XCTAssertTrue(apply.isEnabled, "A staged repair with no validation issues must be applicable.")
        apply.tap()

        // The bar's own container is flattened out of the accessibility
        // snapshot inside the loop spine; its Undo button is the contract.
        let undo = app.buttons["lifeboard.receipt.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 15), "Applying the repair must end in a receipt with Undo.")
        attachScreenshot(named: "Home repair receipt")
        scrollUntilHittableWithSmallSteps(undo, in: app, maximumSteps: 12)
        XCTAssertTrue(undo.isHittable, "The repair receipt's Undo must be reachable.")
        undo.tap()

        XCTAssertTrue(deck.waitForExistence(timeout: 15), "Undo must return the loop spine to the repair deck.")
        attachScreenshot(named: "Home repair after undo")
    }

    /// Reflection happens where the session ended: the dial settles, the
    /// in-place reflection appears under it, Done saves and the way back stays.
    func testFocusReflectionHappensWhereTheSessionEnded() {
        let app = launchFoundationApp(accessibilityCategory: "UICTContentSizeCategoryL", seedEstablishedWorkspace: true)
        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)

        // Agenda lists the planned tasks with a visible menu; the canvas's
        // block menu is too small to hit at this hour's block heights.
        let agenda = app.buttons["plan.day.presentation.toggle"]
        XCTAssertTrue(agenda.waitForExistence(timeout: 8))
        agenda.tap()
        let menu = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'plan.taskMenu.'")).firstMatch
        scrollUntilHittableWithSmallSteps(menu, in: app, maximumSteps: 24)
        XCTAssertTrue(menu.waitForExistence(timeout: 8), "A planned task card must offer its menu.")
        menu.tap()
        let startFocus = app.buttons["Start focus"]
        XCTAssertTrue(startFocus.waitForExistence(timeout: 5))
        startFocus.tap()
        let start = app.buttons["plan.focus.setup.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()

        // The route scaffold's own identifier flattens the surface root out
        // of the snapshot, so the dial stands in for "the surface is open".
        let surface = app.descendants(matching: .any)["focus.surface.dial"]
        XCTAssertTrue(surface.waitForExistence(timeout: 12), "Starting a session must open the focus surface.")
        let endSession = app.buttons["focus.surface.endSession"]
        scrollUntilHittableWithSmallSteps(endSession, in: app, maximumSteps: 12)
        XCTAssertTrue(endSession.waitForExistence(timeout: 8))
        endSession.tap()
        let completed = app.buttons["focus.surface.end.completed"]
        XCTAssertTrue(completed.waitForExistence(timeout: 5))
        // Two taps: choosing the ending commits it; there is no separate
        // confirmation step any more.
        completed.tap()

        let reflection = app.descendants(matching: .any)["focus.reflection"]
        XCTAssertTrue(reflection.waitForExistence(timeout: 12), "The reflection must appear on the surface after the ending is saved.")
        attachScreenshot(named: "Focus reflection in place")
        let energy = app.buttons["focus.reflection.energy.4"]
        XCTAssertTrue(energy.waitForExistence(timeout: 5))
        energy.tap()
        let done = app.buttons["focus.reflection.commit"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.buttons["focus.surface.done"].waitForExistence(timeout: 8), "The way back to Plan stays after reflecting.")
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: reflection)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 8), .completed, "Done must fold the reflection away.")
        attachScreenshot(named: "Focus reflection saved")
    }

    func testFoundationHomeManualDaypartsRemainIndependentlySelectable() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedEstablishedWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("home", rootIdentifier: "home.header", in: app)

        // Each daypart maps to its own celestial phase, so asserting on the
        // phase marker proves the override actually reached the renderer.
        // "Afternoon" resolving to `midday` is the mapping, not a typo.
        let dayparts: [(stop: AtmosphereStop, phase: String)] = [
            (.morning, "morning"),
            (.afternoon, "midday"),
            (.evening, "goldenHour"),
            (.night, "night")
        ]

        for (stop, phase) in dayparts {
            selectAtmosphere(stop, in: app)
            dismissDisplayPanel(in: app)
            XCTAssertTrue(
                app.descendants(matching: .any)["lifeboard.atmosphere.\(phase)"].waitForExistence(timeout: 8),
                "The Home atmosphere did not resolve the \(stop.title) override."
            )
            XCTAssertTrue(app.descendants(matching: .any)["home.signalRow"].exists)
        }

        // Auto hands the day back to the clock. It is a stop on the same track
        // now, which is what retired the separate "Return to Auto" button.
        selectAtmosphere(.automatic, in: app)
        let slider = app.descendants(matching: .any)["foundation.atmosphere.slider"]
        let readsAuto = XCTNSPredicateExpectation(
            // The readout is "Auto · now <daypart>", so the resolved day
            // stays visible even when the choice is not a time.
            predicate: NSPredicate(format: "value BEGINSWITH %@", "Auto"),
            object: slider
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [readsAuto], timeout: 8),
            .completed,
            "Returning to Auto must be reachable from the slider itself."
        )
        dismissDisplayPanel(in: app)
    }

    /// The five stops on the atmosphere slider, in track order.
    private enum AtmosphereStop: Int, CaseIterable {
        case automatic, morning, afternoon, evening, night

        var title: String {
            switch self {
            case .automatic: "Auto"
            case .morning: "Morning"
            case .afternoon: "Afternoon"
            case .evening: "Evening"
            case .night: "Night"
            }
        }

        /// Normalised x of this stop's lane centre. Auto owns a wider leading
        /// lane than the dayparts, so these are not evenly spaced — see
        /// `AtmosphereSliderGeometry`, which owns the real arithmetic.
        var normalizedX: CGFloat {
            switch self {
            case .automatic: 0.07
            case .morning: 0.28
            case .afternoon: 0.47
            case .evening: 0.66
            case .night: 0.90
            }
        }
    }

    /// Opens Home's Display panel and taps a stop on the atmosphere slider.
    ///
    /// The panel is left open: the caller usually wants to assert on the canvas
    /// behind it, which is exactly why this is a compact sheet rather than a
    /// full-height one.
    private func selectAtmosphere(
        _ stop: AtmosphereStop,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let panel = app.descendants(matching: .any)["foundation.display.panel"]
        if panel.exists == false {
            let more = app.buttons["foundation.more.home"]
            XCTAssertTrue(more.waitForExistence(timeout: 8), file: file, line: line)
            more.tap()
            XCTAssertTrue(panel.waitForExistence(timeout: 8), file: file, line: line)
        }

        let slider = app.descendants(matching: .any)["foundation.atmosphere.slider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 8), file: file, line: line)

        // At accessibility text sizes the slider becomes a row list, because a
        // control whose drag axis is its value axis cannot scroll to stay legible.
        let row = app.buttons["foundation.atmosphere.stop.\(String(describing: stop))"]
        if row.exists {
            row.tap()
            return
        }
        slider
            .coordinate(withNormalizedOffset: CGVector(dx: stop.normalizedX, dy: 0.5))
            .tap()
    }

    private func dismissDisplayPanel(in app: XCUIApplication) {
        let panel = app.descendants(matching: .any)["foundation.display.panel"]
        guard panel.exists else { return }
        // A swipe on the app lands on the panel's own content; the grabber
        // is the reliable handle, with a tap on the dimmed canvas as fallback.
        for attempt in 0..<3 where panel.exists {
            let grabber = app.buttons["Sheet Grabber"]
            if attempt < 2, grabber.exists {
                grabber.swipeDown()
            } else {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
            }
            _ = panel.waitForNonExistence(timeout: 4)
        }
        XCTAssertFalse(panel.exists, "The Display panel must dismiss before the canvas is used.")
    }

    func testFoundationDayCanvasAgendaCreatesAndUndoesPersistedBlock() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedFullTimeline: true
        )
        defer { app.terminate() }

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        let canvas = app.descendants(matching: .any).matching(identifier: "plan.day.canvas").firstMatch
        scrollUntilVisible(canvas, in: app, maximumSwipes: 8)
        XCTAssertTrue(canvas.waitForExistence(timeout: 10), "Day should expose the real time canvas.")

        let presentation = app.buttons["plan.day.presentation.toggle"]
        XCTAssertTrue(presentation.waitForExistence(timeout: 8))
        presentation.tap()

        let addBlock = app.buttons["plan.day.addBlock"]
        scrollUntilHittable(addBlock, in: app, maximumSwipes: 12)
        XCTAssertTrue(addBlock.waitForExistence(timeout: 8))
        addBlock.tap()

        XCTAssertTrue(app.descendants(matching: .any)["plan.block.composer"].waitForExistence(timeout: 8))
        let title = app.descendants(matching: .any)["plan.block.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        title.tap()
        title.typeText("Simulator focus block")
        let add = app.buttons["plan.block.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let savedBlock = app.staticTexts["Simulator focus block"]
        scrollUntilVisible(savedBlock, in: app, maximumSwipes: 12)
        XCTAssertTrue(savedBlock.waitForExistence(timeout: 10), "The agenda composer should expose the persisted block.")

        let undo = app.buttons["Undo last planning change"]
        for _ in 0..<14 where undo.exists == false || undo.isHittable == false { app.swipeDown() }
        XCTAssertTrue(undo.waitForExistence(timeout: 8))
        undo.tap()
        XCTAssertTrue(
            waitForElementToDisappear(undo, timeout: 10),
            "One-step undo should consume the persisted planning receipt."
        )
    }

    func testFoundationOpenDayLaunchesOverdueRescueAndKeepsTaskInPlannedWork() {
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedRescueWorkspace: true
        )
        defer { app.terminate() }

        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)

        let openDay = app.buttons["plan.day.openRescue"]
        scrollUntilHittable(openDay, in: app, maximumSwipes: 12)
        XCTAssertTrue(openDay.waitForExistence(timeout: 10))
        XCTAssertTrue(openDay.isHittable)
        openDay.tap()

        XCTAssertTrue(app.descendants(matching: .any)["home.rescue.sheet"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["Rescue oldest"].waitForExistence(timeout: 8))

        let keep = app.buttons["home.rescue.action.keepToday"]
        XCTAssertTrue(keep.waitForExistence(timeout: 8))
        XCTAssertEqual(keep.label, "Keep today")
        XCTAssertTrue(keep.isHittable, "Keep must remain above the app chrome.")
        XCTAssertTrue(app.buttons["home.rescue.action.moveLater"].isHittable)
        XCTAssertTrue(app.buttons["home.rescue.action.Edit"].isHittable)
        XCTAssertTrue(app.buttons["home.rescue.action.Delete"].isHittable)
        keep.tap()
        XCTAssertTrue(
            app.staticTexts["Rescue middle"].waitForExistence(timeout: 12),
            "The deck should advance only after the task and Planned Work metadata both save."
        )

        let close = app.buttons["home.rescue.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 8))
        XCTAssertTrue(close.isHittable, "Close must sit inside the top safe area.")
        close.tap()
        XCTAssertTrue(
            waitForElementToDisappear(app.descendants(matching: .any)["home.rescue.sheet"], timeout: 8),
            "Closing rescue should return to the existing Plan context."
        )

        // On the Timeline, work kept for today with no time on it sits in the
        // Anytime row as a chip, which is a button to assistive tech, so match
        // the label on any element rather than on static text.
        let plannedTask = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Rescue oldest")
        ).firstMatch
        scrollUntilVisible(plannedTask, in: app, maximumSwipes: 12)
        XCTAssertTrue(
            plannedTask.waitForExistence(timeout: 12),
            "A task kept from Plan rescue should appear immediately under Planned Work."
        )
    }

    func testFoundationWeekUsesSevenDayBoardOnRegularWidth() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launchFoundationApp(
            accessibilityCategory: "UICTContentSizeCategoryL",
            seedFullTimeline: true
        )
        defer { app.terminate() }

        guard app.windows.firstMatch.frame.width >= 700 else {
            throw XCTSkip("The seven-day board requires a regular-width iPad or Catalyst window.")
        }
        let planTab = app.buttons["foundation.expanded.destination.plan"]
        XCTAssertTrue(
            planTab.waitForExistence(timeout: 8),
            "Regular width must expose the direct, accessible Plan root switcher."
        )
        XCTAssertTrue(planTab.isHittable)
        planTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan.header"].waitForExistence(timeout: 12))
        let week = app.buttons["plan.lens.Week"]
        XCTAssertTrue(week.waitForExistence(timeout: 8))
        week.tap()

        let board = app.descendants(matching: .any).matching(identifier: "plan.week.sevenDayBoard").firstMatch
        scrollUntilVisible(board, in: app, maximumSwipes: 10)
        XCTAssertTrue(board.waitForExistence(timeout: 10), "Regular width should mount the seven-day board.")
        XCTAssertFalse(app.descendants(matching: .any)["plan.week.compactList"].exists)

        let dayTargets = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier MATCHES %@", "plan\\.week\\.[0-9]+-[0-9]+-[0-9]+")
        )
        XCTAssertEqual(dayTargets.count, 7, "The adaptive board must expose all seven stable day targets.")
        XCTAssertTrue(app.descendants(matching: .any)["plan.week.operatingLayer"].exists)
    }

    private func launchFoundationApp(
        accessibilityCategory: String,
        seedHabits: Bool = false,
        seedEstablishedWorkspace: Bool = false,
        seedLongHomeTaskAgenda: Bool = false,
        seedHomeUserSpace: Bool = false,
        seedFullTimeline: Bool = false,
        seedRescueWorkspace: Bool = false,
        seedInboxCaptures: Bool = false,
        seedDriftedPlan: Bool = false,
        evaActivationCompleted: Bool = false,
        appearance: String? = nil,
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-RESET_APP_STATE",
            "-UI_TESTING",
            // Deliberately NOT `-DISABLE_ANIMATIONS`. That calls
            // `UIView.setAnimationsEnabled(false)`, which also disables the UIKit
            // animation machinery XCUITest's `swipeUp()` drives — six tests here
            // fail their "reachable by scrolling" assertions with it set.
            // `LifeBoardAnimation.areProcessAnimationsDisabled` already treats
            // `-UI_TESTING` as animations-off, so token-routed motion and the
            // zoom route transition are suppressed without it.
            "-SKIP_ONBOARDING",
            "-DISABLE_CLOUD_SYNC",
            "-LIFEBOARD_ENABLE_LIFE_OS_FOUNDATION",
            "-LIFEBOARD_ENABLE_DASHBOARD_CUSTOMIZATION_V2",
            "-LIFEBOARD_ENABLE_TRACKERS_V1",
            "-LIFEBOARD_ENABLE_HEALTH_INTEGRATIONS_V1",
            "-LIFEBOARD_ENABLE_JOURNAL_V1",
            "-LIFEBOARD_ENABLE_KNOWLEDGE_NOTES_V1",
            "-LIFEBOARD_ENABLE_PLANNING_CORE_V1",
            "-LIFEBOARD_ENABLE_FOCUS_EXECUTION_V2",
            "-LIFEBOARD_ENABLE_TRACK_FOUNDATIONS_V2",
            "-LIFEBOARD_ENABLE_GOALS_ROUTINES_V1",
            "-LIFEBOARD_ENABLE_CARE_MODULES_V2",
            "-LIFEBOARD_ENABLE_LIFE_OS_UNIFIED_PRESENTATION_V2",
            "-UIPreferredContentSizeCategoryName",
            accessibilityCategory
        ]
        if seedHabits { app.launchArguments.append("-LIFEBOARD_TEST_SEED_HABIT_BOARD_WORKSPACE") }
        if seedEstablishedWorkspace { app.launchArguments.append("-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE") }
        if seedLongHomeTaskAgenda { app.launchArguments.append("-LIFEBOARD_TEST_SEED_LONG_HOME_TASK_AGENDA") }
        if seedHomeUserSpace { app.launchArguments.append("-LIFEBOARD_TEST_SEED_HOME_USER_SPACE") }
        if seedFullTimeline { app.launchArguments.append("-LIFEBOARD_TEST_SEED_FULL_TIMELINE_WORKSPACE") }
        if seedRescueWorkspace { app.launchArguments.append("-LIFEBOARD_TEST_SEED_RESCUE_WORKSPACE") }
        if seedInboxCaptures { app.launchArguments.append("-LIFEBOARD_TEST_SEED_INBOX_CAPTURES") }
        if seedDriftedPlan {
            app.launchArguments.append(contentsOf: [
                "-LIFEBOARD_TEST_SEED_DRIFTED_PLAN",
                "-LIFEBOARD_ENABLE_HOME_LOOP_SPINE_V1",
                // In the morning window an unopened day shows the open-the-day
                // stage ahead of Repair (`DayLoopStageResolver`, unit-tested), so
                // the stage is forced; the deck itself still comes from the seed.
                "-LIFEBOARD_FORCE_DAY_REPAIR"
            ])
        }
        if evaActivationCompleted { app.launchArguments.append("-LIFEBOARD_TEST_EVA_ACTIVATION_COMPLETED") }
        if let appearance {
            app.launchArguments.append(contentsOf: ["-AppleInterfaceStyle", appearance])
        }
        app.launchEnvironment["PERFORMANCE_TEST"] = "1"
        app.launchArguments.append(contentsOf: additionalArguments)
        app.launch()
        // The first launch after a fresh install can land on onboarding despite
        // `-SKIP_ONBOARDING` (memory: simulator-verification-traps); one
        // relaunch with the same arguments lands on the shell.
        if app.descendants(matching: .any)["onboarding.lifeweave.flow"].waitForExistence(timeout: 2),
           app.buttons["foundation.destination.home"].exists == false {
            app.terminate()
            app.launch()
        }
        return app
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @discardableResult
    private func assertFoundationEvaRestingLayout(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (composer: XCUIElement, chrome: XCUIElement) {
        let composer = app.descendants(matching: .any)["eva.structured.composer"]
        let chrome = app.descendants(matching: .any)["LifeBoardCompactChrome"]
        XCTAssertTrue(composer.waitForExistence(timeout: 12), file: file, line: line)
        XCTAssertTrue(chrome.waitForExistence(timeout: 8), file: file, line: line)
        assertRequiredEvaDockSpacing(composer: composer, chrome: chrome, in: app, file: file, line: line)
        XCTAssertTrue(
            composer.isHittable,
            "Eva composer must be tappable at rest. composer=\(composer.frame), dock=\(chrome.frame)",
            file: file,
            line: line
        )
        return (composer, chrome)
    }

    private func assertRequiredEvaDockSpacing(
        composer: XCUIElement,
        chrome: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let requiredSpacing: CGFloat = 12
        let interactiveFrame = evaComposerInteractiveFrame(in: app, composer: composer)
        let frameSummary = evaComposerInteractiveControls(in: app, composer: composer)
            .map { "\($0.identifier)=\($0.frame)" }
            .joined(separator: ", ")
        XCTAssertLessThanOrEqual(
            interactiveFrame.maxY + requiredSpacing,
            chrome.frame.minY + 1,
            "Every interactive part of Eva's composer must clear the dock by at least the md spacing token. \(frameSummary)",
            file: file,
            line: line
        )
    }

    private func evaComposerInteractiveFrame(
        in app: XCUIApplication,
        composer: XCUIElement
    ) -> CGRect {
        let controls = evaComposerInteractiveControls(in: app, composer: composer)

        return controls.dropFirst().reduce(composer.frame) { frame, control in
            frame.union(control.frame)
        }
    }

    private func evaComposerInteractiveControls(
        in app: XCUIApplication,
        composer: XCUIElement
    ) -> [XCUIElement] {
        [
            composer,
            app.textFields["chat.command_argument_field"],
            app.buttons["eva.structured.dictation.xmark"],
            app.buttons["eva.structured.dictation.stop.fill"],
            app.buttons["eva.structured.dictation.mic.fill"],
            app.buttons["eva.structured.deferred.mic.fill"],
            app.buttons["eva.structured.deferred.viewfinder"],
            app.buttons["chat.send_button"],
            app.buttons["chat.stop_button"]
        ].filter(\.exists)
    }

    private func saveVisualEvidenceScreenshot(named name: String, platform: String = "ipad") throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let outputDirectory = repositoryRoot
            .appendingPathComponent("docs/evidence/lifeboard-5/root-state-fixtures/\(platform)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try screenshot.pngRepresentation.write(
            to: outputDirectory.appendingPathComponent("\(name).png"),
            options: .atomic
        )
    }

    private func openBacklog(in app: XCUIApplication) {
        let backlog = app.buttons["plan.lens.Backlog"]
        XCTAssertTrue(backlog.waitForExistence(timeout: 8))
        backlog.tap()
        XCTAssertTrue(app.textFields["plan.backlog.search"].waitForExistence(timeout: 8))
    }

    private func openSeededInbox(in app: XCUIApplication) {
        assertFoundationDestination("plan", rootIdentifier: "plan.header", in: app)
        let inbox = app.buttons["plan.lens.Inbox"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 8))
        inbox.tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan.inbox"].waitForExistence(timeout: 10))
    }

    /// Opens a backlog task's action menu.
    ///
    /// This used to tap the task element itself. The card body now opens the
    /// canonical task route instead — tapping it would push a detail screen rather
    /// than surface Delete — so the row's actions are reached through their own
    /// control, which is also the only affordance that was ever a 44-point target.
    private func requestBacklogDeletion(for task: XCUIElement, in app: XCUIApplication) {
        scrollUntilHittable(task, in: app, maximumSwipes: 8)
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        // `plan.taskMenu.` rather than `plan.task.menu.`: the test's own row query
        // matches on the `plan.task.` prefix, so a nested menu identifier would be
        // counted as a task and break every cardinality assertion below.
        let menuIdentifier = task.identifier.replacingOccurrences(
            of: "plan.task.",
            with: "plan.taskMenu."
        )
        let menu = app.buttons[menuIdentifier]
        scrollUntilHittable(menu, in: app, maximumSwipes: 4)
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        XCTAssertTrue(menu.isHittable)
        menu.tap()
        let deletion = app.buttons["Delete task"]
        XCTAssertTrue(deletion.waitForExistence(timeout: 5))
        deletion.tap()
    }

    private func waitForQuery(
        _ query: XCUIElementQuery,
        toHaveCount expectedCount: Int,
        timeout: TimeInterval
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in query.count == expectedCount },
            object: query
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForAccessibilityValue(
        _ value: String,
        on element: XCUIElement,
        timeout: TimeInterval = 8
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func tapHomeAction(
        _ identifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let action = app.buttons[identifier]
        if !action.isHittable {
            for _ in 0..<8 {
                if app.descendants(matching: .any)["home.signalRow"].isHittable { break }
                app.swipeDown()
            }
        }
        scrollUntilHittableWithSmallSteps(action, in: app, maximumSteps: 32)
        XCTAssertTrue(action.waitForExistence(timeout: 8), file: file, line: line)
        XCTAssertTrue(action.isHittable, "Home action \(identifier) must remain reachable.", file: file, line: line)
        action.tap()
    }


    /// Home's "one Now decision" is the hero card, or the loop spine's stage
    /// (commit / repair / rest) when the day loop owns that slot.
    private func assertHomeNowDecision(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let candidates = ["home.hero", "home.loopSpine.commit", "home.loopSpine.repair.body", "home.loopSpine.rest", "home.dayRitual"]
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if candidates.contains(where: { app.descendants(matching: .any)[$0].exists }) { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail("Home exposed none of \(candidates).", file: file, line: line)
    }

    private func assertFoundationDestination(
        _ destination: String,
        rootIdentifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = app.buttons["foundation.destination.\(destination)"]
        XCTAssertTrue(button.waitForExistence(timeout: 8), file: file, line: line)
        // The dock re-measures after a tray or keyboard closes; give it a moment.
        let hittable = NSPredicate(format: "isHittable == true")
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: hittable, object: button)], timeout: 5)
        XCTAssertTrue(button.isHittable, "\(destination) must remain reachable.", file: file, line: line)
        button.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[rootIdentifier].waitForExistence(timeout: 12),
            "\(destination) did not expose its native root.",
            file: file,
            line: line
        )
    }

    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 7
    ) {
        for _ in 0..<maximumSwipes where element.exists == false || element.isHittable == false {
            app.swipeUp()
        }
    }

    private func scrollUntilHittableWithSmallSteps(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSteps: Int = 20
    ) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
        for _ in 0..<maximumSteps where element.exists == false || element.isHittable == false {
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    private func scrollUntilVisible(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 7
    ) {
        for _ in 0..<maximumSwipes {
            if element.exists, app.windows.firstMatch.frame.intersects(element.frame) { return }
            app.swipeUp()
        }
    }

}
