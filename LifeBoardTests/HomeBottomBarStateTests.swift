import SwiftUI
import UIKit
import XCTest
@testable import LifeBoard

@MainActor
final class HomeBottomBarStateTests: XCTestCase {
    /// The switcher is the iPad and Mac chrome; phone-shaped windows and
    /// accessibility text keep the dock, which is keyboard and VoiceOver complete.
    /// Immersive surfaces cover the phone but become page sheets at pad widths;
    /// forms and pages are sheets everywhere.
    func testPresentationPolicyAdaptsImmersiveCoversToPadWidths() {
        for layoutClass in LayoutClass.allCases {
            XCTAssertEqual(LifeBoardPresentationPolicy.style(kind: .form, layoutClass: layoutClass), .sheet(.form))
            XCTAssertEqual(LifeBoardPresentationPolicy.style(kind: .page, layoutClass: layoutClass), .sheet(.page))
            XCTAssertEqual(
                LifeBoardPresentationPolicy.style(kind: .immersive, layoutClass: layoutClass),
                layoutClass.isPad ? .sheet(.page) : .fullScreenCover
            )
        }
    }

    /// Two commands on one chord was how ⌘N came to mean two things.
    func testMainMenuKeyEquivalentsAreUnique() {
        let equivalents = AppCommandMenu.keyEquivalents
        XCTAssertEqual(equivalents.count, Set(equivalents).count)
        let identities = AppCommandMenu.commandIdentities
        XCTAssertEqual(identities.count, Set(identities).count, "UIKit throws on a duplicate action + property list")
        XCTAssertEqual(AppCommandMenu.rootCommands().count, Destination.allCases.count)
    }

    /// File ▸ New follows where the person is.
    func testContextualCaptureKindFollowsTheCurrentRoute() {
        let defaults = UserDefaults(suiteName: "HomeBottomBarStateTests.capture.\(UUID().uuidString)")!
        let router = AppRouter(defaults: defaults)
        router.select(.plan)
        XCTAssertEqual(router.contextualCaptureKind, .task)
        router.select(.track)
        router.setPath([.journalSearch], for: .track)
        XCTAssertEqual(router.contextualCaptureKind, .journal)
        router.setPath([.note(UUID())], for: .track)
        XCTAssertEqual(router.contextualCaptureKind, .note)
        XCTAssertEqual(AppCommandMenu.newCaptureTitle(destination: .eva, captureKind: .task), "New Chat")
        XCTAssertEqual(AppCommandMenu.newCaptureTitle(destination: .track, captureKind: .journal), "New Journal Entry")
    }

    /// Journal only, and on the Mac only when the app leaves the screen.
    func testJournalPrivacyShieldCoversJournalOnlyAndIgnoresMacWindowDeactivation() {
        func shield(_ event: JournalPrivacyShieldPolicy.Event, mac: Bool, enabled: Bool = true, visible: Bool = true) -> Bool {
            JournalPrivacyShieldPolicy.shouldShield(
                event: event, isMacCatalyst: mac, shieldsAppSwitcher: enabled, journalIsVisible: visible
            )
        }
        XCTAssertTrue(shield(.willResignActive, mac: false))
        XCTAssertFalse(shield(.willResignActive, mac: false, visible: false), "Nothing private on screen")
        XCTAssertFalse(shield(.willResignActive, mac: false, enabled: false))
        XCTAssertFalse(shield(.willResignActive, mac: true), "Clicking another Mac app must not blank LifeBoard")
        XCTAssertTrue(shield(.didEnterBackground, mac: true))
        XCTAssertFalse(shield(.didEnterBackground, mac: true, visible: false))
    }

    func testFoundationShellChromeStyleFollowsLayoutClassAndTextSize() {
        XCTAssertEqual(FoundationShellChromePolicy.style(layoutClass: .phone, isAccessibilitySize: false), .dock)
        XCTAssertEqual(FoundationShellChromePolicy.style(layoutClass: .padCompact, isAccessibilitySize: false), .dock)
        XCTAssertEqual(FoundationShellChromePolicy.style(layoutClass: .padRegular, isAccessibilitySize: false), .topSwitcher)
        XCTAssertEqual(FoundationShellChromePolicy.style(layoutClass: .padExpanded, isAccessibilitySize: false), .topSwitcher)
        XCTAssertEqual(FoundationShellChromePolicy.style(layoutClass: .padExpanded, isAccessibilitySize: true), .dock)
    }

    func testFoundationCompactChromeVisibilityTracksOnlyPhoneEvaComposerFocus() {
        XCTAssertTrue(FoundationCompactChromeVisibilityPolicy.isVisible(
            destination: .eva,
            screenMode: .detail,
            usesDockChrome: true,
            isEvaComposerFocused: false,
            showsGlobalChrome: true
        ))
        XCTAssertFalse(FoundationCompactChromeVisibilityPolicy.isVisible(
            destination: .eva,
            screenMode: .detail,
            usesDockChrome: true,
            isEvaComposerFocused: true,
            showsGlobalChrome: true
        ))
        XCTAssertTrue(FoundationCompactChromeVisibilityPolicy.isVisible(
            destination: .plan,
            screenMode: .detail,
            usesDockChrome: true,
            isEvaComposerFocused: true,
            showsGlobalChrome: true
        ))
        XCTAssertTrue(FoundationCompactChromeVisibilityPolicy.isVisible(
            destination: .eva,
            screenMode: .detail,
            usesDockChrome: false,
            isEvaComposerFocused: true,
            showsGlobalChrome: true
        ))
        XCTAssertFalse(FoundationCompactChromeVisibilityPolicy.isVisible(
            destination: .home,
            screenMode: .detail,
            usesDockChrome: true,
            isEvaComposerFocused: false,
            showsGlobalChrome: false
        ))
        XCTAssertFalse(FoundationCompactChromeVisibilityPolicy.isVisible(
            destination: .home,
            screenMode: .utility,
            usesDockChrome: true,
            isEvaComposerFocused: false,
            showsGlobalChrome: true
        ))
    }

    func testFloatingChromeNeverRequiresAnOpaqueFooterBand() {
        XCTAssertFalse(HomeBottomBarVisibilityPolicy.usesOpaqueHostBackground)
        XCTAssertLessThanOrEqual(HomeBottomBarVisibilityPolicy.chromeBackdropMaximumOpacity, 0.2)
    }

    func testSelectUpdatesSelectedItem() {
        let state = HomeBottomBarState()

        state.select(.home)
        XCTAssertEqual(state.selectedItem, .home)

        state.select(.calendar)
        XCTAssertEqual(state.selectedItem, .calendar)

        state.select(.charts)
        XCTAssertEqual(state.selectedItem, .charts)

        state.select(.search)
        XCTAssertEqual(state.selectedItem, .search)

        state.select(.chat)
        XCTAssertEqual(state.selectedItem, .chat)

        state.select(.create)
        XCTAssertEqual(state.selectedItem, .create)
    }

    func testSelectedItemDefaultsToHome() {
        let state = HomeBottomBarState()
        XCTAssertEqual(state.selectedItem, .home)
    }

    func testVisibleAnimatedItemsKeepStableTabOrder() {
        XCTAssertEqual(HomeBottomBarItem.visibleAnimatedItems, [
            .home,
            .calendar,
            .chat,
            .charts,
            .create
        ])
    }

    func testIndexForItemUsesVisibleAnimatedOrder() {
        let state = HomeBottomBarState()

        XCTAssertEqual(state.index(for: .home), 0)
        XCTAssertEqual(state.index(for: .calendar), 1)
        XCTAssertEqual(state.index(for: .chat), 2)
        XCTAssertEqual(state.index(for: .charts), 3)
        XCTAssertEqual(state.index(for: .search), 0)
        XCTAssertEqual(state.index(for: .create), 4)
    }

    func testSelectIndexUpdatesSelectedItem() {
        let state = HomeBottomBarState()

        state.selectIndex(4)

        XCTAssertEqual(state.selectedItem, .create)
        XCTAssertEqual(state.selectedIndex, 4)
    }

    func testSelectIndexIgnoresInvalidIndexes() {
        let state = HomeBottomBarState()

        state.selectIndex(-1)
        XCTAssertEqual(state.selectedItem, .home)

        state.selectIndex(HomeBottomBarItem.visibleAnimatedItems.count)
        XCTAssertEqual(state.selectedItem, .home)
    }

    func testMomentaryCreateRestoresLastPersistentSelection() {
        let state = HomeBottomBarState()
        state.select(.calendar)
        state.select(.search)

        state.selectMomentaryCreate()
        XCTAssertEqual(state.selectedItem, .create)

        state.restoreAfterMomentaryCreate()
        XCTAssertEqual(state.selectedItem, .calendar)
    }

    func testMomentaryCreateDoesNotReplacePersistentSelection() {
        let state = HomeBottomBarState()
        state.select(.charts)
        state.selectMomentaryCreate()
        state.selectMomentaryCreate()

        state.restoreAfterMomentaryCreate()

        XCTAssertEqual(state.selectedItem, .charts)
    }

    func testChatDoesNotReplacePersistentSelectionForMomentaryRestore() {
        let state = HomeBottomBarState()
        state.select(.home)
        state.select(.chat)

        state.selectMomentaryCreate()
        state.restoreAfterMomentaryCreate()

        XCTAssertEqual(state.selectedItem, .home)
    }

    func testSelectIndexForChatDoesNotReplacePersistentSelection() {
        let state = HomeBottomBarState()
        state.select(.home)

        state.selectIndex(2)
        XCTAssertEqual(state.selectedItem, .chat)

        state.selectMomentaryCreate()
        state.restoreAfterMomentaryCreate()

        XCTAssertEqual(state.selectedItem, .home)
    }

    func testChatSunriseFaceMapsToChatBottomBarItemAndFullReveal() {
        XCTAssertEqual(HomeSunriseFace.chat.selectedBottomBarItem, .chat)
        XCTAssertTrue(HomeSunriseFace.chat.isBackFace)
        XCTAssertEqual(HomeSunriseFace.chat.surfaceAccessibilityValue, "fullReveal")
    }

    func testChatPromptFocusRequestIncrementsRequestID() {
        let coordinator = HomeFaceCoordinator()

        XCTAssertEqual(coordinator.chatPromptFocusRequestID, 0)

        coordinator.requestChatPromptFocus()
        XCTAssertEqual(coordinator.chatPromptFocusRequestID, 1)

        coordinator.requestChatPromptFocus()
        XCTAssertEqual(coordinator.chatPromptFocusRequestID, 2)
    }

    func testChatBottomBarConcealsWhenPromptFocused() {
        XCTAssertTrue(HomeBottomBarVisibilityPolicy.shouldConcealBottomBar(
            activeFace: .chat,
            isPromptFocused: true,
            keyboardOverlapHeight: 0
        ))
    }

    func testChatBottomBarConcealsWhenKeyboardOverlaps() {
        XCTAssertTrue(HomeBottomBarVisibilityPolicy.shouldConcealBottomBar(
            activeFace: .chat,
            isPromptFocused: false,
            keyboardOverlapHeight: 240
        ))
    }

    func testIdleChatKeepsBottomBarAvailableAndAppliesComposerClearance() {
        XCTAssertFalse(HomeBottomBarVisibilityPolicy.shouldConcealBottomBar(
            activeFace: .chat,
            isPromptFocused: false,
            keyboardOverlapHeight: 0
        ))

        XCTAssertEqual(
            HomeBottomBarVisibilityPolicy.chatComposerClearance(
                layoutClass: .phone,
                bottomOverlayObstruction: 72,
                keyboardOverlapHeight: 0,
                isBottomBarConcealed: false,
                idleSpacing: 40,
                idleExtraSpacing: 24,
                keyboardSpacing: 12,
                regularSpacing: 24
            ),
            136
        )
    }

    func testNonChatFacesDoNotConcealBottomBarForPromptFocusOrKeyboard() {
        XCTAssertFalse(HomeBottomBarVisibilityPolicy.shouldConcealBottomBar(
            activeFace: .tasks,
            isPromptFocused: true,
            keyboardOverlapHeight: 240
        ))
    }

    func testChatComposerClearancePrefersKeyboardOverBottomBar() {
        XCTAssertEqual(
            HomeBottomBarVisibilityPolicy.chatComposerClearance(
                layoutClass: .phone,
                bottomOverlayObstruction: 72,
                keyboardOverlapHeight: 240,
                isBottomBarConcealed: true,
                idleSpacing: 40,
                idleExtraSpacing: 24,
                keyboardSpacing: 16,
                regularSpacing: 24
            ),
            256
        )
    }

    func testChatComposerClearanceUsesRegularSpacingWhenBottomBarIsNotObstructing() {
        XCTAssertEqual(
            HomeBottomBarVisibilityPolicy.chatComposerClearance(
                layoutClass: .phone,
                bottomOverlayObstruction: 0,
                keyboardOverlapHeight: 0,
                isBottomBarConcealed: false,
                idleSpacing: 40,
                idleExtraSpacing: 24,
                keyboardSpacing: 12,
                regularSpacing: 24
            ),
            24
        )
    }

    func testFocusedChatComposerClearanceKeepsIdleLiftBeforeKeyboardFrameArrives() {
        XCTAssertEqual(
            HomeBottomBarVisibilityPolicy.chatComposerClearance(
                layoutClass: .phone,
                bottomOverlayObstruction: 72,
                keyboardOverlapHeight: 0,
                isBottomBarConcealed: true,
                idleSpacing: 40,
                idleExtraSpacing: 24,
                keyboardSpacing: 12,
                regularSpacing: 24
            ),
            136
        )
    }

    func testRestingDockDownshiftAppliesSixPointHostLiftWithoutChangingObstructionMetrics() {
        let safeAreaBottom: CGFloat = 34
        let baselineDownshift = HomeBottomBarVisibilityPolicy.restingDockDownshift(
            safeAreaBottom: safeAreaBottom,
            verticalLift: 0
        )
        let liftedDownshift = HomeBottomBarVisibilityPolicy.restingDockDownshift(
            safeAreaBottom: safeAreaBottom,
            verticalLift: 6
        )

        XCTAssertEqual(baselineDownshift, 24, accuracy: 0.001)
        XCTAssertEqual(liftedDownshift, 18, accuracy: 0.001)
        XCTAssertEqual(baselineDownshift - liftedDownshift, 6, accuracy: 0.001)
        XCTAssertEqual(
            HomeBottomBarVisibilityPolicy.chatComposerClearance(
                layoutClass: .phone,
                bottomOverlayObstruction: 72,
                keyboardOverlapHeight: 0,
                isBottomBarConcealed: false,
                idleSpacing: 40,
                idleExtraSpacing: 24,
                keyboardSpacing: 12,
                regularSpacing: 24
            ),
            136
        )
    }

    func testCalendarBottomBarSymbolBuildsDaySpecificCalendarSFImageNames() {
        XCTAssertEqual(HomeCalendarBottomBarSymbol.symbolName(day: 1), "1.calendar")
        XCTAssertEqual(HomeCalendarBottomBarSymbol.symbolName(day: 31), "31.calendar")
    }

    func testCalendarBottomBarSymbolFallsBackForInvalidDay() {
        XCTAssertEqual(HomeCalendarBottomBarSymbol.symbolName(day: 0), HomeCalendarBottomBarSymbol.defaultSymbol)
        XCTAssertEqual(HomeCalendarBottomBarSymbol.symbolName(day: 32), HomeCalendarBottomBarSymbol.defaultSymbol)
    }

    func testCollapsedChromeStateKeepsBottomBarExpanded() {
        let state = HomeBottomBarState()

        state.handleChromeStateChange(.collapsed)

        XCTAssertFalse(state.isMinimized)
    }

    func testExpandedChromeStateKeepsBottomBarExpanded() {
        let state = HomeBottomBarState()
        state.isMinimized = true

        state.handleChromeStateChange(.expanded)

        XCTAssertFalse(state.isMinimized)
    }

    func testNearTopChromeStateKeepsBottomBarExpanded() {
        let state = HomeBottomBarState()
        state.isMinimized = true

        state.handleChromeStateChange(.nearTop)

        XCTAssertFalse(state.isMinimized)
    }

    func testIdleChromeStateKeepsBottomBarExpanded() {
        let state = HomeBottomBarState()
        state.isMinimized = true

        state.handleChromeStateChange(.idle)

        XCTAssertFalse(state.isMinimized)
    }




}

/// Esc with a text field focused used to leave every sheet open: the field took
/// the key before the Cancel button's `.cancelAction` shortcut saw it.
@MainActor
final class SheetEscapeRouterTests: XCTestCase {
    private var window: UIWindow!
    private var previousKeyWindow: UIWindow?

    override func setUp() async throws {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
    }

    override func tearDown() async throws {
        window.rootViewController?.dismiss(animated: false)
        window.isHidden = true
        window = nil
        previousKeyWindow?.makeKeyAndVisible()
    }

    func testEscapeCommandIsHiddenAndOutranksTextEditing() throws {
        let command = try XCTUnwrap(AppCommandMenu.escapeMenu().children.first as? UIKeyCommand)
        XCTAssertEqual(command.input, UIKeyCommand.inputEscape)
        XCTAssertTrue(command.attributes.contains(.hidden), "A key, not a menu item")
        XCTAssertTrue(command.wantsPriorityOverSystemBehavior, "Must run before the focused field takes Esc")
    }

    func testNothingPresentedLeavesEscapeAlone() {
        XCTAssertEqual(SheetEscapeRouter.shared.resolution(in: window), .none)
        XCTAssertFalse(SheetEscapeRouter.shared.handleEscape(in: window))
    }

    func testRegisteredSheetCancelsEvenWithAFieldFocused() throws {
        var cancelled = 0
        let sheet = present(EscapeProbeSheet { cancelled += 1 })
        let field = try focusField(in: sheet)
        XCTAssertTrue(field.isFirstResponder)

        XCTAssertEqual(SheetEscapeRouter.shared.resolution(in: window), .cancel)
        XCTAssertTrue(SheetEscapeRouter.shared.handleEscape(in: window))
        XCTAssertEqual(cancelled, 1, "Esc runs the sheet's own cancel action")
        XCTAssertFalse(field.isFirstResponder)
    }

    func testSomethingInFrontOfTheSheetKeepsEscape() {
        var cancelled = 0
        let sheet = present(EscapeProbeSheet { cancelled += 1 })
        let alert = UIAlertController(title: "Discard?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep", style: .cancel))
        sheet.present(alert, animated: false)
        settle()
        XCTAssertTrue(sheet.presentedViewController === alert, "Precondition: the alert is in front")

        XCTAssertEqual(SheetEscapeRouter.shared.resolution(in: window), .none)
        XCTAssertFalse(SheetEscapeRouter.shared.handleEscape(in: window))
        XCTAssertEqual(cancelled, 0, "The alert owns Esc, not the sheet behind it")
    }

    func testUnregisteredSheetEndsEditingSoTheNextEscapeReachesItsCancelButton() throws {
        let sheet = UIViewController()
        let field = UITextField(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
        sheet.view.addSubview(field)
        window.rootViewController?.present(sheet, animated: false)
        settle()
        XCTAssertTrue(window.rootViewController?.presentedViewController === sheet, "Precondition: the sheet is in front")
        XCTAssertTrue(field.becomeFirstResponder(), "Precondition: the field is focused")

        XCTAssertEqual(SheetEscapeRouter.shared.resolution(in: window), .endEditing)
        XCTAssertTrue(SheetEscapeRouter.shared.handleEscape(in: window))
        XCTAssertFalse(field.isFirstResponder)
        XCTAssertEqual(SheetEscapeRouter.shared.resolution(in: window), .none)
    }

    func testASheetInAnotherWindowIsNotClosed() throws {
        var cancelled = 0
        present(EscapeProbeSheet { cancelled += 1 })
        let scene = try XCTUnwrap(window.windowScene)
        let other = UIWindow(windowScene: scene)
        other.rootViewController = UIViewController()
        other.makeKeyAndVisible()
        defer { other.isHidden = true }

        XCTAssertEqual(SheetEscapeRouter.shared.resolution(in: other), .none)
        XCTAssertFalse(SheetEscapeRouter.shared.handleEscape(in: other))
        XCTAssertEqual(cancelled, 0)
    }

    @discardableResult
    private func present(_ view: EscapeProbeSheet) -> UIViewController {
        let host = UIHostingController(rootView: view)
        window.rootViewController?.present(host, animated: false)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        settle()
        XCTAssertTrue(window.rootViewController?.presentedViewController === host, "Precondition: the sheet is in front")
        return host
    }

    /// Presentation finishes on a later run-loop turn even when not animated.
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }

    private func focusField(in controller: UIViewController) throws -> UITextField {
        let field = UITextField(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
        controller.view.addSubview(field)
        XCTAssertTrue(field.becomeFirstResponder(), "Precondition: the field is focused")
        return field
    }
}

private struct EscapeProbeSheet: View {
    let onCancel: () -> Void

    var body: some View {
        Text("Probe")
            .escapeCancels(perform: onCancel)
    }
}
