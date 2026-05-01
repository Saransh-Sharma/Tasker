import XCTest
import UIKit
import CoreData
@testable import To_Do_List

final class HomeViewControllerLifecycleTests: XCTestCase {
    func testStoryboardInstantiatedHomeViewControllerDeallocatesWithoutInjectedDependencies() throws {
        weak var weakController: HomeViewController?
        let storyboard = try XCTUnwrap(mainStoryboard())

        autoreleasepool {
            let controller = storyboard.instantiateViewController(withIdentifier: "homeScreen") as? HomeViewController

            XCTAssertNotNil(controller)
            weakController = controller
        }

        XCTAssertNil(weakController)
    }

    func testDeferredHomeAttachShowsBootstrapFailureWhenInjectionFails() {
        let sceneDelegate = SceneDelegate()
        sceneDelegate.window = UIWindow()

        let result = sceneDelegate.makeDeferredHomeRootController(
            bootstrapState: .ready(makeBootstrapContainer()),
            failureMessage: "Injected failure",
            instantiateHomeViewController: { HomeViewController() },
            tryInject: { _ in false }
        )

        XCTAssertNil(result)
        XCTAssertTrue(sceneDelegate.window?.rootViewController is BootstrapFailureViewController)
    }

    func testLaunchSplashAssetsResolveFromMainBundle() {
        XCTAssertNotNil(
            UIImage(named: "TaskerSplashIcon", in: Bundle.main, compatibleWith: nil)
        )
        XCTAssertNotNil(
            UIColor(named: "LaunchCanvas", in: Bundle.main, compatibleWith: nil)
        )
    }

    func testLaunchSplashCoverScaleOverfillsPortraitAndLandscapeViewports() {
        let portraitSize = CGSize(width: 393, height: 852)
        let landscapeSize = CGSize(width: 852, height: 393)

        XCTAssertGreaterThanOrEqual(
            TaskerLaunchSplashMetrics.iconSide
                * TaskerLaunchSplashMetrics.coverScale(for: portraitSize),
            max(portraitSize.width, portraitSize.height)
                * TaskerLaunchSplashMetrics.coverOverscan
        )
        XCTAssertGreaterThanOrEqual(
            TaskerLaunchSplashMetrics.iconSide
                * TaskerLaunchSplashMetrics.coverScale(for: landscapeSize),
            max(landscapeSize.width, landscapeSize.height)
                * TaskerLaunchSplashMetrics.coverOverscan
        )
    }

    private func mainStoryboard() -> UIStoryboard? {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        for bundle in bundles where bundle.path(forResource: "Main", ofType: "storyboardc") != nil {
            return UIStoryboard(name: "Main", bundle: bundle)
        }
        return nil
    }

    private func makeBootstrapContainer() -> NSPersistentCloudKitContainer {
        NSPersistentCloudKitContainer(name: "HomeLifecycleTests", managedObjectModel: NSManagedObjectModel())
    }
}
