import XCTest
import UIKit
import CoreData
@testable import To_Do_List

final class HomeViewControllerLifecycleTests: XCTestCase {
    func testStoryboardInstantiatedHomeViewControllerDeallocatesWithoutInjectedDependencies() throws {
        weak var weakController: HomeViewController?

        autoreleasepool {
            let storyboard = try XCTUnwrap(mainStoryboard())
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
