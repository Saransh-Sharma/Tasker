import UIKit

struct DeviceOrientationPolicyResolver {
    func supportedOrientations(for idiom: UIUserInterfaceIdiom) -> UIInterfaceOrientationMask {
        switch idiom {
        case .pad:
            return .all
        default:
            return [.portrait, .portraitUpsideDown]
        }
    }
}
